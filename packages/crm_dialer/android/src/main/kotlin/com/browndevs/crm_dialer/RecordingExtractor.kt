package com.browndevs.crm_dialer

import android.content.ContentUris
import android.content.Context
import android.content.pm.PackageManager
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class RecordingExtractor(private val context: Context) {
    private val RECORDING_CHANNEL = "com.trevioncrm/recording_extraction"

    fun setupChannel(binaryMessenger: BinaryMessenger) {
        val channel = MethodChannel(binaryMessenger, RECORDING_CHANNEL)
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

    private fun hasAudioPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.checkSelfPermission(android.Manifest.permission.READ_MEDIA_AUDIO) == PackageManager.PERMISSION_GRANTED
        } else {
            context.checkSelfPermission(android.Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun findLatestRecording(phoneNumber: String, expectedDurationSeconds: Int): Map<String, Any?> {
        val now = System.currentTimeMillis()
        val windowMs = 90L * 60 * 1000 // 90-minute search window

        val cleanNumber = phoneNumber.replace(Regex("\\D"), "")
        val last10 = if (cleanNumber.length >= 10) cleanNumber.takeLast(10) else cleanNumber
        val last7 = if (cleanNumber.length >= 7) cleanNumber.takeLast(7) else cleanNumber
        val expectedDurationMs = expectedDurationSeconds * 1000L

        android.util.Log.d("RecordingExtraction", "Searching for: $phoneNumber (clean: $cleanNumber)")

        // Tier 1: MediaStore with 90-minute time window
        var candidate = searchMediaStore(
            context, now, windowMs, cleanNumber, last10, last7, expectedDurationMs
        )

        // Tier 2: MediaStore without date filter
        if (candidate == null) {
            android.util.Log.d("RecordingExtraction", "Tier-1 empty. Retrying MediaStore without date filter...")
            candidate = searchMediaStore(
                context, now, Long.MAX_VALUE / 2, cleanNumber, last10, last7, expectedDurationMs
            )
        }

        // Tier 3: Direct file-system scan
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
            val dateModifiedCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_MODIFIED)
            val relPathCol      = cursor.getColumnIndex(MediaStore.Audio.Media.RELATIVE_PATH)

            while (cursor.moveToNext()) {
                val displayName  = cursor.getString(nameCol) ?: continue
                val sizeBytes    = cursor.getLong(sizeCol)
                val durationMs   = cursor.getLong(durationCol)
                val mimeType     = cursor.getString(mimeCol) ?: "audio/*"
                val relativePath = if (relPathCol >= 0) cursor.getString(relPathCol) ?: "" else ""
                val id           = cursor.getLong(idCol)
                val dateModified = cursor.getLong(dateModifiedCol)

                if (sizeBytes < 1024) continue
                if (durationMs in 1..4999) continue

                val nameLower = displayName.lowercase()
                if (!validExtensions.any { nameLower.endsWith(it) }) continue
                if (nameLower.contains("music") || nameLower.contains("song") || nameLower.contains("podcast")) continue

                var durationBonus = 0
                if (expectedDurationMs > 0 && durationMs > 0) {
                    val diff = kotlin.math.abs(durationMs - expectedDurationMs)
                    if (diff <= 30_000L) {
                        durationBonus = 10
                    } else if (diff <= 90_000L) {
                        durationBonus = 5
                    }
                }

                val score = calculateConfidenceScore(displayName, relativePath, cleanNumber, last10, last7) + durationBonus
                if (score < 1) continue

                val cleanFilename = displayName.replace(Regex("\\D"), "")
                val hasPhoneMatch = cleanNumber.isNotEmpty() && (
                    displayName.contains(cleanNumber) ||
                    displayName.contains(last10) ||
                    displayName.contains(last7) ||
                    cleanFilename.contains(cleanNumber) ||
                    cleanFilename.contains(last10) ||
                    cleanFilename.contains(last7)
                )

                if (!hasPhoneMatch) {
                    val ageSeconds = now / 1000 - dateModified
                    val maxAllowedAgeSeconds = maxOf(900L, (expectedDurationMs / 1000) + 600L)
                    if (ageSeconds > maxAllowedAgeSeconds) {
                        continue
                    }
                }

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
        }

        return bestCandidate
    }

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

        if (path.contains("recording"))   score += 5
        if (path.contains("call"))         score += 5
        if (path.contains("record"))       score += 3
        if (path.contains("phonerecord"))  score += 5
        if (path.contains("sound_rec"))    score += 4
        if (path.contains("voice"))        score += 2

        if (name.contains("call recording")) score += 10
        if (name.contains("call")) score += 3
        if (name.contains("rec")) score += 2

        if (cleanNumber.isNotEmpty()) {
            val cleanFilename = filename.replace(Regex("\\D"), "")
            when {
                filename.contains(cleanNumber) -> score += 15
                filename.contains(last10)      -> score += 10
                filename.contains(last7)       -> score += 6
                cleanFilename.contains(cleanNumber) -> score += 15
                cleanFilename.contains(last10)      -> score += 10
                cleanFilename.contains(last7)       -> score += 6
            }
        }

        if (Regex("\\d{8}|\\d{4}[-_]\\d{2}[-_]\\d{2}").containsMatchIn(filename)) score += 2

        return score
    }

    private fun copyUriToAppStorage(context: Context, uri: Uri, displayName: String): String? {
        return try {
            val appDir = File(context.filesDir, "call_recordings")
            if (!appDir.exists()) appDir.mkdirs()

            cleanupOldRecordings(appDir, maxAgeMs = 24L * 60 * 60 * 1000)

            val sanitizedName = displayName.replace(Regex("[^a-zA-Z0-9._-]"), "_")
            val destFile = File(appDir, "${System.currentTimeMillis()}_$sanitizedName")

            context.contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(destFile).use { output ->
                    input.copyTo(output)
                }
            } ?: return null

            if (destFile.exists() && destFile.length() > 0) {
                destFile.absolutePath
            } else {
                null
            }
        } catch (e: Exception) {
            android.util.Log.e("RecordingExtraction", "Copy error: ${e.message}", e)
            null
        }
    }

    private val oemRecordingDirs: List<String> = listOf(
        "Android/data/com.oneplus.communication.data/files/Record/PhoneRecord",
        "Recordings/Call",
        "Recordings",
        "Recordings/Call recordings",
        "Music/Recordings",
        "Call",
        "Sounds/CallRecord",
        "MIUI/sound_recorder/call_rec",
        "sound_recorder/call_rec",
        "Sounds",
        "HiRecorder",
        "Record/PhoneRecord",
        "Record",
        "PhoneRecord",
        "CallRecord"
    )

    private val validAudioExtensions = setOf("m4a", "mp3", "wav", "amr", "aac", "3gp", "ogg")

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

            val files = dir.listFiles() ?: continue
            for (file in files) {
                if (!file.isFile) continue
                val ext = file.extension.lowercase()
                if (ext !in validAudioExtensions) continue
                if (file.length() < 1024) continue
                if (file.lastModified() < cutoffMs) continue

                val nameLower = file.name.lowercase()
                if (nameLower.contains("music") || nameLower.contains("song") || nameLower.contains("podcast")) continue

                val score = calculateConfidenceScore(
                    file.name, relDir.lowercase(), cleanNumber, last10, last7
                )

                if (score > bestScore) {
                    bestFile = file
                    bestScore = score
                }
            }
        }

        if (bestFile == null) {
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
                    if (age < 90 && bestFile == null) {
                        bestFile = f
                    }
                }
            }
        }

        return bestFile
    }

    private fun copyFileToAppStorage(source: File, appDir: File): String? {
        return try {
            val sanitizedName = source.name.replace(Regex("[^a-zA-Z0-9._-]"), "_")
            val destFile = File(appDir, "${System.currentTimeMillis()}_$sanitizedName")
            source.inputStream().use { input ->
                destFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
            if (destFile.exists() && destFile.length() > 0) destFile.absolutePath else null
        } catch (e: Exception) {
            android.util.Log.e("RecordingExtraction", "[FS] Copy error: ${e.message}", e)
            null
        }
    }

    private fun cleanupOldRecordings(dir: File, maxAgeMs: Long) {
        val now = System.currentTimeMillis()
        val files = dir.listFiles() ?: return

        for (file in files) {
            if (file.isFile && (now - file.lastModified()) > maxAgeMs) {
                file.delete()
            }
        }
    }

    private fun getAudioDurationFromFile(file: File): Long {
        return try {
            val retriever = MediaMetadataRetriever()
            retriever.setDataSource(file.absolutePath)
            val durationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
            retriever.release()
            durationStr?.toLongOrNull() ?: 0L
        } catch (e: Exception) {
            0L
        }
    }

    fun dumpMediaStoreInfo(): Map<String, Any?> {
        val output = mutableMapOf<String, Any?>()

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
        return output
    }
}
