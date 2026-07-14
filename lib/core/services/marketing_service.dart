import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'http_client.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/marketing_template_model.dart';
import 'auth_service.dart';

class MarketingService {
  Future<String> _getToken() async {
    final box = await Hive.openBox('authBox');
    final token = box.get('accessToken');
    if (token == null) throw 'Authentication required';
    return token;
  }

  Map<String, String> _getHeaders(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'Bypass-Tunnel-Reminder': 'true',
      };

  Future<List<MarketingTemplate>> fetchTemplates() async {
    final token = await _getToken();
    // Correct endpoint based on documentation
    final url = Uri.parse('${AuthService.baseUrl}/api/v1/marketing/mail/templates/');

    try {
      debugPrint('🚀 Fetching Marketing Templates: $url');
      final response = await http.get(url, headers: _getHeaders(token));
      
      debugPrint('📩 Fetch Templates Response [${response.statusCode}]: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Standard pattern: { success: true, data: [...] }
        final List rawTemplates = (data['data'] is List) 
            ? data['data'] 
            : (data['data']?['templates'] ?? []);
            
        return rawTemplates.map((e) => MarketingTemplate.fromJson(e)).toList();
      } else {
        throw jsonDecode(response.body)['message'] ?? 'Failed to load templates';
      }
    } catch (e) {
      debugPrint('MarketingService: fetchTemplates Error: $e');
      rethrow;
    }
  }

  Future<bool> createTemplate({
    required String name,
    required String subject,
    required String body,
  }) async {
    final token = await _getToken();
    // Correct endpoint based on documentation
    final url = Uri.parse('${AuthService.baseUrl}/api/v1/marketing/mail/templates/create');

    final payload = {
      'name': name,
      'subject': subject,
      'body': body,
    };

    try {
      debugPrint('🚀 Creating Marketing Template: $url');
      debugPrint('📦 Body: $payload');
      
      final response = await http.post(
        url,
        headers: _getHeaders(token),
        body: jsonEncode(payload),
      );
      
      debugPrint('📩 Create Template Response [${response.statusCode}]: ${response.body}');
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('MarketingService: createTemplate Error: $e');
      return false;
    }
  }

  Future<bool> deleteTemplate(String id) async {
    final token = await _getToken();
    // Using standard pattern for delete if not explicitly documented
    final url = Uri.parse('${AuthService.baseUrl}/api/v1/marketing/mail/templates/$id');

    try {
      debugPrint('🚀 Deleting Marketing Template: $url');
      final response = await http.delete(url, headers: _getHeaders(token));
      
      debugPrint('📩 Delete Template Response [${response.statusCode}]: ${response.body}');
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('MarketingService: deleteTemplate Error: $e');
      return false;
    }
  }
}
