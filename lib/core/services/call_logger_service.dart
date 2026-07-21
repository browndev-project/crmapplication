import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:call_log/call_log.dart';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'http_client.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'auth_service.dart';
import '../../data/models/user_model.dart';
import 'dialer_service.dart';
import 'recording_extraction_service.dart';
import 'r2_service.dart';

class CallLoggerService {
  static final CallLoggerService _instance = CallLoggerService._internal();

  factory CallLoggerService() {
    return _instance;
  }

  CallLoggerService._internal();

  // Static callback for other services (like RecordingProvider) to hook into
  static Function(
    String phoneNumber,
    String uniqueCallId,
    String? companyId,
    String? userId,
    int duration,
  )?
  onSessionEnded;

  Map<String, dynamic>? _lastActivePayload;
  final Map<String, Completer<void>> _recordingCompleters = {};
  final Map<String, Map<String, dynamic>> _activePayloads = {};

  static final StreamController<String> _webhookSentController = StreamController<String>.broadcast();
  static Stream<String> get webhookSentStream => _webhookSentController.stream;

  /// Called by RecordingExtractionNotifier when a system recording is found and uploaded
  Future<void> reportSystemRecording(String uniqueCallId, String? r2Url) async {
    bool updated = false;

    if (_currentSession != null &&
        _currentSession!['uniqueCallId'] == uniqueCallId) {
      debugPrint("CallLogger: System recording reported (active session): $r2Url");
      _currentSession!['recordingUrl'] = r2Url;
      _currentSession!['recordingSource'] = 'SYSTEM_RECORDING';
      updated = true;
    }

    if (_lastActivePayload != null &&
        _lastActivePayload!['uniqueCallId'] == uniqueCallId) {
      _lastActivePayload!['recordingUrl'] = r2Url;
      _lastActivePayload!['recordingSource'] = 'SYSTEM_RECORDING';
      updated = true;
    }

    final payload = _activePayloads[uniqueCallId];
    if (payload != null) {
      debugPrint("CallLogger: System recording reported (payload map): $r2Url");
      payload['recordingUrl'] = r2Url;
      payload['recordingSource'] = 'SYSTEM_RECORDING';
      updated = true;
    }

    if (updated) {
      final completer = _recordingCompleters[uniqueCallId];
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }

      if (_systemRecordingCompleter != null &&
          !_systemRecordingCompleter!.isCompleted) {
        _systemRecordingCompleter!.complete();
      }
    }
  }

  // Active Session Data
  Map<String, dynamic>? _currentSession;
  List<Map<String, dynamic>> _callDetails = [];
  String? _lastState;
  DateTime? lastStateTime;
  int _simSlot = 1;
  String _simDisplayName = '';

  Completer<void>? _systemRecordingCompleter;

  bool get isSessionActive => _currentSession != null;

  // Re-entrancy guard for endSession to prevent duplicate webhook sends
  bool _isEnding = false;

  Future<File> _getSessionFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/active_call_session.json');
  }

  Future<void> initSession(Map<String, dynamic> fcmData) async {
    final uuid = const Uuid().v4();
    final now = DateTime.now().toUtc(); // Use UTC as per example 'Z'

    // Get Current User and Device ID
    String callerNumber = '';
    String deviceId = '';

    // Get all active SIMs first
    List<Map<String, dynamic>> activeSims = [];
    try {
      activeSims = await DialerService().getActiveSims();
      debugPrint("CallLogger: Active SIMs found: ${activeSims.length}");
      for (var sim in activeSims) {
        debugPrint(
          "CallLogger: SIM - slotIndex: ${sim['slotIndex']}, number: ${sim['number']}, displayName: ${sim['displayName']}, subscriptionId: ${sim['subscriptionId']}",
        );
      }
    } catch (e) {
      debugPrint("CallLogger: Failed to get active SIMs: $e");
    }

    // Ensure Hive is initialized (Required for Background Isolate)
    try {
      await Hive.initFlutter();
    } catch (e) {
      // Ignore if already initialized
    }

    // For outgoing calls with multiple SIMs, we may need to wait for phoneAccountId
    // to determine which SIM was actually used.
    // For now, if single SIM, use it; if multiple, we'll update later when phoneAccountId arrives.
    if (activeSims.length == 1 &&
        activeSims[0]['number'] != null &&
        activeSims[0]['number'].toString().isNotEmpty) {
      callerNumber = activeSims[0]['number'].toString();
      _simSlot = (activeSims[0]['slotIndex'] as int? ?? 0) + 1;
      _simDisplayName = activeSims[0]['displayName']?.toString() ?? '';
      debugPrint(
        "CallLogger: Single SIM found, using: $callerNumber, simSlot: $_simSlot",
      );
    } else if (activeSims.isNotEmpty) {
      // Multiple SIMs - we'll try to use the first one for now, but will update when phoneAccountId is available
      callerNumber = activeSims[0]['number']?.toString() ?? '';
      _simSlot = (activeSims[0]['slotIndex'] as int? ?? 0) + 1;
      _simDisplayName = activeSims[0]['displayName']?.toString() ?? '';
      debugPrint(
        "CallLogger: Multiple SIMs found, using first for now: $callerNumber, simSlot: $_simSlot (will update when phoneAccountId received)",
      );
    }

    // Fallback to Hive User Profile if SIM number is empty
    if (callerNumber.isEmpty) {
      try {
        // Check if Hive is ready
        if (!Hive.isBoxOpen('authBox')) {
          try {
            await Hive.openBox('authBox');
          } catch (e) {
            debugPrint("CallLogger: Failed to open authBox: $e");
          }
        }

        if (Hive.isBoxOpen('authBox')) {
          final box = Hive.box('authBox');
          final userJson = box.get('user_data');
          deviceId = box.get('crm_device_id') ?? '';

          if (userJson != null) {
            try {
              final user = User.fromJson(jsonDecode(userJson));
              callerNumber = user.phoneNo;
              debugPrint(
                "CallLogger: Found Profile Number (Fallback): $callerNumber",
              );
            } catch (e) {
              debugPrint("CallLogger: Failed to parse user data: $e");
            }
          }
        }
      } catch (e) {
        debugPrint('CallLogger: Hive Data unavailable: $e');
      }
    }

    final String direction =
        fcmData['direction'] ??
        (fcmData['callId'] != null ||
                [
                  'AUTO_DIAL',
                  'CALL_INITIATE',
                  'MANUAL_DIAL',
                ].contains(fcmData['type'])
            ? 'WEB_INITIATED'
            : 'APP_INITIATED');

    final String generatedUniqueId = fcmData['uniqueCallId'] ?? "call_${uuid}_${now.millisecondsSinceEpoch}";
    fcmData['uniqueCallId'] = generatedUniqueId;

    _currentSession = {
      "uniqueCallId": generatedUniqueId,
      "callId": fcmData['callId'],
      "leadId": fcmData['leadId'],
      "userId": fcmData['userId'],
      "companyId": fcmData['companyId'],
      "receiverNumber":
          fcmData['phoneNo'] ?? fcmData['phoneNumber'] ?? fcmData['number'],
      "callerNumber": callerNumber,
      "deviceId": deviceId,
      "callType": fcmData['callType'] ?? "OUTGOING",
      "direction": direction,
      "callSource": fcmData['callSource'] ?? 'APP',
      "startTime": now.toUtc().toIso8601String(),
      "startTimeMillis": now.millisecondsSinceEpoch,
      "endTime": null,
      "duration": 0,
      "simSlot": _simSlot.toString(),
      "simDisplayName": _simDisplayName,
    };

    _callDetails = [];
    lastStateTime = now;
    _lastState = 'INITIATED'; // Initial internal state

    debugPrint(
      "CallLogger: Session Initialized: ${_currentSession!['uniqueCallId']} ($direction)",
    );

    // PERSIST SESSION FOR CROSS-ISOLATE ACCESS
    try {
      // Also initialize saved_details to ensure consistency if app killed immediately
      _currentSession!['saved_details'] = _callDetails;

      final file = await _getSessionFile();
      await file.writeAsString(jsonEncode(_currentSession));
      debugPrint("CallLogger: Session Persisted to ${file.path}");
    } catch (e) {
      debugPrint("CallLogger: Failed to persist session: $e");
    }
  }

  void updatePhoneAccountId(String? id) {
    if (_currentSession != null && id != null && id.isNotEmpty) {
      _currentSession!['phoneAccountId'] = id;
      debugPrint("CallLogger: Updated phoneAccountId to $id");

      // Try to match SIM based on phoneAccountId
      _matchSimByPhoneAccountId(id);
    }
  }

  Future<void> _matchSimByPhoneAccountId(String phoneAccountId) async {
    try {
      final activeSims = await DialerService().getActiveSims();
      debugPrint(
        "CallLogger: Matching SIM for phoneAccountId: $phoneAccountId",
      );

      String? matchedNumber;
      String? matchedDisplayName;
      int? matchedSlotIndex;

      for (var sim in activeSims) {
        final subId = sim['subscriptionId']?.toString();
        final slotIndex = sim['slotIndex']?.toString();
        final iccId = sim['iccId']?.toString();

        debugPrint(
          "CallLogger: Checking SIM - slotIndex: ${sim['slotIndex']}, subscriptionId: $subId, iccId: $iccId, number: ${sim['number']}, displayName: ${sim['displayName']}",
        );

        if (subId == phoneAccountId ||
            slotIndex == phoneAccountId ||
            (iccId != null && iccId.isNotEmpty && (iccId == phoneAccountId || phoneAccountId.contains(iccId) || iccId.contains(phoneAccountId))) ||
            (subId != null && phoneAccountId.contains(subId)) ||
            (slotIndex != null && phoneAccountId.contains(slotIndex))) {
          matchedNumber = sim['number']?.toString();
          matchedDisplayName = sim['displayName']?.toString();
          matchedSlotIndex = (sim['slotIndex'] as num?)?.toInt();
          debugPrint(
            "CallLogger: Matched SIM by phoneAccountId ($phoneAccountId): slot $matchedSlotIndex, number: $matchedNumber",
          );
          break;
        }
      }

      if (matchedSlotIndex != null) {
        if (_currentSession != null) {
          if (matchedNumber != null && matchedNumber.isNotEmpty) {
            String newCallerNumber = matchedNumber;
            if (matchedDisplayName != null && matchedDisplayName.isNotEmpty) {
              newCallerNumber = '$matchedNumber ($matchedDisplayName)';
            }
            _currentSession!['callerNumber'] = newCallerNumber;
          } else {
            // Keep existing callerNumber but append matchedDisplayName if present
            final String currentCaller = _currentSession!['callerNumber']?.toString() ?? '';
            if (matchedDisplayName != null && matchedDisplayName.isNotEmpty && !currentCaller.contains(matchedDisplayName)) {
              _currentSession!['callerNumber'] = '$currentCaller ($matchedDisplayName)';
            }
          }
          
          _currentSession!['simSlot'] = (matchedSlotIndex + 1).toString();
          _currentSession!['simDisplayName'] = matchedDisplayName ?? '';
          
          debugPrint(
            "CallLogger: Updated callerNumber to: ${_currentSession!['callerNumber']}, simSlot: ${_currentSession!['simSlot']}",
          );

          // Persist the updated session
          _currentSession!['saved_details'] = _callDetails;
          try {
            final file = await _getSessionFile();
            await file.writeAsString(jsonEncode(_currentSession));
          } catch (e) {
            debugPrint("CallLogger: Failed to persist updated session: $e");
          }
        }
      }
    } catch (e) {
      debugPrint("CallLogger: Error matching SIM by phoneAccountId: $e");
    }
  }

  /// Initialize a session for an incoming call (triggered by system broadcast)
  Future<void> initIncomingSession(String phoneNumber) async {
    if (isSessionActive) return; // Already have a session

    debugPrint("CallLogger: Initializing Incoming Session for $phoneNumber");

    // We create a minimal FCM-like structure
    final fcmData = {
      'phoneNo': phoneNumber,
      'direction': 'INCOMING_APP',
      'callType': 'INCOMING',
      'callSource': 'APP',
      // IDs will be null until backend sync, but we need session for recording
      'callId': null,
      'leadId': null,
      'userId': null,
      'companyId': null,
    };

    await initSession(fcmData);

    // Override callType to INCOMING (initSession defaults to OUTGOING)
    if (_currentSession != null) {
      _currentSession!['callType'] = 'INCOMING';
    }
  }

  /// Initialize a session for an outgoing call (triggered by system dialer)
  Future<void> initOutgoingSession(String phoneNumber, {String initialState = 'DIALING'}) async {
    if (isSessionActive) return;

    debugPrint("CallLogger: Initializing Outgoing Session for $phoneNumber");

    final fcmData = {
      'phoneNo': phoneNumber,
      'direction': 'OUTGOING_APP',
      'callType': 'OUTGOING',
      'callSource': 'APP',
      'callId': null,
      'leadId': null,
      'userId': null,
      'companyId': null,
    };

    await initSession(fcmData);

    if (_currentSession != null) {
      _currentSession!['callType'] = 'OUTGOING';
    }

    await logState(initialState);
  }

  // RECOVERY: Check for any open session file on app start
  Future<void> checkPendingSession() async {
    if (Platform.isIOS) {
      debugPrint("CallLogger: checkPendingSession is bypassed on iOS.");
      return;
    }
    if (_currentSession != null) {
      debugPrint("CallLogger: Session is active in memory. Skipping pending restore.");
      return;
    }
    debugPrint("CallLogger: Checking for pending session...");
    try {
      final file = await _getSessionFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final tempSession = jsonDecode(content);
          if (tempSession['isEnding'] == true) {
            debugPrint("CallLogger: Pending session on disk is already ending. Skipping restore.");
            return;
          }
          _currentSession = tempSession;
          // Load Details
          if (_currentSession!.containsKey('saved_details')) {
            _callDetails = List<Map<String, dynamic>>.from(
              _currentSession!['saved_details'],
            );

            // Restore state for context
            if (_callDetails.isNotEmpty) {
              _lastState = _callDetails.last['state'];
            }
          }

          debugPrint(
            "CallLogger: Found pending session ${_currentSession!['uniqueCallId']}. Finalizing now.",
          );

          // Force End (assume Disconnected now since app restarted)
          // We add a DISCONNECTED event if not present
          if (_lastState != 'DISCONNECTED') {
            // Guard: if the session started less than 30 minutes ago and
            // hasn't reached DISCONNECTED yet, it may still be a live call
            // (e.g., user opened the app while the call was in progress and
            // the background isolate is still running).  Restore it to memory
            // and let the normal DISCONNECTED event end it cleanly.
            final startMillis = _currentSession!['startTimeMillis'] as int?;
            if (startMillis != null) {
              final elapsedMs =
                  DateTime.now().millisecondsSinceEpoch - startMillis;
              if (elapsedMs < 30 * 60 * 1000) {
                debugPrint(
                  'CallLogger: Pending session is ${elapsedMs ~/ 1000}s old '
                  'and not yet DISCONNECTED — possibly still live. '
                  'Restoring in-memory without force-ending.',
                );
                return;
              }
            }
            await logState('DISCONNECTED');
            // logState calls endSession if Disconnected
          } else {
            await endSession();
          }
        }
      } else {
        // Clear in-memory session if file was deleted by Kotlin background service
        if (_currentSession != null) {
          debugPrint(
            "CallLogger: Pending file not found but session is active in memory. Clearing in-memory state.",
          );
          _currentSession = null;
          _callDetails = [];
          lastStateTime = null;
          _systemRecordingCompleter = null;
          _lastActivePayload = null;
          _simSlot = 1;
          _simDisplayName = '';
        }
      }
    } catch (e) {
      debugPrint("CallLogger: Restore check failed: $e");
    }
  }

  // Log a state change
  Future<void> logState(String state) async {
    // Attempt to restore session if null (Background Isolate case)
    if (_currentSession == null) {
      try {
        final file = await _getSessionFile();
        if (await file.exists()) {
          final content = await file.readAsString();
          if (content.isNotEmpty) {
            final tempSession = jsonDecode(content);
            if (tempSession['isEnding'] == true) {
              debugPrint("CallLogger: Restore skipped - session is already ending.");
              return;
            }
            _currentSession = tempSession;
            debugPrint(
              "CallLogger: Restored Session from File: ${_currentSession!['uniqueCallId']}",
            );

            // Also restore details if present in session? No, details usually in separate var or we append.
            // IMPORTANT: in bg isolate, _callDetails is empty. We need to load it too?
            // Currently _currentSession doesn't store callDetails in file?
            // Wait, in initSession we write _currentSession to file.
            // But _currentSession is just the metadata map.
            // We need to persist callDetails continuously or read/write complete state.

            // Let's implement full state read/write for robustness.
            if (_currentSession!.containsKey('saved_details')) {
              _callDetails = List<Map<String, dynamic>>.from(
                _currentSession!['saved_details'],
              );

              // RESTORE _lastState so we don't duplicate or break logic
              if (_callDetails.isNotEmpty) {
                _lastState = _callDetails.last['state'];
                // _lastStateTime = DateTime.parse(_callDetails.last['startTime']); // Optional
              }
            }
          }
        }
      } catch (e) {
        debugPrint("CallLogger: Failed to restore session: $e");
      }
    }

    if (!isSessionActive) {
      debugPrint("CallLogger: Ignored state $state (No Active Session)");
      return;
    }

    // Ignore duplicate/noisy state updates
    if (_lastState == state) {
      debugPrint(
        "CallLogger: ⚠️ Duplicate state ignored: $state (already $_lastState)",
      );
      return;
    }

    // STATE GUARD: Once we are ACTIVE or CONNECTED, do not go back to DIALING/RINGING
    // This fixes the issue where long calls "re-enter" dialing state incorrectly.
    if ((_lastState == 'ACTIVE' || _lastState == 'CONNECTED') &&
        (state == 'DIALING' ||
            state == 'RINGING' ||
            state == 'INCOMING' ||
            state == 'CONNECTING')) {
      debugPrint(
        "CallLogger: Ignored illegal state transition: $_lastState -> $state",
      );
      return;
    }

    final now = DateTime.now().toUtc();
    final nowStr = now.toIso8601String();

    // Finalize PREVIOUS State
    if (_callDetails.isNotEmpty) {
      final lastEntry = _callDetails.last;
      final start = DateTime.parse(lastEntry['startTime']);
      final duration = now.difference(start).inSeconds;

      lastEntry['endTime'] = nowStr;
      lastEntry['duration'] = duration;
    } else {
      // First state starts here
    }

    // Add NEW Active State
    _callDetails.add({
      "state": state,
      "startTime": nowStr,
      "endTime": null,
      "duration": 0,
    });

    _lastState = state;
    lastStateTime = now;

    debugPrint("CallLogger: State Logged: $state");

    // PERSIST UPDATE FOR CROSS-ISOLATE Or FUTURE RESTORE
    _currentSession!['saved_details'] = _callDetails;
    try {
      final file = await _getSessionFile();
      await file.writeAsString(jsonEncode(_currentSession));
    } catch (e) {
      // ignore write error
    }

    // --- AUTOMATIC RECORDING START REMOVED ---
    // (We now rely only on system recordings)
    // ----------------------------------

    if (state == "DISCONNECTED") {
      await endSession();
    }
  }

  // Finalize and Send
  Future<void> endSession() async {
    if (_currentSession == null) return;
    if (_isEnding) {
      debugPrint(
        "CallLogger: endSession already in progress, skipping duplicate call",
      );
      return;
    }
    _isEnding = true;

    final uniqueId = _currentSession!['uniqueCallId'].toString();
    debugPrint("CallLogger: endSession STARTED for session $uniqueId");

    // Check if the session file was deleted (which means Kotlin background service already successfully sent the webhook)
    try {
      final file = await _getSessionFile();
      if (!await file.exists()) {
        debugPrint(
          "CallLogger: Session file was already deleted/sent by background service. Clearing in-memory state.",
        );
        _currentSession = null;
        _callDetails = [];
        lastStateTime = null;
        _systemRecordingCompleter = null;
        _lastActivePayload = null;
        _simSlot = 1;
        _simDisplayName = '';
        _isEnding = false;
        return;
      }

      // Check for disk-based isEnding lock to handle multi-isolate concurrency
      final content = await file.readAsString();
      if (content.isNotEmpty) {
        final diskSession = jsonDecode(content);
        if (diskSession['isEnding'] == true) {
          debugPrint("CallLogger: endSession already locked on disk by another isolate. Aborting.");
          _currentSession = null;
          _callDetails = [];
          lastStateTime = null;
          _systemRecordingCompleter = null;
          _lastActivePayload = null;
          _simSlot = 1;
          _simDisplayName = '';
          _isEnding = false;
          return;
        }
      }

      // Lock session on disk
      _currentSession!['isEnding'] = true;
      _currentSession!['saved_details'] = _callDetails;
      await file.writeAsString(jsonEncode(_currentSession));
      debugPrint("CallLogger: Session lock written to disk.");
    } catch (e) {
      debugPrint("CallLogger: Failed to check/write disk lock: $e");
    }

    final now = DateTime.now().toUtc();
    final nowStr = now.toIso8601String();
    _currentSession!['endTime'] = nowStr;

    // Preliminary duration
    int appCalculatedDuration = 0;
    if (_currentSession!['startTimeMillis'] != null) {
      final int startMillis = _currentSession!['startTimeMillis'] as int;
      appCalculatedDuration = (DateTime.now().millisecondsSinceEpoch - startMillis) ~/ 1000;
      if (appCalculatedDuration < 0) appCalculatedDuration = 0;
    } else if (_currentSession!['startTime'] != null) {
      final sessionStart = DateTime.parse(_currentSession!['startTime']).toUtc();
      appCalculatedDuration = now.difference(sessionStart).inSeconds;
    }
    _currentSession!['duration'] = appCalculatedDuration;

    // Finalize LAST state duration in local list
    if (_callDetails.isNotEmpty) {
      final lastEntry = _callDetails.last;
      if (lastEntry['endTime'] == null) {
        final start = DateTime.parse(lastEntry['startTime']);
        lastEntry['endTime'] = nowStr;
        lastEntry['duration'] = now.difference(start).inSeconds;
      }
    }

    // Capture references for background processing
    final sessionDataCopy = Map<String, dynamic>.from(_currentSession!);
    final callDetailsCopy = List<Map<String, dynamic>>.from(
      _callDetails.map((e) => Map<String, dynamic>.from(e)),
    );

    // IMMEDIATELY reset memory state so that subsequent calls placed within the
    // 60-second system recording extraction window are not silently ignored!
    _currentSession = null;
    _callDetails = [];
    lastStateTime = null;
    _systemRecordingCompleter = null;
    _lastActivePayload = null;
    _simSlot = 1;
    _simDisplayName = '';
    _isEnding = false;

    // Start background finalization and sync
    _runFinalizationInBackground(
      uniqueId,
      sessionDataCopy,
      callDetailsCopy,
      appCalculatedDuration,
    );
  }

  Future<void> _runFinalizationInBackground(
    String uniqueId,
    Map<String, dynamic> session,
    List<Map<String, dynamic>> details,
    int appCalculatedDuration,
  ) async {
    debugPrint("CallLogger: Background finalization started for $uniqueId");

    int systemDuration = 0;
    bool matchFound = false;
    CallLogEntry? matchedEntry;

    try {
      // Wait for system to write call log (Essential for accurate duration)
      await Future.delayed(const Duration(seconds: 3));

      final phone = session['receiverNumber'].toString();
      Iterable<CallLogEntry> entries = await CallLog.query(
        dateFrom: DateTime.now().subtract(const Duration(minutes: 5)).millisecondsSinceEpoch,
      );
      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      final int sessionStartMs = session['startTimeMillis'] as int? ??
          (session['startTime'] != null
              ? DateTime.parse(session['startTime']).millisecondsSinceEpoch
              : DateTime.now().subtract(const Duration(minutes: 5)).millisecondsSinceEpoch);

      final int windowStart = sessionStartMs - 10000;
      final int windowEnd = DateTime.now().millisecondsSinceEpoch + 30000;

      final matchedEntries = entries.where((e) {
        final eNum = (e.number ?? '').replaceAll(RegExp(r'\D'), '');
        final isNumMatch = eNum.isNotEmpty &&
            (eNum == cleanPhone ||
                eNum.endsWith(cleanPhone) ||
                cleanPhone.endsWith(eNum));
        if (!isNumMatch) return false;

        final ts = e.timestamp ?? 0;
        return ts >= windowStart && ts <= windowEnd;
      }).toList();

      matchedEntries.sort((a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0));

      if (matchedEntries.isNotEmpty) {
        matchedEntry = matchedEntries.first;
        matchFound = true;
        systemDuration = matchedEntry.duration ?? 0;
      }
    } catch (e) {
      debugPrint("CallLogger: Duration Sync Error: $e");
    }

    List<Map<String, dynamic>> finalDetails = [];
    if (matchFound) {
      debugPrint("CallLogger: Sync success. System Duration: $systemDuration sec");
      session['duration'] = systemDuration;

      // Update call status dynamically based on system call log properties
      if (matchedEntry != null) {
        final logType = matchedEntry.callType;
        if (systemDuration == 0) {
          if (logType == CallType.missed) {
            session['status'] = 'missed';
          } else if (logType == CallType.rejected) {
            session['status'] = 'rejected';
          } else if (logType == CallType.blocked) {
            session['status'] = 'blocked';
          } else {
            session['status'] = 'missed';
          }
        } else {
          session['status'] = 'delivered';
        }
        debugPrint("CallLogger: System status resolved to: ${session['status']} (Type: $logType)");
      }

      // Match active SIM to resolve correct callerNumber for Dual SIMs
      try {
        final activeSims = await DialerService().getActiveSims();
        Map<String, dynamic>? matchedSim;

        final sessionPhoneAccountId = session['phoneAccountId'];
        final logPhoneAccountId = matchedEntry?.phoneAccountId;
        final pId = logPhoneAccountId ?? sessionPhoneAccountId;
        if (pId != null) {
          final pIdStr = pId.toString();
          for (var sim in activeSims) {
            final subId = sim['subscriptionId']?.toString();
            final slot = sim['slotIndex']?.toString();
            final iccId = sim['iccId']?.toString();
            if (subId == pIdStr ||
                slot == pIdStr ||
                (iccId != null && iccId.isNotEmpty && (iccId == pIdStr || pIdStr.contains(iccId) || iccId.contains(pIdStr))) ||
                (subId != null && pIdStr.contains(subId)) ||
                (slot != null && pIdStr.contains(slot))) {
              matchedSim = sim;
              break;
            }
          }
        }

        if (matchedSim == null &&
            matchedEntry?.simDisplayName != null &&
            matchedEntry!.simDisplayName!.isNotEmpty) {
          final disp = matchedEntry.simDisplayName!.toLowerCase().trim();
          for (var sim in activeSims) {
            final sDisp = (sim['displayName'] ?? '').toString().toLowerCase().trim();
            if (sDisp.isNotEmpty && (sDisp.contains(disp) || disp.contains(sDisp))) {
              matchedSim = sim;
              break;
            }
          }

          if (matchedSim == null) {
            int? slotIndex;
            if (disp.contains('sim 1') || disp.contains('slot 1') || disp == '1') {
              slotIndex = 0;
            } else if (disp.contains('sim 2') || disp.contains('slot 2') || disp == '2') {
              slotIndex = 1;
            }
            if (slotIndex != null) {
              for (var sim in activeSims) {
                if (sim['slotIndex'] == slotIndex) {
                  matchedSim = sim;
                  break;
                }
              }
            }
          }
        }

        if (matchedSim != null) {
          final matchedNumber = matchedSim['number']?.toString() ?? '';
          final matchedDisplayName = matchedSim['displayName']?.toString() ?? '';
          final slotIndex = (matchedSim['slotIndex'] as num?)?.toInt() ?? 0;

          if (matchedNumber.isNotEmpty) {
            if (matchedDisplayName.isNotEmpty && !matchedNumber.contains(matchedDisplayName)) {
              session['callerNumber'] = '$matchedNumber ($matchedDisplayName)';
            } else {
              session['callerNumber'] = matchedNumber;
            }
          } else {
            final String currentCaller = session['callerNumber']?.toString() ?? '';
            if (matchedDisplayName.isNotEmpty && !currentCaller.contains(matchedDisplayName)) {
              session['callerNumber'] = '$currentCaller ($matchedDisplayName)';
            }
          }
          
          session['simSlot'] = (slotIndex + 1).toString();
          session['simDisplayName'] = matchedDisplayName;
        } else if (matchedEntry?.simDisplayName != null &&
            matchedEntry!.simDisplayName!.isNotEmpty) {
          final String currentCaller = session['callerNumber']?.toString() ?? '';
          if (!currentCaller.contains(matchedEntry.simDisplayName!)) {
            session['callerNumber'] = '$currentCaller (${matchedEntry.simDisplayName})';
          }
          final disp = matchedEntry.simDisplayName!.toLowerCase().trim();
          int slotIndex = 0;
          if (disp.contains('sim 2') || disp.contains('slot 2') || disp == '2') {
            slotIndex = 1;
          } else if (disp.contains('sim 1') || disp.contains('slot 1') || disp == '1') {
            slotIndex = 0;
          } else {
            final existingSlot = int.tryParse(session['simSlot']?.toString() ?? '');
            if (existingSlot != null) {
              slotIndex = existingSlot - 1;
            }
          }
          session['simSlot'] = (slotIndex + 1).toString();
          session['simDisplayName'] = matchedEntry.simDisplayName;
        }
      } catch (e) {
        debugPrint("CallLogger: Error matching SIM: $e");
      }

      final talkTime = systemDuration;
      var elapsedTotal = appCalculatedDuration;
      if (talkTime > elapsedTotal) {
        elapsedTotal = talkTime;
      }
      if (talkTime == 0) {
        session['duration'] = 0;
      } else {
        session['duration'] = elapsedTotal;
      }

      if (talkTime > 0) {
        final dialingDur = elapsedTotal > talkTime ? elapsedTotal - talkTime : 0;
        final startDt = DateTime.parse(session['startTime']);
        final activeStartDt = startDt.add(Duration(seconds: dialingDur));

        finalDetails.add({
          "state": "DIALING",
          "startTime": session['startTime'],
          "endTime": activeStartDt.toIso8601String(),
          "duration": dialingDur,
        });
        finalDetails.add({
          "state": "ACTIVE",
          "startTime": activeStartDt.toIso8601String(),
          "endTime": session['endTime'],
          "duration": talkTime,
        });
      } else {
        finalDetails.add({
          "state": "DIALING",
          "startTime": session['startTime'],
          "endTime": session['endTime'],
          "duration": elapsedTotal,
        });
      }
      finalDetails.add({
        "state": "DISCONNECTED",
        "startTime": session['endTime'],
        "endTime": session['endTime'],
        "duration": 0,
      });
    } else {
      debugPrint("CallLogger: No matching system call log found. Reconstructing.");
      int totalHoldDuration = 0;
      for (var detail in details) {
        if (detail['state'] == 'HOLDING') {
          totalHoldDuration += (detail['duration'] as num).toInt();
        }
      }
      session['holdDuration'] = totalHoldDuration;

      bool hasActive = details.any((d) => d['state'] == 'ACTIVE' || d['state'] == 'CONNECTED');
      final activeDuration = hasActive
          ? details
              .where((d) => d['state'] == 'ACTIVE' || d['state'] == 'CONNECTED')
              .fold<int>(0, (sum, d) => sum + ((d['duration'] as num?)?.toInt() ?? 0))
          : 0;

      var elapsedTotal = appCalculatedDuration;
      if (activeDuration > elapsedTotal) {
        elapsedTotal = activeDuration;
      }
      
      if (activeDuration == 0) {
        session['duration'] = 0;
        session['status'] = 'missed';
      } else {
        session['duration'] = elapsedTotal;
        session['status'] = 'delivered';
      }

      if (activeDuration > 0) {
        final dialingDur = elapsedTotal > activeDuration ? elapsedTotal - activeDuration : 0;
        final startDt = DateTime.parse(session['startTime']);
        final activeStartDt = startDt.add(Duration(seconds: dialingDur));

        finalDetails.add({
          "state": "DIALING",
          "startTime": session['startTime'],
          "endTime": activeStartDt.toIso8601String(),
          "duration": dialingDur,
        });
        finalDetails.add({
          "state": "ACTIVE",
          "startTime": activeStartDt.toIso8601String(),
          "endTime": session['endTime'],
          "duration": activeDuration,
        });
      } else {
        finalDetails.add({
          "state": "DIALING",
          "startTime": session['startTime'],
          "endTime": session['endTime'],
          "duration": elapsedTotal,
        });
      }
      finalDetails.add({
        "state": "DISCONNECTED",
        "startTime": session['endTime'],
        "endTime": session['endTime'],
        "duration": 0,
      });
    }

    session.remove('saved_details');
    final payload = {...session, "callDetails": finalDetails};
    _activePayloads[uniqueId] = payload;

    final duration = payload['duration'] ?? 0;
    final status = payload['status']?.toString() ?? '';

    // Bypass search & delay for missed/unanswered/cut calls (no system recording exists)
    bool isUnconnected = duration == 0 ||
        status == 'missed' ||
        status == 'rejected' ||
        status == 'blocked' ||
        status == 'failed' ||
        status == 'cancelled' ||
        status == 'no_answer';

    final phone = session['receiverNumber'].toString();
    final companyId = session['companyId']?.toString();
    final userId = session['userId']?.toString();

    if (!isUnconnected) {
      if (onSessionEnded != null) {
        // Main-isolate path: delegate to the Riverpod-managed provider.
        debugPrint("CallLogger: Answered call ($duration sec). Triggering system extraction & waiting...");
        final completer = Completer<void>();
        _recordingCompleters[uniqueId] = completer;

        onSessionEnded!(phone, uniqueId, companyId, userId, duration);

        try {
          // 75 s covers the 20 s write delay + 3 retries × 8 s on slow devices.
          await completer.future.timeout(const Duration(seconds: 75));
          debugPrint("CallLogger: System recording resolved in background.");
        } catch (e) {
          debugPrint("CallLogger: System extraction timed out in background. Proceeding.");
        }
      } else {
        // Background-isolate path: onSessionEnded callback is not set because
        // main.dart never ran in this isolate (app was killed / backgrounded).
        // Extract the recording directly without Riverpod.
        debugPrint("CallLogger: Answered call ($duration sec). onSessionEnded not set — extracting directly.");
        await _extractRecordingDirectly(phone, uniqueId, companyId, userId, duration);
      }
    } else {
      debugPrint("CallLogger: Unconnected call ($status, duration $duration). Bypassing recording search entirely.");
    }

    // Sync back any recording details if populated by reportSystemRecording
    final updatedPayload = _activePayloads[uniqueId] ?? payload;
    
    // Final webhook delivery
    await _sendFinalWebhook(updatedPayload);

    // Cleanup session file safely
    try {
      final file = await _getSessionFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final diskSession = jsonDecode(content);
          if (diskSession['uniqueCallId'] == uniqueId) {
            await file.delete();
            debugPrint("CallLogger: Disk Session File Deleted for session $uniqueId.");
          } else {
            debugPrint("CallLogger: Disk Session File belongs to another active session (${diskSession['uniqueCallId']}). Keeping it.");
          }
        }
      }
    } catch (e) {
      debugPrint("CallLogger: Failed to delete disk session file: $e");
    }

    _recordingCompleters.remove(uniqueId);
    _activePayloads.remove(uniqueId);
  }

  Future<void> _sendFinalWebhook(Map<String, dynamic> payload) async {
    debugPrint("CallLogger: ----------------------------------------");
    debugPrint(
      "CallLogger: 🚀 SENDING FINAL WEBHOOK (UniqueId: ${payload['uniqueCallId']})",
    );
    debugPrint("CallLogger: Recording Source: ${payload['recordingSource']}");
    debugPrint("CallLogger: Recording URL: ${payload['recordingUrl']}");
    debugPrint(
      "CallLogger: Endpoint: ${AuthService.baseUrl}/api/v1/push/dialer/webhook",
    );
    debugPrint("CallLogger: Call Stack: ${StackTrace.current}");
    debugPrint("CallLogger: Payload Body: ${jsonEncode(payload)}");

    try {
      final response = await http
          .post(
            Uri.parse('${AuthService.baseUrl}/api/v1/push/dialer/webhook'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint("CallLogger: Webhook Result: Status ${response.statusCode}");
      debugPrint("CallLogger: Response Body: ${response.body}");
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _webhookSentController.add(payload['uniqueCallId']?.toString() ?? '');
      }
    } catch (e) {
      debugPrint("CallLogger: CRITICAL FAILURE Sending Webhook: $e");
    }
    debugPrint("CallLogger: ----------------------------------------");
  }

  /// Fallback recording extraction used when [onSessionEnded] is not set
  /// (e.g. the session ends inside a background isolate where the Riverpod
  /// provider is unavailable).  Mirrors the logic in
  /// [RecordingExtractionNotifier.handleCallEnd].
  Future<void> _extractRecordingDirectly(
    String phone,
    String uniqueCallId,
    String? companyId,
    String? userId,
    int durationSeconds,
  ) async {
    debugPrint('CallLogger: [DirectExtract] Starting for $phone ($uniqueCallId)');
    try {
      // Give the device time to finish writing the recording to MediaStore.
      // 20 s covers Samsung One UI which can take 15-25 s to finalise.
      await Future.delayed(const Duration(seconds: 20));

      File? file;
      for (int attempt = 1; attempt <= 3; attempt++) {
        debugPrint('CallLogger: [DirectExtract] Search attempt $attempt for $phone');
        file = await RecordingExtractionService().findLatestRecording(
          phone,
          expectedDurationSeconds: durationSeconds,
        );
        if (file != null) break;
        if (attempt < 3) {
          debugPrint('CallLogger: [DirectExtract] Not found, retrying in 8 s...');
          await Future.delayed(const Duration(seconds: 8));
        }
      }

      if (file != null) {
        debugPrint('CallLogger: [DirectExtract] Found: \${file.path}');
        final r2Url = await R2Service().uploadAudio(
          file,
          uniqueCallId,
          companyId: companyId,
          userId: userId,
        );
        await reportSystemRecording(uniqueCallId, r2Url);
        debugPrint('CallLogger: [DirectExtract] Upload result: \$r2Url');
        try {
          await file.delete();
        } catch (_) {}
      } else {
        debugPrint('CallLogger: [DirectExtract] No recording found. Releasing webhook.');
        await reportSystemRecording(uniqueCallId, null);
      }
    } catch (e) {
      debugPrint('CallLogger: [DirectExtract] Error: \$e');
      await reportSystemRecording(uniqueCallId, null);
    }
  }
}
