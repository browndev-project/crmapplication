import 'dart:convert';
import 'http_client.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/calendar_event_model.dart';
import 'auth_service.dart';

class CalendarService {
  Future<List<CalendarEvent>> fetchEvents(DateTime start, DateTime end) async {
    final box = Hive.box('authBox');
    final token = box.get('accessToken');

    if (token == null) {
      throw Exception('No access token found');
    }

    final queryParams = {
      'start': start.toUtc().toIso8601String(),
      'end': end.toUtc().toIso8601String(),
    };

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/calendar-events/system/list').replace(queryParameters: queryParams);

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null && data['data']['events'] != null) {
          final List<dynamic> eventsJson = data['data']['events'];
          return eventsJson.map((e) => CalendarEvent.fromJson(e)).toList();
        }
        return [];
      } else {
        final data = jsonDecode(response.body);
        throw data['message'] ?? 'Failed to fetch calendar events';
      }
    } catch (e) {
      throw e.toString();
    }
  }
}
