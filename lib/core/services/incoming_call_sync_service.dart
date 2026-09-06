import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:call_log/call_log.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'http_client.dart' as http;
import 'auth_service.dart';
import 'dialer_service.dart';
import '../../data/models/user_model.dart';

/// Optimized service to synchronize local phone Incoming Call Logs with Trevion CRM backend.
/// Designed for zero lag and minimal server load even with 50,000+ leads.
///
/// NOTE: This feature is strictly for Android (`Platform.isAndroid`).
/// On iOS, Web, and all other platforms, it exits immediately with no side-effects.
class IncomingCallSyncService {
  static final IncomingCallSyncService _instance = IncomingCallSyncService._internal();

  factory IncomingCallSyncService() => _instance;

  IncomingCallSyncService._internal();

  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  final Set<String> _inMemorySyncedIds = {};
  Box? _syncCacheBox;

  /// Ensure local cache box is opened for persistent deduplication
  Future<Box> _getCacheBox() async {
    if (_syncCacheBox != null && _syncCacheBox!.isOpen) {
      return _syncCacheBox!;
    }
    _syncCacheBox = await Hive.openBox('synced_incoming_calls_box');
    return _syncCacheBox!;
  }

  bool _isCallAlreadySynced(String appCallId, Box cacheBox) {
    if (_inMemorySyncedIds.contains(appCallId)) return true;
    return cacheBox.containsKey(appCallId);
  }

  Future<void> _markCallAsSynced(String appCallId, Box cacheBox) async {
    _inMemorySyncedIds.add(appCallId);
    try {
      await cacheBox.put(appCallId, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint("IncomingCallSyncService: Error saving synced call id to cache: $e");
    }
  }

  /// Helper to clean old entries from cache box to prevent unbounded growth
  Future<void> _pruneCacheBoxIfNeeded(Box cacheBox) async {
    try {
      if (cacheBox.length > 2000) {
        // Keep the most recent 1000 items
        final keys = cacheBox.keys.toList();
        final keysToDelete = keys.take(keys.length - 1000);
        await cacheBox.deleteAll(keysToDelete);
      }
    } catch (_) {}
  }

  /// Normalizes phone numbers to compare them accurately (matches exact digits or last 10 digits)
  bool _phoneMatches(String p1, String p2) {
    final d1 = p1.replaceAll(RegExp(r'\D'), '');
    final d2 = p2.replaceAll(RegExp(r'\D'), '');
    if (d1.isEmpty || d2.isEmpty) return false;
    if (d1 == d2) return true;
    if (d1.length >= 10 && d2.length >= 10) {
      return d1.substring(d1.length - 10) == d2.substring(d2.length - 10);
    }
    return false;
  }

  /// Main method: Executes the 4-step sync workflow asynchronously.
  /// 
  /// [force]: If true, bypasses the 20-second throttle.
  /// [hoursBack]: How many hours back to look for incoming calls (default: 48h).
  Future<void> syncIncomingCalls({bool force = false, int hoursBack = 48}) async {
    // 1. Android ONLY Guard: Non-Android platforms exit immediately.
    if (!Platform.isAndroid) {
      debugPrint("IncomingCallSyncService: Bypassed — incoming call sync is Android-only.");
      return;
    }

    // 2. Concurrency & Debounce Check
    if (_isSyncing) {
      debugPrint("IncomingCallSyncService: Sync already in progress. Skipping duplicate run.");
      return;
    }

    final now = DateTime.now();
    if (!force && _lastSyncTime != null && now.difference(_lastSyncTime!) < const Duration(seconds: 20)) {
      debugPrint("IncomingCallSyncService: Throttled (last sync was ${now.difference(_lastSyncTime!).inSeconds}s ago).");
      return;
    }

    _isSyncing = true;
    _lastSyncTime = now;

    try {
      // 3. Permission Check
      final phoneGranted = await Permission.phone.status.isGranted;
      if (!phoneGranted) {
        debugPrint("IncomingCallSyncService: Phone/CallLog permission not granted. Skipping sync.");
        return;
      }

      // 4. Token & Auth Check
      final authBox = await Hive.openBox('authBox');
      final token = authBox.get('accessToken');
      if (token == null || token.toString().trim().isEmpty) {
        debugPrint("IncomingCallSyncService: User is not logged in (no accessToken). Skipping sync.");
        return;
      }

      // -------------------------------------------------------------
      // Step 1: Read recent incoming call logs from local phone DB
      // -------------------------------------------------------------
      final fromMillis = now.subtract(Duration(hours: hoursBack)).millisecondsSinceEpoch;
      debugPrint("IncomingCallSyncService: Step 1 - Querying incoming call logs from last $hoursBack hours...");

      Iterable<CallLogEntry> allEntries;
      try {
        allEntries = await CallLog.query(dateFrom: fromMillis);
      } catch (e) {
        debugPrint("IncomingCallSyncService: CallLog.query failed: $e");
        return;
      }

      // Filter entries to only incoming call types
      final incomingEntries = allEntries.where((entry) {
        if (entry.number == null || entry.number!.trim().isEmpty) return false;
        final type = entry.callType;
        return type == CallType.incoming ||
            type == CallType.missed ||
            type == CallType.rejected ||
            type == CallType.blocked ||
            type == CallType.answeredExternally;
      }).toList();

      debugPrint("IncomingCallSyncService: Found ${incomingEntries.length} incoming call logs in phone.");

      if (incomingEntries.isEmpty) {
        debugPrint("IncomingCallSyncService: No incoming calls found in queried window.");
        return;
      }

      // -------------------------------------------------------------
      // Step 2: Extract unique numbers and check matching leads with backend
      // -------------------------------------------------------------
      final Set<String> uniqueNumbersSet = {};
      for (final entry in incomingEntries) {
        final raw = entry.number!.trim();
        if (raw.isNotEmpty) {
          uniqueNumbersSet.add(raw);
        }
      }

      if (uniqueNumbersSet.isEmpty) {
        return;
      }

      debugPrint("IncomingCallSyncService: Step 2 - Checking ${uniqueNumbersSet.length} unique incoming numbers via API...");

      final checkUrl = Uri.parse('${AuthService.baseUrl}/api/v1/leads/call/incoming-check');
      final checkResponse = await http.post(
        checkUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Bypass-Tunnel-Reminder': 'true',
        },
        body: jsonEncode({
          'phoneNumbers': uniqueNumbersSet.toList(),
        }),
      );

      if (checkResponse.statusCode != 200 && checkResponse.statusCode != 201) {
        debugPrint("IncomingCallSyncService: incoming-check error (${checkResponse.statusCode}): ${checkResponse.body}");
        return;
      }

      final checkJson = jsonDecode(checkResponse.body);
      final List matchedLeads = (checkJson['data'] != null && checkJson['data']['leads'] != null)
          ? checkJson['data']['leads']
          : [];

      debugPrint("IncomingCallSyncService: Matched ${matchedLeads.length} leads from company database.");

      if (matchedLeads.isEmpty) {
        debugPrint("IncomingCallSyncService: None of the incoming numbers matched existing leads.");
        return;
      }

      // Resolve Agent Receiver Number (for receiverNumber in logs)
      String? receiverNumber;
      try {
        final activeSims = await DialerService().getActiveSims();
        for (var sim in activeSims) {
          final simPhone = sim['phoneNumber']?.toString();
          if (simPhone != null && simPhone.trim().isNotEmpty) {
            receiverNumber = simPhone.trim();
            break;
          }
        }
      } catch (_) {}
      if (receiverNumber == null || receiverNumber.isEmpty) {
        try {
          final userJson = authBox.get('user');
          if (userJson != null) {
            final user = User.fromJson(jsonDecode(userJson));
            if (user.phoneNo.trim().isNotEmpty) {
              receiverNumber = user.phoneNo.trim();
            }
          }
        } catch (_) {}
      }

      final cacheBox = await _getCacheBox();
      await _pruneCacheBoxIfNeeded(cacheBox);

      // -------------------------------------------------------------
      // Step 3: Filter incoming calls newer than lastIncomingCall
      // -------------------------------------------------------------
      debugPrint("IncomingCallSyncService: Step 3 - Filtering new calls newer than lastIncomingCall...");

      final List<Map<String, dynamic>> logsToSync = [];
      final Set<String> batchProcessedIds = {};

      for (final lead in matchedLeads) {
        final leadPhone = (lead['phone'] ?? lead['phoneNo'] ?? '').toString().trim();
        final lastIncomingStr = lead['lastIncomingCall']?.toString();
        DateTime? lastIncomingUtc;
        if (lastIncomingStr != null && lastIncomingStr.isNotEmpty) {
          lastIncomingUtc = DateTime.tryParse(lastIncomingStr)?.toUtc();
        }

        // Find all call log entries from the phone matching this lead
        final leadEntries = incomingEntries.where((e) => _phoneMatches(e.number ?? '', leadPhone)).toList();

        for (final entry in leadEntries) {
          final timestamp = entry.timestamp;
          if (timestamp == null || timestamp <= 0) continue;

          final callTimeUtc = DateTime.fromMillisecondsSinceEpoch(timestamp).toUtc();

          // Compare timestamps:
          // If lastIncomingUtc is null -> This lead has no prior incoming calls synced -> SELECT
          // If callTimeUtc > lastIncomingUtc -> Newer call -> SELECT
          // If callTimeUtc <= lastIncomingUtc -> Already synced -> SKIP
          bool isNewCall = false;
          if (lastIncomingUtc == null) {
            isNewCall = true;
          } else {
            isNewCall = callTimeUtc.millisecondsSinceEpoch > lastIncomingUtc.millisecondsSinceEpoch;
          }

          if (!isNewCall) {
            continue;
          }

          // Generate unique appCallId for deduplication
          final cleanPhone = (entry.number ?? leadPhone).replaceAll(RegExp(r'[^\d+]'), '');
          final appCallId = "INCOMING_${cleanPhone}_$timestamp";

          // Deduplication checks (within current batch & local cache)
          if (batchProcessedIds.contains(appCallId) || _isCallAlreadySynced(appCallId, cacheBox)) {
            continue;
          }
          batchProcessedIds.add(appCallId);

          // Resolve duration & status
          final isMissed = entry.callType == CallType.missed;
          final isRejected = entry.callType == CallType.rejected;
          final isBlocked = entry.callType == CallType.blocked;
          final duration = (isMissed || isRejected || isBlocked) ? 0 : (entry.duration ?? 0);

          String status = 'completed';
          if (isMissed) {
            status = 'missed';
          } else if (isRejected) {
            status = 'rejected';
          } else if (isBlocked) {
            status = 'blocked';
          } else if (duration == 0) {
            status = 'missed';
          }

          final endTimeUtc = callTimeUtc.add(Duration(seconds: duration));

          logsToSync.add({
            "phone": leadPhone.isNotEmpty ? leadPhone : (entry.number ?? ''),
            "callerNumber": entry.number ?? leadPhone,
            if (receiverNumber != null && receiverNumber.isNotEmpty)
              "receiverNumber": receiverNumber,
            "duration": duration,
            "callTime": callTimeUtc.toIso8601String(),
            "endTime": endTimeUtc.toIso8601String(),
            "status": status,
            "appCallId": appCallId,
          });
        }
      }

      debugPrint("IncomingCallSyncService: Filtered ${logsToSync.length} new incoming calls to sync.");

      if (logsToSync.isEmpty) {
        debugPrint("IncomingCallSyncService: No new calls to sync. Everything is up-to-date.");
        return;
      }

      // -------------------------------------------------------------
      // Step 4: Bulk sync new incoming calls to backend
      // -------------------------------------------------------------
      debugPrint("IncomingCallSyncService: Step 4 - Bulk syncing ${logsToSync.length} calls to POST /call/bulk-sync-incoming...");

      final bulkSyncUrl = Uri.parse('${AuthService.baseUrl}/api/v1/leads/call/bulk-sync-incoming');
      final syncResponse = await http.post(
        bulkSyncUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Bypass-Tunnel-Reminder': 'true',
        },
        body: jsonEncode({
          'logs': logsToSync,
        }),
      );

      if (syncResponse.statusCode == 200 || syncResponse.statusCode == 201) {
        debugPrint("IncomingCallSyncService: Bulk sync success! Result: ${syncResponse.body}");

        // Save synced appCallIds to local cache
        for (final item in logsToSync) {
          final id = item['appCallId']?.toString();
          if (id != null && id.isNotEmpty) {
            await _markCallAsSynced(id, cacheBox);
          }
        }
      } else {
        debugPrint("IncomingCallSyncService: Bulk sync failed (${syncResponse.statusCode}): ${syncResponse.body}");
      }
    } catch (e, stack) {
      debugPrint("IncomingCallSyncService: Exception during incoming call sync: $e\n$stack");
    } finally {
      _isSyncing = false;
    }
  }
}
