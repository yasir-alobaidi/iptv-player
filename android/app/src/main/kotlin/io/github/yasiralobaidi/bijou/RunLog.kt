package io.github.yasiralobaidi.bijou

import android.content.Context
import android.os.Process
import android.util.Log
import java.io.File
import java.io.RandomAccessFile

/**
 * Each run's own logcat, kept in the app's files (ADR-059): every line this process wrote (the
 * engine's, a GPU driver's, the app's log, the keys and the activity's steps from
 * [MainActivity]) up to the moment it ended, however it ended, for the next run's report. Android
 * lets an app read its own lines only, and a TV nobody reaches with adb has no other way to give
 * them.
 *
 * A `logcat` child writes `runlog/run.log` (256 KB, then one older file); the next launch moves
 * both to `runlog/previous.log`. Supervised (hard rule 8): its pid in `runlog/logcat.pid`,
 * stopped when Bijou leaves, killed with the app's process group when Android ends it, and one
 * left over from a run that ended any other way is killed at the next start. Nothing here throws:
 * without it the app runs as before.
 */
object RunLog {
    private const val TAG = "Bijou"
    private const val DIR = "runlog"
    private const val RUN = "run.log"
    private const val PREVIOUS = "previous.log"
    private const val PID = "logcat.pid"
    private const val ROTATE_KB = 256

    /** The run before, as kept: its newest part. */
    private const val MAX_PREVIOUS = 512 * 1024

    private var logcat: java.lang.Process? = null

    /** Bijou is leaving: a start still to come would outlive it. */
    private var stopped = false

    /** Keeps the last run's file and starts this run's: once per process. */
    @Synchronized
    fun start(context: Context) {
        if (logcat != null || stopped) return
        try {
            val dir = File(context.filesDir, DIR).apply { mkdirs() }
            killLeftover(dir)
            keepPrevious(dir)
            val run = File(dir, RUN)
            val pid = File(dir, PID)
            // `$$` is the shell's pid, and logcat's after `exec`.
            val command = "echo \$\$ > '${pid.path}'; exec logcat -v threadtime " +
                "--pid=${Process.myPid()} -b main -b system -b crash " +
                "-f '${run.path}' -r $ROTATE_KB -n 1 > /dev/null 2>&1"
            logcat = ProcessBuilder("/system/bin/sh", "-c", command).start().apply {
                outputStream.close()
                inputStream.close()
                errorStream.close()
            }
            Log.i(TAG, "This run's log is kept (pid ${Process.myPid()})")
        } catch (e: Throwable) {
            Log.w(TAG, "This run's log couldn't be kept", e)
        }
    }

    /** Bijou is leaving by itself: its logcat goes too, or it would outlive the process. */
    @Synchronized
    fun stop(context: Context) {
        stopped = true
        try {
            logcat?.destroy()
            logcat = null
            File(File(context.filesDir, DIR), PID).delete()
        } catch (e: Throwable) {
            Log.w(TAG, "This run's logcat couldn't be stopped", e)
        }
    }

    /** `{previous, current}`: the run before's lines and this run's, each its newest [maxBytes]. */
    fun read(context: Context, maxBytes: Int): Map<String, String?> {
        val dir = File(context.filesDir, DIR)
        return mapOf(
            "previous" to tail(listOf(File(dir, PREVIOUS)), maxBytes),
            "current" to tail(listOf(File(dir, "$RUN.1"), File(dir, RUN)), maxBytes),
        )
    }

    private fun killLeftover(dir: File) {
        val pidFile = File(dir, PID)
        val pid = pidFile.takeIf { it.isFile }?.readText()?.trim()?.toIntOrNull()
        pidFile.delete()
        if (pid == null || pid == Process.myPid()) return
        // A pid is reused: only a logcat of this app's is ours to end.
        val command = File("/proc/$pid/cmdline").takeIf { it.canRead() }?.readText().orEmpty()
        if (command.startsWith("logcat")) {
            Process.killProcess(pid)
            Log.i(TAG, "A logcat left by an earlier run was stopped")
        }
    }

    private fun keepPrevious(dir: File) {
        val parts = listOf(File(dir, "$RUN.1"), File(dir, RUN)).filter { it.isFile }
        if (parts.isEmpty()) return
        val previous = File(dir, PREVIOUS)
        val text = tail(parts, MAX_PREVIOUS)
        if (text != null) previous.writeText(text) else previous.delete()
        parts.forEach { it.delete() }
    }

    /** The newest [maxBytes] of [files] in order, from a whole line; null when there is none. */
    private fun tail(files: List<File>, maxBytes: Int): String? = try {
        val present = files.filter { it.isFile && it.length() > 0 }
        var left = maxBytes.toLong()
        val parts = ArrayDeque<String>()
        for (file in present.reversed()) {
            if (left <= 0) break
            RandomAccessFile(file, "r").use { input ->
                val from = maxOf(0L, input.length() - left)
                input.seek(from)
                val bytes = ByteArray((input.length() - from).toInt())
                input.readFully(bytes)
                var text = String(bytes, Charsets.UTF_8)
                if (from > 0) text = text.substringAfter('\n', "")
                parts.addFirst(text)
                left -= bytes.size
            }
        }
        parts.joinToString("").ifEmpty { null }
    } catch (e: Exception) {
        Log.w(TAG, "A run's log couldn't be read", e)
        null
    }
}
