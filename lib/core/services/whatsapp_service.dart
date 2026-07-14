import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'http_client.dart' as http;
import 'package:http/http.dart' as raw_http;
import 'package:hive_flutter/hive_flutter.dart';
import 'auth_service.dart';

class WhatsAppService {
  Map<String, String> _buildHeaders() {
    return {
      'Content-Type': 'application/json',
      'Bypass-Tunnel-Reminder': 'true',
    };
  }

  Future<Map<String, dynamic>> _getWithAuth(Uri uri) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final headers = _buildHeaders();
    headers['Authorization'] = 'Bearer $accessToken';

    debugPrint('[WhatsAppService] GET: $uri');
    final response = await http.get(uri, headers: headers);
    debugPrint('[WhatsAppService] Response ${response.statusCode}: ${response.body}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw 'Failed: ${response.statusCode} - ${response.body}';
    }
  }

  Future<Map<String, dynamic>> _postWithAuth(Uri uri, {Map<String, dynamic>? body, String? jsonBody}) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final headers = _buildHeaders();
    headers['Authorization'] = 'Bearer $accessToken';

    debugPrint('[WhatsAppService] POST: $uri');
    debugPrint('[WhatsAppService] Body: ${body ?? jsonBody}');
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonBody ?? (body != null ? jsonEncode(body) : null),
    );
    debugPrint('[WhatsAppService] Response ${response.statusCode}: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errMsg = _extractApiError(response.body);
      throw 'Failed: ${response.statusCode} - $errMsg';
    }
  }

  String _extractApiError(String responseBody) {
    try {
      final parsed = jsonDecode(responseBody);
      if (parsed is Map) {
        final parts = <String>[];
        if (parsed['message'] case final m?) parts.add(m.toString());
        final err = parsed['error'];
        if (err is Map) {
          if (err['code'] case final c?) parts.add('code=$c');
          if (err['error_subcode'] case final sc?) parts.add('subcode=$sc');
          if (err['type'] case final t?) parts.add('type=$t');
          if (err['fbtrace_id'] case final tr?) parts.add('trace=$tr');
          if (err['message'] case final em?) parts.add(em.toString());
          if (err['error_data'] is Map) {
            final ed = err['error_data'] as Map;
            if (ed['details'] case final d?) parts.add('details=$d');
            if (ed['reason'] case final r?) parts.add('reason=$r');
            if (ed['messaging_product'] case final mp?) parts.add('product=$mp');
          }
          if (err['error_user_title'] case final eut?) parts.add(eut.toString());
          if (err['error_user_msg'] case final eum?) parts.add(eum.toString());
        }
        if (parts.isNotEmpty) return parts.join(' | ');
        return responseBody;
      }
    } catch (_) {}
    return responseBody;
  }

  Future<Map<String, dynamic>> _putWithAuth(Uri uri, {Map<String, dynamic>? body, String? jsonBody}) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final headers = _buildHeaders();
    headers['Authorization'] = 'Bearer $accessToken';

    debugPrint('[WhatsAppService] PUT: $uri');
    debugPrint('[WhatsAppService] Body: ${body ?? jsonBody}');
    final response = await http.put(
      uri,
      headers: headers,
      body: jsonBody ?? (body != null ? jsonEncode(body) : null),
    );
    debugPrint('[WhatsAppService] Response ${response.statusCode}: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw 'Failed: ${response.statusCode} - ${response.body}';
    }
  }

  // --- Integration Check ---

  Future<Map<String, dynamic>> checkIntegrationStatus() async {
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/whatsapp/conversations?limit=1');
    return _getWithAuth(uri);
  }

  Future<Map<String, dynamic>> fetchAccountDetails(String companyId) async {
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/whatsapp-auth/account-details/$companyId');
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final response = await raw_http.get(uri, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
      'Bypass-Tunnel-Reminder': 'true',
    });
    debugPrint('[WhatsAppService] AccountDetails Response ${response.statusCode}: ${response.body}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 404) {
      return {'success': false, 'message': 'Integration not found'};
    } else {
      throw 'Failed: ${response.statusCode} - ${response.body}';
    }
  }

  // --- Conversations & Messages ---

  Future<Map<String, dynamic>> fetchConversations() async {
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/whatsapp/conversations');
    return _getWithAuth(uri);
  }

  Future<Map<String, dynamic>> fetchMessages(String conversationId) async {
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/whatsapp/messages/$conversationId');
    return _getWithAuth(uri);
  }

  Future<Map<String, dynamic>> sendMessage(Map<String, dynamic> body) async {
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/whatsapp/send');
    return _postWithAuth(uri, body: body);
  }

  Future<Map<String, dynamic>> sendMediaMessage({
    required String waId,
    required String conversationId,
    required String type,
    required File file,
  }) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/whatsapp/send');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $accessToken';

    request.fields['waId'] = waId;
    request.fields['conversationId'] = conversationId;
    request.fields['type'] = type;

    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw 'Failed to send media message: ${response.body}';
    }
  }


  // --- Templates ---

  Future<Map<String, dynamic>> fetchTemplates() async {
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/whatsapp/templates');
    return _getWithAuth(uri);
  }

  Future<Map<String, dynamic>> createTemplate(Map<String, dynamic> body) async {
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/whatsapp/templates');
    return _postWithAuth(uri, body: body);
  }

  // --- Incoming Leads Automations ---

  Future<Map<String, dynamic>> fetchIncomingLeadsAutomations() async {
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/whatsapp-automations');
    return _getWithAuth(uri);
  }

  Future<Map<String, dynamic>> createIncomingLeadsAutomation(Map<String, dynamic> body) async {
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/whatsapp-automations');
    return _postWithAuth(uri, body: body);
  }

  Future<Map<String, dynamic>> updateIncomingLeadsAutomation(String id, Map<String, dynamic> body) async {
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/whatsapp-automations/$id');
    return _putWithAuth(uri, body: body);
  }

  Future<Map<String, dynamic>> toggleIncomingLeadsAutomation(String id) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/whatsapp-automations/$id/toggle');
    final response = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'Bypass-Tunnel-Reminder': 'true',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw 'Failed: ${response.statusCode} - ${response.body}';
    }
  }

  Future<Map<String, dynamic>> deleteIncomingLeadsAutomation(String id) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/whatsapp-automations/$id');
    final response = await http.delete(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Bypass-Tunnel-Reminder': 'true',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw 'Failed: ${response.statusCode} - ${response.body}';
    }
  }

  // --- Meta & Website Integration Forms (For Overrides) ---

  Future<Map<String, dynamic>> fetchMetaIntegrationStatus(String companyId) async {
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/meta-integration/status/$companyId');
    return _getWithAuth(uri);
  }

  Future<Map<String, dynamic>> fetchMetaPageForms(String pageId) async {
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/meta/pages/$pageId/forms');
    return _getWithAuth(uri);
  }

  Future<Map<String, dynamic>> fetchWebsiteIntegrationForms({int page = 1, int limit = 100, String? search}) async {
    String url = '${AuthService.baseUrl}/api/v1/website-integration/form/?page=$page&limit=$limit';
    if (search != null && search.isNotEmpty) {
      url += '&search=$search';
    }
    final uri = Uri.parse(url);
    return _getWithAuth(uri);
  }

  // --- Event Automations (Status & Visits) ---

  Future<Map<String, dynamic>> fetchEventAutomations() async {
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/event-automations');
    return _getWithAuth(uri);
  }

  Future<Map<String, dynamic>> createEventAutomation(Map<String, dynamic> body) async {
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/event-automations');
    return _postWithAuth(uri, body: body);
  }

  Future<Map<String, dynamic>> updateEventAutomation(String id, Map<String, dynamic> body) async {
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/event-automations/$id');
    return _putWithAuth(uri, body: body);
  }

  Future<Map<String, dynamic>> toggleEventAutomation(String id, bool isActive) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/event-automations/$id/toggle-status');
    final response = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'Bypass-Tunnel-Reminder': 'true',
      },
      body: jsonEncode({'isActive': isActive}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw 'Failed: ${response.statusCode} - ${response.body}';
    }
  }

  Future<Map<String, dynamic>> deleteEventAutomation(String id) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/event-automations/$id');
    final response = await http.delete(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Bypass-Tunnel-Reminder': 'true',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw 'Failed: ${response.statusCode} - ${response.body}';
    }
  }

  // --- Bulk Campaigns (Marketing) ---

  Future<Map<String, dynamic>> fetchCampaigns({int page = 1, int limit = 20}) async {
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/whatsapp/campaigns?page=$page&limit=$limit');
    return _getWithAuth(uri);
  }

  Future<Map<String, dynamic>> fetchCampaignDetails(String id) async {
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/whatsapp/campaigns/$id');
    return _getWithAuth(uri);
  }

  Future<Map<String, dynamic>> fetchCampaignRecipients(
    String id, {
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    String urlStr = '${AuthService.baseUrl}/api/v1/whatsapp/campaigns/$id/recipients?page=$page&limit=$limit';
    if (status != null && status.isNotEmpty) {
      urlStr += '&status=$status';
    }
    final uri = Uri.parse(urlStr);
    return _getWithAuth(uri);
  }

  Future<Map<String, dynamic>> createCampaign(
    Map<String, dynamic> fields, {
    File? file,
    List<String>? leadIds,
  }) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/whatsapp/campaigns');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $accessToken';
    request.headers['Bypass-Tunnel-Reminder'] = 'true';

    // Add standard fields
    fields.forEach((key, value) {
      if (value != null) {
        request.fields[key] = value.toString();
      }
    });

    // Add excel recipient file if source is excel
    if (file != null) {
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
    }

    // Add selected lead list if source is leads
    if (leadIds != null) {
      request.fields['leadIds'] = jsonEncode(leadIds);
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw 'Failed to create campaign: ${response.body}';
    }
  }

  Future<Map<String, dynamic>> triggerCampaignSend(String id) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/whatsapp/campaigns/$id/send');
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Bypass-Tunnel-Reminder': 'true',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw 'Failed to start campaign sending: ${response.body}';
    }
  }

  Future<Map<String, dynamic>> updateCampaignStatus(String id, String status) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/whatsapp/campaigns/$id/status');
    final response = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'Bypass-Tunnel-Reminder': 'true',
      },
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw 'Failed to update campaign status: ${response.body}';
    }
  }

  Future<Map<String, dynamic>> deleteCampaign(String id) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

final uri = Uri.parse('${AuthService.baseUrl}/api/v1/whatsapp/campaigns/$id');
    final response = await http.delete(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Bypass-Tunnel-Reminder': 'true',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw 'Failed to delete campaign: ${response.body}';
    }
  }

  // --- Messaging Limits & Daily Meta Cap ---

  Future<Map<String, dynamic>> fetchMessagingLimit() async {
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/whatsapp/campaigns/settings/messaging-limit');
    return _getWithAuth(uri);
  }

  Future<Map<String, dynamic>> updateMessagingLimit(int limit) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/whatsapp/campaigns/settings/messaging-limit');
    final response = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'Bypass-Tunnel-Reminder': 'true',
      },
      body: jsonEncode({'messagingLimit': limit}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw 'Failed to update messaging limit: ${response.body}';
    }
  }
}
