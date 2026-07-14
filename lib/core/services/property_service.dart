import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:developer' as dev;
import 'http_client.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/property_model.dart';

class PropertyService {
  static const String baseUrl = 'https://crm-app-backend-btpi.onrender.com';

  void _logRequest(Uri url, Map<String, String> headers) {
    dev.log('[PropertyService] GET $url', name: 'API');
    dev.log(
      '[PropertyService] Headers: ${headers.keys.map((k) => "$k: ${k == 'Authorization' ? 'Bearer ***' : headers[k]}}").join(', ')}',
      name: 'API',
    );
  }

  String _extractPreview(String body, int maxLen) {
    if (body.isEmpty) return '(empty body)';
    final preview = body.length > maxLen
        ? '${body.substring(0, maxLen)}...'
        : body;
    return preview;
  }

  static List<String> parseStringList(
    dynamic value, {
    List<String> containerKeys = const ['data', 'items', 'results'],
  }) {
    if (value == null) return const [];

    if (value is List) {
      return value
          .expand(
            (entry) => parseStringList(entry, containerKeys: containerKeys),
          )
          .where((entry) => entry.trim().isNotEmpty)
          .toList();
    }

    if (value is Map) {
      final map = value.cast<String, dynamic>();
      for (final key in containerKeys) {
        final nested = map[key];
        if (nested != null) {
          final parsed = parseStringList(nested, containerKeys: containerKeys);
          if (parsed.isNotEmpty) return parsed;
        }
      }

      final directCandidates = <String?>[
        map['name'],
        map['city'],
        map['cityName'],
        map['title'],
        map['value'],
        map['label'],
        map['displayName'],
      ];
      for (final candidate in directCandidates) {
        if (candidate != null) {
          final parsed = parseStringList(
            candidate,
            containerKeys: containerKeys,
          );
          if (parsed.isNotEmpty) return parsed;
        }
      }

      for (final entry in map.entries) {
        final lowerKey = entry.key.toString().toLowerCase();
        if (lowerKey.contains('city') ||
            lowerKey.contains('name') ||
            lowerKey.contains('title') ||
            lowerKey.contains('label') ||
            lowerKey.contains('value')) {
          final parsed = parseStringList(
            entry.value,
            containerKeys: containerKeys,
          );
          if (parsed.isNotEmpty) return parsed;
        }
      }

      final nestedValues = <String>[];
      for (final entry in map.values) {
        nestedValues.addAll(
          parseStringList(entry, containerKeys: containerKeys),
        );
      }
      return nestedValues.where((entry) => entry.trim().isNotEmpty).toList();
    }

    final text = value.toString().trim();
    return text.isEmpty ? const [] : [text];
  }

  Future<List<String>> getCities() async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');

    final url = Uri.parse('$baseUrl/api/v1/projects/property/cities');

    _logRequest(url, {'Authorization': token != null ? 'Bearer $token' : ''});

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Bypass-Tunnel-Reminder': 'true',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    dev.log(
      '[PropertyService] getCities Response Status: ${response.statusCode}',
      name: 'API',
    );
    dev.log(
      '[PropertyService] getCities Response Body: ${response.body}',
      name: 'API',
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final rawList = parseStringList(
        decoded,
        containerKeys: ['cities', 'data', 'items', 'results'],
      );
      if (rawList.isEmpty) {
        dev.log(
          '[PropertyService] getCities parsed no values from response body: ${response.body}',
          name: 'API',
        );
      }
      return rawList;
    } else {
      throw 'Failed to fetch cities: ${response.statusCode}';
    }
  }

  Future<List<String>> getAmenities() async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');

    final url = Uri.parse('$baseUrl/api/v1/projects/property/amenities');

    _logRequest(url, {'Authorization': token != null ? 'Bearer $token' : ''});

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Bypass-Tunnel-Reminder': 'true',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    dev.log(
      '[PropertyService] getAmenities Response Status: ${response.statusCode}',
      name: 'API',
    );
    dev.log(
      '[PropertyService] getAmenities Response Body: ${response.body}',
      name: 'API',
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final rawList = parseStringList(
        decoded,
        containerKeys: ['amenities', 'data', 'items', 'results'],
      );
      if (rawList.isEmpty) {
        dev.log(
          '[PropertyService] getAmenities parsed no values from response body: ${response.body}',
          name: 'API',
        );
      }
      return rawList;
    } else {
      throw 'Failed to fetch amenities: ${response.statusCode}';
    }
  }

  Future<PropertyResponse> getProperties({
    String? projectId,
    int page = 1,
    int limit = 20,
    String? propertyType,
    String? status,
    String? category,
    double? minPrice,
    double? maxPrice,
    String? facing,
    int? bedrooms,
    int? bathrooms,
    String? areaUnit,
    double? minArea,
    double? maxArea,
    String? listingType,
    String? allowedTenants,
    String? city,
    String? searchQuery,
    String? sort,
    String? direction,
    String? furnishingStatus,
    String? preferredGender,
    String? amenities,
    String? availableBy,
    String? builtUp,
    String? fromInventoryDate,
    String? toInventoryDate,
  }) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');

    final queryParams = <String, String>{
      if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
      'page': page.toString(),
      'limit': limit.toString(),
      if (propertyType != null && propertyType.isNotEmpty)
        'propertyType': propertyType,
      if (status != null && status.isNotEmpty) 'status': status,
      if (category != null && category.isNotEmpty) 'category': category,
      if (minPrice != null) 'minPrice': minPrice.toString(),
      if (maxPrice != null) 'maxPrice': maxPrice.toString(),
      if (facing != null && facing.isNotEmpty) 'facing': facing,
      if (bedrooms != null) 'bedrooms': bedrooms.toString(),
      if (bathrooms != null) 'bathrooms': bathrooms.toString(),
      if (areaUnit != null && areaUnit.isNotEmpty) 'areaUnit': areaUnit,
      if (minArea != null) 'minArea': minArea.toString(),
      if (maxArea != null) 'maxArea': maxArea.toString(),
      if (listingType != null && listingType.isNotEmpty)
        'listingType': listingType,
      if (allowedTenants != null && allowedTenants.isNotEmpty)
        'allowedTenants': allowedTenants,
      if (city != null && city.isNotEmpty) 'city': city,
      if (furnishingStatus != null && furnishingStatus.isNotEmpty)
        'furnishingStatus': furnishingStatus,
      if (preferredGender != null && preferredGender.isNotEmpty)
        'preferredGender': preferredGender,
      if (amenities != null && amenities.isNotEmpty) 'amenities': amenities,
      if (availableBy != null && availableBy.isNotEmpty)
        'availabilityDate': availableBy,
      if (searchQuery != null && searchQuery.isNotEmpty)
        'searchQuery': searchQuery,
      if (sort != null && sort.isNotEmpty) 'sort': sort,
      if (direction != null && direction.isNotEmpty) 'direction': direction,
      if (builtUp != null) 'builtUp': builtUp,
      if (fromInventoryDate != null && fromInventoryDate.isNotEmpty)
        'fromInventoryDate': fromInventoryDate,
      if (toInventoryDate != null && toInventoryDate.isNotEmpty)
        'toInventoryDate': toInventoryDate,
    };

    final url = Uri.parse(
      '$baseUrl/api/v1/projects/property/list',
    ).replace(queryParameters: queryParams);

    _logRequest(url, {'Authorization': token != null ? 'Bearer $token' : ''});

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Bypass-Tunnel-Reminder': 'true',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      try {
        final json = jsonDecode(response.body);
        return PropertyResponse.fromJson(json);
      } on FormatException catch (e) {
        dev.log(
          '[PropertyService] getProperties JSON decode FAILED: $e',
          name: 'API',
        );
        dev.log(
          '[PropertyService] Body preview: ${_extractPreview(response.body, 200)}',
          name: 'API',
        );
        throw 'Invalid server response: Expected JSON but received ${response.body.contains("<!DOCTYPE") ? "HTML" : "unknown format"}. '
            'Status: ${response.statusCode}, Body starts with: ${_extractPreview(response.body, 200)}';
      } catch (e) {
        dev.log(
          '[PropertyService] getProperties model parse error: $e',
          name: 'API',
        );
        dev.log(
          '[PropertyService] Response body preview: ${_extractPreview(response.body, 300)}',
          name: 'API',
        );
        throw 'Failed to parse properties response: $e';
      }
    } else {
      throw 'Failed to fetch properties: ${response.statusCode}';
    }
  }

  Future<ProjectListResponse> getProjects({
    int page = 1,
    int limit = 20,
    String? searchQuery,
    String? status,
    String? projectCategory,
    String? propertyCategory,
    String? from,
    String? to,
    String? sort,
  }) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');

    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (searchQuery != null && searchQuery.isNotEmpty)
        'searchQuery': searchQuery,
      if (status != null && status.isNotEmpty) 'status': status,
      if (projectCategory != null && projectCategory.isNotEmpty)
        'projectCategory': projectCategory,
      if (propertyCategory != null && propertyCategory.isNotEmpty)
        'propertyCategory': propertyCategory,
      if (from != null && from.isNotEmpty) 'from': from,
      if (to != null && to.isNotEmpty) 'to': to,
      if (sort != null && sort.isNotEmpty) 'sort': sort,
    };

    final url = Uri.parse(
      '$baseUrl/api/v1/projects/list',
    ).replace(queryParameters: queryParams);

    _logRequest(url, {'Authorization': token != null ? 'Bearer $token' : ''});

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Bypass-Tunnel-Reminder': 'true',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      try {
        final json = jsonDecode(response.body);
        return ProjectListResponse.fromJson(json);
      } on FormatException catch (e) {
        dev.log(
          '[PropertyService] getProjects JSON decode FAILED: $e',
          name: 'API',
        );
        dev.log(
          '[PropertyService] Body preview: ${_extractPreview(response.body, 200)}',
          name: 'API',
        );
        throw 'Invalid server response: Expected JSON but received ${response.body.contains("<!DOCTYPE") ? "HTML" : "unknown format"}. '
            'Status: ${response.statusCode}, Body starts with: ${_extractPreview(response.body, 200)}';
      } catch (e) {
        dev.log(
          '[PropertyService] getProjects model parse error: $e',
          name: 'API',
        );
        dev.log(
          '[PropertyService] Response body preview: ${_extractPreview(response.body, 300)}',
          name: 'API',
        );
        throw 'Failed to parse projects response: $e';
      }
    } else {
      throw 'Failed to fetch projects: ${response.statusCode}';
    }
  }

  Future<PropertyNameResponse> getPropertyNames(String projectId) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');

    final url = Uri.parse(
      '$baseUrl/api/v1/projects/property/names?projectId=$projectId',
    );

    _logRequest(url, {'Authorization': token != null ? 'Bearer $token' : ''});

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Bypass-Tunnel-Reminder': 'true',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      try {
        final json = jsonDecode(response.body);
        return PropertyNameResponse.fromJson(json);
      } on FormatException catch (e) {
        dev.log(
          '[PropertyService] getPropertyNames JSON decode FAILED: $e',
          name: 'API',
        );
        throw 'Invalid server response: Expected JSON but received ${response.body.contains("<!DOCTYPE") ? "HTML" : "unknown format"}.';
      } catch (e) {
        dev.log(
          '[PropertyService] getPropertyNames model parse error: $e',
          name: 'API',
        );
        dev.log(
          '[PropertyService] Response body preview: ${_extractPreview(response.body, 300)}',
          name: 'API',
        );
        throw 'Failed to parse property names response: $e';
      }
    } else {
      throw 'Failed to fetch property names (${response.statusCode})';
    }
  }

  Future<void> updateProject(
    String projectId,
    Map<String, dynamic> data,
  ) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');

    final url = Uri.parse('$baseUrl/api/v1/projects/update/$projectId');

    final response = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Bypass-Tunnel-Reminder': 'true',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final errorData = jsonDecode(response.body);
      throw errorData['message'] ?? 'Failed to update project';
    }
  }

  Future<void> createProject(Map<String, dynamic> data) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');

    final url = Uri.parse('$baseUrl/api/v1/projects/create');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Bypass-Tunnel-Reminder': 'true',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final errorData = jsonDecode(response.body);
      throw errorData['message'] ?? 'Failed to create project';
    }
  }

  Future<void> createProperty(Map<String, dynamic> data) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');

    final url = Uri.parse('$baseUrl/api/v1/projects/property/create');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Bypass-Tunnel-Reminder': 'true',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      String errorMessage =
          'Failed to create property (${response.statusCode})';
      try {
        final errorData = jsonDecode(response.body);
        errorMessage = errorData['message'] ?? errorMessage;
      } catch (_) {
        if (response.body.contains("<!DOCTYPE")) {
          errorMessage =
              'Server Error (${response.statusCode}): Received HTML instead of JSON. The backend might be down or the URL is incorrect.';
        }
      }
      throw errorMessage;
    }
  }

  Future<void> updateProperty(
    String propertyId,
    Map<String, dynamic> data,
  ) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');

    final url = Uri.parse('$baseUrl/api/v1/projects/property/$propertyId');

    dev.log('[PropertyService] updateProperty PATCH $url', name: 'API');
    dev.log(
      '[PropertyService] updateProperty Body: ${jsonEncode(data)}',
      name: 'API',
    );

    debugPrint('===== PROPERTY UPDATE REQUEST =====');
    debugPrint('URL: $url');
    debugPrint('Payload: ${jsonEncode(data)}');
    debugPrint('====================================');

    final bodyStr = jsonEncode(data);
    debugPrint(
      '===== BODY TYPE: ${bodyStr.runtimeType}, token type: ${token.runtimeType}, token is null: ${token == null} =====',
    );

    final response = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Bypass-Tunnel-Reminder': 'true',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: bodyStr,
    );

    debugPrint('===== http.patch returned, status: ${response.statusCode} =====');

    dev.log(
      '[PropertyService] updateProperty Response Status: ${response.statusCode}',
      name: 'API',
    );
    dev.log(
      '[PropertyService] updateProperty Response Body: ${_extractPreview(response.body, 300)}',
      name: 'API',
    );

    // Print full response for debugging
    debugPrint('===== PROPERTY UPDATE RESPONSE =====');
    debugPrint('Status: ${response.statusCode}');
    debugPrint('Body: ${response.body}');
    debugPrint('=====================================');

    if (response.statusCode != 200 && response.statusCode != 201) {
      String errorMessage =
          'Failed to update property (${response.statusCode})';
      try {
        final errorData = jsonDecode(response.body);
        errorMessage = errorData['message'] ?? errorMessage;
      } catch (_) {
        if (response.body.contains("<!DOCTYPE")) {
          errorMessage =
              'Server Error (${response.statusCode}): Received HTML instead of JSON. The backend might be down or the URL is incorrect.';
        }
      }
      throw errorMessage;
    }
  }

  Future<void> deleteProject(String id) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');

    final url = Uri.parse('$baseUrl/api/v1/projects/$id');

    final response = await http.delete(
      url,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final errorData = jsonDecode(response.body);
      throw errorData['message'] ?? 'Failed to delete project';
    }
  }

  Future<void> deleteProperty(String id) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');

    final url = Uri.parse('$baseUrl/api/v1/projects/property/$id');

    final response = await http.delete(
      url,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final errorData = jsonDecode(response.body);
      throw errorData['message'] ?? 'Failed to delete property';
    }
  }

  Future<bool> bulkUpdateProperties(
    List<String> propertyIds,
    Map<String, dynamic> updates,
  ) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');

    final url = Uri.parse('$baseUrl/api/v1/projects/property/bulk-update');

    try {
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'propertyIds': propertyIds, ...updates}),
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        final bodyData = response.body;
        try {
          final errorData = jsonDecode(bodyData);
          throw errorData['message'] ??
              'Failed to update properties (${response.statusCode})';
        } catch (_) {
          throw 'Failed to update properties: ${response.statusCode}';
        }
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<bool> bulkUpdateProjects(
    List<String> projectIds,
    Map<String, dynamic> updates,
  ) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');

    final url = Uri.parse('$baseUrl/api/v1/projects/bulk-update');

    try {
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'projectIds': projectIds, ...updates}),
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        final bodyData = response.body;
        try {
          final errorData = jsonDecode(bodyData);
          throw errorData['message'] ??
              'Failed to update projects (${response.statusCode})';
        } catch (_) {
          throw 'Failed to update projects: ${response.statusCode}';
        }
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<Map<String, dynamic>> getProjectShareMessage(String projectId) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');

    final url = Uri.parse('$baseUrl/api/v1/projects/$projectId/share');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Bypass-Tunnel-Reminder': 'true',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      try {
        final json = jsonDecode(response.body);
        return json['data'] as Map<String, dynamic>;
      } on FormatException catch (e) {
        dev.log(
          '[PropertyService] getProjectShareMessage JSON decode FAILED: $e',
          name: 'API',
        );
        throw 'Invalid server response for share message. Body: ${_extractPreview(response.body, 200)}';
      } catch (e) {
        dev.log(
          '[PropertyService] getProjectShareMessage model parse error: $e',
          name: 'API',
        );
        throw 'Failed to parse share message response: $e';
      }
    } else {
      throw 'Failed to fetch share message: ${response.statusCode}';
    }
  }

  Future<Map<String, dynamic>> getPropertyShareMessage(
    String propertyId,
  ) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');

    final url = Uri.parse(
      '$baseUrl/api/v1/projects/property/$propertyId/share',
    );

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Bypass-Tunnel-Reminder': 'true',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      try {
        final json = jsonDecode(response.body);
        return json['data'] as Map<String, dynamic>;
      } on FormatException catch (e) {
        dev.log(
          '[PropertyService] getPropertyShareMessage JSON decode FAILED: $e',
          name: 'API',
        );
        throw 'Invalid server response for share message. Body: ${_extractPreview(response.body, 200)}';
      } catch (e) {
        dev.log(
          '[PropertyService] getPropertyShareMessage model parse error: $e',
          name: 'API',
        );
        throw 'Failed to parse share message response: $e';
      }
    } else {
      throw 'Failed to fetch share message: ${response.statusCode}';
    }
  }
}
