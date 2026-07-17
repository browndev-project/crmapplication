import 'dart:convert';
import 'http_client.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/services/auth_service.dart';
import '../../data/models/lead_model.dart'; 
import '../../data/models/call_log_model.dart'; 
import '../../data/models/status_model.dart'; 

class LeadService {
  Future<LeadsResponse> fetchLeads({
    int page = 1, 
    int limit = 10,
    String? search,
    String? service,
    String? status,
    String? source,
    String? pipeline,
    String? assignedTo,
    String? team,
    String? group,
    String? project,
    String? sort,
    String? startDate,
    String? endDate,
    bool? duplicate,
    String? gender,
    bool? onlySubAssigned,
    bool? isLost,
  }) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');

    if (accessToken == null) {
      throw 'No access token found';
    }

    // Build Query Params
    final Map<String, dynamic> queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
        if (search != null && search.isNotEmpty) 'keyword': search, // redundancy for backend compatibility
        if (search != null && search.isNotEmpty) 'searchQuery': search, // exact match with final docs

        if (service != null && service.isNotEmpty) 'service': service,
        if (status != null && status.isNotEmpty) 'status': status,
        if (project != null && project.isNotEmpty) 'project': project,
        if (source != null && source.isNotEmpty) 'source': source,
        if (pipeline != null && pipeline.isNotEmpty) 'pipeline': pipeline,
        if (assignedTo != null && assignedTo.isNotEmpty) 'assignedToEmp': assignedTo,
        if (team != null && team.isNotEmpty) 'team': team,
        if (group != null && group.isNotEmpty) 'group': group,
        if (sort != null && sort.isNotEmpty) 'sort': sort,
        if (startDate != null && startDate.isNotEmpty) 'from': startDate,
        if (endDate != null && endDate.isNotEmpty) 'to': endDate,
        if (duplicate == true) 'showDuplicates': 'true',
        if (gender != null && gender.isNotEmpty) 'gender': gender,
        if (onlySubAssigned == true) 'onlySubAssigned': 'true',
        if (isLost == true) 'isLost': 'true',
    };

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/leads/system/list').replace(queryParameters: queryParams);
    
    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );
      
      debugPrint('🚀 Fetch Leads URI: $uri');
      debugPrint('🔍 Search Param: $search');


      debugPrint('--- Lead API Response ---');
      debugPrint('Status Code: ${response.statusCode}');
      final bodyStr = response.body;
      for (int i = 0; i < bodyStr.length; i += 1000) {
        final end = (i + 1000 < bodyStr.length) ? i + 1000 : bodyStr.length;
        debugPrint(bodyStr.substring(i, end));
      }
      debugPrint('-------------------------');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return LeadsResponse.fromJson(data);
      } else {
        throw 'Failed to load leads: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<Lead> fetchLeadDetails(String id) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');

    if (accessToken == null) {
      throw 'No access token found';
    }
  
    final url = Uri.parse('${AuthService.baseUrl}/api/v1/leads/$id/details');

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
        if (jsonResponse['data'] != null && jsonResponse['data']['lead'] != null) {
            final leadData = jsonResponse['data']['lead'];
            return Lead.fromJson(leadData);
        } else {
             throw 'Invalid API response format';
        }
      } else {
         throw 'Failed to load lead details: ${response.statusCode}';
      }
    } catch (e) {
      throw e.toString();
    }
  }
  Future<bool> createManualLead(Map<String, dynamic> leadData) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');

    if (accessToken == null) {
      throw 'No access token found';
    }

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/leads/create/manual');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(leadData),
      );

      if (response.statusCode == 201) {
        return true;
      } else {
        throw 'Failed to create lead: ${response.body}';
      }
    } catch (e) {
      throw e.toString();
    }
  }
  Future<bool> updateLead(String id, Map<String, dynamic> leadData) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');

    if (accessToken == null) {
      throw 'No access token found';
    }

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/leads/update/$id');

    try {
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(leadData),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw 'Failed to update lead: ${response.body}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<bool> updateStatus(
    String id,
    String status, {
    String? comment,
    bool? isLost,
    bool? isScheduleFollowup,
    String? followUpTitle,
    String? followUpDate,
  }) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');

    if (accessToken == null) {
      throw 'No access token found';
    }

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/leads/$id/updateStatus');

    try {
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'status': status,
          if (comment != null && comment.isNotEmpty) 'comment': comment,
          if (isLost != null) 'isLost': isLost,
          'isScheduleFollowup': isScheduleFollowup ?? false,
          if (isScheduleFollowup == true) ...{
            'followUpTitle': followUpTitle ?? 'Follow up',
            'followUpDate': followUpDate ?? DateTime.now().toUtc().toIso8601String(),
          },
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw 'Failed to update lead status: ${response.body}';
      }
    } catch (e) {
      throw e.toString();
    }
  }
  
  Future<bool> assignLead(String id, String toUserId) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');

    if (accessToken == null) {
      throw 'No access token found';
    }

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/leads/$id/assign');

    try {
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'toUser': toUserId,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw 'Failed to assign lead: ${response.body}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<bool> deleteLead(String id) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');

    if (accessToken == null) {
      throw 'No access token found';
    }

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/leads/delete/$id');

    try {
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw 'Failed to delete lead: ${response.body}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<CallLogsResult> fetchCallLogs(String leadId, {int page = 1, int limit = 20}) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');

    if (accessToken == null) {
      throw 'No access token found';
    }
  
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/leads/call/logs').replace(queryParameters: {
      'leadId': leadId,
      'page': page.toString(),
      'limit': limit.toString(),
    });

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        
        if (jsonResponse['data'] != null) {
            var logsData = [];
            int totalCount = 0;
            int totalPages = 1;
            int currentPage = page;
           
            final data = jsonResponse['data'];
            if (data['data'] != null) {
                 logsData = data['data'];
            } else if (data['logs'] != null) {
                logsData = data['logs'];
            } else if (data is List) {
                logsData = data;
            }

            if (data is Map) {
              if (data['totalCount'] != null) totalCount = data['totalCount'];
              if (data['total'] != null) totalCount = data['total'];
              if (data['totalPages'] != null) totalPages = data['totalPages'];
              if (data['page'] != null) currentPage = data['page'];
              if (data['pagination'] != null && data['pagination'] is Map) {
                totalPages = data['pagination']['totalPages'] ?? totalPages;
                currentPage = data['pagination']['page'] ?? currentPage;
                if (data['pagination']['total'] != null) totalCount = data['pagination']['total'];
              }
            }

            final logs = logsData.map<CallLog>((e) => CallLog.fromJson(e)).toList();
            return CallLogsResult(
              logs: logs,
              totalCount: totalCount,
              totalPages: totalPages,
              currentPage: currentPage,
            );
        } else {
             return CallLogsResult(logs: [], totalCount: 0, totalPages: 1, currentPage: 1);
        }
      } else {
         throw 'Failed to load call logs: ${response.statusCode}';
      }
    } catch (e) {
      throw e.toString();
    }
  }
  Future<List<LeadStatus>> fetchLeadStatuses() async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');

    if (accessToken == null) {
      throw 'No access token found';
    }

    // Endpoint: lead-status/company/list
    final url = Uri.parse('${AuthService.baseUrl}/api/v1/lead-status/company/list');

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
        debugPrint('🔥 FULL STATUS API RESPONSE: $jsonResponse');
        
        // Expected format based on standard API: { data: [ { name: "StatusName", ... }, ... ] } or { data: ["Status1", ...] }
        // Adjusting based on common patterns in this project (usually data field)
        final data = jsonResponse['data'];
        
        List<dynamic> rawList = [];
        
        if (data is List) {
           rawList = data;
        } else if (data is Map) {
           // Handle { data: { leadStatuses: [...] } }
           if (data['leadStatuses'] is List) {
              rawList = data['leadStatuses'];
           } else if (data['statuses'] is List) {
              rawList = data['statuses'];
           } else if (data['data'] is List) {
              rawList = data['data']; // Common pagination pattern
           } else if (data['list'] is List) {
              rawList = data['list'];
           }
        }

        if (rawList.isNotEmpty) {
           // Extract name or status field logic
           final statuses = rawList.map<LeadStatus>((e) {
              if (e is Map<String, dynamic>) {
                 return LeadStatus.fromJson(e);
              }
              // Handle unexpected string format by creating a dummy object if needed, or skip
              return LeadStatus(id: '', name: e.toString(), color: '', backgroundColor: '', isActive: true);
           }).where((s) => s.id.isNotEmpty).toList();
           
           debugPrint('✅ API Fetched Statuses: ${statuses.length}');
           return statuses;
        }
        
        debugPrint('⚠️ API Returned Empty Status List. Raw Data: $data');
      return [];
      } else {
        throw 'Failed to load statuses: ${response.statusCode}';
      }
    } catch (e) {
      // Fallback or rethrow? For now, rethrow to let provider handle it
      throw e.toString();
    }
  }

  Future<String?> getGoogleAuthStatus() async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) {
      debugPrint('❌ Google Auth Check: No Access Token');
      return null;
    }

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/google-auth/status');
    try {
      debugPrint('🔍 Checking Google Auth: $url');
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });
      
      debugPrint('📩 Google Auth Response [${response.statusCode}]: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (_parseIsConnected(data)) {
           return data['data']?['googleEmail'] as String?;
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error checking Google Auth: $e');
      return null;
    }
  }

  Future<String?> getMicrosoftAuthStatus() async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) {
      debugPrint('❌ Microsoft Auth Check: No Access Token');
      return null;
    }

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/microsoft-auth/status');
    try {
      debugPrint('🔍 Checking Microsoft Auth: $url');
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });

      debugPrint('📩 Microsoft Auth Response [${response.statusCode}]: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (_parseIsConnected(data)) {
           return data['data']?['outlookEmail'] as String?;
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error checking Microsoft Auth: $e');
      return null;
    }
  }

  bool _parseIsConnected(dynamic data) {
    if (data == null) return false;
    // Check root level
    if (_isTrue(data['isConnected'])) return true;
    if (_isTrue(data['connected'])) return true;
    
    // Check nested data
    if (data['data'] != null) {
       if (_isTrue(data['data']['isConnected'])) return true;
       if (_isTrue(data['data']['connected'])) return true;
       
       // Fallback: checks for specific status string
       if (data['data']['status'] == 'connected') return true;
    }
    return false;
  }

  bool _isTrue(dynamic value) {
    if (value == true) return true;
    if (value == 'true') return true;
    if (value == 1) return true;
    return false;
  }

  Future<bool> sendGoogleBulkEmail({
    required String subject,
    required String body,
    required List<String> recipients,
    required String employeeMail,
    required String mailType, // 'marketing' or 'personal'
  }) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) {
      debugPrint('❌ Send Gmail: No Access Token');
      return false;
    }

    // Endpoint: /api/v1/google-service/gmail/bulk/send
    final url = Uri.parse('${AuthService.baseUrl}/api/v1/google-service/gmail/bulk/send');
    
    final bodyData = {
      "subject": subject,
      "body": body,
      "recipients": recipients,
      "employeeMail": employeeMail,
      "mailType": mailType
    };

    try {
      debugPrint('🚀 Sending Gmail: $url');
      debugPrint('📦 Body: $bodyData');
      
      final response = await http.post(
        url, 
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(bodyData)
      );
      
      debugPrint('📩 Send Gmail Response [${response.statusCode}]: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error sending Google Mail: $e');
      return false;
    }
  }

  Future<bool> sendOutlookBulkEmail({
    required String subject,
    required String body,
    required List<String> recipients,
    required String employeeMail,
    required String mailType, // 'marketing' or 'personal'
  }) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) {
      debugPrint('❌ Send Outlook: No Access Token');
      return false;
    }

    // Endpoint: /api/v1/microsoft-service/outlook/bulk/send
    final url = Uri.parse('${AuthService.baseUrl}/api/v1/microsoft-service/outlook/bulk/send');
    
    final bodyData = {
      "subject": subject,
      "body": body,
      "recipients": recipients,
      "employeeMail": employeeMail,
      "mailType": mailType
    };

    try {
      debugPrint('🚀 Sending Outlook Email: $url');
      debugPrint('📦 Body: $bodyData');
      
      final response = await http.post(
        url, 
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(bodyData)
      );
      
      debugPrint('📩 Send Outlook Response [${response.statusCode}]: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error sending Outlook Mail: $e');
      return false;
    }
  }

  Future<bool> sendCustomBulkEmail({
    required String subject,
    required String body,
    required List<String> recipients,
    required String employeeMail,
    String? mailType,
  }) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) {
      debugPrint('❌ Send Custom Email: No Access Token');
      return false;
    }

    final isBulk = recipients.length > 1;
    final url = Uri.parse('${AuthService.baseUrl}/api/v1/custom-email${isBulk ? '/bulk/send' : '/send'}');
    
    final dynamic bodyData;
    if (isBulk) {
      bodyData = {
        "recipients": recipients,
        "subject": subject,
        "body": body,
        "mailType": mailType ?? "personal",
      };
    } else {
      bodyData = {
        "to": recipients.first,
        "subject": subject,
        "body": body,
        "employeeMail": employeeMail,
      };
    }

    try {
      debugPrint('🚀 Sending Custom Email: $url');
      debugPrint('📦 Body: $bodyData');
      
      final response = await http.post(
        url, 
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(bodyData)
      );
      
      debugPrint('📩 Send Custom Email Response [${response.statusCode}]: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error sending Custom Email: $e');
      return false;
    }
  }

  Future<String?> getCustomEmailStatus() async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) {
      debugPrint('❌ Custom Email Auth Check: No Access Token');
      return null;
    }

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/custom-email/status');
    try {
      debugPrint('🔍 Checking Custom Email status: $url');
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      });

      debugPrint('📩 Custom Email Auth Response [${response.statusCode}]: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true || data['connected'] == true || data['isConnected'] == true || data['data'] != null) {
          final email = data['data']?['smtpUser'] ?? data['data']?['email'] ?? data['data']?['user'] ?? data['email'] ?? '';
          return email.isNotEmpty ? email : 'Custom Email';
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error checking Custom Email status: $e');
      return null;
    }
  }

  Future<bool> createLeadStatus({required String name, required String color, required String backgroundColor}) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');

    if (accessToken == null) {
      throw 'No access token found';
    }

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/lead-status/company/create');

    try {
      final body = {
        "name": name,
        "color": color,
        "backgroundColor": backgroundColor
      };
      
      debugPrint('🚀 Creating Lead Status: $url');
      debugPrint('📦 Body: $body');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(body),
      );

      debugPrint('📩 Create Status Response [${response.statusCode}]: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        throw 'Failed to create status: ${response.body}';
      }
    } catch (e) {
      throw e.toString();
    }
  }
  Future<bool> updateCompanyLeadStatus(String id, {bool? isActive}) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');

    if (accessToken == null) {
      throw 'No access token found';
    }

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/lead-status/update/$id');

    try {
      final body = {
        if (isActive != null) "active": isActive,
      };
      
      debugPrint('🚀 Updating Lead Status: $url');
      debugPrint('📦 Body: $body');

      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(body),
      );

      debugPrint('📩 Update Status Response [${response.statusCode}]: ${response.body}');

      if (response.statusCode == 200) {
        return true;
      } else {
        throw 'Failed to update status: ${response.body}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<Map<String, dynamic>> bulkUploadLeads(dynamic file) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');

    if (accessToken == null) {
      throw 'No access token found';
    }

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/leads/create/bulk-upload');

    try {
      var request = http.MultipartRequest('POST', url);
      request.headers.addAll({
        'Authorization': 'Bearer $accessToken',
      });

      // Change field name from 'leads_file' to 'file'
      if (file.path != null) {
          request.files.add(await http.MultipartFile.fromPath('file', file.path!));
      } else if (file.bytes != null) {
          request.files.add(http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name));
      }

      debugPrint('🚀 Bulk Uploading Leads: $url');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint('📩 Bulk Upload Response [${response.statusCode}]: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = jsonDecode(response.body);
        return result['data'] ?? result; // Return the upload summary
      } else {
        final error = jsonDecode(response.body);
        throw error['message'] ?? 'Failed to upload leads';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<bool> bulkAssign(List<String> leadIds, String toUserId) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/leads/bulk-assign');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'leadIds': leadIds, 'toUser': toUserId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      throw e.toString();
    }
  }

  Future<bool> bulkUpdate(List<String> leadIds, Map<String, dynamic> updates) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/leads/bulk-update');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'leadIds': leadIds, 'updates': updates}),
      );
      return response.statusCode == 200;
    } catch (e) {
      throw e.toString();
    }
  }

  Future<List<Lead>> searchLeads(String searchQuery) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');

    if (accessToken == null) {
      throw 'No access token found';
    }

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/leads/search').replace(queryParameters: {
      'searchQuery': searchQuery,
    });

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['data'] != null && jsonResponse['data']['leads'] != null) {
          final List<dynamic> leadsList = jsonResponse['data']['leads'];
          return leadsList.map((e) => Lead.fromJson(e)).toList();
        }
        return [];
      } else {
        throw 'Failed to search leads: ${response.statusCode}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<Map<String, dynamic>> getIvrConfig() async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');

    if (accessToken == null) {
      throw 'No access token found';
    }

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/ivr/config');

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
        if (jsonResponse['data'] != null) {
          return jsonResponse['data'] is Map<String, dynamic> ? jsonResponse['data'] : jsonResponse;
        }
        return jsonResponse;
      } else {
        throw 'Failed to fetch IVR config: ${response.statusCode}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<Map<String, dynamic>> initiateClickToCall({
    required String targetPhone,
    String? leadId,
    String? agentId,
  }) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');

    if (accessToken == null) {
      throw 'No access token found';
    }

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/ivr/click-to-call');

    final body = {
      'targetPhone': targetPhone,
      if (leadId != null && leadId.isNotEmpty) 'leadId': leadId,
      if (agentId != null && agentId.isNotEmpty) 'agentId': agentId,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return jsonResponse['data'] is Map<String, dynamic> ? jsonResponse['data'] : jsonResponse;
      } else {
        final bodyText = response.body;
        try {
          final errData = jsonDecode(bodyText);
          throw errData['message'] ?? 'Failed to initiate call (${response.statusCode})';
        } catch (_) {
          throw 'Failed to initiate call: ${response.statusCode}';
        }
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<List<Map<String, dynamic>>> fetchAssignableUsers() async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');

    if (accessToken == null) {
      throw 'No access token found';
    }

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/users/assignable');

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
        dynamic rawUsers;
        if (data is Map) {
          final nestedData = data['data'];
          if (nestedData is List) {
            rawUsers = nestedData;
          } else if (nestedData is Map) {
            rawUsers = nestedData['users'] ?? nestedData['data'] ?? nestedData['list'] ?? [];
          } else {
            rawUsers = data['users'] ?? data['list'] ?? [];
          }
        } else if (data is List) {
          rawUsers = data;
        }
        final users = (rawUsers is List) ? rawUsers : [];
        return users.whereType<Map<String, dynamic>>().cast<Map<String, dynamic>>().toList();
      } else {
        throw 'Failed to fetch assignable users: ${response.statusCode}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<Map<String, dynamic>> updateSubAssignees(String leadId, List<String> userIds) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');

    if (accessToken == null) {
      throw 'No access token found';
    }

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/leads/$leadId/sub-assignees');

    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'userIds': userIds}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        final bodyText = response.body;
        try {
          final errData = jsonDecode(bodyText);
          throw errData['message'] ?? 'Failed to update sub-assignees (${response.statusCode})';
        } catch (_) {
          throw 'Failed to update sub-assignees: ${response.statusCode}';
        }
      }
    } catch (e) {
      throw e.toString();
    }
  }
}
