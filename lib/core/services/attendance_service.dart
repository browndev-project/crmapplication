import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'http_client.dart' as http;
import '../../data/models/attendance_model.dart';
import 'auth_service.dart';

class AttendanceService {

  Future<CompanyAttendanceResponse?> getCompanyAttendanceCurrent() async {
    debugPrint('🔥 AttendanceService: getCompanyAttendanceCurrent CALLED');

    try {
      final box = await Hive.openBox('authBox');
      final accessToken = box.get('accessToken');

      debugPrint(
          '🔑 AttendanceService: Access Token exists: ${accessToken != null}');

      if (accessToken == null) {
        debugPrint('❌ Attendance: No Access Token');
        return CompanyAttendanceResponse(success: false, message: "No Access Token found in Hive");
      }

      final url = Uri.parse('${AuthService.baseUrl}/api/v1/attendance/getCompanyAttendanceCurrent');
      debugPrint('🔗 AttendanceService: URL -> $url');
      debugPrint('🔑 Token (First 10 chars): ${accessToken.substring(0, 10)}...');

      try {
        debugPrint('🔍 Fetching Attendance: $url');
        final response = await http.get(url, headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        }).timeout(const Duration(seconds: 15));

        debugPrint('📩 Attendance Response [${response.statusCode}]: ${response.body}');

        if (response.statusCode == 200) {
          final Map<String, dynamic> json = jsonDecode(response.body);
          debugPrint('🔍 Parsing JSON: records=${json['data']?['records']?.length}, total=${json['data']?['total']}');
          final parsed = CompanyAttendanceResponse.fromJson(json);
          debugPrint('✅ Parsed Records Count: ${parsed.data?.records.length}');
          return parsed;
        } else {
           return CompanyAttendanceResponse(success: false, message: "Server Error: ${response.statusCode}\nBody: ${response.body}");
        }
      } catch (e) {
        debugPrint('❌ Error fetching attendance: $e');
        return CompanyAttendanceResponse(success: false, message: "Network Error: $e");
      }
    } catch (e) {
      debugPrint('❌ Error in AttendanceService outer block: $e');
      return CompanyAttendanceResponse(success: false, message: "Service Exception: $e");
    }
  }

  // Executive Controls
  Future<Map<String, dynamic>?> startAttendance() async {
    final result = await _postRequest('/api/v1/attendance/start', {"deviceType": "app"});
    
    // Fallback if already started
    if (result != null && result['success'] == false) {
       final bodyStr = result['body'] as String?;
       if (bodyStr != null && bodyStr.contains('Attendance already started')) {
          debugPrint('⚠️ Attendance already started. Fetching current status...');
          final statusResult = await _fetchTodayStatus();
          
          // Check if today's attendance is already finished (inactive)
          if (statusResult != null && statusResult['success'] == true) {
             final record = statusResult['data']?['record'];
             if (record != null && record['status'] == 'inactive') {
                return {
                  "success": false,
                  "message": "Today's attendance is over."
                };
             }
          }
          return statusResult;
       }
    }
    return result;
  }

  Future<Map<String, dynamic>?> _fetchTodayStatus() async {
    try {
      final box = await Hive.openBox('authBox');
      final accessToken = box.get('accessToken');

      if (accessToken == null) return {"success": false, "message": "No Access Token"};

      final url = Uri.parse('${AuthService.baseUrl}/api/v1/attendance/today');
      debugPrint('🔄 Fetching Today Status: $url');
      
      final response = await http.get(url, 
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        }
      ).timeout(const Duration(seconds: 15));

      debugPrint('📥 Today Status Response [${response.statusCode}]: ${response.body}');

      if (response.statusCode == 200) {
         return jsonDecode(response.body);
      } else {
         return {"success": false, "message": "Failed to sync status: ${response.statusCode}"};
      }
    } catch (e) {
      debugPrint('❌ Fetch Today Error: $e');
      return {"success": false, "message": "Error syncing status: $e"};
    }
  }

  Future<Map<String, dynamic>?> endAttendance() async {
    return _postRequest('/api/v1/attendance/end', {});
  }

  Future<Map<String, dynamic>?> startBreak(String reason) async {
    return _postRequest('/api/v1/attendance/break/start', {"reasonKey": reason});
  }

  Future<Map<String, dynamic>?> endBreak() async {
    return _postRequest('/api/v1/attendance/break/end', {});
  }

  Future<Map<String, dynamic>?> _postRequest(String endpoint, Map<String, dynamic> body) async {
    try {
      final box = await Hive.openBox('authBox');
      final accessToken = box.get('accessToken');

      if (accessToken == null) return {"success": false, "message": "No Access Token"};

      final url = Uri.parse('${AuthService.baseUrl}$endpoint');
      debugPrint('🚀 Attendance Action: $endpoint');
      
      final response = await http.post(url, 
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(body)
      ).timeout(const Duration(seconds: 15));

      debugPrint('📥 Response [${response.statusCode}]: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
         return jsonDecode(response.body);
      } else {
         return {"success": false, "message": "Error: ${response.statusCode}", "body": response.body};
      }
    } catch (e) {
      debugPrint('❌ Attendance Action Error: $e');
      return {"success": false, "message": "Network Error: $e"};
    }
  }

  // History API
  Future<AttendanceHistoryResponse> getAttendanceRecords({
    required String userId,
    int page = 1,
    int limit = 10,
    String? fromDate,
    String? toDate,
  }) async {
    try {
      final box = await Hive.openBox('authBox');
      final accessToken = box.get('accessToken');

      if (accessToken == null) {
        return AttendanceHistoryResponse(statusCode: 401, message: "No Access Token", success: false);
      }

      final queryParams = {
        'userId': userId,
        'page': page.toString(),
        'limit': limit.toString(),
        if (fromDate != null && fromDate.isNotEmpty) 'fromDate': fromDate,
        if (toDate != null && toDate.isNotEmpty) 'toDate': toDate,
      };

      final uri = Uri.parse('${AuthService.baseUrl}/api/v1/attendance/getAttendanceRecords')
          .replace(queryParameters: queryParams);

      debugPrint('🔗 Fetching History: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      debugPrint('📩 History Response [${response.statusCode}]: ${response.body}');

      if (response.statusCode == 200) {
        return AttendanceHistoryResponse.fromJson(jsonDecode(response.body));
      } else {
        return AttendanceHistoryResponse(
            statusCode: response.statusCode,
            message: "Server Error: ${response.statusCode}",
            success: false);
      }
    } catch (e) {
      debugPrint('❌ Error fetching history: $e');
      return AttendanceHistoryResponse(statusCode: 500, message: "Error: $e", success: false);
    }
  }
}
