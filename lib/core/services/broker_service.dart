import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'http_client.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/broker_model.dart';
import 'auth_service.dart';

class BrokerService {
  void _logApiCall({
    required String method,
    required Uri url,
    required Map<String, String> headers,
    dynamic body,
    required int statusCode,
    required String responseBody,
  }) {
    debugPrint('--- 🌐 [BROKER API CALL] ---');
    debugPrint('Method: $method');
    debugPrint('URL: $url');
    debugPrint('Headers: $headers');
    if (body != null) {
      debugPrint('Request Body: $body');
    }
    debugPrint('Response Status: $statusCode');
    debugPrint('Response Body: $responseBody');
    debugPrint('-----------------------------');
  }

  Future<BrokerData> fetchBrokers({
    int page = 1,
    int limit = 20,
    String? searchQuery,
    String? type,
    String? status,
  }) async {
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');

    if (accessToken == null) {
      debugPrint('❌ [BrokerService.fetchBrokers] Error: No access token found in Hive authBox');
      throw 'No access token found';
    }

    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (searchQuery != null && searchQuery.isNotEmpty) {
      queryParams['searchQuery'] = searchQuery;
    }
    if (type != null && type.isNotEmpty && type != 'All Types') {
      queryParams['type'] = type;
    }
    if (status != null && status.isNotEmpty && status != 'All Status') {
      queryParams['status'] = status.toLowerCase();
    }

    final queryString = Uri(queryParameters: queryParams).query;
    final url = Uri.parse('${AuthService.baseUrl}/api/v1/brokers/list?$queryString');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    try {
      final response = await http.get(url, headers: headers);
      _logApiCall(
        method: 'GET',
        url: url,
        headers: headers,
        statusCode: response.statusCode,
        responseBody: response.body,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final brokerResponse = BrokerResponse.fromJson(jsonResponse);
        
        if (brokerResponse.success && brokerResponse.data != null) {
          return brokerResponse.data!;
        } else {
          throw brokerResponse.message;
        }
      } else {
        throw 'Failed to load brokers: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('❌ [BrokerService.fetchBrokers] Exception: $e');
      throw 'Error fetching brokers: $e';
    }
  }

  Future<void> createBroker(Map<String, dynamic> data) async {
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');
    
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/brokers/create');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
    final body = jsonEncode(data);

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: body,
      );
      _logApiCall(
        method: 'POST',
        url: url,
        headers: headers,
        body: body,
        statusCode: response.statusCode,
        responseBody: response.body,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        final errorData = jsonDecode(response.body);
        throw errorData['message'] ?? 'Failed to create partner';
      }
    } catch (e) {
      debugPrint('❌ [BrokerService.createBroker] Exception: $e');
      throw 'Error creating partner: $e';
    }
  }

  Future<void> updateBroker(String id, Map<String, dynamic> data) async {
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');
    
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/brokers/$id');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
    final body = jsonEncode(data);

    try {
      final response = await http.patch(
        url,
        headers: headers,
        body: body,
      );
      _logApiCall(
        method: 'PATCH',
        url: url,
        headers: headers,
        body: body,
        statusCode: response.statusCode,
        responseBody: response.body,
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw errorData['message'] ?? 'Failed to update partner';
      }
    } catch (e) {
      debugPrint('❌ [BrokerService.updateBroker] Exception: $e');
      throw 'Error updating partner: $e';
    }
  }

  Future<void> deleteBroker(String id) async {
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');
    
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/brokers/$id');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    try {
      final response = await http.delete(
        url,
        headers: headers,
      );
      _logApiCall(
        method: 'DELETE',
        url: url,
        headers: headers,
        statusCode: response.statusCode,
        responseBody: response.body,
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw errorData['message'] ?? 'Failed to delete partner';
      }
    } catch (e) {
      debugPrint('❌ [BrokerService.deleteBroker] Exception: $e');
      throw 'Error deleting partner: $e';
    }
  }

  Future<BrokerStats> fetchStats() async {
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');

    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/brokers/stats');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    try {
      final response = await http.get(url, headers: headers);
      _logApiCall(
        method: 'GET',
        url: url,
        headers: headers,
        statusCode: response.statusCode,
        responseBody: response.body,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          final statsData = jsonResponse['data']['data'] ?? jsonResponse['data'];
          return BrokerStats.fromJson(statsData);
        } else {
          throw jsonResponse['message'] ?? 'Failed to load stats';
        }
      } else {
        throw 'Failed to load stats: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('❌ [BrokerService.fetchStats] Exception: $e');
      throw 'Error fetching stats: $e';
    }
  }

  Future<BrokerDashboardData> fetchBrokerDashboard(String id) async {
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');

    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/brokers/$id/dashboard');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    try {
      final response = await http.get(url, headers: headers);
      _logApiCall(
        method: 'GET',
        url: url,
        headers: headers,
        statusCode: response.statusCode,
        responseBody: response.body,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final data = jsonResponse['data'] ?? jsonResponse;
        return BrokerDashboardData.fromJson(data);
      } else {
        throw 'Failed to load broker stats: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('❌ [BrokerService.fetchBrokerDashboard] Exception: $e');
      throw 'Error fetching broker stats: $e';
    }
  }

  Future<List<Map<String, dynamic>>> fetchBrokerNames() async {
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');

    if (accessToken == null) return [];

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/brokers/names');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    try {
      final response = await http.get(url, headers: headers);
      _logApiCall(
        method: 'GET',
        url: url,
        headers: headers,
        statusCode: response.statusCode,
        responseBody: response.body,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final list = jsonResponse['data']?['brokers'] as List?;
        return list?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
      }
      return [];
    } catch (e) {
      debugPrint('❌ [BrokerService.fetchBrokerNames] Exception: $e');
      return [];
    }
  }

  Future<BrokerDashboardData> fetchMyDashboard() async {
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');

    if (accessToken == null) {
      debugPrint('❌ [BrokerService.fetchMyDashboard] Error: No access token found in Hive authBox');
      throw 'No access token found';
    }

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/brokers/my-dashboard');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    try {
      final response = await http.get(url, headers: headers);
      _logApiCall(
        method: 'GET',
        url: url,
        headers: headers,
        statusCode: response.statusCode,
        responseBody: response.body,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final data = jsonResponse['data'] ?? jsonResponse;
        return BrokerDashboardData.fromJson(data);
      } else {
        throw 'Failed to load dashboard: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('❌ [BrokerService.fetchMyDashboard] Exception: $e');
      throw 'Error fetching dashboard: $e';
    }
  }

  Future<List<BrokerReferredLead>> fetchMyLeads() async {
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');

    if (accessToken == null) {
      debugPrint('❌ [BrokerService.fetchMyLeads] Error: No access token found in Hive authBox');
      throw 'No access token found';
    }

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/brokers/my-leads');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };

    try {
      final response = await http.get(url, headers: headers);
      _logApiCall(
        method: 'GET',
        url: url,
        headers: headers,
        statusCode: response.statusCode,
        responseBody: response.body,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final list = jsonResponse['data']?['leads'] as List?;
        if (list != null) {
          return list.map((e) => BrokerReferredLead.fromJson(e)).toList();
        }
        return [];
      } else {
        throw 'Failed to load leads: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('❌ [BrokerService.fetchMyLeads] Exception: $e');
      throw 'Error fetching leads: $e';
    }
  }
}
