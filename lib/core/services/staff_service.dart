import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'http_client.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/group_model.dart';
import '../../data/models/staff_model.dart';
import '../../data/models/team_model.dart';
import '../../data/models/location_model.dart';
import 'auth_service.dart';

class StaffService {
  Future<TeamListResponse> fetchTeams({
    int page = 1,
    int limit = 10,
    String search = '',
  }) async {
    final box = Hive.box('authBox');
    final token = box.get('accessToken');

    if (token == null) {
      throw Exception('No access token found');
    }

    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      'searchQuery': search,
    };

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/team/list').replace(queryParameters: queryParams);

    debugPrint('--------------- TEAMS API REQUEST ---------------');
    debugPrint('URI: $uri');
    debugPrint('Token (Masked): ${token.substring(0, 10)}...');
    debugPrint('-------------------------------------------------');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('--------------- TEAMS API RESPONSE ---------------');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Body: ${response.body}');
      debugPrint('--------------------------------------------------');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return TeamListResponse.fromJson(data);
      } else {
        throw Exception('Failed to load teams: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching teams: $e');
    }
  }

  Future<Team> fetchTeamDetails(String id) async {
    final box = Hive.box('authBox');
    final token = box.get('accessToken');

    if (token == null) throw Exception('No access token found');

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/team/$id');

    debugPrint('--------------- TEAM DETAIL REQUEST ---------------');
    debugPrint('URI: $uri');
    debugPrint('---------------------------------------------------');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('--------------- TEAM DETAIL RESPONSE ---------------');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Body: ${response.body}');
      debugPrint('----------------------------------------------------');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Response format: { "data": { "team": { ... } } }
        final teamData = data['data']['team'];
        return Team.fromJson(teamData);
      } else {
        throw Exception('Failed to load team details');
      }
    } catch (e) {
      throw Exception('Error fetching team details: $e');
    }
  }

  Future<void> createTeam({required String name, required bool active}) async {
    final box = Hive.box('authBox');
    final token = box.get('accessToken');

    if (token == null) throw Exception('No access token found');

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/team/create');
    final body = jsonEncode({
      'name': name,
      'active': active,
    });

    debugPrint('--------------- CREATE TEAM REQUEST ---------------');
    debugPrint('URI: $uri');
    debugPrint('Body: $body');
    debugPrint('---------------------------------------------------');

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      debugPrint('--------------- CREATE TEAM RESPONSE ---------------');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Body: ${response.body}');
      debugPrint('----------------------------------------------------');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      } else {
        throw Exception('Failed to create team: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating team: $e');
    }
  }

  Future<void> updateTeam({required String id, required String name, required bool active}) async {
    final box = Hive.box('authBox');
    final token = box.get('accessToken');

    if (token == null) throw Exception('No access token found');

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/team/update/$id');
    final body = jsonEncode({
      'name': name,
      'active': active,
    });

    debugPrint('--------------- UPDATE TEAM REQUEST ---------------');
    debugPrint('URI: $uri');
    debugPrint('Body: $body');
    debugPrint('---------------------------------------------------');

    try {
      final response = await http.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      debugPrint('--------------- UPDATE TEAM RESPONSE ---------------');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Body: ${response.body}');
      debugPrint('----------------------------------------------------');

      if (response.statusCode == 200) {
        return;
      } else {
        throw Exception('Failed to update team: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error updating team: $e');
    }
  }

  Future<void> deleteTeam(String id) async {
    final box = Hive.box('authBox');
    final token = box.get('accessToken');
    if (token == null) throw Exception('No access token found');

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/team/delete/$id');

    try {
      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete team: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error deleting team: $e');
    }
  }




  // ---------------- GROUPS ----------------

  Future<GroupListResponse> fetchGroups({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    final box = Hive.box('authBox');
    final token = box.get('accessToken');

    if (token == null) throw Exception('No access token found');

    // Assuming endpoint follows Team pattern
    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      'searchQuery': search ?? '',
    };

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/group/list').replace(queryParameters: queryParams); // Guessing endpoint

    debugPrint('--------------- FETCH GROUPS REQUEST ---------------');
    debugPrint('URI: $uri');
    debugPrint('----------------------------------------------------');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('--------------- FETCH GROUPS RESPONSE ---------------');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Body: ${response.body}');
      debugPrint('-----------------------------------------------------');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return GroupListResponse.fromJson(data);
      } else {
        throw Exception('Failed to load groups: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching groups: $e');
    }
  }

  Future<Group> fetchGroupDetails(String id) async {
    final box = Hive.box('authBox');
    final token = box.get('accessToken');

    if (token == null) throw Exception('No access token found');

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/group/$id');

    debugPrint('--------------- GROUP DETAIL REQUEST ---------------');
    debugPrint('URI: $uri');
    debugPrint('----------------------------------------------------');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('--------------- GROUP DETAIL RESPONSE ---------------');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Body: ${response.body}');
      debugPrint('-----------------------------------------------------');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final groupData = data['data']['group']; // Assuming standard response wrapper
        return Group.fromJson(groupData);
      } else {
        throw Exception('Failed to load group details');
      }
    } catch (e) {
      throw Exception('Error fetching group details: $e');
    }
  }
  
  Future<void> createGroup({required String name, required bool active}) async {
    final box = Hive.box('authBox');
    final token = box.get('accessToken');

    if (token == null) throw Exception('No access token found');

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/group/create');
    final body = jsonEncode({
      'name': name,
      'active': active,
    });

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to create group: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating group: $e');
    }
  }

    Future<void> updateGroup({required String id, required String name, required bool active}) async {
    final box = Hive.box('authBox');
    final token = box.get('accessToken');

    if (token == null) throw Exception('No access token found');

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/group/update/$id');
    final body = jsonEncode({
      'name': name,
      'active': active,
    });

    try {
      final response = await http.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update group: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error updating group: $e');
    }
  }

  Future<void> deleteGroup(String id) async {
    final box = Hive.box('authBox');
    final token = box.get('accessToken');
    if (token == null) throw Exception('No access token found');

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/group/delete/$id');

    try {
      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete group: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error deleting group: $e');
    }
  }

  Future<void> addTeamsToGroup({required String groupId, required List<String> teamIds}) async {
    final box = Hive.box('authBox');
    final token = box.get('accessToken');

    if (token == null) throw Exception('No access token found');

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/group/$groupId/add-teams');
    final body = jsonEncode({
      'teamIds': teamIds,
    });

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to add teams: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error adding teams: $e');
    }
  }

  Future<void> removeTeamsFromGroup({required String groupId, required List<String> teamIds}) async {
    final box = Hive.box('authBox');
    final token = box.get('accessToken');

    if (token == null) throw Exception('No access token found');

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/group/$groupId/remove-teams');
    final body = jsonEncode({
      'teamIds': teamIds,
    });

    try {
      final response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: body
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to remove teams: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error removing teams: $e');
    }
  }

  Future<void> addMembersToTeam({required String teamId, required List<String> memberIds}) async {
    final box = Hive.box('authBox');
    final token = box.get('accessToken');

    if (token == null) throw Exception('No access token found');

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/team/$teamId/add-executives');
    final body = jsonEncode({
      'executiveIds': memberIds,
    });

    debugPrint('--------------- ADD EXECUTIVES REQUEST ---------------');
    debugPrint('URI: $uri');
    debugPrint('Body: $body');

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');
      debugPrint('----------------------------------------------------');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to add executives: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error: $e');
      throw Exception('Error adding executives: $e');
    }
  }

  Future<void> removeMembersFromTeam({required String teamId, required List<String> memberIds}) async {
    final box = Hive.box('authBox');
    final token = box.get('accessToken');

    if (token == null) throw Exception('No access token found');

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/team/$teamId/remove-executives');
    final body = jsonEncode({
      'executiveIds': memberIds,
    });

    debugPrint('--------------- REMOVE EXECUTIVES REQUEST ---------------');
    debugPrint('URI: $uri');
    debugPrint('Body: $body');

    try {
      final response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: body
      );

      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');
      debugPrint('----------------------------------------------------');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to remove executives: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error removing executives: $e');
    }
  }

  Future<void> assignLeadersToTeam({required String teamId, required List<String> leaderIds}) async {
    final box = Hive.box('authBox');
    final token = box.get('accessToken');

    if (token == null) throw Exception('No access token found');

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/team/$teamId/assign-leader');
    final body = jsonEncode({
      'leaderIds': leaderIds,
    });

    debugPrint('--------------- ASSIGN LEADER REQUEST ---------------');
    debugPrint('URI: $uri');
    debugPrint('Body: $body');

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');
      debugPrint('----------------------------------------------------');

      if (response.statusCode != 200) {
        throw Exception('Failed to assign leader: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error assigning leader: $e');
    }
  }

  Future<void> assignManagersToGroup({required String groupId, required List<String> managerIds}) async {
    final box = Hive.box('authBox');
    final token = box.get('accessToken');

    if (token == null) throw Exception('No access token found');

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/group/$groupId/assign-manager');
    final body = jsonEncode({
      'managerIds': managerIds,
    });

    debugPrint('--------------- ASSIGN MANAGERS REQUEST ---------------');
    debugPrint('URI: $uri');
    debugPrint('Body: $body');

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');
      debugPrint('----------------------------------------------------');

      if (response.statusCode != 200) {
        throw Exception('Failed to assign manager: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error assigning manager: $e');
    }
  }

  Future<StaffListResponse> fetchStaff({
    required String role,
    int page = 1,
    int limit = 200,
    String search = '',
  }) async {
    final box = Hive.box('authBox');
    final token = box.get('accessToken');

    if (token == null) {
      throw Exception('No access token found');
    }

    // User Instruction: "make sure that the systemrole should eb from the current user role"
    // Validated: The user wants to fetch users OF that role. 
    
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      'searchQuery': search,
    };

    if (role.isNotEmpty) {
      queryParams['systemRole'] = role;
    }

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/users/system/list').replace(queryParameters: queryParams);

    debugPrint('--------------- STAFF API REQUEST (GET Query) ---------------');
    debugPrint('URI: $uri');
    debugPrint('Token (Masked): ${token.substring(0, 10)}...');
    debugPrint('-----------------------------------------------------------');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('--------------- STAFF API RESPONSE ---------------');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Body: ${response.body}');
      debugPrint('------------------------------------------------');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final checkData = data['data'] ?? data; 
        return StaffListResponse.fromJson(checkData);
      } else {
        throw Exception('Failed to load staff: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching staff: $e');
    }
  }
  Future<void> createStaff(Map<String, dynamic> data) async {
    final box = Hive.box('authBox');
    final token = box.get('accessToken');
    final userData = box.get('user_data');

    if (token == null) {
      throw Exception('No access token found');
    }

    // Try to attach company ID from current user
    if (!data.containsKey('company') && userData != null) {
         try {
             // userData might be stored as Map or formatted String. Handle both.
             final userMap = userData is String ? jsonDecode(userData) : userData;
             if (userMap is Map) {
                 final company = userMap['company'];
                 if (company != null) {
                     if (company is String) {
                         data['company'] = company;
                     } else if (company is Map) {
                         data['company'] = company['_id'] ?? company['id'];
                     }
                 }
             }
         } catch (e) {
             debugPrint('Error parsing user_data for company ID: $e'); // Keep print for debugging if needed, or use debugPrint
         }
    }

    String endpoint;
    final role = data['systemRole'];
    
    // Determine endpoint based on role
    if (role == 'sales_manager') {
      endpoint = '/api/v1/users/company/createSalesManager';
    } else if (role == 'team_leader') {
      endpoint = '/api/v1/users/company/createTeamLeader';
    } else if (role == 'sales_executive') {
      endpoint = '/api/v1/users/company/createSalesExecutive';
    } else {
      endpoint = '/api/v1/users/create'; 
    }

    // Clean payload for specific endpoints
    final payload = Map<String, dynamic>.from(data);
    if (role == 'sales_manager' || role == 'team_leader' || role == 'sales_executive') {
       payload.remove('systemRole');
       // payload.remove('status'); // Fix: Do not remove status, backend needs it
       // user provided payload for Team Leader didn't have company, but logs showed it. 
       // If creating under company context, maybe company ID in body is redundant or potentially conflicting if not needed.
       // Safe bet: The endpoint /users/company/... likely implies company context.
       // However, to avoid 500 if backend fails to find properties, I will stick to the stripped payload as it matches the user's snippet.
       // payload.remove('company'); // I will COMMENT THIS OUT to send company if available, just in case. 
       // Actually, let's keep it removed. The user's snippet was very specific.
       payload.remove('company');
    }

    final uri = Uri.parse('${AuthService.baseUrl}$endpoint');
    final body = jsonEncode(payload);

    debugPrint('--------------- CREATE STAFF REQUEST ---------------');
    debugPrint('URI: $uri');
    debugPrint('Body: $body');
    debugPrint('----------------------------------------------------');

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      debugPrint('--------------- CREATE STAFF RESPONSE ---------------');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Body: ${response.body}');
      debugPrint('-----------------------------------------------------');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      } else {
        throw Exception('Failed to create staff: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating staff: $e');
    }
  }

  Future<void> updateStaff(String staffId, Map<String, dynamic> data) async {
    final box = Hive.box('authBox');
    final token = box.get('accessToken');

    if (token == null) {
      throw Exception('No access token found');
    }

    String endpoint;
    final role = data['systemRole'];
    
    // Determine endpoint based on role
    if (role == 'sales_manager') {
      endpoint = '/api/v1/users/company/updateSalesManager/$staffId';
    } else if (role == 'team_leader') {
      endpoint = '/api/v1/users/company/updateTeamLeader/$staffId';
    } else if (role == 'sales_executive') {
      endpoint = '/api/v1/users/company/updateSalesExecutive/$staffId';
    } else {
      endpoint = '/api/v1/users/update/$staffId'; 
    }

    // Clean payload for specific endpoints
    final payload = Map<String, dynamic>.from(data);
    if (role == 'sales_manager' || role == 'team_leader' || role == 'sales_executive') {
       payload.remove('systemRole');
       payload.remove('company');
    }

    final uri = Uri.parse('${AuthService.baseUrl}$endpoint');
    final body = jsonEncode(payload);

    debugPrint('--------------- UPDATE STAFF REQUEST ---------------');
    debugPrint('Staff ID: $staffId');
    debugPrint('Role: $role');
    debugPrint('URI: $uri');
    debugPrint('Body: $body');
    debugPrint('----------------------------------------------------');

    try {
      final response = await http.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      debugPrint('--------------- UPDATE STAFF RESPONSE ---------------');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Body: ${response.body}');
      debugPrint('-----------------------------------------------------');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      } else {
        throw Exception('Failed to update staff: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error updating staff: $e');
    }
  }

  Future<void> deleteStaff(String id) async {
    final box = Hive.box('authBox');
    final token = box.get('accessToken');
    if (token == null) throw Exception('No access token found');

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/users/delete/$id');

    try {
      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete staff: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error deleting staff: $e');
    }
  }

  /// Fetch staff list with location data for the Live Location Tracking screen.
  /// Uses the V2 list endpoint - location data is embedded in each user object.
  Future<List<StaffLocationUser>> fetchStaffWithLocations({required String systemRole}) async {
    final box = Hive.box('authBox');
    final token = box.get('accessToken');
    if (token == null) throw Exception('No access token found');

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/users/system/list').replace(queryParameters: {
      'systemRole': systemRole,
      'status': 'true',
      'limit': '200',
    });

    try {
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final users = (data['data']?['users'] as List?) ?? [];
        return users.map((u) => StaffLocationUser.fromJson(u as Map<String, dynamic>)).toList();
      } else {
        throw Exception('Failed to fetch staff locations: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching staff locations: $e');
    }
  }

  /// Find nearby staff given a lat/lng center, radius, and optional project filter.
  Future<List<NearbyStaffUser>> findNearbyStaff({
    required double lat,
    required double lng,
    double maxDistance = 50000,
    String? projectId,
    String? systemRole,
    String? userId,
  }) async {
    final box = Hive.box('authBox');
    final token = box.get('accessToken');

    if (token == null) throw Exception('No access token found');

    // Retrieve company ID from stored user data
    String? companyId;
    final userDataStr = box.get('user_data');
    if (userDataStr != null) {
      try {
        final userData = json.decode(userDataStr);
        companyId = userData['company'];
      } catch (e) {
        debugPrint('Error parsing user data for company filter: $e');
      }
    }

    final queryParams = <String, String>{
      'lat': lat.toString(),
      'lng': lng.toString(),
      'maxDistance': maxDistance.toString(),
    };
    if (projectId != null && projectId.isNotEmpty) {
      queryParams['projectId'] = projectId;
    }
    if (systemRole != null && systemRole.isNotEmpty) {
      queryParams['systemRole'] = systemRole;
    }
    if (userId != null && userId.isNotEmpty) {
      queryParams['userId'] = userId;
    }
    if (companyId != null && companyId.isNotEmpty) {
      queryParams['company'] = companyId; // Filter by company
    }

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/location/nearby').replace(queryParameters: queryParams);

    try {
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        List staffList = [];
        
        if (decoded is List) {
          // Response is a direct list: [ {...}, {...} ]
          staffList = decoded;
        } else if (decoded is Map) {
          // Response is a Map: { "data": ... }
          final dataField = decoded['data'];
          if (dataField is List) {
            // Case: { "data": [ {...}, {...} ] }
            staffList = dataField;
          } else if (dataField is Map) {
            // Case: { "data": { "staff": [ {...} ] } }
            if (dataField['staff'] is List) {
              staffList = dataField['staff'];
            }
          } else if (decoded['staff'] is List) {
            // Case: { "staff": [ {...} ] }
            staffList = decoded['staff'];
          }
        }
        
        return staffList
            .whereType<Map<String, dynamic>>()
            .map((s) => NearbyStaffUser.fromJson(s))
            .toList();
      } else {
        throw Exception('Failed to find nearby staff: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error finding nearby staff: $e');
    }
  }
}

