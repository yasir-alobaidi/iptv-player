package io.github.yasiralobaidi.bijou

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.InputStream
import java.util.concurrent.Executors

/**
 * Why Bijou's last runs ended (ADR-058), for `lib/data/platform/android_last_exits.dart` over
 * `bijou/exits`, so a TV nobody can reach with adb says itself what went wrong.
 *
 * - `read` → `{exits, seenUpTo, drawing}`: Android's own record of the app's last ends (Android 11
 *   and later; none before), newest first, each `{time, reason, status, importance, pssKb, rssKb,
 *   description, byBijou}` and what was kept of a crash: a native crash's `signal`, `thread`,
 *   `abort`, `cause`, `frames` and `drawing` (its tombstone, Android 12 and later), a Java crash's
 *   or an ANR's `trace`. `seenUpTo` is the newest end already told; `drawing` is [Drawing.state].
 * - `seen {upTo}` → remembers the newest end told.
 *
 * Read off the main thread (a tombstone is a few hundred KB). Nothing here throws to Dart: what
 * fails is logged (tag "Bijou") and left out.
 */
class LastExits(private val context: Context, messenger: BinaryMessenger) :
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
            "read" -> worker.execute {
                val answer = read()
                main.post { result.success(answer) }
            }
            "seen" -> result.success(seen(call))
            else -> result.notImplemented()
        }
    }

    private fun read(): Map<String, Any?> = try {
        val leftAt = prefs(context).getLong(LEFT_AT, 0L)
        mapOf(
            "exits" to recent(context).map { describe(it, leftAt) },
            "seenUpTo" to prefs(context).getLong(SEEN_UP_TO, 0L),
            "drawing" to Drawing.state(context),
        )
    } catch (e: Throwable) {
        Log.w(TAG, "The app's last ends couldn't be read", e)
        mapOf("exits" to emptyList<Any>(), "drawing" to Drawing.state(context))
    }

    private fun seen(call: MethodCall): Boolean = try {
        val upTo = (call.argument<Any?>("upTo") as? Number)?.toLong()
        if (upTo != null) prefs(context).edit().putLong(SEEN_UP_TO, upTo).apply()
        upTo != null
    } catch (e: Exception) {
        Log.w(TAG, "The last end told couldn't be kept", e)
        false
    }

    @RequiresApi(Build.VERSION_CODES.R)
    private fun describe(info: ApplicationExitInfo, leftAt: Long): Map<String, Any?> {
        val exit = mutableMapOf<String, Any?>(
            "time" to info.timestamp,
            "reason" to reasonName(info.reason),
            "status" to info.status,
            "importance" to info.importance,
            "pssKb" to info.pss,
            "rssKb" to info.rss,
            "description" to info.description?.take(TEXT_CHARS),
            // Back on Home ends the process itself (MainActivity.onDestroy, ADR-032).
            "byBijou" to (leftAt != 0L && info.timestamp - leftAt in 0..LEAVE_WINDOW_MS),
        )
        when (info.reason) {
            ApplicationExitInfo.REASON_CRASH_NATIVE -> nativeCrash(info)?.let { crash ->
                exit["signal"] = crash.signal
                exit["thread"] = crash.thread
                exit["abort"] = crash.abort?.take(TEXT_CHARS)
                exit["cause"] = crash.cause?.take(TEXT_CHARS)
                exit["frames"] = crash.frames.take(FRAMES).map { it.line() }
                exit["drawing"] = Drawing.isDrawingCrash(crash)
            }
            ApplicationExitInfo.REASON_ANR -> exit["trace"] = anrTrace(info)
            ApplicationExitInfo.REASON_CRASH -> exit["trace"] = JavaCrashes.near(context, info.timestamp)
        }
        return exit
    }

    @RequiresApi(Build.VERSION_CODES.R)
    private fun anrTrace(info: ApplicationExitInfo): String? = try {
        val lines = info.traceInputStream?.use { readAtMost(it, MAX_TRACE_BYTES) }
            ?.toString(Charsets.UTF_8)?.lines() ?: return null
        // The main thread's stack is what was stuck.
        val start = lines.indexOfFirst { it.startsWith("\"main\"") }
        lines.drop(maxOf(start, 0)).take(TRACE_LINES).joinToString("\n")
    } catch (e: Exception) {
        Log.w(TAG, "An ANR's trace couldn't be read", e)
        null
    }

    companion object {
        private const val CHANNEL = "bijou/exits"
        private const val TAG = "Bijou"
        private const val PREFS = "bijou_exits"
        private const val SEEN_UP_TO = "seenUpTo"
        private const val LEFT_AT = "leftAt"

        /** The newest ends kept: enough for a crash and the launches after it. */
        private const val MAX_EXITS = 5
        private const val FRAMES = 16
        private const val TRACE_LINES = 40
        private const val TEXT_CHARS = 600
        private const val MAX_TRACE_BYTES = 8 shl 20

        /** An end this soon after Back on Home was that Back. */
        private const val LEAVE_WINDOW_MS = 10_000L

        private fun prefs(context: Context) =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        /** The app's newest ends, newest first; none before Android 11. */
        fun recent(context: Context): List<ApplicationExitInfo> {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return emptyList()
            val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                ?: return emptyList()
            return manager.getHistoricalProcessExitReasons(context.packageName, 0, MAX_EXITS)
                .filter { it.processName == context.packageName }
        }

        /** A native crash's tombstone (Android 12 and later); null when none was kept. */
        @RequiresApi(Build.VERSION_CODES.R)
        fun nativeCrash(info: ApplicationExitInfo): NativeCrash? = try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                null
            } else {
                info.traceInputStream?.use { Tombstone.read(readAtMost(it, MAX_TRACE_BYTES)) }
            }
        } catch (e: Throwable) {
            Log.w(TAG, "A native crash's tombstone couldn't be read", e)
            null
        }

        /** Back on Home is about to end the process: its end is the app's own. */
        fun leaving(context: Context) {
            try {
                prefs(context).edit().putLong(LEFT_AT, System.currentTimeMillis()).commit()
            } catch (e: Exception) {
                Log.w(TAG, "The leave couldn't be noted", e)
            }
        }

        private fun reasonName(reason: Int): String = when (reason) {
            ApplicationExitInfo.REASON_EXIT_SELF -> "exitSelf"
            ApplicationExitInfo.REASON_SIGNALED -> "signaled"
            ApplicationExitInfo.REASON_LOW_MEMORY -> "lowMemory"
            ApplicationExitInfo.REASON_CRASH -> "crash"
            ApplicationExitInfo.REASON_CRASH_NATIVE -> "crashNative"
            ApplicationExitInfo.REASON_ANR -> "anr"
            ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "initializationFailure"
            ApplicationExitInfo.REASON_PERMISSION_CHANGE -> "permissionChange"
            ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "excessiveResourceUsage"
            ApplicationExitInfo.REASON_USER_REQUESTED -> "userRequested"
            ApplicationExitInfo.REASON_USER_STOPPED -> "userStopped"
            ApplicationExitInfo.REASON_DEPENDENCY_DIED -> "dependencyDied"
            ApplicationExitInfo.REASON_OTHER -> "other"
            // Android 13's and 14's, by number: their names aren't in every SDK level's.
            14 -> "freezer"
            15 -> "packageStateChange"
            16 -> "packageUpdated"
            else -> "unknown"
        }

        private fun readAtMost(input: InputStream, limit: Int): ByteArray {
            val out = java.io.ByteArrayOutputStream()
            val buffer = ByteArray(64 * 1024)
            while (out.size() < limit) {
                val read = input.read(buffer, 0, minOf(buffer.size, limit - out.size()))
                if (read < 0) break
                out.write(buffer, 0, read)
            }
            return out.toByteArray()
        }
    }
}

/** What a native crash's tombstone says of it: the crashing thread and where it was. */
class NativeCrash(
    val signal: String?,
    val thread: String?,
    val abort: String?,
    val cause: String?,
    val frames: List<Frame>,
) {
    class Frame(val relPc: Long, val file: String, val function: String?, val offset: Long) {
        /** `pc 0000000000521385 libflutter.so`, `pc 00000000000b2747 libc.so (read+7)`. */
        fun line(): String {
            val name = file.substringAfterLast('!').substringAfterLast('/')
            val at = function?.takeIf { it.isNotEmpty() }
                ?.let { " (${withoutParameters(it)}+$offset)" }
                ?: ""
            return "pc ${relPc.toString(16).padStart(16, '0')} $name$at"
        }

        /**
         * `egl_window_surface_t::swapBuffers` for `egl_window_surface_t::swapBuffers() const`: a
         * C++ name's parameters fill a photo of the screen and say little.
         */
        private fun withoutParameters(function: String): String {
            val name = function.removeSuffix(" const")
            if (!name.endsWith(')')) return function
            var depth = 0
            for (i in name.indices.reversed()) {
                when (name[i]) {
                    ')' -> depth++
                    '(' -> if (--depth == 0) return name.substring(0, i).ifEmpty { function }
                }
            }
            return function
        }
    }
}

/**
 * Android 12's tombstone (`system/core/debuggerd/proto/tombstone.proto`), only as far as
 * [NativeCrash] needs: the crashing thread's id (6), the signal (10: its name 2, code name 4),
 * the abort message (14), the first cause (15: 1), and the threads (16, a map of id to thread:
 * id 1, name 2, frames 4: rel_pc 1, function 4, offset 5, file 6). Anything else is skipped,
 * and a tombstone that can't be read is null.
 */
object Tombstone {
    fun read(bytes: ByteArray): NativeCrash? = try {
        var tid = -1L
        var signal: String? = null
        var abort: String? = null
        var cause: String? = null
        val threads = mutableMapOf<Long, Wire.Span>()
        Wire(bytes).fields { number, wire ->
            when (number) {
                6 -> tid = wire.long()
                10 -> signal = signalOf(wire.span())
                14 -> abort = wire.string()
                15 -> if (cause == null) cause = firstString(wire.span(), 1)
                16 -> {
                    var key = -1L
                    var value: Wire.Span? = null
                    wire.span().fields { n, w ->
                        when (n) {
                            1 -> key = w.long()
                            2 -> value = w.span()
                            else -> w.skip()
                        }
                    }
                    value?.let { threads[key] = it }
                }
                else -> wire.skip()
            }
        }
        val crashed = threads[tid]
        var name: String? = null
        val frames = mutableListOf<NativeCrash.Frame>()
        crashed?.fields { number, wire ->
            when (number) {
                2 -> name = wire.string()
                4 -> frames += frameOf(wire.span())
                else -> wire.skip()
            }
        }
        NativeCrash(signal, name, abort, cause, frames)
    } catch (e: Exception) {
        Log.w("Bijou", "A tombstone couldn't be read", e)
        null
    }

    private fun signalOf(span: Wire.Span): String? {
        var name: String? = null
        var code: String? = null
        span.fields { number, wire ->
            when (number) {
                2 -> name = wire.string()
                4 -> code = wire.string()
                else -> wire.skip()
            }
        }
        return listOfNotNull(name, code?.takeIf { it.isNotEmpty() }).joinToString(" ").ifEmpty { null }
    }

    private fun firstString(span: Wire.Span, field: Int): String? {
        var found: String? = null
        span.fields { number, wire -> if (number == field && found == null) found = wire.string() else wire.skip() }
        return found
    }

    private fun frameOf(span: Wire.Span): NativeCrash.Frame {
        var relPc = 0L
        var function: String? = null
        var offset = 0L
        var file = ""
        span.fields { number, wire ->
            when (number) {
                1 -> relPc = wire.long()
                4 -> function = wire.string()
                5 -> offset = wire.long()
                6 -> file = wire.string()
                else -> wire.skip()
            }
        }
        return NativeCrash.Frame(relPc, file, function, offset)
    }
}

/** Protocol buffers' wire format, read field by field with no schema. */
class Wire(private val bytes: ByteArray, private val start: Int = 0, private val end: Int = bytes.size) {
    class Span(val bytes: ByteArray, val start: Int, val end: Int) {
        fun fields(each: (Int, Field) -> Unit) = Wire(bytes, start, end).fields(each)
    }

    /** The field being read: one of its readers, or [skip], must be called once. */
    inner class Field(private val type: Int) {
        fun long(): Long = if (type == 0) varint() else { skip(); 0L }

        fun span(): Span {
            if (type != 2) {
                skip()
                return Span(bytes, 0, 0)
            }
            val length = varint().toInt()
            require(length >= 0 && pos + length <= end) { "a field runs past its message" }
            return Span(bytes, pos, pos + length).also { pos += length }
        }

        fun string(): String {
            val span = span()
            return String(bytes, span.start, span.end - span.start, Charsets.UTF_8)
        }

        fun skip() {
            when (type) {
                0 -> varint()
                1 -> pos += 8
                2 -> span()
                5 -> pos += 4
                else -> throw IllegalArgumentException("wire type $type")
            }
        }
    }

    private var pos = start

    fun fields(each: (Int, Field) -> Unit) {
        while (pos < end) {
            val key = varint()
            each((key ushr 3).toInt(), Field((key and 7).toInt()))
        }
        require(pos == end) { "a message runs past its end" }
    }

    private fun varint(): Long {
        var result = 0L
        var shift = 0
        while (true) {
            require(pos < end && shift < 64) { "a number runs past its message" }
            val byte = bytes[pos++].toInt()
            result = result or ((byte and 0x7f).toLong() shl shift)
            if (byte and 0x80 == 0) return result
            shift += 7
        }
    }
}

/**
 * A Java crash's stack, kept in the app's files as it happens: Android keeps none of it for
 * [LastExits] (only "crash"). Installed by [MainActivity] before anything else.
 */
object JavaCrashes {
    private const val MAX_CHARS = 16_000

    /** A crash written this long before the end it caused is that end's. */
    private const val WINDOW_MS = 60_000L

    private fun file(context: Context) = File(context.filesDir, "crash/java.txt")

    fun install(context: Context) {
        val file = file(context.applicationContext)
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        if (previous is Recorder) return
        Thread.setDefaultUncaughtExceptionHandler(Recorder(file, previous))
    }

    /** The stack written just before [time], when there is one. */
    fun near(context: Context, time: Long): String? = try {
        val lines = file(context).takeIf { it.isFile }?.readLines()
        val written = lines?.firstOrNull()?.toLongOrNull()
        if (lines == null || written == null || time - written !in -5_000L..WINDOW_MS) {
            null
        } else {
            lines.drop(1).take(40).joinToString("\n")
        }
    } catch (e: Exception) {
        Log.w("Bijou", "A Java crash's stack couldn't be read", e)
        null
    }

    private class Recorder(
        private val file: File,
        private val next: Thread.UncaughtExceptionHandler?,
    ) : Thread.UncaughtExceptionHandler {
        override fun uncaughtException(thread: Thread, error: Throwable) {
            try {
                file.parentFile?.mkdirs()
                file.writeText(
                    "${System.currentTimeMillis()}\nthread ${thread.name}\n" +
                        Log.getStackTraceString(error).take(MAX_CHARS),
                )
            } catch (_: Throwable) {
                // The crash goes on as before.
            }
            next?.uncaughtException(thread, error)
        }
    }
}
