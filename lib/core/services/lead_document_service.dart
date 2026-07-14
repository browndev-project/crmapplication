import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'http_client.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/lead_document_model.dart';
import 'auth_service.dart';

class LeadDocumentService {
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

  // --- Lead Documents ---

  Future<List<LeadDocument>> fetchLeadDocuments(String leadId) async {
    final token = await _getToken();
    final url = Uri.parse('${AuthService.baseUrl}/api/v1/lead-documents/list/$leadId');

    try {
      final response = await http.get(url, headers: _getHeaders(token));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List docs = data['data']['documents'] ?? [];
        return docs.map((e) => LeadDocument.fromJson(e)).toList();
      } else {
        throw jsonDecode(response.body)['message'] ?? 'Failed to load documents';
      }
    } catch (e) {
      debugPrint('LeadDocumentService: fetchLeadDocuments Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchAllDocuments({
    String? search,
    String? fileType,
    String? uploadedBy,
    int page = 1,
    int limit = 10,
  }) async {
    final token = await _getToken();
    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
      if (fileType != null && fileType.isNotEmpty) 'fileType': fileType,
      if (uploadedBy != null && uploadedBy.isNotEmpty) 'uploadedBy': uploadedBy,
    };

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/lead-documents/all').replace(queryParameters: queryParams);

    try {
      final response = await http.get(url, headers: _getHeaders(token));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        final List docs = data['documents'] ?? [];
        return {
          'documents': docs.map((e) => LeadDocument.fromJson(e)).toList(),
          'totalCount': data['totalCount'] ?? 0,
          'totalPages': data['pagination']?['totalPages'] ?? 1,
        };
      } else {
        throw jsonDecode(response.body)['message'] ?? 'Failed to load documents';
      }
    } catch (e) {
      debugPrint('LeadDocumentService: fetchAllDocuments Error: $e');
      rethrow;
    }
  }

  Future<bool> uploadDocumentMetadata({
    required String leadId,
    required String label,
    required String fileType,
    required int size,
    required String r2Key,
  }) async {
    final token = await _getToken();
    final url = Uri.parse('${AuthService.baseUrl}/api/v1/lead-documents/upload');

    final payload = {
      'leadId': leadId,
      'label': label,
      'fileType': fileType,
      'size': size,
      'r2Key': r2Key,
    };

    try {
      final response = await http.post(
        url,
        headers: _getHeaders(token),
        body: jsonEncode(payload),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('LeadDocumentService: uploadDocumentMetadata Error: $e');
      return false;
    }
  }

  Future<bool> deleteDocument(String id) async {
    final token = await _getToken();
    final url = Uri.parse('${AuthService.baseUrl}/api/v1/lead-documents/$id');

    try {
      final response = await http.delete(url, headers: _getHeaders(token));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('LeadDocumentService: deleteDocument Error: $e');
      return false;
    }
  }

  Future<bool> toggleLock(String id) async {
    final token = await _getToken();
    final url = Uri.parse('${AuthService.baseUrl}/api/v1/lead-documents/toggle-lock/$id');

    try {
      final response = await http.patch(url, headers: _getHeaders(token));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('LeadDocumentService: toggleLock Error: $e');
      return false;
    }
  }

  // --- Document Forms ---

  Future<List<DocumentForm>> fetchForms() async {
    final token = await _getToken();
    final url = Uri.parse('${AuthService.baseUrl}/api/v1/document-forms/list');

    try {
      final response = await http.get(url, headers: _getHeaders(token));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List forms = (data['data'] is Map) ? (data['data']['forms'] ?? []) : (data['data'] ?? []);
        return forms.map((e) => DocumentForm.fromJson(e)).toList();
      } else {
        throw jsonDecode(response.body)['message'] ?? 'Failed to load forms';
      }
    } catch (e) {
      debugPrint('LeadDocumentService: fetchForms Error: $e');
      rethrow;
    }
  }

  Future<bool> createForm(String name, List<DocumentFormField> fields) async {
    final token = await _getToken();
    final url = Uri.parse('${AuthService.baseUrl}/api/v1/document-forms/create');

    final payload = {
      'name': name,
      'fields': fields.map((e) => e.toJson()).toList(),
    };

    try {
      final response = await http.post(
        url,
        headers: _getHeaders(token),
        body: jsonEncode(payload),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('LeadDocumentService: createForm Error: $e');
      return false;
    }
  }

  Future<bool> updateForm(String id, String name, List<DocumentFormField> fields) async {
    final token = await _getToken();
    final url = Uri.parse('${AuthService.baseUrl}/api/v1/document-forms/$id');

    final payload = {
      'name': name,
      'fields': fields.map((e) => e.toJson()).toList(),
    };

    try {
      final response = await http.put(
        url,
        headers: _getHeaders(token),
        body: jsonEncode(payload),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('LeadDocumentService: updateForm Error: $e');
      return false;
    }
  }

  Future<bool> deleteForm(String id) async {
    final token = await _getToken();
    final url = Uri.parse('${AuthService.baseUrl}/api/v1/document-forms/$id');

    try {
      final response = await http.delete(url, headers: _getHeaders(token));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('LeadDocumentService: deleteForm Error: $e');
      return false;
    }
  }
}
