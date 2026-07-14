import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../presentation/providers/navigation_provider.dart';
import '../../main.dart';
import 'whatsapp_state_tracker.dart';
import 'local_notification_service.dart';

class WhatsAppNotificationHandler {
  static final WhatsAppNotificationHandler _instance = WhatsAppNotificationHandler._internal();
  factory WhatsAppNotificationHandler() => _instance;
  WhatsAppNotificationHandler._internal();

  ProviderContainer? container;

  void initialize(ProviderContainer container) {
    container = container;
    _setupNotificationTapListener();
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

  void _setupNotificationTapListener() {
    localNotificationStream.listen((response) {
      final payload = response.payload;
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('👆 [NOTIFICATION] TAPPED');
      debugPrint('  payload: $payload');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      if (payload != null && payload.isNotEmpty) {
        _navigateToWhatsAppChat(payload);
      } else {
        _navigateToWhatsAppScreen();
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📱 [FCM] TAPPED (background)');
      debugPrint('  data: ${message.data}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final convId = message.data['conversationId'] ?? '';
      final type = message.data['type'] ?? '';

      if (type == 'whatsapp_message' || type == 'WHATSAPP_MESSAGE' || type == 'whatsapp_incoming') {
        if (convId.isNotEmpty) {
          _navigateToWhatsAppChat(convId);
        } else {
          _navigateToWhatsAppScreen();
        }
      }
    });
  }

  Future<void> handleTerminatedMessage() async {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📱 [FCM] INITIAL MESSAGE (terminated)');
      debugPrint('  data: ${initialMessage.data}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final convId = initialMessage.data['conversationId'] ?? '';
      final type = initialMessage.data['type'] ?? '';

      if (type == 'whatsapp_message' || type == 'WHATSAPP_MESSAGE' || type == 'whatsapp_incoming') {
        if (convId.isNotEmpty) {
          _navigateToWhatsAppChat(convId);
        } else {
          _navigateToWhatsAppScreen();
        }
      }
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
      if (context == null) return;
      final container = ProviderScope.containerOf(context, listen: false);
      container.read(currentRouteProvider.notifier).state = 'Chats';
    } catch (e) {
      debugPrint('  ❌ Route error: $e');
    }
  }
}

final StreamController<NotificationResponse> _notificationTapController =
    StreamController<NotificationResponse>.broadcast();

Stream<NotificationResponse> get localNotificationStream => _notificationTapController.stream;

void handleNotificationTap(NotificationResponse response) {
  _notificationTapController.add(response);
}
