import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'whatsapp_notification_handler.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'whatsapp_messages',
        'WhatsApp Messages',
        description: 'Notifications for incoming WhatsApp messages',
        importance: Importance.max,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'general_notifications',
        'General Notifications',
        description: 'Notifications for CRM updates, task alerts, and reminders',
        importance: Importance.max,
      ),
    );
    // Update location service channel to use Trevion icon
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'location_service',
        'Location Tracking',
        description: 'Shows when your location is being tracked in the background',
        importance: Importance.low,
      ),
    );

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification clicked: ${response.payload}');
        handleNotificationTap(response);
      },
    );
  }

  static Future<String?> _downloadAndSaveFile(String url, String fileName) async {
    try {
      final Directory directory = await getApplicationDocumentsDirectory();
      final String filePath = '${directory.path}/$fileName';
      final http.Response response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final File file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        return filePath;
      }
      return null;
    } catch (e) {
      debugPrint('Error downloading notification image: $e');
      return null;
    }
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? imageUrl,
    String soundName = 'message_recieve',
    String channelId = 'whatsapp_messages',
    String channelName = 'WhatsApp Messages',
    String channelDescription = 'Notifications for incoming WhatsApp messages',
  }) async {
    BigPictureStyleInformation? bigPictureStyleInformation;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      final String? localPath = await _downloadAndSaveFile(imageUrl, 'notification_img_$id.jpg');
      if (localPath != null) {
        bigPictureStyleInformation = BigPictureStyleInformation(
          FilePathAndroidBitmap(localPath),
          hideExpandedLargeIcon: true,
          contentTitle: title,
          summaryText: body,
        );
      }
    }

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      sound: soundName.isNotEmpty ? RawResourceAndroidNotificationSound(soundName) : null,
      styleInformation: bigPictureStyleInformation,
    );

    DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      sound: soundName.isNotEmpty ? '$soundName.mp3' : null,
      presentSound: true,
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }
}
