import 'dart:convert';
import 'http_client.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'auth_service.dart';
import '../../data/models/invoice_model.dart';

class InvoiceService {
  Future<InvoicesResponse> fetchInvoices({
    int page = 1,
    int limit = 10,
    String? search,
    String? status,
    String? startDate,
    String? endDate,
    String? lead,
  }) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');

    if (accessToken == null) throw 'No access token found';

    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      if (search != null && search.isNotEmpty) 'searchQuery': search,
      if (status != null && status.isNotEmpty && status != 'All Statuses') 'status': status.toUpperCase(),
      if (startDate != null && startDate.isNotEmpty) 'from': startDate,
      if (endDate != null && endDate.isNotEmpty) 'to': endDate,
      if (lead != null && lead.isNotEmpty) 'lead': lead,
    };

    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/invoice/list').replace(queryParameters: queryParams);

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
        debugPrint('[InvoiceService] fetchInvoices response: ${jsonEncode(decoded)}');
        return InvoicesResponse.fromJson(decoded);
      } else {
        throw 'Failed to load invoices: ${response.statusCode}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<Invoice> fetchInvoiceDetails(String id) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/invoice/$id');

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
        debugPrint('[InvoiceService] Response: $data');
        final dataObj = data['data'] as Map<String, dynamic>?;
        if (dataObj != null && dataObj['invoice'] != null) {
          return Invoice.fromJson(dataObj['invoice'] as Map<String, dynamic>);
        } else if (dataObj != null && dataObj['_id'] != null) {
          return Invoice.fromJson(dataObj);
        } else if (data['invoice'] != null) {
          return Invoice.fromJson(data['invoice'] as Map<String, dynamic>);
        } else {
          return Invoice.fromJson(data);
        }
      } else {
        throw 'Failed to load invoice details: ${response.statusCode}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<bool> createInvoice(Map<String, dynamic> invoiceData) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/invoice/create');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(invoiceData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        throw 'Failed to create invoice: ${response.body}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<bool> updateInvoice(String id, Map<String, dynamic> invoiceData) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/invoice/update/$id');

    try {
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(invoiceData),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw 'Failed to update invoice: ${response.body}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<bool> updateInvoiceStatus(String id, String status) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/invoice/update-status/$id');

    try {
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'status': status.toUpperCase()}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw 'Failed to update status: ${response.body}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<bool> deleteInvoice(String id) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/invoice/delete/$id');

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
        throw 'Failed to delete invoice: ${response.body}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<String?> generateShareLink(String id) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/invoice/generate/$id');

    try {
      final response = await http.get(
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

  Future<bool> sendInvoiceEmail(String invoiceId, String email) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/invoice/send');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'invoiceId': invoiceId,
          'email': email,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Uint8List?> downloadInvoicePdf(String id) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/invoice/download/$id');
    debugPrint('[InvoiceService] Download URL: $url');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      debugPrint('[InvoiceService] Download response status: ${response.statusCode}');
      debugPrint('[InvoiceService] Download response length: ${response.bodyBytes.length}');

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw 'Failed to download invoice: ${response.statusCode}';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<String> getShareMessage(String id) async {
    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) throw 'No access token found';

    final url = Uri.parse('${AuthService.baseUrl}/api/v1/invoice/$id/share-message');

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
