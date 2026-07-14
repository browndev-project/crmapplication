import 'dart:convert';
import 'http_client.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'auth_service.dart';
import '../../data/models/voucher_model.dart';

class VoucherService {
  Future<VouchersResponse> fetchVouchers({
    int page = 1,
    int limit = 10,
    String? search,
    String? type,
    String? status,
    String? lead,
  }) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');

    if (accessToken == null) throw 'No access token found';

    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      if (search != null && search.isNotEmpty) 'searchQuery': search,
      if (type != null && type.isNotEmpty && type != 'All Types') 'voucherType': type.toUpperCase(),
      if (status != null && status.isNotEmpty && status != 'All Statuses') 'status': status.toUpperCase(),
      if (lead != null && lead.isNotEmpty) 'lead': lead,
    };

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/vouchers').replace(queryParameters: queryParams);

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        return VouchersResponse.fromJson(jsonDecode(response.body));
      } else {
        throw 'Failed to load vouchers: ${response.statusCode}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<Voucher> fetchVoucherDetails(String id) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/vouchers/$id');

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
        final dataObj = data['data'] as Map<String, dynamic>?;
        if (dataObj != null && dataObj['voucher'] != null) {
          return Voucher.fromJson(dataObj['voucher'] as Map<String, dynamic>);
        } else if (dataObj != null && dataObj['_id'] != null) {
          return Voucher.fromJson(dataObj);
        } else if (data['voucher'] != null) {
          return Voucher.fromJson(data['voucher'] as Map<String, dynamic>);
        } else {
          return Voucher.fromJson(data);
        }
      } else {
        throw 'Failed to load voucher details: ${response.statusCode}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<bool> createVoucher(Map<String, dynamic> voucherData) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/vouchers');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(voucherData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        throw 'Failed to create voucher: ${response.body}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<bool> updateVoucher(String id, Map<String, dynamic> voucherData) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/vouchers/$id');

    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(voucherData),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw 'Failed to update voucher: ${response.body}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<bool> deleteVoucher(String id) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/vouchers/$id');

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
        throw 'Failed to delete voucher: ${response.body}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<String?> generateShareLink(String id) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/vouchers/$id/generate-link');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['pdfUrl'] ?? data['data']?['pdfUrl'];
      } else {
        throw 'Failed to generate link: ${response.statusCode}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<Uint8List?> downloadVoucherPdf(String id) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/vouchers/$id/pdf');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw 'Failed to download voucher: ${response.statusCode}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<String> getShareMessage(String id) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/vouchers/$id/share-message');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final dataObj = data['data'] as Map<String, dynamic>?;
      return dataObj?['message'] ?? data['message'] ?? '';
    } else {
      throw 'Failed to fetch share message: ${response.statusCode}';
    }
  }
}
