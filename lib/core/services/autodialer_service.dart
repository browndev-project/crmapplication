import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/autodialer_model.dart';
import '../../main.dart';
import '../../presentation/screens/autodialer/autodialer_dialog.dart';
import 'auth_service.dart';
// Original:
// import 'http_client.dart' as http;
import 'package:http/http.dart' as raw_http;
import 'http_client.dart' as http;
// Original:
// class AutoDialerService {
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/autodialer_provider.dart';

class AutoDialerService {
  static final AutoDialerService _instance = AutoDialerService._internal();
  factory AutoDialerService() => _instance;
  static AutoDialerService get instance => _instance;

  AutoDialerService._internal();

  ProviderContainer? _container;
  void initialize(ProviderContainer container) {
    _container = container;
  }

  bool _isDialogOpen = false;
  bool get isDialogOpen => _isDialogOpen;
  void setDialogState(bool open) => _isDialogOpen = open;

  DateTime? _lastTriggerTime;

  Future<String> _getAccessToken() async {
    final box = await Hive.openBox('authBox');
    final token = box.get('accessToken');
    if (token == null || token.toString().isEmpty) {
      throw 'No access token found. Please log in again.';
    }
    return token.toString();
  }

  Map<String, String> _buildHeaders(String token) {
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Endpoint 1: Fetch Current or Claim Next Queue Item
  // Original:
  // /// GET /api/v1/autodialer/my-queue/current
  /// GET /api/v1/autodialer/campaigns/my-queue/current
  // Original:
  // Future<AutoDialerQueueItem?> fetchCurrentQueueItem() async {
  //   final token = await _getAccessToken();
  //   final uri = Uri.parse('${AuthService.baseUrl}/api/v1/autodialer/my-queue/current');
  //   debugPrint('📡 [AUTODIALER API] GET $uri');
  //   final response = await http.get(uri, headers: _buildHeaders(token));
  //   debugPrint('📥 [AUTODIALER API] Response [${response.statusCode}]: ${response.body}');
  //   if (response.statusCode == 200) {
  //     final Map<String, dynamic> decoded = jsonDecode(response.body);
  //     final currentCallData = decoded['data']?['currentCall'];
  //     if (currentCallData != null && currentCallData is Map<String, dynamic>) {
  //       return AutoDialerQueueItem.fromJson(currentCallData);
  //     }
  //     return null;
  //   } else {
  //     final Map<String, dynamic> decoded = jsonDecode(response.body);
  //     throw decoded['message'] ?? 'Failed to fetch current autodialer queue item';
  //   }
  // }
  // Original:
  // Future<AutoDialerQueueItem?> fetchCurrentQueueItem({String? campaignId}) async {
  //   final token = await _getAccessToken();
  //   var uri = Uri.parse('${AuthService.baseUrl}/api/v1/autodialer/campaigns/my-queue/current');
  //   if (campaignId != null && campaignId.isNotEmpty) {
  //     uri = uri.replace(queryParameters: {'campaignId': campaignId});
  //   }
  //   final headers = {
  //     ..._buildHeaders(token),
  //     'Bypass-Tunnel-Reminder': 'true',
  //   };
  //   debugPrint('📡 [AUTODIALER API] GET $uri');
  //   var response = await raw_http.get(uri, headers: headers);
  Future<AutoDialerQueueItem?> fetchCurrentQueueItem({String? campaignId}) async {
    final token = await _getAccessToken();
    final headers = {
      ..._buildHeaders(token),
      'Bypass-Tunnel-Reminder': 'true',
    };

    // 1. Primary: Standard plain endpoint without query parameters
    final plainUri = Uri.parse('${AuthService.baseUrl}/api/v1/autodialer/campaigns/my-queue/current');
    debugPrint('📡 [AUTODIALER API] GET $plainUri');
    var response = await raw_http.get(plainUri, headers: headers);
    debugPrint('📥 [AUTODIALER API] Status: [${response.statusCode}]');
    debugPrint('📥 [AUTODIALER API] Body: ${response.body}');

    // 2. If plain returns 404 or empty and campaignId was provided, attempt with campaignId parameter
    if ((response.statusCode == 404 || _isResponseBodyEmpty(response.body)) &&
        campaignId != null &&
        campaignId.isNotEmpty) {
      final queryUri = plainUri.replace(queryParameters: {'campaignId': campaignId});
      debugPrint('📡 [AUTODIALER API] Retrying with query param: GET $queryUri');
      final queryResponse = await raw_http.get(queryUri, headers: headers);
      debugPrint('📥 [AUTODIALER API] Query Response [${queryResponse.statusCode}]: ${queryResponse.body}');
      if (queryResponse.statusCode == 200 && !_isResponseBodyEmpty(queryResponse.body)) {
        response = queryResponse;
      }
    }

    // 3. Fallback: legacy endpoint without /campaigns if still 404
    if (response.statusCode == 404) {
      final fallbackUri = Uri.parse('${AuthService.baseUrl}/api/v1/autodialer/my-queue/current');
      debugPrint('📡 [AUTODIALER API] Trying legacy fallback: GET $fallbackUri');
      final fallbackResponse = await raw_http.get(fallbackUri, headers: headers);
      debugPrint('📥 [AUTODIALER API] Fallback Response [${fallbackResponse.statusCode}]: ${fallbackResponse.body}');
      if (fallbackResponse.statusCode == 200) {
        response = fallbackResponse;
      }
    }

    if (response.statusCode == 200) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        final itemJson = _extractQueueItemJson(decoded);
        if (itemJson != null) {
          return AutoDialerQueueItem.fromJson(itemJson);
        }
        return null;
      } catch (e) {
        debugPrint('⚠️ [AUTODIALER API] Error decoding JSON: $e');
        return null;
      }
    } else if (response.statusCode == 404) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        final msg = (decoded['message'] ?? '').toString();
        debugPrint('ℹ️ [AUTODIALER API] Backend 404 ($msg) - Treating as empty queue.');
        return null;
      } catch (_) {
        debugPrint('⚠️ [AUTODIALER API] Route returned 404 Not Found HTML. Endpoint might not be deployed yet.');
        return null;
      }
    } else {
      try {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        throw decoded['message'] ?? 'Failed to fetch queue item (${response.statusCode})';
      } catch (_) {
        throw 'Server returned status ${response.statusCode}';
      }
    }
  }

  bool _isResponseBodyEmpty(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data == null) return true;
        if (data is Map &&
            data['currentCall'] == null &&
            data['nextCall'] == null &&
            data['queueId'] == null &&
            data['_id'] == null) {
          return true;
        }
        if (data is List && data.isEmpty) return true;
      }
      return false;
    } catch (_) {
      return true;
    }
  }

  Map<String, dynamic>? _extractQueueItemJson(Map<String, dynamic> decoded) {
    if (decoded['data'] is Map<String, dynamic>) {
      final data = decoded['data'] as Map<String, dynamic>;
      if (data['currentCall'] is Map<String, dynamic>) {
        return data['currentCall'] as Map<String, dynamic>;
      }
      if (data['nextCall'] is Map<String, dynamic>) {
        return data['nextCall'] as Map<String, dynamic>;
      }
      if (data['queueId'] != null || data['_id'] != null || data['contactInfo'] != null) {
        return data;
      }
    } else if (decoded['data'] is List && (decoded['data'] as List).isNotEmpty) {
      final first = (decoded['data'] as List).first;
      if (first is Map<String, dynamic>) {
        return first;
      }
    }
    if (decoded['currentCall'] is Map<String, dynamic>) {
      return decoded['currentCall'] as Map<String, dynamic>;
    }
    if (decoded['nextCall'] is Map<String, dynamic>) {
      return decoded['nextCall'] as Map<String, dynamic>;
    }
    return null;
  }

  /// Endpoint 2: Complete Call, Save Log & Recording, and Fetch Next Contact
  // Original:
  // /// POST /api/v1/autodialer/my-queue/:queueId/complete
  /// POST /api/v1/autodialer/campaigns/my-queue/:queueId/complete
  // Original:
  // Future<AutoDialerCompleteResponse> completeQueueItem(
  //   String queueId,
  //   AutoDialerCompletePayload payload,
  // ) async {
  //   final token = await _getAccessToken();
  //   final uri = Uri.parse('${AuthService.baseUrl}/api/v1/autodialer/my-queue/$queueId/complete');
  //   debugPrint('AutoDialerService: POST $uri');
  //   debugPrint('AutoDialerService: Payload: ${jsonEncode(payload.toJson())}');
  //   final response = await http.post(
  //     uri,
  //     headers: _buildHeaders(token),
  //     body: jsonEncode(payload.toJson()),
  //   );
  //   debugPrint('AutoDialerService: Response [${response.statusCode}]: ${response.body}');
  //   if (response.statusCode == 200 || response.statusCode == 201) {
  //     final Map<String, dynamic> decoded = jsonDecode(response.body);
  //     return AutoDialerCompleteResponse.fromJson(decoded);
  //   } else {
  //     final Map<String, dynamic> decoded = jsonDecode(response.body);
  //     throw decoded['message'] ?? 'Failed to complete autodialer queue item';
  //   }
  // }
  Future<AutoDialerCompleteResponse> completeQueueItem(
    String queueId,
    AutoDialerCompletePayload payload,
  ) async {
    final token = await _getAccessToken();
    // Original:
    // final uri = Uri.parse('${AuthService.baseUrl}/api/v1/autodialer/my-queue/$queueId/complete');
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/autodialer/campaigns/my-queue/$queueId/complete');

    debugPrint('📡 [AUTODIALER API] POST $uri');
    debugPrint('📤 [AUTODIALER API] Payload: ${jsonEncode(payload.toJson())}');

    final response = await raw_http.post(
      uri,
      headers: {
        ..._buildHeaders(token),
        'Bypass-Tunnel-Reminder': 'true',
      },
      body: jsonEncode(payload.toJson()),
    );

    debugPrint('📥 [AUTODIALER API] Complete Response [${response.statusCode}]: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final Map<String, dynamic> decoded = jsonDecode(response.body);
      return AutoDialerCompleteResponse.fromJson(decoded);
    } else {
      try {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        throw decoded['message'] ?? 'Failed to complete autodialer queue item (${response.statusCode})';
      } catch (_) {
        throw 'Failed to complete queue item (${response.statusCode})';
      }
    }
  }

  /// Helper to fetch Device metadata
  Future<Map<String, dynamic>> getDeviceMeta() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    String deviceId = 'Unknown Device';
    String androidVersion = 'Unknown Version';

    try {
      if (!kIsWeb && Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        deviceId = '${androidInfo.brand} ${androidInfo.model}';
        androidVersion = androidInfo.version.release;
      } else if (!kIsWeb && Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        deviceId = '${iosInfo.name} ${iosInfo.model}';
        androidVersion = iosInfo.systemVersion;
      }
    } catch (e) {
      debugPrint('AutoDialerService: Error reading device info: $e');
    }

    return {
      'deviceId': deviceId,
      'androidVersion': androidVersion,
    };
  }

  /// Handles FCM Push Notification when type == "AUTODIALER_CAMPAIGN_STARTED"
  // Original:
  // /// Automatically calls GET /api/v1/autodialer/my-queue/current and pops up calling dialog
  /// Automatically calls GET /api/v1/autodialer/campaigns/my-queue/current and pops up calling dialog
  // Original:
  // Future<void> handleCampaignStarted({BuildContext? context}) async {
  //   final now = DateTime.now();
  //   if (_lastTriggerTime != null &&
  //       now.difference(_lastTriggerTime!) < const Duration(seconds: 2)) {
  //     debugPrint('AutoDialerService: Debouncing duplicate campaign trigger');
  //     return;
  //   }
  //   _lastTriggerTime = now;
  //   try {
  //     final box = await Hive.openBox('authBox');
  //     final token = box.get('accessToken');
  //     if (token == null || token.toString().isEmpty) {
  //       debugPrint('AutoDialerService: User not logged in. Skipping auto-popup.');
  //       return;
  //     }
  //     debugPrint('AutoDialerService: Triggering auto-fetch for current queue item...');
  //     final queueItem = await fetchCurrentQueueItem();
  //     final targetContext = context ?? navigatorKey.currentContext;
  //     if (targetContext == null) {
  //       debugPrint('AutoDialerService: Navigator context is null. Retrying in 500ms...');
  //       await Future.delayed(const Duration(milliseconds: 500));
  //       final retryContext = navigatorKey.currentContext;
  //       if (retryContext != null) {
  //         _showAutoDialerDialog(retryContext, queueItem);
  //       }
  //       return;
  //     }
  //     _showAutoDialerDialog(targetContext, queueItem);
  //   } catch (e) {
  //     debugPrint('AutoDialerService: Error handling campaign started: $e');
  //   }
  // }
  // Original:
  // Future<void> handleCampaignStarted({BuildContext? context}) async {
  //   debugPrint('🚀 [AUTODIALER] handleCampaignStarted() invoked');
  // Original:
  // Future<void> handleCampaignStarted({BuildContext? context, String? campaignId}) async {
  //   debugPrint('🚀 [AUTODIALER] handleCampaignStarted() invoked (campaignId: $campaignId)');
  //   final now = DateTime.now();
  //   if (_lastTriggerTime != null &&
  //       now.difference(_lastTriggerTime!) < const Duration(seconds: 2)) {
  //     debugPrint('⚠️ [AUTODIALER] Debouncing duplicate campaign trigger (< 2s)');
  //     return;
  //   }
  //   _lastTriggerTime = now;
  //   try {
  //     final box = await Hive.openBox('authBox');
  //     final token = box.get('accessToken');
  //     if (token == null || token.toString().isEmpty) {
  //       debugPrint('❌ [AUTODIALER] User not logged in. Cannot auto-popup dialog.');
  //       return;
  //     }
  //     debugPrint('📡 [AUTODIALER] Fetching current contact to call from queue...');
  //     final queueItem = await fetchCurrentQueueItem(campaignId: campaignId);
  //     if (queueItem != null) {
  //       debugPrint('✅ [AUTODIALER] Claimed Contact: queueId=${queueItem.queueId}, name=${queueItem.contactInfo.name}, phone=${queueItem.contactInfo.phoneNo}');
  //     } else {
  //       debugPrint('ℹ️ [AUTODIALER] Current queue is empty or no contacts assigned.');
  //     }
  //     final targetContext = context ?? navigatorKey.currentContext;
  //     if (targetContext == null) {
  //       debugPrint('⚠️ [AUTODIALER] Navigator context is null. Retrying in 500ms...');
  //       await Future.delayed(const Duration(milliseconds: 500));
  //       final retryContext = navigatorKey.currentContext;
  //       if (retryContext != null) {
  //         _showAutoDialerDialog(retryContext, queueItem);
  //       } else {
  //         debugPrint('❌ [AUTODIALER] Navigator context still null after delay. Cannot display dialog.');
  //       }
  //       return;
  //     }
  //     _showAutoDialerDialog(targetContext, queueItem);
  //   } catch (e) {
  //     debugPrint('❌ [AUTODIALER ERROR] Error in handleCampaignStarted: $e');
  //     final targetContext = context ?? navigatorKey.currentContext;
  //     if (targetContext != null) {
  //       _showAutoDialerDialog(targetContext, null);
  //     }
  //   }
  // }
  // void _showAutoDialerDialog(BuildContext context, AutoDialerQueueItem? queueItem) {
  //   if (_isDialogOpen) {
  //     debugPrint('⚠️ [AUTODIALER] AutoDialer dialog is already open.');
  //     return;
  //   }
  //   debugPrint('✨ [AUTODIALER] Displaying AutoDialer BottomSheet dialog!');
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     AutoDialerDialog.show(context, initialItem: queueItem);
  //   });
  // }
  Future<void> handleCampaignStarted({BuildContext? context, String? campaignId}) async {
    debugPrint('🚀 [AUTODIALER] handleCampaignStarted() invoked (campaignId: $campaignId)');
    final now = DateTime.now();
    if (_lastTriggerTime != null &&
        now.difference(_lastTriggerTime!) < const Duration(milliseconds: 1500)) {
      debugPrint('⚠️ [AUTODIALER] Debouncing rapid campaign trigger (< 1.5s)');
      return;
    }
    _lastTriggerTime = now;

    try {
      final box = await Hive.openBox('authBox');
      final token = box.get('accessToken');
      if (token == null || token.toString().isEmpty) {
        debugPrint('❌ [AUTODIALER] User not logged in. Cannot auto-popup dialog.');
        return;
      }

      debugPrint('📡 [AUTODIALER] Fetching current contact to call from queue...');
      // 1. Fetch current queue item
      AutoDialerQueueItem? queueItem = await fetchCurrentQueueItem(campaignId: campaignId);

      // 2. If null on attempt 1 (campaign queue might still be populating on backend),
      // retry up to 2 times with a short backoff:
      if (queueItem == null) {
        debugPrint('ℹ️ [AUTODIALER] Queue item is null on attempt 1. Retrying in 600ms...');
        await Future.delayed(const Duration(milliseconds: 600));
        queueItem = await fetchCurrentQueueItem(campaignId: campaignId);
      }
      if (queueItem == null) {
        debugPrint('ℹ️ [AUTODIALER] Queue item is still null on attempt 2. Retrying in 1200ms...');
        await Future.delayed(const Duration(milliseconds: 1200));
        queueItem = await fetchCurrentQueueItem(campaignId: campaignId);
      }

      // 3. Immediately update global Riverpod provider if container is available
      if (_container != null) {
        if (queueItem != null) {
          _container!.read(autodialerProvider.notifier).setInitialItem(queueItem);
        } else {
          _container!.read(autodialerProvider.notifier).fetchCurrentCall();
        }
      }

      if (queueItem != null) {
        debugPrint('✅ [AUTODIALER] Claimed Contact: queueId=${queueItem.queueId}, name=${queueItem.contactInfo.name}, phone=${queueItem.contactInfo.phoneNo}');
      } else {
        debugPrint('ℹ️ [AUTODIALER] Current queue is empty or no contacts assigned.');
      }

      // 4. Resolve target navigator context safely
      BuildContext? targetContext = context ?? navigatorKey.currentContext ?? navigatorKey.currentState?.context;
      if (targetContext == null) {
        debugPrint('⚠️ [AUTODIALER] Navigator context is null. Retrying in 500ms...');
        await Future.delayed(const Duration(milliseconds: 500));
        targetContext = navigatorKey.currentContext ?? navigatorKey.currentState?.context;
      }

      if (targetContext == null) {
        debugPrint('❌ [AUTODIALER] Navigator context still null after delay. Cannot display dialog.');
        return;
      }

      _showAutoDialerDialog(targetContext, queueItem);
    } catch (e) {
      debugPrint('❌ [AUTODIALER ERROR] Error in handleCampaignStarted: $e');
      BuildContext? targetContext = context ?? navigatorKey.currentContext ?? navigatorKey.currentState?.context;
      if (targetContext != null) {
        _showAutoDialerDialog(targetContext, null);
      }
    }
  }

  void _showAutoDialerDialog(BuildContext context, AutoDialerQueueItem? queueItem) {
    if (_isDialogOpen) {
      debugPrint('⚠️ [AUTODIALER] AutoDialer dialog is already open. Updating active call in provider...');
      if (_container != null && queueItem != null) {
        _container!.read(autodialerProvider.notifier).setInitialItem(queueItem);
      }
      return;
    }

    debugPrint('✨ [AUTODIALER] Displaying AutoDialer BottomSheet dialog!');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final activeContext = navigatorKey.currentContext ?? navigatorKey.currentState?.context ?? context;
      AutoDialerDialog.show(activeContext, initialItem: queueItem);
    });
  }
}
