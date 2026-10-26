package io.github.yasiralobaidi.bijou

import android.app.ActivityManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * What a TV's report says of the TV (ADR-059), for `lib/data/platform/android_system_facts.dart`
 * and `android_run_logs.dart` over `bijou/system`:
 *
 * - `facts` → the model and its chip, Android, the kernel, the GPU's drivers as the system names
 *   them, Vulkan's and OpenGL ES's versions, the memory and what the app may use of it.
 * - `version` → `{version, build_number}` from the app's package: Flutter writes no
 *   `version.json` into an APK, so About and the report said "version unknown" on a TV.
 * - `runLogs {maxBytes}` → [RunLog.read]: the run before's own logcat and this run's.
 *
 * Read off the main thread. Nothing here throws to Dart: what can't be read is left out.
 */
class SystemInfo(private val context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, CHANNEL)
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()

    init {
        channel.setMethodCallHandler(this)
    }

    fun release() {
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "facts" -> answer(result) { facts() }
            "version" -> answer(result) { version() }
            "runLogs" -> {
                val maxBytes = (call.argument<Any?>("maxBytes") as? Number)?.toInt() ?: MAX_LOG
                answer(result) { RunLog.read(context, maxBytes.coerceIn(0, MAX_LOG)) }
            }
            else -> result.notImplemented()
        }
    }

    private fun answer(result: MethodChannel.Result, read: () -> Any?) = worker.execute {
        val answer = try {
            read()
        } catch (e: Throwable) {
            Log.w(TAG, "What the report says of the TV couldn't be read", e)
            null
        }
        main.post { result.success(answer) }
    }

    private fun facts(): Map<String, Any?> {
        val facts = mutableMapOf<String, Any?>(
            "manufacturer" to Build.MANUFACTURER,
            "brand" to Build.BRAND,
            "model" to Build.MODEL,
            "device" to Build.DEVICE,
            "board" to Build.BOARD,
            "hardware" to Build.HARDWARE,
            "release" to Build.VERSION.RELEASE,
            "sdk" to Build.VERSION.SDK_INT,
            "securityPatch" to Build.VERSION.SECURITY_PATCH,
            "build" to Build.DISPLAY,
            "kernel" to System.getProperty("os.version"),
            "abis" to Build.SUPPORTED_ABIS.joinToString(","),
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            facts["socManufacturer"] = Build.SOC_MANUFACTURER
            facts["socModel"] = Build.SOC_MODEL
        }
        facts += properties()
        facts += memory()
        facts += graphics()
        facts["freeStorageMb"] = context.filesDir.usableSpace / MB
        return facts
    }

    private fun version(): Map<String, String?> {
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
        return mapOf("version" to info.versionName, "build_number" to code.toString())
    }

    /** The few system properties that name the chip and its drivers, from one `getprop`. */
    private fun properties(): Map<String, String> = try {
        // Its output ends as it does; destroyed whatever happens (hard rule 8).
        val getprop = ProcessBuilder("/system/bin/getprop").redirectErrorStream(true).start()
        val lines = try {
            getprop.inputStream.bufferedReader().use { it.readLines() }
        } finally {
            getprop.destroy()
        }
        // `[ro.board.platform]: [mt5862]`
        val line = Regex("""^\[([^\]]+)\]: \[(.*)\]$""")
        lines.mapNotNull { line.find(it.trim())?.destructured }
            .filter { (name, value) -> name in PROPERTIES && value.isNotBlank() }
            .associate { (name, value) -> "prop:$name" to value.take(200) }
    } catch (e: Exception) {
        Log.w(TAG, "The system's properties couldn't be read", e)
        emptyMap()
    }

    private fun memory(): Map<String, Any?> {
        val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            ?: return emptyMap()
        val info = ActivityManager.MemoryInfo().also { manager.getMemoryInfo(it) }
        return mapOf(
            "totalMb" to info.totalMem / MB,
            "availableMb" to info.availMem / MB,
            "lowMemoryMb" to info.threshold / MB,
            "lowRam" to manager.isLowRamDevice,
            "heapMb" to manager.memoryClass,
            "largeHeapMb" to manager.largeMemoryClass,
            "glEs" to manager.deviceConfigurationInfo?.glEsVersion,
        )
    }

    /** The newest Vulkan the hardware says it has: `1.1`; none without Vulkan. */
    private fun graphics(): Map<String, Any?> {
        val packages = context.packageManager
        val vulkan = listOf(3, 2, 1, 0).firstOrNull { minor ->
            packages.hasSystemFeature(PackageManager.FEATURE_VULKAN_HARDWARE_VERSION, (1 shl 22) or (minor shl 12))
        }
        return mapOf("vulkan" to vulkan?.let { "1.$it" })
    }

    companion object {
        private const val CHANNEL = "bijou/system"
        private const val TAG = "Bijou"
        private const val MB = 1024L * 1024L

        /** A run's log, at most: the report's whole file stays a phone's quick download. */
        private const val MAX_LOG = 512 * 1024

        private val PROPERTIES = setOf(
            "ro.board.platform", "ro.hardware.egl", "ro.hardware.vulkan", "ro.hardware.gralloc",
            "ro.opengles.version", "ro.product.name", "ro.vendor.product.model",
            "ro.mediatek.platform", "ro.soc.manufacturer", "ro.soc.model", "ro.config.low_ram",
            "dalvik.vm.heapgrowthlimit", "ro.product.first_api_level", "ro.vendor.build.fingerprint",
            // What Flutter's own choice of Vulkan reads (android_context_dynamic_impeller.cc).
            "ro.vendor.build.version.sdk", "ro.vendor.mediatek.platform",
        )
    }
}
