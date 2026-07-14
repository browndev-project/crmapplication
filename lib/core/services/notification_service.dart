import 'dart:convert';
import 'package:flutter/material.dart';
import 'http_client.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'auth_service.dart';
import '../../data/models/notification_model.dart';

class NotificationService {
  static const String _endpoint = '/api/v1/notifications';

  Future<NotificationResponse> fetchNotifications() async {
    try {
      final box = await Hive.openBox('authBox');
      final token = box.get('accessToken');

      if (token == null) {
        return NotificationResponse(
          success: false,
          message: "Authentication token missing",
          notifications: [],
        );
      }

      final url = Uri.parse('${AuthService.baseUrl}$_endpoint');
      debugPrint('🔗 Fetching Notifications: $url');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('📩 Notification Response [${response.statusCode}]: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return NotificationResponse.fromJson(json);
      } else {
        return NotificationResponse(
          success: false,
          message: "Server Error: ${response.statusCode}",
          notifications: [],
        );
      }
    } catch (e) {
      debugPrint('❌ NotificationService Error: $e');
      return NotificationResponse(
        success: false,
        message: "Network/Parse Error: $e",
        notifications: [],
      );
    }
  }
}
