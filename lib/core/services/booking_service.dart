import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'http_client.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'auth_service.dart';
import '../../data/models/booking_model.dart';
import '../../data/models/property_model.dart';
import '../../data/models/broker_model.dart';

class BookingService {
  Future<BookingResponse> fetchBookingStats() async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/bookings/stats');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        return BookingResponse.fromJson(jsonDecode(response.body));
      } else {
        throw 'Failed to load booking stats: ${response.statusCode}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<BookingResponse> fetchBookings({int page = 1, int limit = 10, String? searchQuery, String? status, String? leadId,}) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      if (searchQuery != null && searchQuery.isNotEmpty) 'searchQuery': searchQuery,
      if (status != null && status.isNotEmpty && status != 'all') 'status': status.toLowerCase(),
      if (leadId != null && leadId.isNotEmpty) 'lead': leadId,
    };

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/bookings/list').replace(queryParameters: queryParams);

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        return BookingResponse.fromJson(jsonDecode(response.body));
      } else {
        throw 'Failed to load bookings: ${response.statusCode}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<Booking> createBooking(Map<String, dynamic> bookingData) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/bookings/create');

    debugPrint('🚀 [API REQUEST] POST $uri');
    debugPrint('🚀 [API HEADERS] Authorization: Bearer $accessToken');
    debugPrint('🚀 [API PAYLOAD] ${jsonEncode(bookingData)}');

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(bookingData),
      );

      debugPrint('📥 [API RESPONSE] STATUS: ${response.statusCode}');
      debugPrint('📥 [API RESPONSE] BODY: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        final bookingJson = decoded['data'] != null 
            ? (decoded['data']['booking'] ?? decoded['data'])
            : decoded;
        return Booking.fromJson(bookingJson);
      } else {
        throw 'Failed to create booking: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      debugPrint('❌ [API ERROR] $e');
      throw e.toString();
    }
  }

  Future<bool> updateBooking(String id, Map<String, dynamic> bookingData) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/bookings/update/$id');

    debugPrint('🚀 [API REQUEST] PATCH $uri');
    debugPrint('🚀 [API HEADERS] Authorization: Bearer $accessToken');
    debugPrint('🚀 [API PAYLOAD] ${jsonEncode(bookingData)}');

    try {
      final response = await http.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(bookingData),
      );

      debugPrint('📥 [API RESPONSE] STATUS: ${response.statusCode}');
      debugPrint('📥 [API RESPONSE] BODY: ${response.body}');

      if (response.statusCode == 200) {
        return true;
      } else {
        throw 'Failed to update booking: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      debugPrint('❌ [API ERROR] $e');
      throw e.toString();
    }
  }

  Future<bool> deleteBooking(String id) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/bookings/$id');

    try {
      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      throw e.toString();
    }
  }

  Future<List<PropertyName>> fetchAvailableProperties() async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/projects/property/names?status=available');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic>? rawProperties;
        if (decoded is List) {
          rawProperties = decoded;
        } else if (decoded is Map) {
          final data = decoded['data'];
          if (data is List) {
            rawProperties = data;
          } else if (data is Map) {
            rawProperties = data['properties'] ?? data['data'] ?? data['list'];
          }
          rawProperties ??= decoded['properties'] ?? decoded['data'] ?? decoded['list'];
        }

        if (rawProperties is List) {
          return rawProperties.map((i) => PropertyName.fromJson(Map<String, dynamic>.from(i))).toList();
        }
        return <PropertyName>[];
      } else {
        throw 'Failed to load properties: ${response.statusCode}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<List<Broker>> fetchActiveBrokers() async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/brokers/list?status=active');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic>? rawBrokers;
        if (decoded is List) {
          rawBrokers = decoded;
        } else if (decoded is Map) {
          final data = decoded['data'];
          if (data is List) {
            rawBrokers = data;
          } else if (data is Map) {
            rawBrokers = data['brokers'] ?? data['data'] ?? data['list'];
          }
          rawBrokers ??= decoded['brokers'] ?? decoded['data'] ?? decoded['list'];
        }

        if (rawBrokers is List) {
          return rawBrokers.map((i) => Broker.fromJson(i)).toList();
        }
        return <Broker>[];
      } else {
        throw 'Failed to load partners: ${response.statusCode}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<Property> fetchPropertyDetails(String propertyId) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/projects/property/$propertyId');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final propData = decoded['data'] != null ? (decoded['data']['property'] ?? decoded['data']) : decoded;
        return Property.fromJson(propData);
      } else if (response.statusCode == 404) {
        throw 'Property not found or may have been deleted';
      } else {
        throw 'Failed to fetch property details: ${response.statusCode}';
      }
    } catch (e) {
      throw e.toString();
    }
  }
}
