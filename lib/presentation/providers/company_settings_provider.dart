
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/settings_service.dart';
import '../../data/models/company_settings_model.dart';
import '../providers/login_provider.dart';

final companySettingsProvider = FutureProvider<CompanySettingsModel?>((ref) async {
  final user = ref.watch(loginProvider).user;
  debugPrint('companySettingsProvider: Initialized for user: ${user?.name} (${user?.uniqueId}), company: "${user?.company}"');
  
  if (user == null || user.company.trim().isEmpty) {
    debugPrint('companySettingsProvider: Skipping settings fetch - user or company string is empty/null.');
    return null;
  }

  final service = ref.read(settingsServiceProvider);
  try {
    debugPrint('companySettingsProvider: Fetching company settings for ID: ${user.company}');
    final data = await service.fetchInvoiceSettings(user.company);
    debugPrint('companySettingsProvider: Successfully fetched raw settings map keys: ${data.keys}');
    debugPrint('companySettingsProvider: Bank Accounts List count: ${(data['bankAccounts'] as List?)?.length}');
    
    final model = CompanySettingsModel.fromJson({
      'bankAccounts': data['bankAccounts'],
      'invoiceDefaultTerms': data['invoiceTerms'],
      'logo': data['logo'],
    });
    
    debugPrint('companySettingsProvider: Config Model mapped successfully! Default terms length: ${model.invoiceDefaultTerms.length}');
    return model;
  } catch (e, stackTrace) {
    debugPrint('companySettingsProvider: ERROR fetching company settings: $e');
    debugPrint('companySettingsProvider: StackTrace: $stackTrace');
    return null;
  }
});
