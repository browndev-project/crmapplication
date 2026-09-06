import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'http_client.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/task_model.dart';
import 'auth_service.dart';

class TaskService {
  static const String _boxName = 'taskBox';
  static const String _cacheKey = 'tasks_data';
  static const Duration _cacheDuration = Duration(minutes: 5);

//   Future<TaskData> fetchTasks({int page = 1, int limit = 20, bool forceRefresh = false, String? status}) async {
//     final box = await Hive.openBox(_boxName);
//     
//     // Return cached data if valid and not forcing refresh (skip cache when status filter is active)
//     if (!forceRefresh && page == 1 && (status == null || status.isEmpty || status == 'All')) {
//        // For simplicity, we cache the first page response. 
//        // Deep pagination caching is complex.
//        if (box.containsKey(_cacheKey)) {
//          final cachedMap = jsonDecode(box.get(_cacheKey));
//          final timestamp = cachedMap['timestamp'];
//          if (timestamp != null && DateTime.now().difference(DateTime.parse(timestamp)) < _cacheDuration) {
//            return TaskData.fromJson(cachedMap['data']);
//          }
//        }
//     }
// 
//     // Fetch from API
//     final authBox = await Hive.openBox('authBox');
//     final accessToken = authBox.get('accessToken');
// 
//     if (accessToken == null) {
//       throw 'No access token found';
//     }
// 
//     final queryParams = {
//       'page': page.toString(),
//       'limit': limit.toString(),
//       if (status != null && status.isNotEmpty && status != 'All') 'status': status,
//     };
//     final url = Uri.parse('${AuthService.baseUrl}/api/v1/tasks/system/list').replace(queryParameters: queryParams);
// 
//     try {
//       final response = await http.get(
//         url,
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $accessToken',
//         },
//       );
// 
//       if (response.statusCode == 200) {
//         final jsonResponse = jsonDecode(response.body);
//         final taskResponse = TaskResponse.fromJson(jsonResponse);
//         
//         if (taskResponse.success && taskResponse.data != null) {
//           // Cache first page (only when no status filter)
//           if (page == 1 && (status == null || status.isEmpty || status == 'All')) {
//              final cacheEntry = {
//                'timestamp': DateTime.now().toIso8601String(),
//                'data': jsonResponse['data']
//              };
//              await box.put(_cacheKey, jsonEncode(cacheEntry));
//           }
//           return taskResponse.data!;
//         } else {
//              throw taskResponse.message;
//         }
//       } else {
//         throw 'Failed to load tasks: ${response.statusCode}';
//       }
//     } catch (e) {
//       throw 'Error fetching tasks: $e';
//     }
//   }

  Future<TaskData> fetchTasks({
    int page = 1,
    // int limit = 20,
    int limit = 10,
    bool forceRefresh = false,
    String? category,
    String? quickDate,
    String? dateField,
    String? fromDue,
    String? toDue,
    String? assignedTo,
    String? searchQuery,
    String? sortBy,
    String? status,
  }) async {
    final box = await Hive.openBox(_boxName);
    // final isDefaultQuery = (category == null || category == 'all' || category == 'overdue') &&
    //     (quickDate == null || quickDate == 'all' || quickDate == 'overdue') &&
    //     (searchQuery == null || searchQuery.isEmpty) &&
    //     (fromDue == null || fromDue.isEmpty) &&
    //     (toDue == null || toDue.isEmpty) &&
    //     (assignedTo == null || assignedTo.isEmpty);
    //
    // // Return cached data if valid and not forcing refresh
    // if (!forceRefresh && page == 1 && isDefaultQuery) {
    //   if (box.containsKey(_cacheKey)) {
    //     try {
    //       final cachedMap = jsonDecode(box.get(_cacheKey));
    //       final timestamp = cachedMap['timestamp'];
    //       if (timestamp != null && DateTime.now().difference(DateTime.parse(timestamp)) < _cacheDuration) {
    //         return TaskData.fromJson(cachedMap['data']);
    //       }
    //     } catch (_) {}
    //   }
    // }

    // final isDefaultQuery = limit >= 20 &&
    //     (quickDate == null || quickDate == 'all') &&
    //     (searchQuery == null || searchQuery.isEmpty) &&
    //     (fromDue == null || fromDue.isEmpty) &&
    //     (toDue == null || toDue.isEmpty) &&
    //     (assignedTo == null || assignedTo.isEmpty);

    final isDefaultSort = sortBy == null ||
        sortBy.isEmpty ||
        (category == 'completed' ? sortBy == 'updatedAt_desc' : sortBy == 'dueDate_asc');
    final isDefaultQuickDate = quickDate == null ||
        quickDate == 'all' ||
        (category == 'overdue' && quickDate == 'overdue');

    final isDefaultQuery = limit >= 20 &&
        isDefaultSort &&
        isDefaultQuickDate &&
        (searchQuery == null || searchQuery.isEmpty) &&
        (fromDue == null || fromDue.isEmpty) &&
        (toDue == null || toDue.isEmpty) &&
        (assignedTo == null || assignedTo.isEmpty);

    final categoryCacheKey = '${_cacheKey}_${category ?? 'all'}';

    // Return cached data if valid and not forcing refresh
    if (!forceRefresh && page == 1 && isDefaultQuery) {
      if (box.containsKey(categoryCacheKey)) {
        try {
          final cachedMap = jsonDecode(box.get(categoryCacheKey));
          final timestamp = cachedMap['timestamp'];
          if (timestamp != null && DateTime.now().difference(DateTime.parse(timestamp)) < _cacheDuration) {
            return TaskData.fromJson(cachedMap['data']);
          }
        } catch (_) {}
      }
    }

    // Fetch from API
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');

    if (accessToken == null) {
      throw 'No access token found';
    }

    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (category != null && category.isNotEmpty) 'category': category,
      // if (quickDate != null && quickDate.isNotEmpty) 'quickDate': quickDate,
      if (quickDate != null && quickDate.isNotEmpty && quickDate.toLowerCase() != 'all') 'quickDate': quickDate,
      if (dateField != null && dateField.isNotEmpty) 'dateField': dateField,
      if (fromDue != null && fromDue.isNotEmpty) 'fromDue': fromDue,
      if (toDue != null && toDue.isNotEmpty) 'toDue': toDue,
      if (assignedTo != null && assignedTo.isNotEmpty) 'assignedTo': assignedTo,
      if (searchQuery != null && searchQuery.isNotEmpty) 'searchQuery': searchQuery,
      if (sortBy != null && sortBy.isNotEmpty) 'sortBy': sortBy,
      // if (status != null && status.isNotEmpty && status != 'All') 'status': status,
      if (status != null && status.isNotEmpty && status.toLowerCase() != 'all') 'status': status,
    };

    // Primary endpoint is /api/v1/tasks/app/list, with fallback to /api/v1/tasks/system/list
    final appUrl = Uri.parse('${AuthService.baseUrl}/api/v1/tasks/app/list').replace(queryParameters: queryParams);

    try {
      var response = await http.get(
        appUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'Bypass-Tunnel-Reminder': 'true',
        },
      );

      // Fallback to /api/v1/tasks/system/list if /app/list is not found (404)
      if (response.statusCode == 404) {
        final fallbackUrl = Uri.parse('${AuthService.baseUrl}/api/v1/tasks/system/list').replace(queryParameters: queryParams);
        response = await http.get(
          fallbackUrl,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
            'Bypass-Tunnel-Reminder': 'true',
          },
        );
      }

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final taskResponse = TaskResponse.fromJson(jsonResponse);
        
        if (taskResponse.success && taskResponse.data != null) {
          // Cache default first page
          if (page == 1 && isDefaultQuery) {
            final cacheEntry = {
              'timestamp': DateTime.now().toIso8601String(),
              'data': jsonResponse['data']
            };
            // await box.put(_cacheKey, jsonEncode(cacheEntry));
            await box.put(categoryCacheKey, jsonEncode(cacheEntry));
          }
          return taskResponse.data!;
        } else {
          throw taskResponse.message.isNotEmpty ? taskResponse.message : 'Failed to fetch tasks';
        }
      } else {
        throw 'Failed to load tasks: ${response.statusCode}';
      }
    } catch (e) {
      throw 'Error fetching tasks: $e';
    }
  }

  Future<void> createTask(Map<String, dynamic> data) async {
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/tasks/create');
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
         throw errorData['message'] ?? 'Failed to create task';
      }
    } catch (e) {
      throw 'Error creating task: $e';
    }
  }

  Future<void> updateTask(String id, Map<String, dynamic> data) async {
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/tasks/update/$id');
    try {
      debugPrint('🚀 Updating Task: $url');
      debugPrint('📦 Payload: $data');
      
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(data),
      );
      
      debugPrint('📩 Update Follow Up Response [${response.statusCode}]: ${response.body}');

      if (response.statusCode != 200) {
         final errorData = jsonDecode(response.body);
         throw errorData['message'] ?? 'Failed to update Follow Up';
      }
    } catch (e) {
      throw 'Error updating Follow Up: $e';
    }
  }

  Future<void> deleteTask(String id) async {
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/tasks/delete/$id');
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
         throw errorData['message'] ?? 'Failed to delete task';
      }
    } catch (e) {
      throw 'Error deleting task: $e';
    }
  }
}
