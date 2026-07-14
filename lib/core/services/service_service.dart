import 'dart:convert';
import 'http_client.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/service_model.dart';
import 'auth_service.dart';

class ServiceService {
  Future<ServiceData> fetchServices({int page = 1, int limit = 20, bool forceRefresh = false}) async {
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');

    if (accessToken == null) {
      throw 'No access token found';
    }

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/services/company/list?page=$page&limit=$limit');

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
        final serviceResponse = ServiceResponse.fromJson(jsonResponse);
        
        if (serviceResponse.success && serviceResponse.data != null) {
          return serviceResponse.data!;
        } else {
             throw serviceResponse.message;
        }
      } else {
        throw 'Failed to load services: ${response.statusCode}';
      }
    } catch (e) {
      throw 'Error fetching services: $e';
    }
  }

  Future<void> createService(Map<String, dynamic> data) async {
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');
    
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/services/create');

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
          throw errorData['message'] ?? 'Failed to create service';
      }
    } catch (e) {
      throw 'Error creating service: $e';
    }
  }

  Future<void> updateService(String id, Map<String, dynamic> data) async {
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');
    
    if (accessToken == null) throw 'No access token found';

    // The API endpoint seems to be .../update/:id based on standard REST or the user hint.
    // User request screenshot showed: PATCH http://localhost:8000/api/v1/services/update/68fa...
    final url = Uri.parse('${AuthService.baseUrl}/api/v1/services/update/$id');

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
          throw errorData['message'] ?? 'Failed to update service';
      }
    } catch (e) {
      throw 'Error updating service: $e';
    }
  }

  Future<void> deleteService(String id) async {
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');
    
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/services/delete/$id');

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
          throw errorData['message'] ?? 'Failed to delete service';
      }
    } catch (e) {
      throw 'Error deleting service: $e';
    }
  }
}
