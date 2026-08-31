import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/recording_extraction_service.dart';
import '../../core/services/r2_service.dart';
import '../../core/services/call_logger_service.dart';
import '../../core/services/analytics_service.dart';

/// State of the recording extraction process
enum RecordingExtractionStatus { idle, searching, uploading, success, error, notFound }

class RecordingExtractionState {
  final RecordingExtractionStatus status;
  final String? error;
  final String? foundFilePath;

  RecordingExtractionState({
    required this.status,
    this.error,
    this.foundFilePath,
  });

  factory RecordingExtractionState.initial() => RecordingExtractionState(status: RecordingExtractionStatus.idle);

  RecordingExtractionState copyWith({
    RecordingExtractionStatus? status,
    String? error,
    String? foundFilePath,
  }) {
    return RecordingExtractionState(
      status: status ?? this.status,
      error: error ?? this.error,
      foundFilePath: foundFilePath ?? this.foundFilePath,
    );
  }
}

/// Provider for the Service itself (Dependency Injection)
final recordingServiceProvider = Provider((ref) => RecordingExtractionService());

/// Modern NotifierProvider (Riverpod 2.0+ / 3.0 Industry Standard)
final recordingExtractionProvider = NotifierProvider<RecordingExtractionNotifier, RecordingExtractionState>(() {
  return RecordingExtractionNotifier();
});

class RecordingExtractionNotifier extends Notifier<RecordingExtractionState> {
  @override
  RecordingExtractionState build() {
    return RecordingExtractionState.initial();
  }

  /// Automatically triggers the extraction and upload flow
  Future<void> handleCallEnd(String phoneNumber, String uniqueCallId, String? companyId, String? userId, int durationSeconds) async {
    debugPrint("RecordingProvider: Starting extraction for $phoneNumber (ID: $uniqueCallId, Duration: ${durationSeconds}s)");
    
    // Obtain the service instance via the ref
    final service = ref.read(recordingServiceProvider);
    
    try {
      state = state.copyWith(status: RecordingExtractionStatus.searching);

      // Progressive retry schedule (starts at 2s, total ~45s across 6 attempts)
      File? file;
      final retryDelays = [2, 3, 5, 8, 12, 15];
      for (int attempt = 0; attempt < retryDelays.length; attempt++) {
        await Future.delayed(Duration(seconds: retryDelays[attempt]));
        debugPrint("RecordingProvider: Search attempt ${attempt + 1}/${retryDelays.length} for $phoneNumber");
        file = await service.findLatestRecording(phoneNumber, expectedDurationSeconds: durationSeconds);
        if (file != null) break;
      }
      
      if (file == null) {
        state = state.copyWith(status: RecordingExtractionStatus.notFound);
        // Instantly notify logger service to release the webhook completer so we don't wait
        await CallLoggerService().reportSystemRecording(uniqueCallId, null);
        return;
      }

      // 3. Found file, start upload to Cloudflare R2
      state = state.copyWith(
        status: RecordingExtractionStatus.uploading,
        foundFilePath: file.path,
      );

      final r2Url = await R2Service().uploadAudio(file, uniqueCallId, companyId: companyId, userId: userId);

      if (r2Url != null) {
        debugPrint("RecordingProvider: System recording uploaded to R2: $r2Url");
        
        // Log call recording upload event to Firebase Analytics
        AnalyticsService().logCallRecordingUploaded(
          durationSeconds: durationSeconds.toDouble(),
          uploadStatus: 'success',
        );

        // 4. Report back to CallLoggerService to finalize the webhook
        await CallLoggerService().reportSystemRecording(uniqueCallId, r2Url);
        
        state = state.copyWith(status: RecordingExtractionStatus.success);
        
        // Cleanup local file
        try {
           await file.delete();
        } catch (e) {
           debugPrint("RecordingProvider: Failed to delete system recording file: $e");
        }
      } else {
        state = state.copyWith(status: RecordingExtractionStatus.error, error: "Upload to Cloudflare R2 failed");
        // Release webhook completer on upload failure
        await CallLoggerService().reportSystemRecording(uniqueCallId, null);
      }
    } catch (e) {
      debugPrint("RecordingProvider: Error during extraction/upload: $e");
      state = state.copyWith(status: RecordingExtractionStatus.error, error: e.toString());
      // Release webhook completer on exception
      await CallLoggerService().reportSystemRecording(uniqueCallId, null);
    }
  }
  
  void reset() {
    state = RecordingExtractionState.initial();
  }
}
