import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../presentation/providers/navigation_provider.dart';
import '../../presentation/screens/lead_profile_screen.dart';
import '../../main.dart';
import 'whatsapp_state_tracker.dart';
import 'local_notification_service.dart';

class WhatsAppNotificationHandler {
  static final WhatsAppNotificationHandler _instance = WhatsAppNotificationHandler._internal();
  factory WhatsAppNotificationHandler() => _instance;
  WhatsAppNotificationHandler._internal();

  ProviderContainer? container;
  static const MethodChannel _channel = MethodChannel('com.browndev.crm/notifications');

  void initialize(ProviderContainer container) {
    this.container = container;
    _setupNotificationTapListener();
    _setupNativeChannelListener();
  }

  void handleIncomingMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] ?? '';

    if (type != 'whatsapp_message' && type != 'WHATSAPP_MESSAGE' && type != 'whatsapp_incoming') {
      return;
    }

    final convId = data['conversationId'] ?? '';
    final title = data['title'] ?? data['senderName'] ?? 'New WhatsApp Message';
    String body = data['body'] ?? '';
    final imageUrl = data['imageUrl'] ?? data['mediaUrl'];
    final waId = data['waId'] ?? '';

    if (body.contains('business.facebook.com') || body.isEmpty) {
      body = '📷 Photo';
    }

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📨 [HANDLER] PROCESSING WHATSAPP NOTIFICATION');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('  convId:     $convId');
    debugPrint('  title:      $title');
    debugPrint('  body:       $body');
    debugPrint('  waId:       $waId');
    debugPrint('  screenOpen: ${WhatsAppStateTracker.isScreenOpen}');
    debugPrint('  activeConv: ${WhatsAppStateTracker.activeConversationId}');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    final bool isInSameChat = WhatsAppStateTracker.isScreenOpen &&
        WhatsAppStateTracker.activeConversationId == convId &&
        convId.isNotEmpty;

    if (isInSameChat) {
      debugPrint('  ⏭ SKIP — user is in same chat');
      return;
    }

    LocalNotificationService.showNotification(
      id: convId.hashCode & 0x7FFFFFFF,
      title: title,
      body: body,
      imageUrl: imageUrl,
      soundName: 'message_notify',
    );

    debugPrint('  ✅ NOTIFICATION SHOWN — convId: $convId');
  }

  void handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] ?? '';

    if (type == 'whatsapp_message' || type == 'WHATSAPP_MESSAGE' || type == 'whatsapp_incoming') {
      handleIncomingMessage(message);
      return;
    }

    // For general notifications (like task_reminder, lead_assigned, etc.)
    final title = message.notification?.title ?? data['title'] ?? '';
    final body = message.notification?.body ?? data['body'] ?? '';
    
    if (body.isEmpty && title.isEmpty) return;

    final leadId = _findLeadId(data);
    debugPrint('🔔 [HANDLER] Showing general foreground notification. title="$title", body="$body", leadId="$leadId"');

    LocalNotificationService.showNotification(
      id: message.messageId.hashCode & 0x7FFFFFFF,
      title: title,
      body: body,
      payload: jsonEncode(data),
      soundName: '', // Empty soundName will use the default notification sound
      channelId: 'general_notifications',
      channelName: 'General Notifications',
      channelDescription: 'Notifications for CRM updates, task alerts, and reminders',
    );
  }

  void _setupNotificationTapListener() {
    localNotificationStream.listen((response) {
      final payload = response.payload;
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('👆 [NOTIFICATION] TAPPED');
      debugPrint('  payload: $payload');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      if (payload != null && payload.isNotEmpty) {
        if (payload.trim().startsWith('{')) {
          try {
            final Map<String, dynamic> data = Map<String, dynamic>.from(jsonDecode(payload));
            final convId = data['conversationId'] ?? '';
            final type = data['type'] ?? '';

            if (type == 'whatsapp_message' || type == 'WHATSAPP_MESSAGE' || type == 'whatsapp_incoming') {
              if (convId.isNotEmpty) {
                _navigateToWhatsAppChat(convId);
              } else {
                _navigateToWhatsAppScreen();
              }
            } else {
              final leadId = _findLeadId(data);
              if (leadId != null) {
                final initialTab = _determineTab(data);
                _navigateToLeadProfile(leadId, initialTab);
              } else {
                debugPrint('  ❌ Skipping lead profile navigation from local notification: leadId is null');
              }
            }
            return;
          } catch (e) {
            debugPrint('  ⚠️ Error parsing local notification JSON payload: $e. Falling back to WhatsApp routing...');
          }
        }
        _navigateToWhatsAppChat(payload);
      } else {
        _navigateToWhatsAppScreen();
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📱 [FCM DEBUG] TAPPED (background state)');
      debugPrint('  • Platform: ${Platform.operatingSystem}');
      debugPrint('  • Message ID: ${message.messageId}');
      debugPrint('  • Data payload: ${message.data}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final convId = message.data['conversationId'] ?? '';
      final type = message.data['type'] ?? '';

      if (type == 'whatsapp_message' || type == 'WHATSAPP_MESSAGE' || type == 'whatsapp_incoming') {
        debugPrint('  → Identified as WhatsApp message type. Navigating to WhatsApp...');
        if (convId.isNotEmpty) {
          _navigateToWhatsAppChat(convId);
        } else {
          _navigateToWhatsAppScreen();
        }
      } else {
        debugPrint('  → Searching for lead ID in payload...');
        final leadId = _findLeadId(message.data);
        debugPrint('  • Found leadId: $leadId');
        
        if (leadId != null) {
          final initialTab = _determineTab(message.data);
          debugPrint('  → Lead Notification matched. Navigating to Lead $leadId (Tab: $initialTab)');
          _navigateToLeadProfile(leadId, initialTab);
        } else {
          debugPrint('  ❌ Skipping lead profile navigation: leadId is null');
        }
      }
    });
  }

  Future<void> handleTerminatedMessage() async {
    debugPrint('📱 [FCM DEBUG] Checking initial message (terminated state)...');
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📱 [FCM DEBUG] INITIAL MESSAGE FOUND (terminated state)');
      debugPrint('  • Message ID: ${initialMessage.messageId}');
      debugPrint('  • Data payload: ${initialMessage.data}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final convId = initialMessage.data['conversationId'] ?? '';
      final type = initialMessage.data['type'] ?? '';

      if (type == 'whatsapp_message' || type == 'WHATSAPP_MESSAGE' || type == 'whatsapp_incoming') {
        debugPrint('  → Identified as WhatsApp message type. Navigating to WhatsApp...');
        if (convId.isNotEmpty) {
          _navigateToWhatsAppChat(convId);
        } else {
          _navigateToWhatsAppScreen();
        }
      } else {
        debugPrint('  → Searching for lead ID in payload...');
        final leadId = _findLeadId(initialMessage.data);
        debugPrint('  • Found leadId: $leadId');
        
        if (leadId != null) {
          final initialTab = _determineTab(initialMessage.data);
          debugPrint('  → Lead Notification matched. Navigating to Lead $leadId (Tab: $initialTab)');
          _navigateToLeadProfile(leadId, initialTab);
        } else {
          debugPrint('  ❌ Skipping lead profile navigation: leadId is null');
        }
      }
    } else {
      debugPrint('📱 [FCM DEBUG] No initial message found on launch.');
    }
  }

  void _navigateToWhatsAppScreen() {
    debugPrint('  🧭 → WhatsApp Chats Screen');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setWhatsAppRoute();
    });
  }

  void _navigateToWhatsAppChat(String conversationId) {
    debugPrint('  🧭 → WhatsApp Chat: $conversationId');
    WhatsAppStateTracker.pendingConversationId = conversationId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setWhatsAppRoute();
    });
  }

  void _setWhatsAppRoute() {
    try {
      final context = navigatorKey.currentContext;
      if (context == null) {
        debugPrint('  ❌ _setWhatsAppRoute context is null');
        return;
      }
      final container = ProviderScope.containerOf(context, listen: false);
      container.read(currentRouteProvider.notifier).state = 'Chats';
    } catch (e) {
      debugPrint('  ❌ Route error: $e');
    }
  }

  void _navigateToLeadProfile(String leadId, String initialTab) {
    debugPrint('  🧭 [NAV DEBUG] Pushing Lead Profile: $leadId (Tab: $initialTab)');
    int attempts = 0;
    Timer.periodic(const Duration(milliseconds: 300), (timer) {
      attempts++;
      final navState = navigatorKey.currentState;
      final navContext = navigatorKey.currentContext;
      
      debugPrint('  • Attempt $attempts: navigatorKey.currentState is ${navState != null ? 'READY' : 'NULL'}, context is ${navContext != null ? 'READY' : 'NULL'}');
      
      if (navState != null) {
        timer.cancel();
        debugPrint('  🧭 [NAV DEBUG] SUCCESS: Navigator ready on attempt $attempts. Pushing LeadProfileScreen...');
        navState.push(
          MaterialPageRoute(
            builder: (context) => LeadProfileScreen(
              leadId: leadId,
              initialTab: initialTab,
            ),
          ),
        ).then((result) {
          debugPrint('  🧭 [NAV DEBUG] Pushed screen successfully. Back navigation returned: $result');
        });
      } else if (attempts >= 30) {
        timer.cancel();
        debugPrint('  ❌ [NAV DEBUG] FAILURE: Navigator not ready after 30 attempts (9 seconds). Navigation aborted.');
      }
    });
  }

  String? _findLeadId(Map<String, dynamic> data) {
    debugPrint('  🔍 [PARSER DEBUG] Finding lead ID...');
    final directKeys = ['leadId', 'lead_id', 'lead', 'leadID', 'leadid'];
    for (final key in directKeys) {
      if (data.containsKey(key)) {
        final val = data[key];
        debugPrint('    - Checked direct key "$key": val="$val"');
        if (val != null && val.toString().isNotEmpty) {
          debugPrint('    => Match found in direct key "$key": $val');
          return val.toString();
        }
      }
    }
    
    debugPrint('    - No direct keys matched. Scanning all keys case-insensitively...');
    for (final entry in data.entries) {
      debugPrint('    - Scanning entry: key="${entry.key}", value="${entry.value}"');
      if (entry.key.toLowerCase().contains('lead')) {
        final val = entry.value;
        if (val != null && val.toString().isNotEmpty) {
          debugPrint('    => Match found in key "${entry.key}": $val');
          return val.toString();
        }
      }
    }
    debugPrint('  ❌ [PARSER DEBUG] No lead ID found in payload.');
    return null;
  }

  String _determineTab(Map<String, dynamic> data) {
    debugPrint('  🔍 [PARSER DEBUG] Determining tab...');
    final allText = (data.entries.map((e) => '${e.key}:${e.value}').join(' ')).toLowerCase();
    debugPrint('  • Flattened text representation: "$allText"');
    
    if (allText.contains('task')) {
      debugPrint('    => Match "task" -> Tab: "Follow ups"');
      return 'Follow ups';
    } else if (allText.contains('visit')) {
      debugPrint('    => Match "visit" -> Tab: "Visit"');
      return 'Visit';
    } else if (allText.contains('meeting')) {
      debugPrint('    => Match "meeting" -> Tab: "Meetings"');
      return 'Meetings';
    }
    debugPrint('    => No tab keywords matched -> Tab: "Quick" (default)');
    return 'Quick';
  }

  void _setupNativeChannelListener() {
    debugPrint('📱 [NATIVE CHANNEL] Setting up com.browndev.crm/notifications handler...');
    _channel.setMethodCallHandler((call) async {
      debugPrint('📱 [NATIVE CHANNEL] Received call: ${call.method}');
      if (call.method == 'onNotificationTapped') {
        final arguments = call.arguments;
        debugPrint('📱 [NATIVE CHANNEL] Tapped payload arguments: $arguments');
        if (arguments is Map) {
          final data = Map<String, dynamic>.from(arguments);
          _handleNativePayload(data);
        }
      }
    });

    // Fetch initial notification immediately on startup
    _fetchInitialNativeNotification();
  }

  Future<void> _fetchInitialNativeNotification() async {
    try {
      debugPrint('📱 [NATIVE CHANNEL] Fetching initial notification from native...');
      final result = await _channel.invokeMethod('getInitialNotification');
      debugPrint('📱 [NATIVE CHANNEL] Initial notification result: $result');
      if (result is Map) {
        final data = Map<String, dynamic>.from(result);
        _handleNativePayload(data);
      }
    } catch (e) {
      debugPrint('📱 [NATIVE CHANNEL] Error fetching initial notification: $e');
    }
  }

  void _handleNativePayload(Map<String, dynamic> data) {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📱 [NATIVE DEBUG] PROCESSING TAP PAYLOAD');
    debugPrint('  • Data payload: $data');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    final convId = data['conversationId'] ?? '';
    final type = data['type'] ?? '';

    if (type == 'whatsapp_message' || type == 'WHATSAPP_MESSAGE' || type == 'whatsapp_incoming') {
      debugPrint('  → WhatsApp chat type payload. Navigating...');
      if (convId.toString().isNotEmpty) {
        _navigateToWhatsAppChat(convId.toString());
      } else {
        _navigateToWhatsAppScreen();
      }
    } else {
      final leadId = _findLeadId(data);
      debugPrint('  • Parsed leadId: $leadId');
      
      if (leadId != null) {
        final initialTab = _determineTab(data);
        debugPrint('  → Lead Notification matched. Navigating to Lead $leadId (Tab: $initialTab)');
        _navigateToLeadProfile(leadId, initialTab);
      } else {
        debugPrint('  ❌ Skipping native channel tap navigation: leadId=$leadId');
      }
    }
  }
}

final StreamController<NotificationResponse> _notificationTapController =
    StreamController<NotificationResponse>.broadcast();

Stream<NotificationResponse> get localNotificationStream => _notificationTapController.stream;

void handleNotificationTap(NotificationResponse response) {
  _notificationTapController.add(response);
}
