import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'http_client.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/services/auth_service.dart';
import '../../data/models/attendance_config_model.dart';
import '../../data/models/role_labels_model.dart';

final settingsServiceProvider = Provider((ref) => SettingsService());

class SettingsService {
  
  Future<AttendanceConfigModel?> fetchAttendanceConfig() async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');
    
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/companyAttendanceConfig');
    debugPrint('SettingsService: Fetching Config: $uri');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('SettingsService: Response Status: ${response.statusCode}');
      debugPrint('SettingsService: Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null) {
          return AttendanceConfigModel.fromJson(data['data']);
        }
        return null;
      } else {
        throw 'Failed to fetch config: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('SettingsService Fetch Error: $e');
      throw e.toString();
    }
  }

  Future<void> createAttendanceConfig(AttendanceConfigModel config) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');
    
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/companyAttendanceConfig/create');
    debugPrint('SettingsService: Creating Config: $uri');

    final body = jsonEncode(config.toJson());

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      debugPrint('SettingsService: Create Response: ${response.statusCode} ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
         throw 'Failed to create config: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('SettingsService Create Error: $e');
      throw e.toString();
    }
  }

  Future<void> updateAttendanceConfig(AttendanceConfigModel config) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');
    
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/companyAttendanceConfig/update');
    debugPrint('SettingsService: Updating Config: $uri');

    final body = jsonEncode(config.toJson());

    try {
      final response = await http.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      debugPrint('SettingsService: Update Response: ${response.statusCode} ${response.body}');

      if (response.statusCode != 200) {
         throw 'Failed to update config: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('SettingsService Update Error: $e');
      throw e.toString();
    }
  }

  Future<RoleLabelsModel?> fetchRoleLabels() async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');
    
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/company/role-labels');
    debugPrint('SettingsService: Fetching Role Labels: $uri');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('SettingsService: Labels Response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null) {
          return RoleLabelsModel.fromJson(data['data']);
        }
        return null;
      } else {
        throw 'Failed to fetch labels: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('SettingsService Fetch Labels Error: $e');
      throw e.toString();
    }
  }

  Future<void> updateRoleLabels(RoleLabelsModel labels) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');
    
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/company/role-labels/update');
    debugPrint('SettingsService: Updating Role Labels: $uri');

    final body = jsonEncode(labels.toJson());

    try {
      final response = await http.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      debugPrint('SettingsService: Update Labels Response: ${response.statusCode} ${response.body}');

      if (response.statusCode != 200) {
         throw 'Failed to update labels: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('SettingsService Update Labels Error: $e');
      throw e.toString();
    }
  }

  Future<Map<String, dynamic>> fetchInvoiceSettings(String companyId) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');
    
    final companyUri = Uri.parse('${AuthService.baseUrl}/api/v1/company/getCompanyDetails/$companyId');

    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      debugPrint('SettingsService: Fetching bank accounts...');
      debugPrint('SettingsService: Fetching company details from $companyUri');

      final responses = await Future.wait([
        _getBankAccountsWithFallback(headers).catchError((e) {
          debugPrint('SettingsService: Bank Accounts call failed (graceful): $e');
          return http.Response('[]', 200);
        }),
        http.get(companyUri, headers: headers).catchError((e) {
          debugPrint('SettingsService: Company details call failed (graceful): $e');
          return http.Response('{}', 200);
        }),
      ]);

      final bankRes = responses[0];
      final companyRes = responses[1];

      final Map<String, dynamic> result = {};

      if (bankRes.statusCode == 200) {
        final data = jsonDecode(bankRes.body);
        debugPrint('SettingsService: Bank Accounts Response: ${bankRes.body}');
        final normalized = _normalizeBankAccounts(data);
        result['bankAccounts'] = normalized;
      } else {
        debugPrint('SettingsService: Bank List Failed: ${bankRes.statusCode} ${bankRes.body}');
        result['bankAccounts'] = [];
      }

      if (companyRes.statusCode == 200) {
        final data = jsonDecode(companyRes.body);
        debugPrint('SettingsService: Company Details Response: ${companyRes.body}');
        final rawData = data is Map ? data : <String, dynamic>{};
        final dataBlock = rawData['data'] is Map ? rawData['data'] as Map : rawData;
        final target = dataBlock['company'] is Map ? dataBlock['company'] as Map : dataBlock;
        result['invoiceTerms'] = target['invoiceTerms'] 
            ?? target['termsAndConditions'] 
            ?? dataBlock['invoiceTerms'] 
            ?? dataBlock['termsAndConditions']
            ?? rawData['invoiceTerms'] 
            ?? rawData['termsAndConditions'];
        result['logo'] = target['logo'] ?? dataBlock['logo'] ?? rawData['logo'];
      } else {
        debugPrint('SettingsService: Company Details Failed: ${companyRes.statusCode} ${companyRes.body}');
      }

      return result;
    } catch (e) {
      debugPrint('SettingsService Fetch Error: $e');
      return {};
    }
  }

  Future<http.Response> _getBankAccountsWithFallback(Map<String, String> headers) async {
    final pluralUri = Uri.parse('${AuthService.baseUrl}/api/v1/banks/company/list');
    final singularUri = Uri.parse('${AuthService.baseUrl}/api/v1/bank/company/list');
    
    try {
      debugPrint('SettingsService: Trying plural bank list endpoint: $pluralUri');
      final res = await http.get(pluralUri, headers: headers);
      return res;
    } catch (e) {
      debugPrint('SettingsService: Plural bank list endpoint failed: $e. Trying singular endpoint...');
      try {
        final res = await http.get(singularUri, headers: headers);
        return res;
      } catch (e2) {
        debugPrint('SettingsService: Singular bank list endpoint also failed: $e2');
        rethrow;
      }
    }
  }

  Future<List<dynamic>> fetchBankAccounts() async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');
    
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final response = await _getBankAccountsWithFallback(headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _normalizeBankAccounts(data);
      } else {
        throw 'Failed to fetch bank accounts';
      }
    } catch (e) {
      debugPrint('SettingsService fetchBankAccounts error: $e');
      rethrow;
    }
  }

  Future<void> createBankAccount({
    required String bankName,
    required String accountOwner,
    required String accountNumber,
    required String bankIfsc,
    required String upiId,
  }) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/bank/create');
    
    final payload = {
      'bankName': bankName,
      'accountOwner': accountOwner,
      'accountNumber': accountNumber,
      'bankIfsc': bankIfsc,
      'upiId': upiId,
    };
    
    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw 'Failed to create bank account: ${response.body}';
      }
    } catch (e) {
      debugPrint('SettingsService createBankAccount error: $e');
      rethrow;
    }
  }

  Future<void> updateBankAccount({
    required String id,
    required String bankName,
    required String accountOwner,
    required String accountNumber,
    required String bankIfsc,
    required String upiId,
    bool isDefault = false,
  }) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/bank/update/$id');
    
    final payload = {
      'bankName': bankName,
      'accountOwner': accountOwner,
      'accountNumber': accountNumber,
      'bankIfsc': bankIfsc,
      'upiId': upiId,
      'isDefault': isDefault,
    };
    
    try {
      final response = await http.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );
      if (response.statusCode != 200) {
        throw 'Failed to update bank account: ${response.body}';
      }
    } catch (e) {
      debugPrint('SettingsService updateBankAccount error: $e');
      rethrow;
    }
  }

  Future<void> deleteBankAccount(String id) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/bank/delete/$id');
    
    try {
      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode != 200) {
        throw 'Failed to delete bank account';
      }
    } catch (e) {
      debugPrint('SettingsService deleteBankAccount error: $e');
      rethrow;
    }
  }

  Future<void> updateCompany({
    required String id,
    String? name,
    String? email,
    String? contactPhone,
    String? address,
    String? logo,
    String? invoiceTerms,
  }) async {
    final authBox = await Hive.openBox('authBox');
    final token = authBox.get('accessToken');
    final uri = Uri.parse('${AuthService.baseUrl}/api/v1/company/update/$id');

    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (email != null) payload['email'] = email;
    if (contactPhone != null) payload['contactPhone'] = contactPhone;
    if (address != null) payload['address'] = address;
    if (logo != null) payload['logo'] = logo;
    if (invoiceTerms != null) payload['invoiceTerms'] = invoiceTerms;

    try {
      final response = await http.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );
      if (response.statusCode != 200) {
        throw 'Failed to update company details: ${response.body}';
      }
    } catch (e) {
      debugPrint('SettingsService updateCompany error: $e');
      rethrow;
    }
  }

  List<dynamic> _normalizeBankAccounts(dynamic data) {
    if (data == null) return [];
    if (data is List) return data;
    if (data is Map) {
      final accountsVal = data['accounts'];
      if (accountsVal != null) {
        if (accountsVal is List) return accountsVal;
        if (accountsVal is Map) return [accountsVal];
      }
      final dataVal = data['data'];
      if (dataVal != null) {
        if (dataVal is List) return dataVal;
        if (dataVal is Map) {
          final nestedAccounts = dataVal['accounts'];
          if (nestedAccounts != null) {
            if (nestedAccounts is List) return nestedAccounts;
            if (nestedAccounts is Map) return [nestedAccounts];
          }
          return [dataVal];
        }
      }
      final bankAccountsVal = data['bankAccounts'];
      if (bankAccountsVal != null) {
        if (bankAccountsVal is List) return bankAccountsVal;
        if (bankAccountsVal is Map) return [bankAccountsVal];
      }
      final banksVal = data['banks'];
      if (banksVal != null) {
        if (banksVal is List) return banksVal;
        if (banksVal is Map) return [banksVal];
      }
      final itemsVal = data['items'];
      if (itemsVal != null) {
        if (itemsVal is List) return itemsVal;
        if (itemsVal is Map) return [itemsVal];
      }
      final resultsVal = data['results'];
      if (resultsVal != null) {
        if (resultsVal is List) return resultsVal;
        if (resultsVal is Map) return [resultsVal];
      }
      if (data.containsKey('bankName') ||
          data.containsKey('accountNumber') ||
          data.containsKey('accountOwner') ||
          data.containsKey('accountNo') ||
          data.containsKey('ifscCode') ||
          data.containsKey('_id') ||
          data.containsKey('id')) {
        return [data];
      }
      final values = data.values.toList();
      for (final v in values) {
        if (v is List && v.isNotEmpty) {
          final first = v.first;
          if (first is Map && (first.containsKey('bankName') || first.containsKey('accountNumber') || first.containsKey('accountNo') || first.containsKey('_id'))) {
            return v;
          }
        }
        if (v is Map && (v.containsKey('bankName') || v.containsKey('accountNumber') || v.containsKey('accountNo') || v.containsKey('_id'))) {
          return [v];
        }
      }
      if (data.containsKey('success') || data.containsKey('message') || data.containsKey('statusCode')) {
        return [];
      }
      return [];
    }
    return [];
  }
}