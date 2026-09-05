import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as raw_http;
import 'http_client.dart' as http;
import 'auth_service.dart';

class PromoCampaignService {
  static const String promoBoxName = 'promoAuthBox';
  static const String promoAuthKey = 'trevion_promo_auth';

  static Map<String, dynamic>? _cachedAppControls;
  static bool _hasFetchedAppControls = false;

  /// 1. Fetch Global App Controls & Promo Banner Config (With In-Memory Caching)
  static Future<Map<String, dynamic>?> fetchAppControls({bool forceRefresh = false}) async {
    if (!forceRefresh && _hasFetchedAppControls) {
      return _cachedAppControls;
    }
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/v1/app-controls');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          _cachedAppControls = Map<String, dynamic>.from(body['data']);
          _hasFetchedAppControls = true;
          return _cachedAppControls;
        }
      }
    } catch (e) {
      debugPrint('PromoCampaignService.fetchAppControls error: $e');
    }
    _hasFetchedAppControls = true;
    return _cachedAppControls;
  }

  /// Check if promo banner is active from cached app controls
  static bool isPromoActiveCached() {
    if (_cachedAppControls != null) {
      final promo = _cachedAppControls!['promoBanner'];
      return promo != null && (promo['active'] == true || promo['active'] == 'true' || promo['active'] == 1);
    }
    return false; // Default false if not loaded or inactive
  }

  /// Get promo banner config data from cached app controls
  static Map<String, dynamic>? getCachedPromoData() {
    if (_cachedAppControls != null) {
      final promo = _cachedAppControls!['promoBanner'];
      if (promo != null) {
        return Map<String, dynamic>.from(promo);
      }
    }
    return null;
  }

  /// 1.5. Fetch Available Cities List from API: GET /api/v1/otp/cities
  static Future<List<String>> fetchCities() async {
    const List<String> fallbackCities = [
      'Ahmedabad',
      'Bengaluru',
      'Chandigarh',
      'Chennai',
      'Delhi',
      'Greater Noida',
      'Gurugram',
      'Hyderabad',
      'Mumbai',
      'Navi Mumbai',
      'Noida',
      'Pune',
    ];
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/v1/otp/cities');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] is List) {
          final List<dynamic> rawList = body['data'];
          final cities = rawList.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
          if (cities.isNotEmpty) {
            return cities;
          }
        }
      }
    } catch (e) {
      debugPrint('PromoCampaignService.fetchCities error: $e');
    }
    return fallbackCities;
  }

  /// 2. Send WhatsApp OTP
  static Future<Map<String, dynamic>> sendOtp(String rawPhoneNo) async {
    try {
      // Ensure phoneNo has 91 prefix if 10 digits
      String cleanPhone = rawPhoneNo.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.length == 10) {
        cleanPhone = '91$cleanPhone';
      }

      final url = Uri.parse('${AuthService.baseUrl}/api/v1/otp/send-otp');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phoneNo': cleanPhone}),
      ).timeout(const Duration(seconds: 15));

      final Map<String, dynamic> body = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': body['success'] ?? true,
          'message': body['message'] ?? 'OTP sent successfully via WhatsApp',
          'data': body['data'],
        };
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Failed to send OTP. Please try again.',
        };
      }
    } catch (e) {
      debugPrint('PromoCampaignService.sendOtp error: $e');
      return {
        'success': false,
        'message': 'Network error while sending OTP. Please try again.',
      };
    }
  }

  /// 3. Verify WhatsApp OTP
  static Future<Map<String, dynamic>> verifyOtp(String rawPhoneNo, String otpCode) async {
    try {
      String cleanPhone = rawPhoneNo.replaceAll(RegExp(r'\D'), '');

      final url = Uri.parse('${AuthService.baseUrl}/api/v1/otp/verify-otp');
      debugPrint('📦 [PromoCampaignService] === VERIFY OTP API CALL ===');
      debugPrint('📦 [PromoCampaignService] POST Request URL: $url');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phoneNo': cleanPhone,
          'otpCode': otpCode.trim(),
        }),
      ).timeout(const Duration(seconds: 15));

      debugPrint('📦 [PromoCampaignService] verifyOtp API Status: ${response.statusCode}');
      debugPrint('📦 [PromoCampaignService] FULL verifyOtp API RESPONSE BODY:\n${response.body}');

      final Map<String, dynamic> body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final data = body['data'] ?? {};
        debugPrint('📦 [PromoCampaignService] verifyOtp Data: $data');
        debugPrint('📦 [PromoCampaignService] verifyOtp alreadyPurchased: ${data['alreadyPurchased']}');
        // Save verified auth session locally in Hive
        await savePromoAuth(data);
        return {
          'success': true,
          'message': body['message'] ?? 'OTP verified successfully',
          'data': data,
        };
      } else {
        debugPrint('📦 [PromoCampaignService] verifyOtp failed with message: ${body['message']}');
        return {
          'success': false,
          'message': body['message'] ?? 'Invalid or expired OTP. Please try again.',
        };
      }
    } catch (e) {
      debugPrint('📦 [PromoCampaignService] verifyOtp error: $e');
      return {
        'success': false,
        'message': 'Network error verifying OTP. Please try again.',
      };
    }
  }

  /// 4. Save/Update Verified Lead Details
  static Future<Map<String, dynamic>> updateDetails({
    required String phoneNo,
    required String name,
    required String email,
    required String companyName,
    required String type,
    required String targetCity,
  }) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/v1/otp/update-details');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phoneNo': phoneNo,
          'name': name.trim(),
          'email': email.trim(),
          'companyName': companyName.trim(),
          'type': type.trim(),
          'targetCity': targetCity.trim(),
        }),
      ).timeout(const Duration(seconds: 15));

      final Map<String, dynamic> body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': body['data'],
          'message': body['message'] ?? 'Details updated successfully',
        };
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Failed to update details',
        };
      }
    } catch (e) {
      debugPrint('PromoCampaignService.updateDetails error: $e');
      return {
        'success': false,
        'message': 'Network error updating details. Please try again.',
      };
    }
  }


  /// 5. Initiate Paytm Payment Transaction
  static Future<Map<String, dynamic>> initiatePaytmPayment({
    required String leadId,
    required String phoneNo,
    required String name,
    required String email,
    required String companyName,
    required String type,
    required String targetCity,
    dynamic amount,
  }) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/v1/otp/paytm/initiate');
      final Map<String, dynamic> requestBody = {
        'leadId': leadId,
        'phoneNo': phoneNo,
        'name': name.trim(),
        'email': email.trim(),
        'companyName': companyName.trim(),
        'type': type.trim(),
        'targetCity': targetCity.trim(),
      };

      debugPrint('💳 [PromoCampaignService] === INITIATE PAYTM PAYMENT API CALL ===');
      debugPrint('💳 [PromoCampaignService] POST URL: $url');
      debugPrint('💳 [PromoCampaignService] Request Body: ${jsonEncode(requestBody)}');

      final response = await raw_http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Bypass-Tunnel-Reminder': 'true',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));

      debugPrint('💳 [PromoCampaignService] Response Status: ${response.statusCode}');
      debugPrint('💳 [PromoCampaignService] FULL RESPONSE BODY:\n${response.body}');

      Map<String, dynamic> body = {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          body = Map<String, dynamic>.from(decoded);
        }
      } catch (e) {
        debugPrint('💳 [PromoCampaignService] Failed to parse JSON body: $e');
      }

      if (response.statusCode == 200 && body['success'] == true) {
        return {
          'success': true,
          'data': body['data'],
          'message': body['message'] ?? 'Payment initiated successfully',
        };
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Paytm Gateway System Error',
          'data': body['data'],
        };
      }
    } catch (e, stack) {
      debugPrint('💳 [PromoCampaignService] initiatePaytmPayment EXCEPTION TYPE: ${e.runtimeType}');
      debugPrint('💳 [PromoCampaignService] initiatePaytmPayment EXCEPTION MSG: $e');
      debugPrint('💳 [PromoCampaignService] initiatePaytmPayment STACK TRACE:\n$stack');
      return {
        'success': false,
        'message': 'Paytm Gateway System Error ($e)',
      };
    }
  }

  /// 3.5. Fetch User Profile and Purchased Sheets (By Phone)
  static Future<Map<String, dynamic>> fetchUserData(String rawPhoneNo) async {
    try {
      String cleanPhone = rawPhoneNo.replaceAll(RegExp(r'\D'), '');
      final url = Uri.parse('${AuthService.baseUrl}/api/v1/otp/user-data/$cleanPhone');
      debugPrint('📦 [PromoCampaignService] === FETCH USER DATA / ORDERS API CALL ===');
      debugPrint('📦 [PromoCampaignService] GET Request URL: $url');
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      debugPrint('📦 [PromoCampaignService] Response Status Code: ${response.statusCode}');
      debugPrint('📦 [PromoCampaignService] FULL API RESPONSE BODY:\n${response.body}');

      final Map<String, dynamic> body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final data = body['data'] ?? {};
        debugPrint('📦 [PromoCampaignService] Decoded Data: $data');
        debugPrint('📦 [PromoCampaignService] alreadyPurchased Items: ${data['alreadyPurchased']}');
        await savePromoAuth(data);
        return {
          'success': true,
          'message': body['message'] ?? 'User data fetched successfully',
          'data': data,
        };
      } else {
        debugPrint('📦 [PromoCampaignService] fetchUserData API failed with message: ${body['message']}');
        return {
          'success': false,
          'message': body['message'] ?? 'Failed to fetch user data',
        };
      }
    } catch (e) {
      debugPrint('📦 [PromoCampaignService] fetchUserData error: $e');
      return {
        'success': false,
        'message': 'Network error fetching user data.',
      };
    }
  }

  /// 6. Paytm Webhook Callback
  static Future<Map<String, dynamic>> sendPaytmCallback({
    required String phoneNo,
    required String orderId,
    String status = 'success',
  }) async {
    try {
      String cleanPhone = phoneNo.replaceAll(RegExp(r'\D'), '');
      final url = Uri.parse('${AuthService.baseUrl}/api/v1/otp/paytm/callback');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phoneNo': cleanPhone,
          'orderId': orderId,
          'status': status,
          'STATUS': 'TXN_SUCCESS',
          'RESPCODE': '01',
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        return {'success': false};
      }
    } catch (e) {
      debugPrint('PromoCampaignService.sendPaytmCallback error: $e');
      return {'success': false};
    }
  }

  /// Local Storage: Save Auth Session to Hive
  static Future<void> savePromoAuth(Map<String, dynamic> data) async {
    try {
      final box = await Hive.openBox(promoBoxName);

      // Preserve and store ALL fields and objects returned from API data payload
      final Map<String, dynamic> sessionMap = Map<String, dynamic>.from(data);
      sessionMap['isAuthenticated'] = true;
      sessionMap['phoneNo'] = data['phoneNo'] ?? sessionMap['phoneNo'] ?? '';
      sessionMap['lead'] = data['lead'] ?? sessionMap['lead'] ?? {};
      sessionMap['alreadyPurchased'] = data['alreadyPurchased'] ?? sessionMap['alreadyPurchased'] ?? [];
      sessionMap['savedAt'] = DateTime.now().toIso8601String();

      final String encodedJson = jsonEncode(sessionMap);
      await box.put(promoAuthKey, encodedJson);
      final int itemCount = (sessionMap['alreadyPurchased'] as List?)?.length ?? 0;
      debugPrint('💾 [PromoCampaignService] savePromoAuth saved successfully. Total alreadyPurchased items stored: $itemCount');
    } catch (e) {
      debugPrint('💾 [PromoCampaignService] savePromoAuth error: $e');
    }
  }

  /// Local Storage: Retrieve Saved Auth Session from Hive
  static Future<Map<String, dynamic>?> getPromoAuth() async {
    try {
      final box = await Hive.openBox(promoBoxName);
      final jsonStr = box.get(promoAuthKey);
      if (jsonStr != null && jsonStr.toString().isNotEmpty) {
        final decoded = jsonDecode(jsonStr.toString());
        if (decoded is Map) {
          final Map<String, dynamic> map = Map<String, dynamic>.from(decoded);
          final int itemCount = (map['alreadyPurchased'] as List?)?.length ?? 0;
          debugPrint('💾 [PromoCampaignService] getPromoAuth retrieved successfully. Phone: ${map['phoneNo']}, alreadyPurchased items: $itemCount');
          return map;
        }
      }
    } catch (e) {
      debugPrint('💾 [PromoCampaignService] getPromoAuth error: $e');
    }
    return null;
  }

  /// Local Storage: Clear Auth Session
  static Future<void> clearPromoAuth() async {
    try {
      final box = await Hive.openBox(promoBoxName);
      await box.delete(promoAuthKey);
    } catch (e) {
      debugPrint('PromoCampaignService.clearPromoAuth error: $e');
    }
  }
}
