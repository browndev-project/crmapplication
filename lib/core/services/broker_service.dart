import 'dart:convert';
import 'http_client.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/broker_model.dart';
import 'auth_service.dart';

class BrokerService {
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

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
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
      throw 'Error fetching brokers: $e';
    }
  }

  Future<void> createBroker(Map<String, dynamic> data) async {
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');
    
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/brokers/create');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        final errorData = jsonDecode(response.body);
        throw errorData['message'] ?? 'Failed to create partner';
      }
    } catch (e) {
      throw 'Error creating partner: $e';
    }
  }

  Future<void> updateBroker(String id, Map<String, dynamic> data) async {
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');
    
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/brokers/$id');

    try {
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw errorData['message'] ?? 'Failed to update partner';
      }
    } catch (e) {
      throw 'Error updating partner: $e';
    }
  }

  Future<void> deleteBroker(String id) async {
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');
    
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/brokers/$id');

    try {
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw errorData['message'] ?? 'Failed to delete partner';
      }
    } catch (e) {
      throw 'Error deleting partner: $e';
    }
  }

  Future<BrokerStats> fetchStats() async {
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');

    if (accessToken == null) {
      throw 'No access token found';
    }

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/brokers/stats');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
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
      throw 'Error fetching stats: $e';
    }
  }
}
