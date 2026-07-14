import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'http_client.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/auth_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/email_log_model.dart';
import '../../data/models/service_report_model.dart';
import '../../data/models/todays_report_model.dart';
import '../../data/models/performance_report_model.dart';
import '../../data/models/download_log_model.dart';
import '../../data/models/overall_report_model.dart';

// ... existing imports ...

// ... existing class content ...



final reportServiceProvider = Provider((ref) => ReportService());

class ReportService {
  
  Future<OverallReportModel> fetchOverallReport(String employeeId) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');
    
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/reports/overall/employee/$employeeId');

    debugPrint('ReportService: Fetching Overall Report: $uri');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('ReportService: Overall Report Response Status: ${response.statusCode}');
      debugPrint('ReportService: Overall Report Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return OverallReportModel.fromJson(data);
      } else {
        throw 'Failed to fetch overall report: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('ReportService Overall Report Error: $e');
      throw e.toString();
    }
  }

  Future<TodaysReportV2Model> fetchTodaysReport({
    String? systemRole,
    String? from,
    String? to,
  }) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');

    final params = <String, String>{};
    if (systemRole != null && systemRole.isNotEmpty) params['systemRole'] = systemRole;
    if (from != null && from.isNotEmpty) params['from'] = from;
    if (to != null && to.isNotEmpty) params['to'] = to;

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/reports/today-v2')
        .replace(queryParameters: params);

    debugPrint('ReportService: Fetching Today Report V2: $uri');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('ReportService: Response Status: ${response.statusCode}');
      debugPrint('ReportService: Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return TodaysReportV2Model.fromJson(data);
      } else {
        throw 'Failed to parse response: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('ReportService Error: $e');
      throw e.toString();
    }
  }

  Future<GroupedCallsResponse> fetchEmployeeGroupedCalls(String employeeId, {String? from, String? to, int page = 1, int limit = 10}) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');

    final params = <String, String>{
      'employeeId': employeeId,
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (from != null && from.isNotEmpty) params['from'] = from;
    if (to != null && to.isNotEmpty) params['to'] = to;

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/reports/today-v2/employee-calls')
        .replace(queryParameters: params);

    debugPrint('ReportService: Fetching Grouped Calls: $uri');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return GroupedCallsResponse.fromJson(data);
      } else {
        throw 'Failed to fetch grouped calls: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('ReportService Grouped Calls Error: $e');
      throw e.toString();
    }
  }

  Future<List<DetailedCall>> fetchCallGroupDetails(String employeeId, String phone, {String? from, String? to}) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');

    final params = <String, String>{
      'employeeId': employeeId,
      'phone': phone,
    };
    if (from != null && from.isNotEmpty) params['from'] = from;
    if (to != null && to.isNotEmpty) params['to'] = to;

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/reports/today-v2/group-details')
        .replace(queryParameters: params);

    debugPrint('ReportService: Fetching Call Group Details: $uri');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['calls'] != null) {
          final list = data['calls'] as List;
          return list.map((e) => DetailedCall.fromJson(e)).toList();
        } else {
          return [];
        }
      } else {
        throw 'Failed to fetch call group details: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('ReportService Group Details Error: $e');
      throw e.toString();
    }
  }

  Future<List<PerformanceReportModel>> fetchPerformanceReport(String role, DateTime from, DateTime to) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');
    
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/reports/performance').replace(queryParameters: {
      'systemRole': role,
      'from': from.toIso8601String().split('T')[0], // YYYY-MM-DD
      'to': to.toIso8601String().split('T')[0],
    });

    debugPrint('ReportService: Fetching Performance Report: $uri');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('ReportService: Performance Response Status: ${response.statusCode}');
      debugPrint('ReportService: Performance Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null) {
           final list = data['data'] as List;
           return list.map((e) => PerformanceReportModel.fromJson(e)).toList();
        } else {
           return []; 
        }
      } else {
        throw 'Failed to fetch performance report: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('ReportService Performance Error: $e');
      throw e.toString();
    }
  }

  Future<List<DownloadLogModel>> fetchDownloadLogs({int page = 1, int limit = 20, String? module, String? format, String? status, String? user}) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');

    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (module != null && module.isNotEmpty && module != 'All') params['module'] = module;
    if (format != null && format.isNotEmpty && format != 'All') params['format'] = format;
    if (status != null && status.isNotEmpty && status != 'All') params['status'] = status;
    if (user != null && user.isNotEmpty) params['user'] = user;

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/reports/download-logs').replace(queryParameters: params);

    debugPrint('ReportService: Fetching Download Logs: $uri');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('ReportService: Download Logs Response Status: ${response.statusCode}');
      debugPrint('ReportService: Download Logs Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null && data['data']['logs'] != null) {
           final logs = data['data']['logs'] as List; 
           return logs.map((e) => DownloadLogModel.fromJson(e)).toList();
        } else {
           return []; 
        }
      } else {
        throw 'Failed to fetch logs: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('ReportService Download Logs Error: $e');
      throw e.toString();
    }
  }

  Future<List<EmailLogModel>> fetchEmailLogs({int page = 1, int limit = 20, String? searchQuery, String? provider, String? type, String? user}) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');
    
    final Map<String, String> params = {
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (searchQuery != null && searchQuery.isNotEmpty) params['searchQuery'] = searchQuery;
    if (provider != null && provider != 'All') params['provider'] = provider;
    if (type != null && type != 'All') params['type'] = type;
    if (user != null && user.isNotEmpty) params['user'] = user;

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/reports/email-logs').replace(queryParameters: params);

    debugPrint('ReportService: Fetching Email Logs: $uri');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('ReportService: Email Logs Response Status: ${response.statusCode}');
      debugPrint('ReportService: Email Logs Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Structure: data -> { logs: [...] }
        if (data['data'] != null && data['data']['logs'] != null) {
           final logs = data['data']['logs'] as List; 
           return logs.map((e) => EmailLogModel.fromJson(e)).toList();
        } else {
           return []; 
        }
      } else {
        throw 'Failed to fetch email logs: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('ReportService Email Logs Error: $e');
      throw e.toString();
    }
  }

  Future<ServiceReportModel> fetchServicesReport(DateTime from, DateTime to) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');
    
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/reports/services').replace(queryParameters: {
      'from': from.toIso8601String().split('T')[0],
      'to': to.toIso8601String().split('T')[0],
    });

    debugPrint('ReportService: Fetching Services Report: $uri');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('ReportService: Services Report Response Status: ${response.statusCode}');
      debugPrint('ReportService: Services Report Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ServiceReportModel.fromJson(data);
      } else {
        throw 'Failed to fetch services report: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('ReportService Services Report Error: $e');
      throw e.toString();
    }
  }


}
