import 'dart:convert';
import 'http_client.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/company_model.dart';
import 'auth_service.dart';

class CompanyService {
  Future<Company> fetchCompanyDetails() async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    final String? userJson = box.get('user_data');
    
    // We need companyID. The user object has 'company' field which is expected to be the ID.
    String? companyId;
    if (userJson != null) {
      final userMap = jsonDecode(userJson);
      if (userMap['company'] is String) {
          // If 'company' field in user is just the raw ID string
          companyId = userMap['company']; 
      } else if (userMap['company'] is Map && userMap['company']['_id'] != null) {
          // If 'company' field is populated object
          companyId = userMap['company']['_id'];
      }
    }

    if (accessToken == null) {
      throw 'No access token found';
    }
    
    // Fallback if companyId isn't in user object (shouldn't happen for valid users)
    if (companyId == null || companyId.isEmpty) {
        throw 'Company ID not found for current user';
    }

    // Using the endpoint provided by user logic: .../getCompanyDetails/:id
    final url = Uri.parse('${AuthService.baseUrl}/api/v1/company/getCompanyDetails/$companyId');

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
             final data = jsonResponse['data'];
             final companyMap = data['company'];
             final counts = data['counts'] ?? {};
             
             return Company.fromJson(companyMap, counts);
        } else {
             throw jsonResponse['message'] ?? 'Failed to fetch company details';
        }
      } else {
        throw 'Failed to load company details: ${response.statusCode}';
      }
    } catch (e) {
      throw 'Error fetching company details: $e';
    }
  }
}
