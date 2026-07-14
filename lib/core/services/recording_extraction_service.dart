import 'dart:io';
import 'package:flutter/foundation.dart';
import 'http_client.dart' as http;
import 'auth_service.dart';
import 'mediastore_recording_service.dart';

class RecordingExtractionService {
  final MediaStoreRecordingService _nativeService = MediaStoreRecordingService();

  Future<File?> findLatestRecording(String phoneNumber, {int? expectedDurationSeconds}) async {
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');
    debugPrint("🔍 [RecordingExtractor] Starting search for phone: $phoneNumber (clean: $cleanNumber), expectedDuration: ${expectedDurationSeconds ?? 'Unknown'}s");

    final file = await _nativeService.findLatestRecording(
      phoneNumber,
      expectedDurationSeconds: expectedDurationSeconds,
    );

    if (file != null) {
      final size = await file.length();
      debugPrint("✅ [RecordingExtractor] MATCH FOUND: ${file.path} ($size bytes)");
    } else {
      debugPrint("❌ [RecordingExtractor] No recording found for $phoneNumber (clean: $cleanNumber)");
    }

    return file;
  }

  Future<bool> uploadRecording(File file, String uniqueCallId, {bool deleteAfterUpload = false, String source = 'SYSTEM_RECORDING'}) async {
    try {
      debugPrint("📤 [RecordingExtractor] Starting upload for $uniqueCallId (source: $source)");
      debugPrint("📤 [RecordingExtractor] File: ${file.path}, size: ${await file.length()} bytes");
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AuthService.baseUrl}/api/v1/push/dialer/recording-upload')
      );

      request.fields['uniqueCallId'] = uniqueCallId;
      request.fields['recordingSource'] = source;
      request.files.add(await http.MultipartFile.fromPath('recording', file.path));

      debugPrint("📤 [RecordingExtractor] Sending request to server...");
      final response = await request.send();
      final respStr = await response.stream.bytesToString();

      debugPrint("📥 [RecordingExtractor] Server Response: ${response.statusCode} - $respStr");

      bool isSuccess = response.statusCode == 200;

      if (isSuccess && deleteAfterUpload) {
        try {
          await file.delete();
          debugPrint("🗑️ [RecordingExtractor] Local file cleaned up.");
        } catch (e) {
          debugPrint("⚠️ [RecordingExtractor] Cleanup failed: $e");
        }
      } else if (!isSuccess) {
        debugPrint("❌ [RecordingExtractor] Upload failed with status: ${response.statusCode}");
      }

      return isSuccess;
    } catch (e, stackTrace) {
      debugPrint("❌ [RecordingExtractor] Upload Error: $e");
      debugPrint("❌ [RecordingExtractor] StackTrace: $stackTrace");
      return false;
    }
  }
}
