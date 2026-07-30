import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'http_client.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'auth_service.dart';
import '../../data/models/task_model.dart';
import '../../data/models/meeting_model.dart';
import '../../data/models/visit_model.dart';

class AdminDashboardService {
  Future<Map<String, String>> _getHeaders() async {
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');
    if (accessToken == null) throw 'No access token found';
    return {
      'Content-Type': 'application/json',
      'Bypass-Tunnel-Reminder': 'true',
      'Authorization': 'Bearer $accessToken',
    };
  }

  // A. Total & Lost Leads Counts
  Future<Map<String, int>> fetchTotalLeads() async {
    final headers = await _getHeaders();
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/dashboard/total-leads');
    try {
      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? {};
        return {
          'totalLeads': data['totalLeads'] ?? 0,
          'lostLeads': data['lostLeads'] ?? 0,
        };
      }
      return {'totalLeads': 0, 'lostLeads': 0};
    } catch (e) {
      debugPrint('AdminDashboardService Error fetchTotalLeads: $e');
      return {'totalLeads': 0, 'lostLeads': 0};
    }
  }

  // B. Unassigned Leads Count
  Future<int> fetchUnassignedCount() async {
    final headers = await _getHeaders();
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/dashboard/lead-assignment');
    try {
      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? {};
        return data['unassigned'] ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('AdminDashboardService Error fetchUnassignedCount: $e');
      return 0;
    }
  }

  // C. Converted Leads Count
  Future<int> fetchConvertedCount() async {
    final headers = await _getHeaders();
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/dashboard/convertedLeads');
    try {
      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? {};
        return data['convertedLeads'] ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('AdminDashboardService Error fetchConvertedCount: $e');
      return 0;
    }
  }

  // D. Attention Indicators Count
  Future<Map<String, int>> fetchAttentionCount() async {
    final headers = await _getHeaders();
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/dashboard/attention-count');
    try {
      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] ?? {};
        return {
          'overdueTasksCount': data['overdueTasksCount'] ?? 0,
          'pendingMeetingsCount': data['pendingMeetingsCount'] ?? 0,
          'pendingVisitsCount': data['pendingVisitsCount'] ?? 0,
        };
      }
      return {'overdueTasksCount': 0, 'pendingMeetingsCount': 0, 'pendingVisitsCount': 0};
    } catch (e) {
      debugPrint('AdminDashboardService Error fetchAttentionCount: $e');
      return {'overdueTasksCount': 0, 'pendingMeetingsCount': 0, 'pendingVisitsCount': 0};
    }
  }

  // E. Overdue Tasks List
  Future<List<Task>> fetchOverdueTasks() async {
    final headers = await _getHeaders();
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/tasks/overdue');
    try {
      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = body['data']?['tasks'] ?? [];
        return (list as List).map((json) => Task.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('AdminDashboardService Error fetchOverdueTasks: $e');
      return [];
    }
  }

  // F. Overdue Meetings List
  Future<List<Meeting>> fetchOverdueMeetings() async {
    final headers = await _getHeaders();
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/meetings/overdue');
    try {
      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = body['data']?['meetings'] ?? [];
        return (list as List).map((json) => Meeting.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('AdminDashboardService Error fetchOverdueMeetings: $e');
      return [];
    }
  }

  // G. Overdue Visits List
  Future<List<Visit>> fetchOverdueVisits() async {
    final headers = await _getHeaders();
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/visits/overdue');
    try {
      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = body['data']?['visits'] ?? [];
        return (list as List).map((json) => Visit.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('AdminDashboardService Error fetchOverdueVisits: $e');
      return [];
    }
  }

  // H. Employee Lead Metrics (Performance)
  Future<List<Map<String, dynamic>>> fetchEmployeeLeadMetrics({required String startDate, required String endDate}) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/dashboard/employee-lead-metrics')
        .replace(queryParameters: {
          'startDate': startDate,
          'endDate': endDate,
        });
    try {
      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = body['data'] ?? [];
        return List<Map<String, dynamic>>.from(list);
      }
      return [];
    } catch (e) {
      debugPrint('AdminDashboardService Error fetchEmployeeLeadMetrics: $e');
      return [];
    }
  }

  // I. Employee Call Analytics (Metrics)
  Future<List<Map<String, dynamic>>> fetchEmployeeCallMetrics({required String startDate, required String endDate}) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/dashboard/employee-call-metrics')
        .replace(queryParameters: {
          'startDate': startDate,
          'endDate': endDate,
        });
    try {
      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = body['data'] ?? [];
        return List<Map<String, dynamic>>.from(list);
      }
      return [];
    } catch (e) {
      debugPrint('AdminDashboardService Error fetchEmployeeCallMetrics: $e');
      return [];
    }
  }

  // J. Leads Timeline & Sources
  Future<Map<String, dynamic>> fetchLeadSourceTimeline({required String startDate, required String endDate}) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/dashboard/lead-source-timeline')
        .replace(queryParameters: {
          'startDate': startDate,
          'endDate': endDate,
        });
    try {
      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'] ?? {'timeline': [], 'activeSources': []};
      }
      return {'timeline': [], 'activeSources': []};
    } catch (e) {
      debugPrint('AdminDashboardService Error fetchLeadSourceTimeline: $e');
      return {'timeline': [], 'activeSources': []};
    }
  }
}
