package com.trevioncrm

import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.telecom.TelecomManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.trevioncrm/dialer"
    private val RECORDING_CHANNEL = "com.trevioncrm/recording_extraction"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        setupRecordingChannel(flutterEngine)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Recording Channel Setup
    // ─────────────────────────────────────────────────────────────────────────

    private fun setupRecordingChannel(flutterEngine: FlutterEngine) {
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RECORDING_CHANNEL)

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "findLatestRecording" -> {
                    val phoneNumber = call.argument<String>("phoneNumber") ?: ""
                    val expectedDuration = call.argument<Int>("expectedDurationSeconds") ?: 0
                    try {
                        val recordingInfo = findLatestRecording(phoneNumber, expectedDuration)
                        result.success(recordingInfo)
                    } catch (e: Exception) {
                        android.util.Log.e("RecordingExtraction", "Error finding recording: ${e.message}", e)
                        result.error("EXTRACTION_ERROR", e.message, null)
                    }
                }
                "checkAudioPermission" -> {
                    result.success(hasAudioPermission())
                }
                "dumpDirectories" -> {
                    result.success(dumpMediaStoreInfo())
                }
                else -> result.notImplemented()
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Permission Check (scoped storage only)
    // ─────────────────────────────────────────────────────────────────────────

    private fun hasAudioPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Android 13+: READ_MEDIA_AUDIO
            checkSelfPermission(android.Manifest.permission.READ_MEDIA_AUDIO) == PackageManager.PERMISSION_GRANTED
        } else {
            // Android 12 and below: READ_EXTERNAL_STORAGE
            checkSelfPermission(android.Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MediaStore-based Recording Search (Scoped Storage compliant)
    //
    // Uses MediaStore.Audio.Media ContentResolver queries instead of
    // File.listFiles() on raw external storage paths.
    // This works with READ_MEDIA_AUDIO / READ_EXTERNAL_STORAGE only.
    // MANAGE_EXTERNAL_STORAGE is NOT required or used.
    // ─────────────────────────────────────────────────────────────────────────

    private fun findLatestRecording(phoneNumber: String, expectedDurationSeconds: Int): Map<String, Any?> {
        val context = applicationContext
        val now = System.currentTimeMillis()
        val windowMs = 90L * 60 * 1000 // 90-minute search window

        val cleanNumber = phoneNumber.replace(Regex("\\D"), "")
        val last10 = if (cleanNumber.length >= 10) cleanNumber.takeLast(10) else cleanNumber
        val last7 = if (cleanNumber.length >= 7) cleanNumber.takeLast(7) else cleanNumber
        val expectedDurationMs = expectedDurationSeconds * 1000L

        android.util.Log.d("RecordingExtraction", "Searching for: $phoneNumber (clean: $cleanNumber)")

        // ── Tier 1: MediaStore with 90-minute time window ────────────────────
        var candidate = searchMediaStore(
            context, now, windowMs, cleanNumber, last10, last7, expectedDurationMs
        )

        // ── Tier 2: MediaStore without date filter ───────────────────────────
        // Some OEMs write the DATE_MODIFIED field with a significant delay or
        // use the original recording timestamp, which can differ from 'now'.
        if (candidate == null) {
            android.util.Log.d("RecordingExtraction", "Tier-1 empty. Retrying MediaStore without date filter...")
            candidate = searchMediaStore(
                context, now, Long.MAX_VALUE / 2, cleanNumber, last10, last7, expectedDurationMs
            )
        }

        // ── Tier 3: Direct file-system scan (OEMs that skip MediaStore) ──────
        // OnePlus/ColorOS, Xiaomi/MIUI, Huawei/EMUI, Samsung etc. often save
        // call recordings to fixed directories without indexing them in the
        // shared MediaStore.  We can read these files directly if we hold
        // READ_MEDIA_AUDIO (API 33+) or READ_EXTERNAL_STORAGE (API ≤32).
        if (candidate == null) {
            android.util.Log.d("RecordingExtraction", "Tier-2 empty. Trying file-system scan...")
            val fsFile = findViaFileSystem(now, windowMs, cleanNumber, last10, last7, expectedDurationMs)
            if (fsFile != null) {
                android.util.Log.d("RecordingExtraction", "File-system hit: ${fsFile.absolutePath}")
                val appDir = File(context.filesDir, "call_recordings")
                if (!appDir.exists()) appDir.mkdirs()
                cleanupOldRecordings(appDir, maxAgeMs = 24L * 60 * 60 * 1000)
                val copiedPath = copyFileToAppStorage(fsFile, appDir)
                if (copiedPath != null) {
                    val copiedFile = File(copiedPath)
                    val actualDurationMs = getAudioDurationFromFile(copiedFile)
                    return mapOf(
                        "filePath"        to copiedPath,
                        "originalPath"    to fsFile.absolutePath,
                        "displayName"     to fsFile.name,
                        "durationSeconds" to (actualDurationMs / 1000),
                        "sizeBytes"       to fsFile.length(),
                        "mimeType"        to "audio/*",
                        "confidenceScore" to 10
                    )
                }
            }
        }

        if (candidate == null) {
            android.util.Log.w("RecordingExtraction", "No recording found via any tier")
            return mapOf("error" to "No recording found")
        }

        android.util.Log.d("RecordingExtraction",
            "Best candidate: ${candidate.displayName} (score: ${candidate.score}, uri: ${candidate.uri})")

        // Copy from MediaStore URI to app-private storage.
        val copiedPath = copyUriToAppStorage(context, candidate.uri, candidate.displayName)
        if (copiedPath == null) {
            return mapOf("error" to "Failed to copy recording to app storage")
        }

        val copiedFile = File(copiedPath)
        val actualDurationMs = getAudioDurationFromFile(copiedFile)

        return mapOf(
            "filePath"        to copiedPath,
            "originalPath"    to candidate.uri.toString(),
            "displayName"     to candidate.displayName,
            "durationSeconds" to (actualDurationMs / 1000),
            "sizeBytes"       to candidate.sizeBytes,
            "mimeType"        to candidate.mimeType,
            "confidenceScore" to candidate.score
        )
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MediaStore Query
    // ─────────────────────────────────────────────────────────────────────────

    private data class MediaCandidate(
        val uri: Uri,
        val displayName: String,
        val sizeBytes: Long,
        val mimeType: String,
        val score: Int
    )

    private fun searchMediaStore(
        context: Context,
        now: Long,
        windowMs: Long,
        cleanNumber: String,
        last10: String,
        last7: String,
        expectedDurationMs: Long
    ): MediaCandidate? {
        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }

        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.MIME_TYPE,
            MediaStore.Audio.Media.DATE_MODIFIED,
            MediaStore.Audio.Media.RELATIVE_PATH
        )

        // Filter: only files modified within the search window.
        val cutoffSecs = (now - windowMs) / 1000
        val selection = "${MediaStore.Audio.Media.DATE_MODIFIED} >= ?"
        val selectionArgs = arrayOf(cutoffSecs.toString())
        val sortOrder = "${MediaStore.Audio.Media.DATE_MODIFIED} DESC"

        val validExtensions = setOf(".m4a", ".mp3", ".wav", ".amr", ".aac", ".3gp", ".ogg")
        var bestCandidate: MediaCandidate? = null
        var bestScore = 0

        context.contentResolver.query(
            collection, projection, selection, selectionArgs, sortOrder
        )?.use { cursor ->
            val idCol           = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val nameCol         = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)
            val sizeCol         = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
            val durationCol     = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            val mimeCol         = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.MIME_TYPE)
            // RELATIVE_PATH was added in Android Q (API 29). Use getColumnIndex
            // (not getColumnIndexOrThrow) so Android 9 (API 28) devices don't crash.
            val relPathCol      = cursor.getColumnIndex(MediaStore.Audio.Media.RELATIVE_PATH)

            android.util.Log.d("RecordingExtraction", "MediaStore query returned ${cursor.count} audio files in window")

            while (cursor.moveToNext()) {
                val displayName  = cursor.getString(nameCol) ?: continue
                val sizeBytes    = cursor.getLong(sizeCol)
                val durationMs   = cursor.getLong(durationCol)
                val mimeType     = cursor.getString(mimeCol) ?: "audio/*"
                // Guard: relPathCol is -1 on Android 9 (API 28) where RELATIVE_PATH doesn't exist.
                val relativePath = if (relPathCol >= 0) cursor.getString(relPathCol) ?: "" else ""
                val id           = cursor.getLong(idCol)

                // Skip tiny files.
                if (sizeBytes < 1024) continue

                // Skip very short clips (< 5 seconds).
                if (durationMs in 1..4999) continue

                // Extension filter.
                val nameLower = displayName.lowercase()
                if (!validExtensions.any { nameLower.endsWith(it) }) continue

                // Skip music/podcast files.
                if (nameLower.contains("music") || nameLower.contains("song") || nameLower.contains("podcast")) continue

                // Duration match check.
                // Tolerance = max(60 s, 50 % of expected duration).
                // This handles:
                //   • Dialing/ringing time counted differently by each OEM
                //   • MediaStore DURATION vs CallLog.duration discrepancies
                //   • Clock drift between the app process and the system
                if (expectedDurationMs > 0 && durationMs > 0) {
                    val diff = kotlin.math.abs(durationMs - expectedDurationMs)
                    val tolerance = maxOf(60_000L, expectedDurationMs / 2)
                    if (diff > tolerance) {
                        android.util.Log.d("RecordingExtraction",
                            "  Duration mismatch: $displayName got ${durationMs/1000}s expected ${expectedDurationMs/1000}s (tolerance ${tolerance/1000}s)")
                        continue
                    }
                }

                val score = calculateConfidenceScore(displayName, relativePath, cleanNumber, last10, last7)
                // Require at least one positive signal (path or filename keyword, or phone number).
                // Score 0 = no signals at all (music/podcast that slipped the name filter).
                if (score < 1) continue

                android.util.Log.d("RecordingExtraction",
                    "  Candidate: $displayName path=$relativePath score=$score dur=${durationMs/1000}s")

                if (score > bestScore) {
                    val contentUri = ContentUris.withAppendedId(collection, id)
                    bestCandidate = MediaCandidate(
                        uri         = contentUri,
                        displayName = displayName,
                        sizeBytes   = sizeBytes,
                        mimeType    = mimeType,
                        score       = score
                    )
                    bestScore = score
                }
            }
        } ?: run {
            android.util.Log.w("RecordingExtraction", "MediaStore query returned null cursor")
        }

        return bestCandidate
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Confidence Scoring
    // ─────────────────────────────────────────────────────────────────────────

    private fun calculateConfidenceScore(
        filename: String,
        relativePath: String,
        cleanNumber: String,
        last10: String,
        last7: String
    ): Int {
        var score = 0
        val name = filename.lowercase()
        val path = relativePath.lowercase()

        // Path-based signals (recording directories).
        if (path.contains("recording"))   score += 5  // Recordings/, callrecording (Google Dialer)
        if (path.contains("call"))         score += 5  // Call/, Recordings/Call
        if (path.contains("record"))       score += 3  // Record/, PhoneRecord
        if (path.contains("phonerecord"))  score += 5  // OxygenOS PhoneRecord
        if (path.contains("sound_rec"))    score += 4  // MIUI sound_recorder
        if (path.contains("voice"))        score += 2

        // Filename signals.
        if (name.contains("call recording")) score += 10
        if (name.contains("call")) score += 3
        if (name.contains("rec")) score += 2

        // Phone number match.
        if (cleanNumber.isNotEmpty()) {
            when {
                filename.contains(cleanNumber) -> score += 15
                filename.contains(last10)      -> score += 8
                filename.contains(last7)       -> score += 4
            }
        }

        // Date stamp in filename.
        if (Regex("\\d{8}|\\d{4}[-_]\\d{2}[-_]\\d{2}").containsMatchIn(filename)) score += 2

        return score
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Copy URI → App-Private Storage
    // ─────────────────────────────────────────────────────────────────────────

    private fun copyUriToAppStorage(context: Context, uri: Uri, displayName: String): String? {
        return try {
            val appDir = File(context.filesDir, "call_recordings")
            if (!appDir.exists()) appDir.mkdirs()

            // ── Auto-cleanup: delete copies older than 24 hours ──────────────
            // The app copies recordings only temporarily — the real copy lives
            // in Cloudflare R2. Keeping local copies indefinitely wastes storage.
            cleanupOldRecordings(appDir, maxAgeMs = 24L * 60 * 60 * 1000)

            val sanitizedName = displayName.replace(Regex("[^a-zA-Z0-9._-]"), "_")
            val destFile = File(appDir, "${System.currentTimeMillis()}_$sanitizedName")

            context.contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(destFile).use { output ->
                    input.copyTo(output)
                }
            } ?: run {
                android.util.Log.e("RecordingExtraction", "Cannot open input stream for URI: $uri")
                return null
            }

            android.util.Log.d("RecordingExtraction",
                "Copied $displayName (${destFile.length()} bytes) to app storage")

            if (destFile.exists() && destFile.length() > 0) {
                destFile.absolutePath
            } else {
                android.util.Log.w("RecordingExtraction", "Destination file empty after copy")
                null
            }
        } catch (e: Exception) {
            android.util.Log.e("RecordingExtraction", "Copy error: ${e.message}", e)
            null
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // File-System Fallback (Tier 3)
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Known call-recording directories across major OEMs.
     * Relative to Environment.getExternalStorageDirectory().
     * listFiles() returns null on API 30+ for Android/data/ paths — that is
     * handled gracefully (null-safe continue) and by scanAndroidDataPackageDirs().
     */
    private val oemRecordingDirs: List<String> = listOf(
        // ── OnePlus / OxygenOS (Android 10-12, File API accessible) ──────────
        // OxygenOS 11+: Internal Storage/Android/data/com.oneplus.communication.data/…
        "Android/data/com.oneplus.communication.data/files/Record/PhoneRecord",
        // ── OnePlus / ColorOS (Android 12+, indexed to /Recordings/) ─────────
        "Recordings/Call",
        "Recordings",
        // ── Google Phone — indexes to shared storage on Android 10+ ──────────
        // Google Dialer writes recordings as audio files under 'Recordings/' or
        // 'Recordings/Call recordings/' in the shared MediaStore when call
        // recording is enabled.  The /data/user/0/com.google.android.dialer/
        // path is app-internal and CANNOT be accessed by third-party apps.
        "Recordings/Call recordings",
        // ── Older OxygenOS versions ───────────────────────────────────────────
        "Music/Recordings",
        // ── Samsung ───────────────────────────────────────────────────────────
        "Call",
        "Sounds/CallRecord",
        // ── Xiaomi / MIUI ─────────────────────────────────────────────────────
        "MIUI/sound_recorder/call_rec",
        "sound_recorder/call_rec",
        // ── Huawei / EMUI ─────────────────────────────────────────────────────
        "Sounds",
        "HiRecorder",
        // ── OPPO / Realme / Vivo ──────────────────────────────────────────────
        "Record/PhoneRecord",
        "Record",
        "PhoneRecord",
        "CallRecord"
    )

    private val validAudioExtensions = setOf("m4a", "mp3", "wav", "amr", "aac", "3gp", "ogg")

    /**
     * Scans known OEM directories on external storage for a call recording
     * that matches [cleanNumber] / [last10] / [last7] and was modified within
     * [windowMs] milliseconds of [now].  Returns the best-scoring [File] found,
     * or null if nothing matches.
     */
    private fun findViaFileSystem(
        now: Long,
        windowMs: Long,
        cleanNumber: String,
        last10: String,
        last7: String,
        expectedDurationMs: Long
    ): File? {
        val externalRoot = android.os.Environment.getExternalStorageDirectory()
        val cutoffMs = now - windowMs

        var bestFile: File? = null
        var bestScore = 0

        for (relDir in oemRecordingDirs) {
            val dir = File(externalRoot, relDir)
            if (!dir.exists() || !dir.isDirectory) continue

            android.util.Log.d("RecordingExtraction", "[FS] Scanning $dir")

            val files = dir.listFiles() ?: continue
            for (file in files) {
                if (!file.isFile) continue
                val ext = file.extension.lowercase()
                if (ext !in validAudioExtensions) continue
                if (file.length() < 1024) continue
                // Time window check — use file's lastModified()
                if (file.lastModified() < cutoffMs) continue

                val nameLower = file.name.lowercase()
                // Skip obvious non-call files
                if (nameLower.contains("music") || nameLower.contains("song") ||
                    nameLower.contains("podcast")) continue

                val score = calculateConfidenceScore(
                    file.name, relDir.lowercase(), cleanNumber, last10, last7
                )
                android.util.Log.d("RecordingExtraction",
                    "[FS] ${file.name} score=$score lastMod=${file.lastModified()}")

                if (score > bestScore) {
                    bestFile = file
                    bestScore = score
                }
            }
        }

        // If no phone-number-matched file found, fall back to the most-recently
        // modified audio file in any recording directory (within time window).
        if (bestFile == null) {
            android.util.Log.d("RecordingExtraction", "[FS] No scored match. Trying most-recent audio file...")
            for (relDir in oemRecordingDirs) {
                val dir = File(externalRoot, relDir)
                if (!dir.exists() || !dir.isDirectory) continue
                val files = dir.listFiles() ?: continue
                files.filter { f ->
                    f.isFile &&
                    f.extension.lowercase() in validAudioExtensions &&
                    f.length() >= 1024 &&
                    f.lastModified() >= cutoffMs
                }.maxByOrNull { it.lastModified() }?.let { f ->
                    val age = (now - f.lastModified()) / 1000
                    android.util.Log.d("RecordingExtraction",
                        "[FS] Fallback candidate: ${f.name} (${age}s ago, ${f.length()}B)")
                    // Only use if very recent (last 10 minutes) and not already set
                    if (age < 10 * 60 && bestFile == null) {
                        bestFile = f
                    }
                }
            }
        }

        // ── Android/data/ package scan (API ≤ 29 only) ————————————————
        // On Android 11+ scoped storage blocks File access to Android/data/
        // for other apps. On API ≤29 we can still read it directly.
        // NOTE: Google Phone's /data/user/0/com.google.android.dialer/ is
        // app-internal storage and is NEVER accessible without root on any
        // API level — no workaround exists for that path.
        if (bestFile == null && Build.VERSION.SDK_INT <= Build.VERSION_CODES.Q) {
            bestFile = scanAndroidDataPackageDirs(externalRoot, cutoffMs, now, cleanNumber, last10, last7)
        }

        return bestFile
    }

    /**
     * Scans well-known Android/data/<package>/files/ recording paths.
     * Only works on API ≤ 29 (Android 10); silently skipped on API 30+
     * where scoped storage denies File access to other apps' Android/data dirs.
     */
    private fun scanAndroidDataPackageDirs(
        externalRoot: File,
        cutoffMs: Long,
        now: Long,
        cleanNumber: String,
        last10: String,
        last7: String
    ): File? {
        // Package-relative paths known to store call recordings.
        val packagePaths = listOf(
            // OnePlus OxygenOS dialer (all OxygenOS versions)
            "Android/data/com.oneplus.communication.data/files/Record/PhoneRecord",
            "Android/data/com.oneplus.communication.data/files/Record",
            // OnePlus second package name used on some models
            "Android/data/com.oneplus.dialer/files/Record/PhoneRecord",
            // Google Dialer (recordings NOT accessible via this path on any API;
            // kept here as a no-op in case a ROM exposes it externally)
            "Android/data/com.google.android.dialer/files/callrecording"
        )
        var bestFile: File? = null
        var bestScore = 0

        for (relPath in packagePaths) {
            val dir = File(externalRoot, relPath)
            val files = try {
                if (!dir.exists() || !dir.isDirectory) continue
                dir.listFiles() ?: continue
            } catch (e: SecurityException) {
                android.util.Log.w("RecordingExtraction",
                    "[FS] SecurityException scanning $relPath (API ${Build.VERSION.SDK_INT}): ${e.message}")
                continue
            }

            android.util.Log.d("RecordingExtraction", "[FS/data] Scanning $dir")
            for (file in files) {
                if (!file.isFile) continue
                if (file.extension.lowercase() !in validAudioExtensions) continue
                if (file.length() < 1024) continue
                if (file.lastModified() < cutoffMs) continue

                val relDir = relPath.lowercase()
                val score = calculateConfidenceScore(file.name, relDir, cleanNumber, last10, last7)
                android.util.Log.d("RecordingExtraction",
                    "[FS/data] ${file.name} score=$score")
                if (score > bestScore) {
                    bestFile = file
                    bestScore = score
                }
            }
        }

        // Fallback: most-recently-modified file across all package paths
        if (bestFile == null) {
            for (relPath in packagePaths) {
                val dir = File(externalRoot, relPath)
                val files = try {
                    if (!dir.exists() || !dir.isDirectory) continue
                    dir.listFiles() ?: continue
                } catch (_: SecurityException) { continue }

                files.filter { f ->
                    f.isFile &&
                    f.extension.lowercase() in validAudioExtensions &&
                    f.length() >= 1024 &&
                    f.lastModified() >= cutoffMs
                }.maxByOrNull { it.lastModified() }?.let { f ->
                    val age = (now - f.lastModified()) / 1000
                    if (age < 10 * 60 && bestFile == null) bestFile = f
                }
            }
        }

        return bestFile
    }

    /**
     * Copies [source] directly to app-private [appDir] storage.
     * Used for the file-system fallback path where we have a File handle
     * rather than a MediaStore URI.
     */
    private fun copyFileToAppStorage(source: File, appDir: File): String? {
        return try {
            val sanitizedName = source.name.replace(Regex("[^a-zA-Z0-9._-]"), "_")
            val destFile = File(appDir, "${System.currentTimeMillis()}_$sanitizedName")
            source.inputStream().use { input ->
                destFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
            android.util.Log.d("RecordingExtraction",
                "[FS] Copied ${source.name} (${destFile.length()} bytes) to app storage")
            if (destFile.exists() && destFile.length() > 0) destFile.absolutePath else null
        } catch (e: Exception) {
            android.util.Log.e("RecordingExtraction", "[FS] Copy error: ${e.message}", e)
            null
        }
    }

    /**
     * Deletes recording copies from app-private storage that are older than [maxAgeMs].
     * Safe to call frequently — only removes files in the call_recordings folder.
     */
    private fun cleanupOldRecordings(dir: File, maxAgeMs: Long) {
        val now = System.currentTimeMillis()
        val files = dir.listFiles() ?: return
        var deletedCount = 0
        var freedBytes = 0L

        for (file in files) {
            if (file.isFile && (now - file.lastModified()) > maxAgeMs) {
                val size = file.length()
                if (file.delete()) {
                    deletedCount++
                    freedBytes += size
                }
            }
        }

        if (deletedCount > 0) {
            android.util.Log.d("RecordingExtraction",
                "Cleanup: deleted $deletedCount old recording(s), freed ${freedBytes / 1024}KB")
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Audio Duration Helper
    // ─────────────────────────────────────────────────────────────────────────

    private fun getAudioDurationFromFile(file: File): Long {
        return try {
            val retriever = MediaMetadataRetriever()
            retriever.setDataSource(file.absolutePath)
            val durationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
            retriever.release()
            durationStr?.toLongOrNull() ?: 0L
        } catch (e: Exception) {
            android.util.Log.w("RecordingExtraction", "Duration read error: ${e.message}")
            0L
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Debug / Diagnostics — uses MediaStore, not raw filesystem paths
    // ─────────────────────────────────────────────────────────────────────────

    private fun dumpMediaStoreInfo(): Map<String, Any?> {
        val output = mutableMapOf<String, Any?>()
        val context = applicationContext

        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }

        val projection = arrayOf(
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.RELATIVE_PATH,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATE_MODIFIED
        )

        val cutoffSecs = (System.currentTimeMillis() - 90L * 60 * 1000) / 1000
        val selection = "${MediaStore.Audio.Media.DATE_MODIFIED} >= ?"
        val selectionArgs = arrayOf(cutoffSecs.toString())
        val sortOrder = "${MediaStore.Audio.Media.DATE_MODIFIED} DESC"

        val entries = mutableListOf<String>()
        context.contentResolver.query(
            collection, projection, selection, selectionArgs, sortOrder
        )?.use { cursor ->
            val nameCol     = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)
            val pathCol     = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.RELATIVE_PATH)
            val sizeCol     = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
            val durationCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)

            while (cursor.moveToNext()) {
                val name     = cursor.getString(nameCol) ?: "unknown"
                val path     = cursor.getString(pathCol) ?: ""
                val size     = cursor.getLong(sizeCol)
                val duration = cursor.getLong(durationCol) / 1000
                entries.add("$path$name | ${size}B | ${duration}s")
            }
        }

        output["mediastore_audio_recent_90min"] = entries
        output["count"] = entries.size

        android.util.Log.d("RecordingExtraction", "=== MEDIASTORE DUMP ===")
        entries.forEach { android.util.Log.d("RecordingExtraction", it) }
        android.util.Log.d("RecordingExtraction", "=== END DUMP ===")

        return output
    }
}
