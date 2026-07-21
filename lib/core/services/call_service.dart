
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:call_log/call_log.dart';
import 'package:phone_state/phone_state.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'call_logger_service.dart';
import 'dialer_service.dart';

class CallService {
  
  // Singleton pattern if needed, or just a service class.
  
  Future<bool> requestPermissions() async {
      if (Platform.isIOS) {
        // iOS doesn't require telephony permissions. Standard permission handler handles notification.
        await [Permission.notification].request();
        return true;
      }
      // Request all critical permissions for the app functionality
      Map<Permission, PermissionStatus> statuses = await [
        Permission.phone,             // Calls, Read Phone State, Read Numbers + READ_CALL_LOG (mapped natively)
        Permission.notification,      // For Foreground Service notifications (Android 13+)
        Permission.systemAlertWindow, // For Call Overlay
        Permission.audio,             // READ_MEDIA_AUDIO (Android 13+) — needed to find call recordings
        Permission.storage,           // READ_EXTERNAL_STORAGE (Android ≤12) — needed to find call recordings
      ].request();
      
      debugPrint("CallService: Permissions requested: $statuses");
      
      // Return true if critical permissions are granted (Phone is most critical)
      return statuses[Permission.phone]?.isGranted ?? false;
  }
  


  /// 1. Open Dialer
  /// set [isBackground] to true if initiating from FCM or Background Service to bypass restrictions
  Future<void> makeCall(String phoneNumber, {Map<String, dynamic>? callContext, bool isBackground = false}) async {
    try {
      final number = _normalize(phoneNumber);
      debugPrint("CallService: makeCall initiated for $number (isBackground=$isBackground)");
      
      final Uri launchUri = Uri(
        scheme: 'tel',
        path: number,
      );

      if (Platform.isIOS) {
        debugPrint("CallService: Launching system dialer prompt on iOS");
        try {
          final launched = await launchUrl(launchUri);
          if (!launched) {
            throw 'launchUrl returned false';
          }
        } catch (e) {
          debugPrint("CallService: launchUrl failed on iOS: $e. Trying fallback externalApplication mode...");
          try {
            final launchedFallback = await launchUrl(launchUri, mode: LaunchMode.externalApplication);
            if (!launchedFallback) {
              throw 'launchUrl fallback returned false';
            }
          } catch (e2) {
            debugPrint("CallService: Fallback launch failed: $e2");
            throw 'This device does not support cellular calls (or is a simulator).';
          }
        }
        return;
      }
      
      // Init Logging if context provided
      if (callContext != null) {
          callContext['phoneNo'] = number; 
          await CallLoggerService().initSession(callContext);
      }
      
      // Safety Check: Permission
      if (await Permission.phone.status.isGranted) {
          debugPrint("CallService: Phone permission is granted.");
      } else {
          debugPrint("CallService: Phone permission NOT granted. Call might fail if in background.");
      }

      
      // Check if we are the default dialer (Self-Managed)
      bool isDefault = false;
      try {
         isDefault = await DialerService().checkIsDefault();
      } catch (e) {
         debugPrint("CallService: Error checking default dialer: $e");
      }
      
      debugPrint("CallService: isDefaultDialer = $isDefault");

      if (isDefault) {
          // Use our internal logic to place call via TelecomManager
          debugPrint("CallService: App is default dialer, using native placeCall");
          try {
             await DialerService().placeCall(number);
          } catch(e) {
             debugPrint("CallService: Native placeCall failed: $e");
             // Fallback
             await launchUrl(launchUri);
          }
      } else {
          // Logic for System Dialer (Overlay + Intent)
          final name = callContext?['name'] ?? 'Unknown';
          
          if (isBackground) {
             // BACKGROUND: Use Overlay Service to initiate call (bypass restrictions)
             debugPrint("CallService: BACKGROUND MODE - Launching via Overlay Service for: $number");
             try {
                await DialerService().startOverlay(name, number, makeCall: true, extraData: callContext); 
             } catch (e) {
                debugPrint("CallService: Overlay start failed (Bg): $e");
             }
          } else {
             // FOREGROUND (Manual): Use Overlay for UI + Direct Call Intent
             debugPrint("CallService: FOREGROUND MODE - Launching Overlay + Direct Call for: $number");
             
             // 1. Show Overlay (UI) - Optional but good for UX
             try {
                await DialerService().startOverlay(name, number, makeCall: false);
             } catch(e) {
                 debugPrint("CallService: Overlay start failed (Fg): $e");
             }

             // 2. Launch Direct Call (ACTION_CALL) via Native Plugin
             // Short delay to let overlay appear
             await Future.delayed(const Duration(milliseconds: 300));
             
             try {
                // This uses Intent.ACTION_CALL (Direct Call)
                await DialerService().placeCall(number);
             } catch (e2) {
                debugPrint("CallService: Direct placeCall failed: $e2");
                
                // Fallback: Default Dialer Launch (ACTION_DIAL)
                debugPrint("CallService: Fallback to ACTION_DIAL");
                try {
                   if (!await launchUrl(launchUri, mode: LaunchMode.externalApplication)) {
                      throw 'Could not launch $number';
                   }
                } catch (e3) {
                   debugPrint("CallService: Final fallback failed: $e3");
                }
             }
          }
      }
    } catch (e) {
      debugPrint("CallService: makeCall Critical Error: $e");
      rethrow;
    }
  }


  /// 2. Request Permissions (Removed duplicate)
  /// Use the implementation at the top of the file
  
  Future<bool> requestOverlayPermission() async {
      if (Platform.isIOS) return true;
      return await Permission.systemAlertWindow.request().isGranted;
  }

  /// 3. Get Last Call Details
  Future<Map<String, dynamic>?> getLastCallDetails(String phoneNumber) async {
    if (Platform.isIOS) return null;
    // wait a brief moment for system to write log if we just hung up
    await Future.delayed(const Duration(seconds: 2));
    
    debugPrint("CallService: Querying last call details for $phoneNumber");
    
    try {
      final now = DateTime.now();
      final dateFrom = now.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch;
      
      Iterable<CallLogEntry> entries = await CallLog.query(
        dateFrom: dateFrom,
        number: phoneNumber
      );
      
      if (entries.isNotEmpty) {
          final lastCall = entries.first;
          debugPrint("CallService: Found call log entry for $phoneNumber: duration=${lastCall.duration}s");
          return {
             "duration_seconds": lastCall.duration ?? 0,
             "call_type": _getCallTypeString(lastCall.callType),
             "timestamp": lastCall.timestamp,
             "datetime": DateTime.fromMillisecondsSinceEpoch(lastCall.timestamp ?? 0).toIso8601String(),
             "connected": (lastCall.duration ?? 0) > 0
          };
      }
    } catch (e) {
      debugPrint("CallService: Error getting last call details: $e");
    }
    
    // Fallback to active session duration if call log lookup fails
    return null;
  }

  /// 4. Get Call History for a Number
  Future<List<Map<String, dynamic>>> getCallHistory(String phoneNumber) async {
    if (Platform.isIOS) return [];
    final now = DateTime.now();
    final fromDate = now.subtract(const Duration(days: 30)).millisecondsSinceEpoch;
    
    // Query logs
    Iterable<CallLogEntry> entries = await CallLog.query(
      dateFrom: fromDate,
      // number: phoneNumber, // Filtering by number directly sometimes fails if formatting differs
    );

    List<Map<String, dynamic>> history = [];
    for (var entry in entries) {
      if (entry.number != null && _normalize(entry.number!) == _normalize(phoneNumber)) {
        history.add(_formatCallData(entry));
      }
    }
    return history;
  }
  
  String _normalize(String phone) {
    return phone.replaceAll(RegExp(r'[^\d+]'), ''); // Keep digits and +
  }

  /// Format data into the requested JSON structure
  Map<String, dynamic> _formatCallData(CallLogEntry entry) {
    return {
      "number_dialed": entry.number,
      "formatted_number": entry.formattedNumber,
      "name_captured": entry.name, // Name from contacts if available
      "timestamp": entry.timestamp, 
      "datetime": DateTime.fromMillisecondsSinceEpoch(entry.timestamp ?? 0).toIso8601String(),
      "call_start_time": DateTime.fromMillisecondsSinceEpoch(entry.timestamp ?? 0).toIso8601String(), 
      "call_end_time": DateTime.fromMillisecondsSinceEpoch((entry.timestamp ?? 0) + (entry.duration ?? 0) * 1000).toIso8601String(),
      "duration_seconds": entry.duration,
      "call_type": _getCallTypeString(entry.callType),
      "connected": (entry.duration ?? 0) > 0, 
      "cached_number_type": entry.cachedNumberType, // e.g., 1 (Home), 2 (Mobile)
      "cached_number_label": entry.cachedNumberLabel,
      "sim_display_name": entry.simDisplayName, // Useful for Dual SIM
      "phone_account_id": entry.phoneAccountId,
    };
  }

  String _getCallTypeString(CallType? type) {
    switch (type) {
      case CallType.outgoing: return "OUTGOING";
      case CallType.incoming: return "INCOMING";
      case CallType.missed: return "MISSED";
      case CallType.rejected: return "REJECTED";
      default: return "UNKNOWN";
    }
  }

  // Helper to print sample JSON
  void printSampleResponse() {
     final sample = {
      "number_dialed": "9876543210",
      "timestamp": 1704873600000,
      "datetime": "2026-01-10T10:00:00.000",
      "call_start_time": "2026-01-10T10:00:00.000",
      "call_end_time": "2026-01-10T10:00:45.000",
      "duration_seconds": 45,
      "call_type": "OUTGOING",
      "connected": true
    };
    debugPrint("Sample Response: ${jsonEncode(sample)}");
  }

  /// 5. Start Global Call Listener
  void startCallListener() {
    if (Platform.isIOS) {
      debugPrint("CallService: Skipping PhoneState/Dialer Listeners on iOS");
      return;
    }
    debugPrint("CallService: Starting PhoneState Listener...");
    
    // 1. Standard PhoneState Listener (General events)
    PhoneState.stream.listen((event) {
      debugPrint("CallService: Phone State Changed -> ${event.status}");
      switch (event.status) {
        case PhoneStateStatus.CALL_ENDED:
          debugPrint("CallService: Call Ended detected!");
          CallLoggerService().logState("DISCONNECTED");
          // Also stop overlay if visible
          debugPrint("CallService: Stopping overlay...");
          DialerService().stopOverlay();
          break;
        case PhoneStateStatus.CALL_INCOMING:
          CallLoggerService().logState("RINGING");
          break;
        case PhoneStateStatus.CALL_STARTED:
          CallLoggerService().logState("DIALING");
          break;
        case PhoneStateStatus.NOTHING:
        default:
          break;
      }
    });

    // 2. Native Dialer Service Listener (Detailed events like HOLD)
    DialerService().callStateStream.listen((event) {
        final type = event['type'];
        final data = event['data'] as String?;
        final phoneAccountId = event['phoneAccountId'] as String?;
        debugPrint("CallService: Native Call State -> $type (Data: $data, phoneAccountId: $phoneAccountId)");
        
        if (phoneAccountId != null) {
            CallLoggerService().updatePhoneAccountId(phoneAccountId);
        }

        String? number;
        if (data != null && data.contains('|')) {
            number = data.split('|').last;
        }

        if (type == 'RINGING' || type == 'INCOMING') {
            if (number != null && number != 'Unknown') {
                CallLoggerService().initIncomingSession(number);
            }
            CallLoggerService().logState('RINGING');
        } else if (type == 'DIALING' || type == 'CONNECTING') {
            if (!CallLoggerService().isSessionActive && number != null && number != 'Unknown') {
                CallLoggerService().initOutgoingSession(number).catchError((e) {
                    debugPrint("CallService: initOutgoingSession failed: $e");
                });
            } else if (CallLoggerService().isSessionActive) {
                CallLoggerService().logState('DIALING');
            }
        } else if (type == 'HOLDING') {
            CallLoggerService().logState('HOLDING');
        } else if (type == 'ACTIVE') {
            CallLoggerService().logState('ACTIVE'); 
        } else if (type == 'DISCONNECTED') {
             CallLoggerService().logState('DISCONNECTED');
        }
    });
  }
}
