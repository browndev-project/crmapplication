import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'http_client.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/services/auth_service.dart';
import '../../data/models/dashboard_model.dart';
import 'dart:async';

class DashboardService {
  static const String _boxName = 'dashboardBox';
  static const String _cacheKey = 'dashboardData';
  // Cache duration of 15 minutes to reduce server load as requested
  static const Duration _cacheDuration = Duration(minutes: 15); 

  Future<DashboardData> fetchDashboardData({bool forceRefresh = false, DateTime? startDate, DateTime? endDate, bool isAdmin = false, String? assignedTo}) async {
    final box = await Hive.openBox(_boxName);
    
    // Check Cache (Only if no specific filters, as cache is generic)
    bool isFiltered = startDate != null || endDate != null || assignedTo != null;
    if (!forceRefresh && !isFiltered && box.containsKey(_cacheKey)) {
      try {
        final cachedJson = jsonDecode(box.get(_cacheKey));
        final cachedData = DashboardData.fromJson(cachedJson);
        
        if (cachedData.lastUpdated != null) {
          final difference = DateTime.now().difference(cachedData.lastUpdated!);
          if (difference < _cacheDuration) {
            debugPrint('DashboardService: Returning cached data (Age: ${difference.inMinutes} mins)');
            return cachedData;
          }
        }
      } catch (e) {
        debugPrint('DashboardService: Cache parsing failed, fetching fresh.');
      }
    }

    // Fetch Fresh Data
    debugPrint('DashboardService: Fetching fresh data (Filtered: $isFiltered)...');
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');

    if (accessToken == null) throw 'No access token';

    final headers = {
      'Content-Type': 'application/json',
      'Bypass-Tunnel-Reminder': 'true',
      'Authorization': 'Bearer $accessToken',
    };

    // Construct Query Params
    Map<String, String> queryParams = {};
    if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String().split('T')[0];
    }
    if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String().split('T')[0];
    }
    if (assignedTo != null) {
        queryParams['assignedTo'] = assignedTo;
    }

    LeadAssignmentStats? assignment;
    TodayScheduleStats? schedule;
    LeadSourceStats? sources;
    LeadStatusStats? status;
    PipelineStats? pipelines;
    TodayVisitsStats? visits;
    PersonalCallStats? personalCalls;
    List<TeamMemberCallStats>? teamCalls;

    // Helper to fetch safely
    Future<T?> fetchSafe<T>(String endpoint, T Function(Map<String, dynamic>) parser) async {
       try {
         return await _fetchEndpoint<T>(endpoint, headers, parser, queryParams);
       } catch (e) {
         debugPrint('DashboardService Warning: Failed to fetch $endpoint ($e). proceeding...');
         return null;
       }
    }

    // Helper to fetch list safely
    Future<List<TeamMemberCallStats>?> fetchSafeList(String endpoint) async {
       try {
         var uri = Uri.parse('${AuthService.baseUrl}$endpoint');
         if (queryParams.isNotEmpty) uri = uri.replace(queryParameters: queryParams);
         final response = await http.get(uri, headers: headers);
         if (response.statusCode == 200) {
           final body = jsonDecode(response.body);
           final list = body is List ? body : (body['data'] is List ? body['data'] : []);
           return (list as List).map((e) => TeamMemberCallStats.fromJson(e)).toList();
         }
         return null;
       } catch (e) {
         debugPrint('DashboardService Warning: Failed to fetch $endpoint ($e). proceeding...');
         return null;
       }
    }

    // 1. Lead Assignment (Only for Admin)
    if (isAdmin) {
      assignment = await fetchSafe<LeadAssignmentStats>(
        '/api/v1/dashboard/lead-assignment', 
        (json) => LeadAssignmentStats.fromJson(json)
      );
      if (assignment != null) await Future.delayed(const Duration(milliseconds: 200));
    }

    // 2. Today Schedule
    schedule = await fetchSafe<TodayScheduleStats>(
      '/api/v1/dashboard/today-schedule', 
      (json) => TodayScheduleStats.fromJson(json)
    );
    debugPrint('📍 DashboardService: TodaySchedule: tasksDueToday=${schedule?.tasksDueToday}, meetingsToday=${schedule?.meetingsToday}');
    if (schedule != null) await Future.delayed(const Duration(milliseconds: 200));

    // 3. Lead Sources
    sources = await fetchSafe<LeadSourceStats>(
      '/api/v1/dashboard/lead-sources', 
      (json) => LeadSourceStats.fromJson(json)
    );
    if (sources != null) await Future.delayed(const Duration(milliseconds: 200));

    // 4. Lead Status
    status = await fetchSafe<LeadStatusStats>(
      '/api/v1/dashboard/lead-status', 
      (json) => LeadStatusStats.fromJson(json)
    );
    if (status != null) await Future.delayed(const Duration(milliseconds: 200));

    // 5. Pipelines
    pipelines = await fetchSafe<PipelineStats>(
      '/api/v1/dashboard/pipelines', 
      (json) => PipelineStats.fromJson(json)
    );
    if (pipelines != null) await Future.delayed(const Duration(milliseconds: 200));

    // 6. Today Visits (Using specialized summary endpoint for accuracy)
    visits = await fetchSafe<TodayVisitsStats>(
      '/api/v1/visits/summary/counts',
      (json) {
        if (json.containsKey('data')) json = json['data'];
        final scheduled = json['scheduled'] ?? 0;
        final completed = json['completed'] ?? 0;
        final cancelled = json['cancelled'] ?? 0;
        return TodayVisitsStats(
          totalVisits: scheduled + completed + cancelled,
          scheduled: scheduled,
          completed: completed,
          cancelled: cancelled,
        );
      }
    );
    if (visits != null) await Future.delayed(const Duration(milliseconds: 200));

    // 7. Personal Call Stats
    personalCalls = await fetchSafe<PersonalCallStats>(
      '/api/v1/dashboard/personal-call-stats',
      (json) => PersonalCallStats.fromJson(json)
    );
    if (personalCalls != null) await Future.delayed(const Duration(milliseconds: 200));

    // 8. Team Call Stats
    teamCalls = await fetchSafeList('/api/v1/dashboard/team-call-stats');


    final newData = DashboardData(
      leadAssignment: assignment,
      todaySchedule: schedule,
      leadSources: sources,
      leadStatus: status,
      pipelines: pipelines,
      todayVisits: visits,
      personalCallStats: personalCalls,
      teamCallStats: teamCalls,
      lastUpdated: DateTime.now(),
    );

    // Save to Cache ONLY if not filtered (keep cache for general view)
    if (!isFiltered) {
        await box.put(_cacheKey, jsonEncode(newData.toJson()));
    }
    return newData;
  }

  Future<T> _fetchEndpoint<T>(
    String endpoint, 
    Map<String, String> headers, 
    T Function(Map<String, dynamic>) parser,
    [Map<String, String>? queryParams]
  ) async {
    var uri = Uri.parse('${AuthService.baseUrl}$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
    }

    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      return parser(jsonDecode(response.body));
    } else {
      throw 'Failed to fetch $endpoint: ${response.statusCode}';
    }
  }
}
