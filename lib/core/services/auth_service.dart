import 'dart:convert';
import 'package:http/http.dart' as raw_http;
import 'http_client.dart' as http;
import '../../data/models/user_model.dart';
import '../../data/models/permission_model.dart';
import 'package:flutter/foundation.dart';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';

class AuthService {
  static const String baseUrl = 'https://crm-app-backend-btpi.onrender.com';

  String _mapLoginError(int statusCode, String? message) {
    final msg = message?.toLowerCase() ?? '';
    if (msg.contains('incorrect password') || msg.contains('wrong password') || msg.contains('invalid password')) return 'Incorrect password. Please try again.';
    if (msg.contains('user not found') || msg.contains('account not found') || msg.contains('invalid email') || msg.contains('email not found')) return 'Account not found.';
    if (msg.contains('invalid credentials') || msg.contains('unauthorized') || msg.contains('invalid login')) return 'Invalid email or password.';
    if (msg.contains('session expired') || msg.contains('token expired')) return 'Session expired. Please log in again.';
    
    switch (statusCode) {
      case 400: return 'Invalid request. Please check your input.';
      case 401: return 'Invalid email or password.';
      case 403: return 'Access denied. Please contact support.';
      case 404: return 'Account not found.';
      case 429: return 'Too many attempts. Please try again later.';
      case 500: return 'Server error. Please try again later.';
      default: return message?.isNotEmpty == true ? message! : 'Login failed. Please try again.';
    }
  }

  Future<LoginResponse> loginBasic(String uniqueId, String password) async {
    final url = Uri.parse('$baseUrl/api/v1/auth/login');
    try {
      final response = await raw_http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uniqueId': uniqueId, 'password': password}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return LoginResponse.fromJson(jsonDecode(response.body));
      } else {
        final data = jsonDecode(response.body);
        throw _mapLoginError(response.statusCode, data['message']);
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<LoginResponse> login(String uniqueId, String password) async {
    final url = Uri.parse('$baseUrl/api/v1/auth/login');
    final authBox = await Hive.openBox('authBox');
    String? deviceId = authBox.get('crm_device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await authBox.put('crm_device_id', deviceId);
    }
    final deviceInfo = await _getDeviceInfo();
    final payload = {
      'uniqueId': uniqueId, 'password': password, 'deviceId': deviceId,
      'deviceType': 'app', 'isApp': true, 'deviceName': deviceInfo['deviceName'],
    };

    try {
      final response = await raw_http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Bypass-Tunnel-Reminder': 'true'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return LoginResponse.fromJson(jsonDecode(response.body));
      } else {
        String? errorMessage;
        try { errorMessage = jsonDecode(response.body)['message']; } catch (_) {}
        throw _mapLoginError(response.statusCode, errorMessage);
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('socket') || errorStr.contains('timeout') || errorStr.contains('connection') || errorStr.contains('network')) {
        throw 'Unable to connect. Please check your internet connection.';
      }
      throw e.toString();
    }
  }


  Future<Map<String, dynamic>> _getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    String deviceType = 'desktop'; 
    String? deviceName;
    String? platform;

    try {
      if (kIsWeb) {
        final webInfo = await deviceInfoPlugin.webBrowserInfo;
        deviceName = webInfo.userAgent;
        if (webInfo.userAgent!.contains('Mobile')) deviceType = 'mobile';
      } else {
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfoPlugin.androidInfo;
          deviceType = 'mobile';
          deviceName = '${androidInfo.brand} ${androidInfo.model}';
          platform = 'Android ${androidInfo.version.release}';
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfoPlugin.iosInfo;
          deviceType = 'mobile'; 
          deviceName = '${iosInfo.name} ${iosInfo.systemName}';
          platform = 'iOS ${iosInfo.systemVersion}';
        } else if (Platform.isWindows) {
           final windowsInfo = await deviceInfoPlugin.windowsInfo;
           deviceType = 'desktop';
           deviceName = windowsInfo.productName;
           platform = 'Windows';
        }
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }
    
    return {
        'deviceType': deviceType,
        'deviceName': deviceName,
        'platform': platform
    };
  }

  Future<void> saveSubscriptionBasic(String fcmToken) async {
      // Placeholder for basic subscription without device info
      debugPrint('Basic Subscription (Stub): $fcmToken');
  }

  Future<void> saveSubscription(String fcmToken) async {
      try {
          final authBox = await Hive.openBox('authBox');
          
          // 1. Get/Generate Device ID
          String? deviceId = authBox.get('crm_device_id');
          if (deviceId == null) {
              deviceId = const Uuid().v4();
              await authBox.put('crm_device_id', deviceId);
          }
          
          final sessionId = authBox.get('sessionId');
          
          // 2. Get Device Info
          final deviceInfo = await _getDeviceInfo();
          final extendedDeviceInfo = Map<String, dynamic>.from(deviceInfo);
          extendedDeviceInfo['isApp'] = true;

          final payload = {
              'subscription': {
                  'fcm_token': fcmToken,
              },
              'deviceId': deviceId,
              'deviceInfo': extendedDeviceInfo,
              'sessionId': sessionId,
              'deviceType': 'app', // As per previous login explanation
          };

          final url = Uri.parse('$baseUrl/api/v1/push/save-subscription'); 


          final token = authBox.get('accessToken');

          debugPrint('Sending FCM Subscription: $payload');

          final response = await http.post(
              url,
              headers: {
                  'Content-Type': 'application/json',
                  'Bypass-Tunnel-Reminder': 'true',
                  'Authorization': 'Bearer $token',
              },
              body: jsonEncode(payload)
          );
          
          debugPrint('Subscription Response: ${response.body}');
      } catch (e) {
          // Fail silently/gracefully as requested ("current working app should not get disturbed")
          debugPrint('Error saving subscription: $e'); 
      }
  }

  Future<void> removeSubscription() async {
      try {
          final authBox = await Hive.openBox('authBox');
          final deviceId = authBox.get('crm_device_id');
          
          if (deviceId == null) return; // Nothing to remove if no device ID

          final payload = {
              'deviceId': deviceId,
          };

          final url = Uri.parse('$baseUrl/api/v1/notification/unsubscribe'); 

          debugPrint('Removing FCM Subscription: $payload');

          final response = await http.post(
              url,
              headers: {
                  'Content-Type': 'application/json',
                  'Bypass-Tunnel-Reminder': 'true',
              },
              body: jsonEncode(payload)
          );
          
          debugPrint('Unsubscribe Response: ${response.body}');
      } catch (e) {
          debugPrint('Error removing subscription: $e'); 
      }
  }

  Future<bool> checkSession(String sessionId) async {
    final url = Uri.parse('$baseUrl/api/v1/auth/session/$sessionId');
    try {
      final authBox = await Hive.openBox('authBox');
      final token = authBox.get('accessToken');

      final response = await raw_http.get(
        url,
        headers: {
            'Content-Type': 'application/json',
            'Bypass-Tunnel-Reminder': 'true',
            if (token != null) 'Authorization': 'Bearer $token',
        }
      ).timeout(const Duration(seconds: 10));
      
      debugPrint('Check Session Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['ok'] == true;
      } else if (response.statusCode == 401 || response.statusCode == 403 || response.statusCode == 404) {
        return false;
      } else {
        throw HttpException('Server returned error status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Check Session Error: $e');
      rethrow;
    }
  }

  Future<void> logoutUser(String sessionId) async {
    final url = Uri.parse('$baseUrl/api/v1/auth/logout');
    try {
       final authBox = await Hive.openBox('authBox');
       final deviceId = authBox.get('crm_device_id');

       final payload = {
         'sessionId': sessionId,
         'deviceId': deviceId
       };

       await http.post(
         url,
         headers: {'Content-Type': 'application/json'},
         body: jsonEncode(payload)
       );
    } catch (e) {
      debugPrint('Logout API Error: $e');
    }
  }

  Future<PermissionResponse> getPermissions() async {
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');
    final userId = authBox.get('user_id');

    debugPrint('Permissions API Fetch - UserID: $userId, Token: ${accessToken != null}');
    if (accessToken == null || userId == null) {
      throw 'User not authenticated';
    }

    final url = Uri.parse('$baseUrl/api/v1/users/$userId/getPermissions');
    debugPrint('Calling Permissions API: $url');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'Bypass-Tunnel-Reminder': 'true',
        },
      );

      debugPrint('Permissions API Status Code: ${response.statusCode}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('Permissions API Success Response: ${response.body}');
        return PermissionResponse.fromJson(data);
      } else {
        debugPrint('Permissions API Error Response: ${response.body}');
        final data = jsonDecode(response.body);
        throw data['message'] ?? 'Failed to fetch permissions';
      }
    } catch (e) {
      debugPrint('Permissions API Exception: $e');
      throw e.toString();
    }
  }
}
