import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'http_client.dart' as http;
import 'auth_service.dart';
import '../../data/models/cold_lead_model.dart';

class ColdLeadService {
  Future<String> _getAccessToken() async {
    final box = await Hive.openBox('authBox');
    final token = box.get('accessToken');
    if (token == null || token.toString().isEmpty) {
      throw 'No access token found. Please log in again.';
    }
    return token.toString();
  }

  Map<String, String> _buildHeaders(String token) {
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// List Cold Leads with pagination, search, status, and conversion filters
  // Future<ColdLeadsResponse> fetchColdLeads({
  //   int page = 1,
  //   int limit = 20,
  //   String? searchQuery,
  //   String? status,
  //   bool? isConverted,
  // }) async {
  Future<ColdLeadsResponse> fetchColdLeads({
    int page = 1,
    int limit = 10,
    String? searchQuery,
    String? status,
    bool? isConverted,
  }) async {
    final token = await _getAccessToken();

    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      queryParams['searchQuery'] = searchQuery.trim();
    }

    if (status != null && status.isNotEmpty && status.toLowerCase() != 'all') {
      queryParams['status'] = status;
    }

    if (isConverted != null) {
      queryParams['isConverted'] = isConverted.toString();
    }

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/cold-leads')
        .replace(queryParameters: queryParams);

    // Original:
    // debugPrint('ColdLeadService: GET $uri');
    // final response = await http.get(uri, headers: _buildHeaders(token));
    // final Map<String, dynamic> decoded = jsonDecode(response.body);
    debugPrint('ColdLeadService: GET $uri');
    final response = await http.get(uri, headers: _buildHeaders(token));
    debugPrint('ColdLeadService: Response [${response.statusCode}]: ${response.body}');
    final Map<String, dynamic> decoded = jsonDecode(response.body);
    return ColdLeadsResponse.fromJson(decoded);
  }

  /// Get single Cold Lead details by ID
  Future<ColdLead> getColdLead(String id) async {
    final token = await _getAccessToken();
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/cold-leads/$id');

    debugPrint('ColdLeadService: GET $uri');
    final response = await http.get(uri, headers: _buildHeaders(token));

    final Map<String, dynamic> decoded = jsonDecode(response.body);
    final leadData = decoded['data']?['coldLead'] ?? decoded['data'];
    if (leadData is Map<String, dynamic>) {
      return ColdLead.fromJson(leadData);
    }
    throw 'Invalid response format for cold lead details';
  }

  /// Update Status and/or Notes of a Cold Lead
  Future<ColdLead> updateColdLead(
    String id, {
    String? status,
    String? notes,
  }) async {
    final token = await _getAccessToken();
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/cold-leads/$id');

    final body = <String, dynamic>{};
    if (status != null && status.isNotEmpty) {
      body['status'] = status;
    }
    if (notes != null) {
      body['notes'] = notes;
    }

    debugPrint('ColdLeadService: PATCH $uri with body: $body');
    final response = await http.patch(
      uri,
      headers: _buildHeaders(token),
      body: jsonEncode(body),
    );

    final Map<String, dynamic> decoded = jsonDecode(response.body);
    final leadData = decoded['data']?['coldLead'] ?? decoded['data'];
    if (leadData is Map<String, dynamic>) {
      return ColdLead.fromJson(leadData);
    }
    throw 'Failed to parse updated cold lead';
  }

  /// Delete a Cold Lead
  Future<bool> deleteColdLead(String id) async {
    final token = await _getAccessToken();
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/cold-leads/$id');

    debugPrint('ColdLeadService: DELETE $uri');
    final response = await http.delete(uri, headers: _buildHeaders(token));

    final Map<String, dynamic> decoded = jsonDecode(response.body);
    return decoded['success'] == true;
  }
}
