
class BankAccount {
  final String id;
  final String accountOwner;
  final String bankName;
  final String bankIfsc;
  final String accountNumber;
  final String upiId;
  final bool isDefault;

  BankAccount({
    this.id = '',
    required this.accountOwner,
    required this.bankName,
    required this.bankIfsc,
    required this.accountNumber,
    this.upiId = '',
    this.isDefault = false,
  });

factory BankAccount.fromJson(Map<String, dynamic> json) {
    return BankAccount(
      id: json['_id'] ?? json['id'] ?? '',
      accountOwner: json['accountOwner'] ?? json['account_owner'] ?? json['owner'] ?? '',
      bankName: json['bankName'] ?? json['bank_name'] ?? json['bank'] ?? '',
      bankIfsc: json['bankIfsc'] ?? json['bank_ifsc'] ?? json['ifscCode'] ?? json['ifsc_code'] ?? json['ifsc'] ?? '',
      accountNumber: json['accountNumber'] ?? json['account_number'] ?? json['number'] ?? json['accountNo'] ?? '',
      upiId: json['upiId'] ?? json['upi_id'] ?? json['upi'] ?? '',
      isDefault: json['isDefault'] ?? json['is_default'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'accountOwner': accountOwner,
    'bankName': bankName,
    'bankIfsc': bankIfsc,
    'accountNumber': accountNumber,
    'upiId': upiId,
    'isDefault': isDefault,
  };
}

class CompanySettingsModel {
  final List<BankAccount> bankAccounts;
  final String invoiceDefaultTerms;
  final String logo;

  CompanySettingsModel({
    required this.bankAccounts,
    required this.invoiceDefaultTerms,
    this.logo = '',
  });

  factory CompanySettingsModel.fromJson(Map<String, dynamic> json) {
    final rawBankAccounts = json['bankAccounts'];
    List<dynamic> normalizedList = [];

    if (rawBankAccounts is List) {
      normalizedList = rawBankAccounts;
    } else if (rawBankAccounts is Map) {
      final dataVal = rawBankAccounts['data'];
      final bankAccountsVal = rawBankAccounts['bankAccounts'];
      
      // 1. Support nested data.accounts format
      if (dataVal is Map && dataVal['accounts'] is List) {
        normalizedList = dataVal['accounts'];
      } else if (rawBankAccounts['accounts'] is List) {
        normalizedList = rawBankAccounts['accounts'];
      } else if (dataVal is List) {
        normalizedList = dataVal;
      } else if (dataVal is Map) {
        normalizedList = [dataVal];
      } else if (bankAccountsVal is List) {
        normalizedList = bankAccountsVal;
      } else if (bankAccountsVal is Map) {
        normalizedList = [bankAccountsVal];
      } else {
        normalizedList = [rawBankAccounts];
      }
    }

    bool looksLikeBankAccount(Map m) =>
        m.containsKey('bankName') ||
        m.containsKey('bank_name') ||
        m.containsKey('bank') ||
        m.containsKey('accountNumber') ||
        m.containsKey('account_number') ||
        m.containsKey('accountNo') ||
        m.containsKey('account_no') ||
        m.containsKey('accountOwner') ||
        m.containsKey('account_owner') ||
        m.containsKey('owner') ||
        m.containsKey('bankIfsc') ||
        m.containsKey('ifscCode') ||
        m.containsKey('ifsc_code') ||
        m.containsKey('_id') ||
        m.containsKey('id');

    final bankList = <BankAccount>[];
    for (final e in normalizedList) {
      if (e is Map<String, dynamic>) {
        if (looksLikeBankAccount(e)) {
          bankList.add(BankAccount.fromJson(e));
        }
      } else if (e is Map) {
        final m = Map<String, dynamic>.from(e);
        if (looksLikeBankAccount(m)) {
          bankList.add(BankAccount.fromJson(m));
        }
      }
    }

    return CompanySettingsModel(
      bankAccounts: bankList,
      invoiceDefaultTerms: json['invoiceDefaultTerms'] ?? json['termsAndConditions'] ?? '',
      logo: json['logo'] ?? '',
    );
  }
}
