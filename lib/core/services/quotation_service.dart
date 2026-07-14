import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'http_client.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'auth_service.dart';
import '../../data/models/quotation_model.dart';

class QuotationService {
  Future<String?> _getAccessToken() async {
    final box = await Hive.openBox('authBox');
    return box.get('accessToken');
  }

  Future<Map<String, dynamic>> getQuotations({
    String searchQuery = '',
    String? status,
    int page = 1,
    int limit = 10,
    String? lead,
  }) async {
    final token = await _getAccessToken();
    final queryParams = {
      'searchQuery': searchQuery,
      if (status != null && status != 'ALL') 'status': status,
      'page': page.toString(),
      'limit': limit.toString(),
      if (lead != null && lead.isNotEmpty) 'lead': lead,
    };
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/quotation').replace(queryParameters: queryParams);
    
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
      throw 'Failed to load quotations: ${response.statusCode}';
    }
  }

  Future<Quotation> createQuotation(Map<String, dynamic> data) async {
    final token = await _getAccessToken();
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/quotation');
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
      return Quotation.fromJson(nestedData['quotation'] ?? nestedData);
    } else {
      throw _parseError(response.statusCode, response.body);
    }
  }

  Future<String?> getLatestQuotationNumberForDay(String datePrefix) async {
    try {
      final token = await _getAccessToken();
      final uri = Uri.parse('${AuthService.baseUrl}/api/v1/quotation/latest/$datePrefix');
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
        return nestedData['quotationNumber'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  String _parseError(int statusCode, String body) {
    final lower = body.toLowerCase();
    if (lower.contains('e11000') || lower.contains('duplicate key') || lower.contains('quotationnumber')) {
      return 'Quotation number already exists. Please try again.';
    }
    if (statusCode == 400) {
      return 'Invalid quotation data. Please check all fields.';
    }
    if (statusCode == 401 || statusCode == 403) {
      return 'Permission denied. You may not have access to perform this action.';
    }
    if (statusCode == 404) {
      return 'Resource not found.';
    }
    if (statusCode >= 500) {
      return 'Server error. Please try again later.';
    }
    return 'Unable to save quotation right now. Please try again.';
  }

  Future<Quotation> updateQuotation(String id, Map<String, dynamic> data) async {
    final token = await _getAccessToken();
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/quotation/$id');
    debugPrint('PATCH $uri');
    debugPrint('Payload: $data');
    final response = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    debugPrint('Response status: ${response.statusCode}');
    debugPrint('Response body: ${response.body}');

    if (response.statusCode == 200) {
      final resData = jsonDecode(response.body);
      final nestedData = resData['data'] ?? resData;
      final quotationData = nestedData['quotation'] ?? nestedData;
      if (quotationData == null || quotationData is! Map<String, dynamic>) {
        throw 'Invalid response: quotation data not found';
      }
      return Quotation.fromJson(quotationData);
    } else {
      String errorMsg;
      try {
        final errBody = jsonDecode(response.body);
        errorMsg = errBody['message'] ?? errBody['error'] ?? response.body;
      } catch (_) {
        errorMsg = response.body;
      }
      throw 'Failed to update quotation ($errorMsg)';
    }
  }

  Future<void> deleteQuotation(String id) async {
    final token = await _getAccessToken();
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/quotation/$id');
    final response = await http.delete(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 201 && response.statusCode != 202 && response.statusCode != 204) {
      throw 'Failed to delete quotation: ${response.body}';
    }
  }

  Future<Quotation> getQuotationDetail(String id) async {
    final token = await _getAccessToken();
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/quotation/$id');
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
      return Quotation.fromJson(nestedData['quotation'] ?? nestedData);
    } else {
      throw 'Failed to get quotation detail: ${response.statusCode}';
    }
  }

  Future<String?> downloadQuotation(String id, String quotationNo) async {
    try {
      final token = await _getAccessToken();
      final uri = Uri.parse('${AuthService.baseUrl}/api/v1/quotation/generate/$id');
      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/Quotation_$quotationNo.pdf';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        return filePath;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String> getShareLink(String id) async {
    final token = await _getAccessToken();
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/quotation/generate/$id');
    final response = await http.get(
      uri,
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final nestedData = data['data'] ?? data;
      return nestedData['pdfUrl'] ?? nestedData['downloadUrl'] ?? nestedData['url'] ?? '';
    } else {
      throw 'Failed to get share link: ${response.statusCode}';
    }
  }

  Future<String> getShareMessage(String id) async {
    final token = await _getAccessToken();
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/quotation/$id/share-message');
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
}
