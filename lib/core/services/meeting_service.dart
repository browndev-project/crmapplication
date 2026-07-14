import 'dart:convert';
import 'http_client.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/services/auth_service.dart';
import '../../data/models/meeting_model.dart';
import 'package:flutter/foundation.dart';

class MeetingService {
  Future<MeetingsResponse> fetchMeetings({
    int page = 1,
    int limit = 10,
    String? search,
    String? status,
    String? leadId,
    String? assignedTo,
  }) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');

    if (accessToken == null) {
      throw 'No access token found';
    }

final url = Uri.parse('${AuthService.baseUrl}/api/v1/meetings/system/list')
        .replace(
          queryParameters: {
            'page': page.toString(),
            'limit': limit.toString(),
            if (search != null && search.trim().isNotEmpty)
              'searchQuery': search.trim(),
            if (status != null && status != 'All' && status.isNotEmpty)
              'status': status,
            if (leadId != null && leadId.isNotEmpty) 'lead': leadId,
            if (assignedTo != null && assignedTo.isNotEmpty)
              'assignedToEmp': assignedTo,
          },
        );

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return MeetingsResponse.fromJson(data);
      } else {
        debugPrint('Failed to load meetings: ${response.body}');
        throw 'Failed to load meetings: ${response.statusCode}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> createMeeting(Map<String, dynamic> data) async {
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/meetings/create');
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
        throw errorData['message'] ?? 'Failed to create meeting';
      }
    } catch (e) {
      throw 'Error creating meeting: $e';
    }
  }

  Future<void> updateMeeting(String id, Map<String, dynamic> data) async {
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/meetings/update/$id');
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
        throw errorData['message'] ?? 'Failed to update meeting';
      }
    } catch (e) {
      throw 'Error updating meeting: $e';
    }
  }

  Future<void> deleteMeeting(String id) async {
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/meetings/delete/$id');
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
        throw errorData['message'] ?? 'Failed to delete meeting';
      }
    } catch (e) {
      throw 'Error deleting meeting: $e';
    }
  }

  Future<Meeting> getMeeting(String id) async {
    final authBox = await Hive.openBox('authBox');
    final accessToken = authBox.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/meetings/$id');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('GET_MEETING raw response keys: ${data.keys}');
        final rawData = data['data'] ?? data;
        debugPrint('GET_MEETING rawData has sendMail: ${rawData['sendMail']} whatsappAutomation: ${rawData['whatsappAutomation']}');
        final meetingData = rawData['meeting'] ?? rawData;
        debugPrint('GET_MEETING meetingData has sendMail: ${meetingData['sendMail']} whatsappAutomation: ${meetingData['whatsappAutomation']}');
        final meeting = Meeting.fromJson(meetingData);
        debugPrint('GET_MEETING parsed: sendMail=${meeting.sendMail} whatsappAutomation=${meeting.whatsappAutomation}');
        return meeting;
      } else {
        final errorData = jsonDecode(response.body);
        throw errorData['message'] ?? 'Failed to fetch meeting';
      }
    } catch (e) {
      throw 'Error fetching meeting: $e';
    }
  }
}
