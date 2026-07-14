import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class MediaStoreRecordingResult {
  final String filePath;
  final String originalPath;
  final String displayName;
  final int durationSeconds;
  final int sizeBytes;
  final String mimeType;
  final int confidenceScore;

  MediaStoreRecordingResult({
    required this.filePath,
    required this.originalPath,
    required this.displayName,
    required this.durationSeconds,
    required this.sizeBytes,
    required this.mimeType,
    required this.confidenceScore,
  });

  factory MediaStoreRecordingResult.fromMap(Map<dynamic, dynamic> map) {
    return MediaStoreRecordingResult(
      filePath: map['filePath'] as String? ?? '',
      originalPath: map['originalPath'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      mimeType: map['mimeType'] as String? ?? '',
      confidenceScore: (map['confidenceScore'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  String toString() {
    return 'RecordingResult(displayName: $displayName, duration: ${durationSeconds}s, size: $sizeBytes, score: $confidenceScore)';
  }
}

class MediaStoreRecordingService {
  static const MethodChannel _channel = MethodChannel('com.trevioncrm/recording_extraction');

  /// Returns true if the app currently holds the necessary audio read permission.
  ///
  /// On Android 13+ (API 33) we need READ_MEDIA_AUDIO.
  /// On Android 12 and below, READ_EXTERNAL_STORAGE covers audio files.
  /// MANAGE_EXTERNAL_STORAGE is NOT requested — it violates Google Play policy
  /// for apps whose core purpose is not file management.
  Future<bool> hasPermission() async {
    if (Platform.isAndroid) {
      // Android 13+ uses granular media permissions.
      if (await Permission.audio.isGranted) {
        debugPrint("🔐 [RecordingService] READ_MEDIA_AUDIO granted");
        return true;
      }
      // Android 12 and below: READ_EXTERNAL_STORAGE covers audio.
      if (await Permission.storage.isGranted) {
        debugPrint("🔐 [RecordingService] READ_EXTERNAL_STORAGE granted");
        return true;
      }
      debugPrint("❌ [RecordingService] No audio read permissions granted");
      return false;
    }
    return false;
  }

  /// Requests the minimum necessary permission to read audio/call recordings.
  ///
  /// Uses scoped storage permissions only. No MANAGE_EXTERNAL_STORAGE.
  Future<bool> requestPermission() async {
    debugPrint("🔐 [RecordingService] Requesting permissions...");
    if (await hasPermission()) return true;

    if (Platform.isAndroid) {
      // Try READ_MEDIA_AUDIO first (Android 13+; harmless no-op on older).
      final audioStatus = await Permission.audio.request();
      debugPrint("🔐 [RecordingService] READ_MEDIA_AUDIO status: $audioStatus");
      if (audioStatus.isGranted) return true;

      // Fallback: READ_EXTERNAL_STORAGE for Android 12 and below.
      final storageStatus = await Permission.storage.request();
      debugPrint("🔐 [RecordingService] READ_EXTERNAL_STORAGE status: $storageStatus");
      if (storageStatus.isGranted) return true;

      if (storageStatus.isPermanentlyDenied || audioStatus.isPermanentlyDenied) {
        debugPrint("⚠️ [RecordingService] Permission permanently denied, opening settings");
        await openAppSettings();
      }
    }

    return false;
  }

  Future<File?> findLatestRecording(String phoneNumber, {int? expectedDurationSeconds}) async {
    try {
      debugPrint("🔍 [RecordingService] Checking permissions for $phoneNumber...");
      final hasPerm = await hasPermission();
      if (!hasPerm) {
        debugPrint("🔐 [RecordingService] No permission, requesting...");
        final granted = await requestPermission();
        if (!granted) {
          debugPrint("❌ [RecordingService] Storage permission denied");
          return null;
        }
      }

      debugPrint("🔍 [RecordingService] Invoking native MediaStore scan for $phoneNumber"
          " (expectedDuration: ${expectedDurationSeconds ?? 'Unknown'}s)");
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('findLatestRecording', {
        'phoneNumber': phoneNumber,
        'expectedDurationSeconds': expectedDurationSeconds ?? 0,
      });

      if (result == null) {
        debugPrint("❌ [RecordingService] Null result from native channel");
        return null;
      }

      if (result.containsKey('error')) {
        debugPrint("❌ [RecordingService] Native error: ${result['error']}");
        return null;
      }

      final recordingResult = MediaStoreRecordingResult.fromMap(result);
      debugPrint("✅ [RecordingService] Native found: $recordingResult");

      final file = File(recordingResult.filePath);
      if (await file.exists() && await file.length() > 1024) {
        debugPrint("✅ [RecordingService] File validated: ${file.path} (${await file.length()} bytes)");
        return file;
      }

      debugPrint("❌ [RecordingService] Copied file invalid or missing: ${file.path}");
      return null;
    } on PlatformException catch (e) {
      debugPrint("❌ [RecordingService] PlatformException: ${e.code} - ${e.message}");
      return null;
    } catch (e, stackTrace) {
      debugPrint("❌ [RecordingService] Unexpected error: $e");
      debugPrint("❌ [RecordingService] StackTrace: $stackTrace");
      return null;
    }
  }

  /// Deletes the local copy of a recording from app-private storage.
  ///
  /// Call this immediately after a successful R2 upload so the file doesn't
  /// accumulate in [filesDir/call_recordings]. The Kotlin side also auto-cleans
  /// files older than 24 h, but calling this right after upload is best practice.
  Future<void> deleteLocalCopy(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
        debugPrint("🗑️ [RecordingService] Deleted local copy: ${file.path}");
      }
    } catch (e) {
      debugPrint("⚠️ [RecordingService] Could not delete local copy: $e");
    }
  }

  Future<Map<String, dynamic>> dumpDirectories() async {
    try {
      debugPrint("📁 [RecordingService] Dumping directories for debugging...");
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('dumpDirectories');
      if (result == null) return {};
      return result.map((key, value) => MapEntry(key.toString(), value));
    } catch (e, stackTrace) {
      debugPrint("❌ [RecordingService] Dump error: $e");
      debugPrint("❌ [RecordingService] StackTrace: $stackTrace");
      return {};
    }
  }

  Future<Map<String, dynamic>> runDiagnostics(String phoneNumber) async {
    final results = <String, dynamic>{};

    results['timestamp'] = DateTime.now().toIso8601String();
    results['phoneNumber'] = phoneNumber;
    results['platform'] = Platform.operatingSystem;

    // Check permissions (scoped storage only).
    final hasAudio = await Permission.audio.isGranted;
    final hasStorage = await Permission.storage.isGranted;
    results['permissions'] = {
      'audio (READ_MEDIA_AUDIO)': hasAudio,
      'storage (READ_EXTERNAL_STORAGE ≤API32)': hasStorage,
    };

    // Dump directories.
    try {
      final dirs = await dumpDirectories();
      results['directories'] = dirs;
    } catch (e) {
      results['directoriesError'] = e.toString();
    }

    // Try to find latest recording.
    try {
      final file = await findLatestRecording(phoneNumber);
      if (file != null) {
        results['latestRecording'] = {
          'path': file.path,
          'size': await file.length(),
        };
      } else {
        results['latestRecording'] = null;
      }
    } catch (e) {
      results['latestRecordingError'] = e.toString();
    }

    debugPrint("📊 [RecordingService] Diagnostics: $results");
    return results;
  }
}
