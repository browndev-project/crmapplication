import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'http_client.dart' as http;
import 'auth_service.dart';
import '../../data/models/constants_model.dart';

class ConstantsService {
  static final ConstantsService _instance = ConstantsService._internal();
  factory ConstantsService() => _instance;
  ConstantsService._internal();

  static const String _boxName = 'constantsBox';
  static const String _cacheKey = 'appConstants';

  /// Fetches system constants from GET /api/v1/constants with Hive caching
  Future<AppConstantsData> fetchConstants({bool forceRefresh = false}) async {
    try {
      final box = await Hive.openBox(_boxName);

      // Check Cache first if forceRefresh is false
      if (!forceRefresh && box.containsKey(_cacheKey)) {
        try {
          final cachedJsonStr = box.get(_cacheKey) as String?;
          if (cachedJsonStr != null) {
            final cachedJson = jsonDecode(cachedJsonStr);
            if (cachedJson is Map<String, dynamic> && cachedJson['data'] != null) {
              debugPrint('[ConstantsService] Returning cached constants from Hive.');
              return AppConstantsData.fromJson(Map<String, dynamic>.from(cachedJson['data']));
            }
          }
        } catch (e) {
          debugPrint('[ConstantsService] Cache parsing error: $e');
        }
      }

      // Fetch Fresh Data from API
      final url = Uri.parse('${AuthService.baseUrl}/api/v1/constants');
      debugPrint('[ConstantsService] Fetching fresh constants from: $url');

      final authBox = await Hive.openBox('authBox');
      final token = authBox.get('accessToken');

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          await box.put(_cacheKey, response.body);
          debugPrint('[ConstantsService] Constants successfully fetched and cached in Hive.');
          return AppConstantsData.fromJson(Map<String, dynamic>.from(body['data']));
        }
      }

      debugPrint('[ConstantsService] API HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      debugPrint('[ConstantsService] Exception fetching constants: $e');
    }

    // Fallback to Hive cache or default values
    try {
      final box = await Hive.openBox(_boxName);
      if (box.containsKey(_cacheKey)) {
        final cachedJson = jsonDecode(box.get(_cacheKey));
        if (cachedJson['data'] != null) {
          return AppConstantsData.fromJson(Map<String, dynamic>.from(cachedJson['data']));
        }
      }
    } catch (_) {}

    debugPrint('[ConstantsService] Returning default fallback constants.');
    return AppConstantsData.defaultValues();
  }
}
