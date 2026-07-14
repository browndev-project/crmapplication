import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'call_service.dart';
import 'whatsapp_state_tracker.dart';
import 'whatsapp_notification_handler.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  debugPrint("📱 [BG] FCM MESSAGE RECEIVED");
  debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  debugPrint("  messageId: ${message.messageId}");
  debugPrint("  data:      ${message.data}");
  debugPrint("  notification: ${message.notification != null ? 'PRESENT' : 'NULL'}");
  debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

  if (message.data['type'] == 'AUTO_DIAL' || message.data['type'] == 'CALL_INITIATE' || message.data['type'] == 'MANUAL_DIAL') {
      final phoneNo = message.data['phoneNo'] ?? message.data['number'] ?? message.data['phoneNumber'];
      debugPrint('Background Auto-Dial for: $phoneNo');
      if (phoneNo != null && phoneNo.toString().isNotEmpty) {
           try {
             CallService().startCallListener();
             final context = Map<String, dynamic>.from(message.data);
             context['direction'] = 'WEB_INITIATED';
             await CallService().makeCall(phoneNo, callContext: context, isBackground: true);
           } catch (e) {
             debugPrint('Background Call Error: $e');
           }
      }
  }

  final type = message.data['type'] ?? '';
  if (type == 'whatsapp_message' || type == 'WHATSAPP_MESSAGE' || type == 'whatsapp_incoming') {
    WhatsAppNotificationHandler().handleIncomingMessage(message);
  }
}

class FCMService {
  static final WhatsAppNotificationHandler _handler = WhatsAppNotificationHandler();

  static Future<void> initializeFirebase() async {
      try {
          await Firebase.initializeApp();
          FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      } catch(e) {
          debugPrint('Error initializing Firebase: $e');
      }
  }

  static Future<void> enableNotifications() async {
    try {
      final firebaseMessaging = FirebaseMessaging.instance;

      NotificationSettings settings = await firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('User granted permission: ${settings.authorizationStatus}');

      final token = await firebaseMessaging.getToken();
      debugPrint('FCM Token: $token');
      
      if (token != null) {
          await AuthService().saveSubscription(token);
      }

      // Foreground Message Listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('📱 [FG] FCM MESSAGE RECEIVED');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('  messageId:   ${message.messageId}');
        debugPrint('  type:        ${message.data['type']}');
        debugPrint('  data:        ${message.data}');
        debugPrint('  notification: ${message.notification != null ? 'PRESENT' : 'NULL'}');
        debugPrint('  title:       ${message.notification?.title}');
        debugPrint('  body:        ${message.notification?.body}');
        debugPrint('  trackerOpen: ${WhatsAppStateTracker.isScreenOpen}');
        debugPrint('  trackerConv: ${WhatsAppStateTracker.activeConversationId}');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        if (message.data['type'] == 'AUTO_DIAL' || message.data['type'] == 'CALL_INITIATE' || message.data['type'] == 'MANUAL_DIAL') {
            debugPrint('Checking keys: phoneNo=${message.data['phoneNo']}, number=${message.data['number']}, phoneNumber=${message.data['phoneNumber']}');
            final phoneNo = message.data['phoneNo'] ?? message.data['number'] ?? message.data['phoneNumber'];
            debugPrint('Auto-Dial Triggered for: $phoneNo');
            if (phoneNo != null && phoneNo.toString().isNotEmpty) {
                 debugPrint('FCM: Triggering foreground/remote call logic (In-App)');
                 final context = Map<String, dynamic>.from(message.data);
                 context['direction'] = 'WEB_INITIATED';
                 CallService().makeCall(phoneNo, callContext: context, isBackground: false);
            }
        }

        final type = message.data['type'] ?? '';
        if (type == 'whatsapp_message' || type == 'WHATSAPP_MESSAGE' || type == 'whatsapp_incoming') {
          _handler.handleIncomingMessage(message);
        }
      });

    } catch (e) {
      debugPrint('Error enabling notifications: $e');
    }
  }
}
