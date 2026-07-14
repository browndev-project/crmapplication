import 'dart:convert';
import 'dart:io';
import 'http_client.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'auth_service.dart';
import '../../data/models/itinerary_model.dart';

class ItineraryService {
  Future<String?> _getAccessToken() async {
    final box = await Hive.openBox('authBox');
    return box.get('accessToken');
  }

  Future<Map<String, dynamic>> getItineraries({
    String searchQuery = '',
    int page = 1,
    int limit = 10,
    bool? hasQuotation,
    String? lead,
  }) async {
    final token = await _getAccessToken();
    final queryParams = {
      'searchQuery': searchQuery,
      'page': page.toString(),
      'limit': limit.toString(),
      if (hasQuotation != null) 'hasQuotation': hasQuotation.toString(),
      if (lead != null && lead.isNotEmpty) 'lead': lead,
    };
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/itinerary-v2/all').replace(queryParameters: queryParams);
    
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw 'Failed to load itineraries: ${response.statusCode}';
    }
  }

  Future<List<Map<String, dynamic>>> getTemplates() async {
    final token = await _getAccessToken();
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/itinerary-v2/templates');
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final nestedData = data['data'] ?? data;
      return List<Map<String, dynamic>>.from(nestedData['templates'] ?? nestedData['itineraries'] ?? []);
    } else {
      throw 'Failed to load templates: ${response.statusCode}';
    }
  }

  Future<String> getTemplatePreviewHtml(String key) async {
    final token = await _getAccessToken();
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/itinerary-v2/templates/$key/preview');
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final text = response.body;
      try {
        final data = jsonDecode(text);
        if (data is Map) {
          final nestedData = data['data'] ?? data;
          if (nestedData is Map) {
            return nestedData['html'] ?? nestedData['preview'] ?? nestedData['htmlContent'] ?? text;
          } else if (nestedData is String) {
            return nestedData;
          }
          return data['html'] ?? data['preview'] ?? text;
        }
      } catch (_) {}
      return text;
    } else {
      throw 'Template preview failed (${response.statusCode}): ${response.body}';
    }
  }

  Future<ItineraryV2> createItinerary(Map<String, dynamic> data) async {
    final token = await _getAccessToken();
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/itinerary-v2/create');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final resData = jsonDecode(response.body);
      final nestedData = resData['data'] ?? resData;
      return ItineraryV2.fromJson(nestedData['itinerary'] ?? nestedData);
    } else {
      throw 'Failed to create itinerary: ${response.body}';
    }
  }

  Future<ItineraryV2> updateItinerary(String id, Map<String, dynamic> data) async {
    final token = await _getAccessToken();
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/itinerary-v2/update/$id');
    final response = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      final resData = jsonDecode(response.body);
      final nestedData = resData['data'] ?? resData;
      return ItineraryV2.fromJson(nestedData['itinerary'] ?? nestedData);
    } else {
      throw 'Failed to update itinerary: ${response.body}';
    }
  }

  Future<void> deleteItinerary(String id) async {
    final token = await _getAccessToken();
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/itinerary-v2/delete/$id');
    final response = await http.delete(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw 'Failed to delete itinerary: ${response.body}';
    }
  }

  Future<ItineraryV2> cloneItinerary(String id) async {
    try {
      final itineraryDetail = await getItineraryDetail(id);
      final originalJson = itineraryDetail.toJson();
      final clonedData = Map<String, dynamic>.from(originalJson);
      
      clonedData['subject'] = '${itineraryDetail.subject} - Copy';
      
      return await createItinerary(clonedData);
    } catch (e) {
      throw 'Failed to clone itinerary: $e';
    }
  }

  Future<String?> downloadItinerary(String id, String title) async {
    try {
      final token = await _getAccessToken();
      final uri = Uri.parse('${AuthService.baseUrl}/api/v1/itinerary-v2/download/$id');
      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/Itinerary_${title.replaceAll(' ', '_')}.pdf';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        return filePath;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> generateItineraryPdf(String id) async {
    try {
      final token = await _getAccessToken();
      final uri = Uri.parse('${AuthService.baseUrl}/api/v1/itinerary-v2/generate/$id');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final nestedData = data['data'] ?? data;
        return nestedData['pdfUrl'] ?? nestedData['link'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<ItineraryV2> getItineraryDetail(String id) async {
    final token = await _getAccessToken();
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/itinerary-v2/$id');
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final nestedData = data['data'] ?? data;
      return ItineraryV2.fromJson(nestedData['itinerary'] ?? nestedData);
    } else {
      throw 'Failed to get itinerary detail: ${response.statusCode}';
    }
  }

  Future<String> getShareMessage(String id) async {
    final token = await _getAccessToken();
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/itinerary-v2/$id/share-message');
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final nestedData = data['data'] ?? data;
      return nestedData['message'] ?? '';
    } else {
      throw 'Failed to fetch share message: ${response.statusCode}';
    }
  }

  Future<Map<String, dynamic>> generateHybrid(Map<String, dynamic> payload) async {
    final token = await _getAccessToken();
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/ai/generate-hybrid');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final resData = jsonDecode(response.body);
      return resData['data'] ?? resData;
    } else {
      throw 'Failed to generate hybrid itinerary: ${response.body}';
    }
  }
}
