
import 'dart:convert';
import 'http_client.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/services/auth_service.dart';
import '../../data/models/visit_model.dart';
import 'package:flutter/foundation.dart';

class VisitService {
  Future<VisitsResponse> fetchVisits({
    int page = 1,
    int limit = 20,
    String? search,
    String? status,
    String? assignedTo,
    String? projectId,
    String? propertyId,
    String? dateFrom,
    String? dateTo,
    String? sort,
  }) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');

    if (accessToken == null) {
      throw 'No access token found';
    }

    String queryString = 'page=$page&limit=$limit';
    if (search != null && search.isNotEmpty) {
      queryString += '&searchQuery=$search';
    }
    if (status != null && status != 'All' && status.isNotEmpty) {
      queryString += '&status=$status';
    }
    if (assignedTo != null && assignedTo.isNotEmpty) {
      queryString += '&assignedToEmp=$assignedTo';
    }
    if (projectId != null && projectId.isNotEmpty) {
      queryString += '&projectId=$projectId&project=$projectId';
    }
    if (propertyId != null && propertyId.isNotEmpty) {
      queryString += '&propertyId=$propertyId&property=$propertyId';
    }
    if (dateFrom != null && dateFrom.isNotEmpty) {
      queryString += '&dateFrom=$dateFrom';
    }
    if (dateTo != null && dateTo.isNotEmpty) {
      queryString += '&dateTo=$dateTo';
    }
    if (sort != null && sort.isNotEmpty) {
      queryString += '&sortBy=$sort';
    }

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/visits/system/list?$queryString');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Bypass-Tunnel-Reminder': 'true',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return VisitsResponse.fromJson(data);
      } else {
        debugPrint('Failed to load visits: ${response.body}');
        throw 'Failed to load visits: ${response.statusCode}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<Map<String, dynamic>> fetchVisitCounts({String? assignedTo}) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    String queryString = '';
    if (assignedTo != null) queryString = 'assignedTo=$assignedTo';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/visits/summary${queryString.isNotEmpty ? "?$queryString" : ""}');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Bypass-Tunnel-Reminder': 'true',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final raw = jsonDecode(response.body);
        final data = raw['data'] ?? raw;
        return {
          'scheduled': data['scheduled'] ?? 0,
          'completed': data['completed'] ?? 0,
          'cancelled': data['cancelled'] ?? 0,
          'upcoming': data['upcoming'] ?? 0,
          'overdue': data['overdue'] ?? 0,
          'total': data['total'] ?? 0,
        };
      } else {
        throw 'Failed to fetch visit counts: ${response.statusCode}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> createVisit(Map<String, dynamic> data) async {
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/visits/create');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Bypass-Tunnel-Reminder': 'true',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(data),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
         final errorData = jsonDecode(response.body);
         throw errorData['message'] ?? 'Failed to create visit';
      }
    } catch (e) {
      throw 'Error creating visit: $e';
    }
  }

  Future<void> updateVisit(String id, Map<String, dynamic> data) async {
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/visits/update/$id');
    try {
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Bypass-Tunnel-Reminder': 'true',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(data),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
         final errorData = jsonDecode(response.body);
         throw errorData['message'] ?? 'Failed to update visit';
      }
    } catch (e) {
      throw 'Error updating visit: $e';
    }
  }

  Future<void> deleteVisit(String id) async {
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/visits/delete/$id');
    try {
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Bypass-Tunnel-Reminder': 'true',
          'Authorization': 'Bearer $accessToken',
        },
      );
      if (response.statusCode != 200 && response.statusCode != 204) {
         final errorData = jsonDecode(response.body);
         throw errorData['message'] ?? 'Failed to delete visit';
      }
    } catch (e) {
      throw 'Error deleting visit: $e';
    }
  }
}
