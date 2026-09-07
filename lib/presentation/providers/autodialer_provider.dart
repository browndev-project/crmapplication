// Original:
// import 'dart:io';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../core/services/autodialer_service.dart';
import '../../core/services/call_logger_service.dart';
import '../../core/services/call_service.dart';
import '../../data/models/autodialer_model.dart';

final autodialerServiceProvider = Provider<AutoDialerService>((ref) {
  return AutoDialerService();
});

class AutoDialerState {
  final bool isLoading;
  final bool isCompleting;
  final String? error;
  final AutoDialerQueueItem? currentCall;
  final bool isCalling;
  final String? appCallId;
  final DateTime? callStartTime;
  final DateTime? callEndTime;
  final int? callDuration;
  final String selectedCallResult;
  final String selectedStatus;
  final String notes;
  final String? callerNumber;
  final String? receiverNumber;
  final String? recordingUrl;
  final int? simSlot;
  final String? carrier;
  final bool isQueueFinished;

  const AutoDialerState({
    this.isLoading = false,
    this.isCompleting = false,
    this.error,
    this.currentCall,
    this.isCalling = false,
    this.appCallId,
    this.callStartTime,
    this.callEndTime,
    this.callDuration,
    this.selectedCallResult = 'Connected',
    this.selectedStatus = 'New',
    this.notes = '',
    this.callerNumber,
    this.receiverNumber,
    this.recordingUrl,
    this.simSlot,
    this.carrier,
    this.isQueueFinished = false,
  });

  // Original:
  // AutoDialerState copyWith({
  //   bool? isLoading,
  //   bool? isCompleting,
  //   String? error,
  //   bool clearError = false,
  //   AutoDialerQueueItem? currentCall,
  //   bool clearCurrentCall = false,
  //   bool? isCalling,
  //   String? appCallId,
  //   DateTime? callStartTime,
  //   DateTime? callEndTime,
  //   int? callDuration,
  //   String? selectedCallResult,
  //   String? selectedStatus,
  //   String? notes,
  //   String? callerNumber,
  //   String? receiverNumber,
  //   String? recordingUrl,
  //   int? simSlot,
  //   String? carrier,
  //   bool? isQueueFinished,
  // }) {
  //   return AutoDialerState(
  //     isLoading: isLoading ?? this.isLoading,
  //     isCompleting: isCompleting ?? this.isCompleting,
  //     error: clearError ? null : (error ?? this.error),
  //     currentCall: clearCurrentCall ? null : (currentCall ?? this.currentCall),
  //     isCalling: isCalling ?? this.isCalling,
  //     appCallId: appCallId ?? this.appCallId,
  //     callStartTime: callStartTime ?? this.callStartTime,
  //     callEndTime: callEndTime ?? this.callEndTime,
  //     callDuration: callDuration ?? this.callDuration,
  //     selectedCallResult: selectedCallResult ?? this.selectedCallResult,
  //     selectedStatus: selectedStatus ?? this.selectedStatus,
  //     notes: notes ?? this.notes,
  //     callerNumber: callerNumber ?? this.callerNumber,
  //     receiverNumber: receiverNumber ?? this.receiverNumber,
  //     recordingUrl: recordingUrl ?? this.recordingUrl,
  //     simSlot: simSlot ?? this.simSlot,
  //     carrier: carrier ?? this.carrier,
  //     isQueueFinished: isQueueFinished ?? this.isQueueFinished,
  //   );
  // }
  AutoDialerState copyWith({
    bool? isLoading,
    bool? isCompleting,
    String? error,
    bool clearError = false,
    AutoDialerQueueItem? currentCall,
    bool clearCurrentCall = false,
    bool? isCalling,
    String? appCallId,
    DateTime? callStartTime,
    DateTime? callEndTime,
    int? callDuration,
    String? selectedCallResult,
    String? selectedStatus,
    String? notes,
    String? callerNumber,
    String? receiverNumber,
    String? recordingUrl,
    bool clearRecordingUrl = false,
    int? simSlot,
    String? carrier,
    bool? isQueueFinished,
  }) {
    return AutoDialerState(
      isLoading: isLoading ?? this.isLoading,
      isCompleting: isCompleting ?? this.isCompleting,
      error: clearError ? null : (error ?? this.error),
      currentCall: clearCurrentCall ? null : (currentCall ?? this.currentCall),
      isCalling: isCalling ?? this.isCalling,
      appCallId: appCallId ?? this.appCallId,
      callStartTime: callStartTime ?? this.callStartTime,
      callEndTime: callEndTime ?? this.callEndTime,
      callDuration: callDuration ?? this.callDuration,
      selectedCallResult: selectedCallResult ?? this.selectedCallResult,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      notes: notes ?? this.notes,
      callerNumber: callerNumber ?? this.callerNumber,
      receiverNumber: receiverNumber ?? this.receiverNumber,
      recordingUrl: clearRecordingUrl ? null : (recordingUrl ?? this.recordingUrl),
      simSlot: simSlot ?? this.simSlot,
      carrier: carrier ?? this.carrier,
      isQueueFinished: isQueueFinished ?? this.isQueueFinished,
    );
  }
}

class AutoDialerNotifier extends StateNotifier<AutoDialerState> {
  final AutoDialerService _service;
  final CallService _callService = CallService();

  // Original:
  // AutoDialerNotifier(this._service) : super(const AutoDialerState());
  StreamSubscription<Map<String, String>>? _recordingSub;

  AutoDialerNotifier(this._service) : super(const AutoDialerState()) {
    _subscribeToRecordings();
  }

  void _subscribeToRecordings() {
    _recordingSub = CallLoggerService.recordingUploadedStream.listen((event) {
      final callId = event['uniqueCallId'];
      final url = event['recordingUrl'];
      if (callId != null && url != null && url.isNotEmpty) {
        if (state.appCallId == callId) {
          debugPrint('AutoDialerNotifier: 🎙️ Matching recording uploaded for $callId: $url');
          state = state.copyWith(recordingUrl: url);
        }
      }
    });
  }

  @override
  void dispose() {
    _recordingSub?.cancel();
    super.dispose();
  }

  // Original:
  // void setInitialItem(AutoDialerQueueItem? item) {
  //   if (item != null) {
  // ...
  //   } else {
  //     fetchCurrentCall();
  //   }
  // }
  // Future<void> fetchCurrentCall() async {
  //   state = state.copyWith(isLoading: true, clearError: true);
  //   try {
  //     final queueItem = await _service.fetchCurrentQueueItem();
  void setInitialItem(AutoDialerQueueItem? item, {String? campaignId}) {
    if (item != null) {
      final defaultStatus = item.targetType.toLowerCase() == 'coldlead'
          ? (item.contactInfo.coldLeadDetails?.status ?? 'New')
          : (item.contactInfo.leadDetails?.status ?? 'New');

      state = state.copyWith(
        currentCall: item,
        selectedStatus: defaultStatus,
        selectedCallResult: 'Connected',
        notes: '',
        isQueueFinished: false,
        clearError: true,
      );
    } else {
      fetchCurrentCall(campaignId: campaignId);
    }
  }

  Future<void> fetchCurrentCall({String? campaignId}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final queueItem = await _service.fetchCurrentQueueItem(campaignId: campaignId);
      if (queueItem != null) {
        final defaultStatus = queueItem.targetType.toLowerCase() == 'coldlead'
            ? (queueItem.contactInfo.coldLeadDetails?.status ?? 'New')
            : (queueItem.contactInfo.leadDetails?.status ?? 'New');

        state = state.copyWith(
          isLoading: false,
          currentCall: queueItem,
          selectedStatus: defaultStatus,
          selectedCallResult: 'Connected',
          notes: '',
          isQueueFinished: false,
          clearError: true,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          clearCurrentCall: true,
          isQueueFinished: true,
          clearError: true,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // Original:
  // Future<void> initiateCall() async {
  //   final current = state.currentCall;
  //   if (current == null) return;
  //
  //   final phoneNo = current.contactInfo.phoneNo;
  //   if (phoneNo.isEmpty) return;
  //
  //   final cleanPhone = phoneNo.replaceAll(RegExp(r'[^\d+]'), '');
  //   final appCallId = 'APP_CALL_${cleanPhone}_${DateTime.now().millisecondsSinceEpoch}';
  //   final startTime = DateTime.now();
  //
  //   state = state.copyWith(
  //     isCalling: true,
  //     appCallId: appCallId,
  //     callStartTime: startTime,
  //     receiverNumber: cleanPhone,
  //   );
  //
  //   try {
  //     final callContext = {
  //       'source': 'AUTODIALER',
  //       'queueId': current.queueId,
  //       'targetType': current.targetType,
  //       'campaignTitle': current.campaignTitle,
  //       'phoneNo': cleanPhone,
  //       'name': current.contactInfo.name,
  //       'uniqueCallId': appCallId,
  //       'direction': 'OUTGOING',
  //     };
  //
  //     if (Platform.isAndroid) {
  //       _callService.startCallListener();
  //     }
  //     await _callService.makeCall(cleanPhone, callContext: callContext);
  //   } catch (e) {
  //     debugPrint('AutoDialerNotifier: Error placing call: $e');
  //   }
  // }
  //
  // Future<void> captureCallCompleted() async {
  //   final current = state.currentCall;
  //   if (current == null) return;
  //
  //   final cleanPhone = current.contactInfo.phoneNo.replaceAll(RegExp(r'[^\d+]'), '');
  //   final now = DateTime.now();
  //
  //   int duration = state.callDuration ?? 0;
  //   String callerNumber = state.callerNumber ?? '';
  //   String? callType = 'OUTGOING';
  //
  //   try {
  //     final lastCall = await _callService.getLastCallDetails(cleanPhone);
  //     if (lastCall != null) {
  //       duration = (lastCall['duration_seconds'] as num?)?.toInt() ?? duration;
  //       callType = lastCall['call_type']?.toString() ?? 'OUTGOING';
  //     }
  //   } catch (e) {
  //     debugPrint('AutoDialerNotifier: Error reading last call details: $e');
  //   }
  //
  //   if (duration == 0 && state.callStartTime != null) {
  //     final elapsed = now.difference(state.callStartTime!).inSeconds;
  //     if (elapsed > 0 && elapsed < 300) {
  //       duration = elapsed;
  //     }
  //   }
  //
  //   final autoResult = duration > 0 ? 'Connected' : 'No Answer';
  //
  //   state = state.copyWith(
  //     isCalling: false,
  //     callEndTime: now,
  //     callDuration: duration,
  //     selectedCallResult: autoResult,
  //     callerNumber: callerNumber,
  //   );
  // }
  Future<void> initiateCall() async {
    final current = state.currentCall;
    if (current == null) return;

    final phoneNo = current.contactInfo.phoneNo;
    if (phoneNo.isEmpty) return;

    final cleanPhone = phoneNo.replaceAll(RegExp(r'[^\d+]'), '');
    final appCallId = 'APP_CALL_${cleanPhone}_${DateTime.now().millisecondsSinceEpoch}';
    final startTime = DateTime.now();

    state = state.copyWith(
      isCalling: true,
      appCallId: appCallId,
      callStartTime: startTime,
      receiverNumber: cleanPhone,
      clearRecordingUrl: true,
    );

    try {
      final callContext = {
        'source': 'AUTODIALER',
        'queueId': current.queueId,
        'targetType': current.targetType,
        'campaignTitle': current.campaignTitle,
        'phoneNo': cleanPhone,
        'name': current.contactInfo.name,
        'uniqueCallId': appCallId,
        'direction': 'OUTGOING',
      };

      if (Platform.isAndroid) {
        _callService.startCallListener();
      }
      await _callService.makeCall(cleanPhone, callContext: callContext);
    } catch (e) {
      debugPrint('AutoDialerNotifier: Error placing call: $e');
    }
  }

  Future<void> captureCallCompleted() async {
    final current = state.currentCall;
    if (current == null) return;

    final cleanPhone = current.contactInfo.phoneNo.replaceAll(RegExp(r'[^\d+]'), '');
    final now = DateTime.now();

    int duration = state.callDuration ?? 0;
    String callerNumber = state.callerNumber ?? '';
    String? callType = 'OUTGOING';

    try {
      final lastCall = await _callService.getLastCallDetails(cleanPhone);
      if (lastCall != null) {
        duration = (lastCall['duration_seconds'] as num?)?.toInt() ?? duration;
        callType = lastCall['call_type']?.toString() ?? 'OUTGOING';
      }
    } catch (e) {
      debugPrint('AutoDialerNotifier: Error reading last call details: $e');
    }

    if (duration == 0 && state.callStartTime != null) {
      final elapsed = now.difference(state.callStartTime!).inSeconds;
      if (elapsed > 0 && elapsed < 300) {
        duration = elapsed;
      }
    }

    final autoResult = duration > 0 ? 'Connected' : 'No Answer';

    // Check if recording is already uploaded & cached in CallLoggerService
    String? cachedRecording = state.recordingUrl;
    if ((cachedRecording == null || cachedRecording.isEmpty) && state.appCallId != null) {
      cachedRecording = CallLoggerService.getUploadedRecordingUrl(state.appCallId!);
      if (cachedRecording != null && cachedRecording.isNotEmpty) {
        debugPrint('AutoDialerNotifier: Found cached recording on call completion: $cachedRecording');
      }
    }

    state = state.copyWith(
      isCalling: false,
      callEndTime: now,
      callDuration: duration,
      selectedCallResult: autoResult,
      callerNumber: callerNumber,
      recordingUrl: cachedRecording,
    );
  }

  void setRecordingUrl(String url) {
    state = state.copyWith(recordingUrl: url);
  }

  void setCallResult(String result) {
    state = state.copyWith(selectedCallResult: result);
  }

  void setStatus(String status) {
    state = state.copyWith(selectedStatus: status);
  }

  void setNotes(String notes) {
    state = state.copyWith(notes: notes);
  }

  Future<bool> submitAndNext() async {
    final current = state.currentCall;
    if (current == null) return false;

    state = state.copyWith(isCompleting: true, clearError: true);

    try {
      final deviceMeta = await _service.getDeviceMeta();
      final startTimeIso = (state.callStartTime ?? DateTime.now().subtract(Duration(seconds: state.callDuration ?? 0)))
          .toUtc()
          .toIso8601String();
      final endTimeIso = (state.callEndTime ?? DateTime.now()).toUtc().toIso8601String();

      // Original:
      // final payload = AutoDialerCompletePayload(
      //   callResult: state.selectedCallResult,
      //   status: state.selectedStatus,
      //   notes: state.notes.trim(),
      //   appCallId: state.appCallId ?? 'APP_CALL_${current.contactInfo.phoneNo}_${DateTime.now().millisecondsSinceEpoch}',
      //   startTime: startTimeIso,
      //   endTime: endTimeIso,
      //   duration: state.callDuration ?? 0,
      //   callType: 'OUTGOING',
      //   callerNumber: state.callerNumber,
      //   receiverNumber: current.contactInfo.phoneNo,
      //   recordingUrl: state.recordingUrl,
      //   recordingSource: 'ANDROID_NATIVE',
      //   callDetails: {
      //     'simSlot': state.simSlot ?? 1,
      //     if (state.carrier != null) 'carrier': state.carrier,
      //   },
      //   meta: deviceMeta,
      // );
      //
      // final response = await _service.completeQueueItem(current.queueId, payload);
      //
      // if (response.nextCall != null) {
      //   final next = response.nextCall!;
      //   final defaultStatus = next.targetType.toLowerCase() == 'coldlead'
      //       ? (next.contactInfo.coldLeadDetails?.status ?? 'New')
      //       : (next.contactInfo.leadDetails?.status ?? 'New');
      //
      //   state = state.copyWith(
      //     isCompleting: false,
      //     currentCall: next,
      //     selectedStatus: defaultStatus,
      //     selectedCallResult: 'Connected',
      //     notes: '',
      //     appCallId: null,
      //     callStartTime: null,
      //     callEndTime: null,
      //     callDuration: null,
      //     isCalling: false,
      //     isQueueFinished: false,
      //     clearError: true,
      //   );
      // } else {
      //   // No more items in queue!
      //   state = state.copyWith(
      //     isCompleting: false,
      //     clearCurrentCall: true,
      //     isQueueFinished: true,
      //     isCalling: false,
      //     clearError: true,
      //   );
      // }

      // Check if recording is already uploaded or cached in CallLoggerService
      String? recordingUrl = state.recordingUrl;
      if ((recordingUrl == null || recordingUrl.isEmpty) && state.appCallId != null) {
        recordingUrl = CallLoggerService.getUploadedRecordingUrl(state.appCallId!);
      }

      // If call was answered with duration > 0 and recording is not yet in cache,
      // check up to 3 seconds for the active R2 background upload to finish
      if ((recordingUrl == null || recordingUrl.isEmpty) &&
          state.appCallId != null &&
          (state.callDuration ?? 0) > 0 &&
          state.selectedCallResult == 'Connected') {
        debugPrint('AutoDialerNotifier: ⏳ Checking for pending recording upload for ${state.appCallId} (up to 3s)...');
        for (int i = 0; i < 3; i++) {
          final cached = CallLoggerService.getUploadedRecordingUrl(state.appCallId!);
          if (cached != null && cached.isNotEmpty) {
            recordingUrl = cached;
            debugPrint('AutoDialerNotifier: 🎙️ Pending recording resolved: $recordingUrl');
            break;
          }
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }

      if (recordingUrl != null && recordingUrl.isNotEmpty) {
        state = state.copyWith(recordingUrl: recordingUrl);
      }

      final payload = AutoDialerCompletePayload(
        callResult: state.selectedCallResult,
        status: state.selectedStatus,
        notes: state.notes.trim(),
        appCallId: state.appCallId ?? 'APP_CALL_${current.contactInfo.phoneNo}_${DateTime.now().millisecondsSinceEpoch}',
        startTime: startTimeIso,
        endTime: endTimeIso,
        duration: state.callDuration ?? 0,
        callType: 'OUTGOING',
        callerNumber: state.callerNumber,
        receiverNumber: current.contactInfo.phoneNo,
        recordingUrl: recordingUrl ?? state.recordingUrl,
        recordingSource: 'ANDROID_NATIVE',
        callDetails: {
          'simSlot': state.simSlot ?? 1,
          if (state.carrier != null) 'carrier': state.carrier,
        },
        meta: deviceMeta,
      );

      final response = await _service.completeQueueItem(current.queueId, payload);

      if (response.nextCall != null) {
        final next = response.nextCall!;
        final defaultStatus = next.targetType.toLowerCase() == 'coldlead'
            ? (next.contactInfo.coldLeadDetails?.status ?? 'New')
            : (next.contactInfo.leadDetails?.status ?? 'New');

        state = state.copyWith(
          isCompleting: false,
          currentCall: next,
          selectedStatus: defaultStatus,
          selectedCallResult: 'Connected',
          notes: '',
          appCallId: null,
          callStartTime: null,
          callEndTime: null,
          callDuration: null,
          isCalling: false,
          isQueueFinished: false,
          clearRecordingUrl: true,
          clearError: true,
        );
      } else {
        // No more items in queue!
        state = state.copyWith(
          isCompleting: false,
          clearCurrentCall: true,
          isQueueFinished: true,
          isCalling: false,
          clearRecordingUrl: true,
          clearError: true,
        );
      }
      return true;
    } catch (e) {
      state = state.copyWith(
        isCompleting: false,
        error: e.toString(),
      );
      return false;
    }
  }

  void reset() {
    state = const AutoDialerState();
  }
}

final autodialerProvider =
    StateNotifierProvider<AutoDialerNotifier, AutoDialerState>((ref) {
  final service = ref.watch(autodialerServiceProvider);
  return AutoDialerNotifier(service);
});
