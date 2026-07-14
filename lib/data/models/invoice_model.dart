import 'package:flutter/foundation.dart';

class InvoiceAddress {
  final String street;
  final String city;
  final String state;
  final String zip;
  final String country;

  InvoiceAddress({
    this.street = '',
    this.city = '',
    this.state = '',
    this.zip = '',
    this.country = '',
  });

  factory InvoiceAddress.fromJson(Map<String, dynamic> json) {
    return InvoiceAddress(
      street: json['street'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      zip: json['zip'] ?? '',
      country: json['country'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'street': street,
    'city': city,
    'state': state,
    'zip': zip,
    'country': country,
  };
}

class InvoiceItem {
  final String itemType; // 'PRODUCT' or 'SERVICE'
  final String name;
  final String description;
  final double quantity;
  final double unitPrice;
  final double discount;
  final double tax;
  final double amount; // quantity * unitPrice
  final double total; // (quantity * unitPrice) + tax - discount

  InvoiceItem({
    required this.itemType,
    required this.name,
    this.description = '',
    required this.quantity,
    required this.unitPrice,
    this.discount = 0,
    this.tax = 0,
    required this.amount,
    required this.total,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    final q = (json['quantity'] ?? 0).toDouble();
    final p = (json['unitPrice'] ?? 0).toDouble();
    final t = (json['tax'] ?? 0).toDouble();
    final d = (json['discount'] ?? 0).toDouble();
    final amt = (json['amount'] ?? (q * p)).toDouble();
    final ttl = (json['total'] ?? (amt + t - d)).toDouble();

    return InvoiceItem(
      itemType: json['itemType'] ?? 'PRODUCT',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      quantity: q,
      unitPrice: p,
      discount: d,
      tax: t,
      amount: amt,
      total: ttl,
    );
  }

  Map<String, dynamic> toJson() => {
    'itemType': itemType,
    'name': name,
    'description': description,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'discount': discount,
    'tax': tax,
    'amount': amount,
    'total': total,
  };
}

class InvoiceAccount {
  final String accountOwner;
  final String bankName;
  final String bankIfsc;
  final String accountNumber;
  final String upiId;

  InvoiceAccount({
    this.accountOwner = '',
    this.bankName = '',
    this.bankIfsc = '',
    this.accountNumber = '',
    this.upiId = '',
  });

  factory InvoiceAccount.fromJson(Map<String, dynamic> json) {
    final accountMap = json['account'] is Map 
        ? Map<String, dynamic>.from(json['account'] as Map) 
        : json;

    String getVal(String camel, String snake, String fallback1, [String? fallback2]) {
      var val = accountMap[camel] ?? accountMap[snake] ?? accountMap[fallback1];
      if (fallback2 != null) val ??= accountMap[fallback2];
      if (val != null && val.toString().trim().isNotEmpty) return val.toString().trim();

      val = json[camel] ?? json[snake] ?? json[fallback1];
      if (fallback2 != null) val ??= json[fallback2];
      if (val != null && val.toString().trim().isNotEmpty) return val.toString().trim();

      return '';
    }

    return InvoiceAccount(
      accountOwner: getVal('accountOwner', 'account_owner', 'owner'),
      bankName: getVal('bankName', 'bank_name', 'bank'),
      bankIfsc: getVal('bankIfsc', 'bank_ifsc', 'ifscCode', 'ifsc'),
      accountNumber: getVal('accountNumber', 'account_number', 'number'),
      upiId: getVal('upiId', 'upi_id', 'upi'),
    );
  }

  Map<String, dynamic> toJson() => {
    'accountOwner': accountOwner,
    'bankName': bankName,
    'bankIfsc': bankIfsc,
    'accountNumber': accountNumber,
    'upiId': upiId,
  };
}

class Invoice {
  final String id;
  final String invoiceNumber;
  final String? subject;
  final String? category;
  final String status;
  final String invoiceDate;
  final String dueDate;
  final String? dealDate;
  
  // Client Details
  final String clientPhoneNo;
  final String clientCompany;
  final String clientName;
  final String clientEmail;

  final String? leadId; // Reference to Lead
  final String? leadReference; // Display ID of Lead

  final InvoiceAddress billingAddress;
  final InvoiceAddress shippingAddress;

  final List<InvoiceItem> items;

  // Totals
  final double subTotal;
  final double discountTotal;
  final double taxTotal;
  final double adjustment;
  final double grandTotal;

  final InvoiceAccount account;
  final String termsAndConditions;
  final String description;

  final String createdAt;
  final String updatedAt;
  final String? createdBy;
  final String? invoiceLink;

  Invoice({
    required this.id,
    required this.invoiceNumber,
    this.subject,
    this.category,
    required this.status,
    required this.invoiceDate,
    required this.dueDate,
    this.dealDate,
    required this.clientPhoneNo,
    required this.clientCompany,
    required this.clientName,
    required this.clientEmail,
    this.leadId,
    this.leadReference,
    required this.billingAddress,
    required this.shippingAddress,
    required this.items,
    required this.subTotal,
    this.discountTotal = 0,
    this.taxTotal = 0,
    this.adjustment = 0,
    required this.grandTotal,
    required this.account,
    this.termsAndConditions = '',
    this.description = '',
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.invoiceLink,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['_id'] ?? '',
      invoiceNumber: json['invoiceNumber'] ?? '',
      subject: json['subject'],
      category: json['category'],
      status: json['status'] ?? 'DRAFT',
      invoiceDate: json['invoiceDate'] ?? '',
      dueDate: json['dueDate'] ?? '',
      dealDate: json['dealDate'],
      clientPhoneNo: json['clientPhoneNo'] ?? '',
      clientCompany: json['clientCompany'] ?? '',
      clientName: json['clientName'] ?? '',
      clientEmail: json['clientEmail'] ?? '',
      leadId: json['lead'] is Map ? json['lead']['_id'] : json['lead'],
      leadReference: json['lead'] is Map ? json['lead']['leadId'] : null,
      billingAddress: InvoiceAddress.fromJson(json['billingAddress'] ?? {}),
      shippingAddress: InvoiceAddress.fromJson(json['shippingAddress'] ?? {}),
      items: (json['items'] as List?)?.map((e) => InvoiceItem.fromJson(e)).toList() ?? [],
      subTotal: (json['subTotal'] ?? 0).toDouble(),
      discountTotal: (json['discountTotal'] ?? (json['discount'] ?? 0)).toDouble(),
      taxTotal: (json['taxTotal'] ?? (json['tax'] ?? 0)).toDouble(),
      adjustment: (json['adjustment'] ?? 0).toDouble(),
      grandTotal: (json['grandTotal'] ?? 0).toDouble(),
      account: InvoiceAccount.fromJson(json),
      termsAndConditions: json['termsAndConditions'] ?? '',
      description: json['description'] ?? '',
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
      createdBy: json['createdBy'] is Map ? json['createdBy']['name'] : json['createdBy'],
      invoiceLink: json['invoiceLink'],
    );
  }

  Map<String, dynamic> toJson() => {
    'subject': subject,
    'category': category,
    'status': status,
    'invoiceDate': invoiceDate,
    'dueDate': dueDate,
    'dealDate': dealDate,
    'clientPhoneNo': clientPhoneNo,
    'clientCompany': clientCompany,
    'clientName': clientName,
    'clientEmail': clientEmail,
    'leadId': leadId,
    'billingAddress': billingAddress.toJson(),
    'shippingAddress': shippingAddress.toJson(),
    'items': items.map((e) => e.toJson()).toList(),
    'adjustment': adjustment,
    'account': account.toJson(),
    'termsAndConditions': termsAndConditions,
    'description': description,
  };
}

class InvoicesResponse {
  final List<Invoice> invoices;
  final int totalCount;
  final int totalPages;
  final int currentPage;
  final int totalInvoices;
  final int paidInvoices;

  InvoicesResponse({
    required this.invoices,
    required this.totalCount,
    required this.totalPages,
    required this.currentPage,
    this.totalInvoices = 0,
    this.paidInvoices = 0,
  });

  factory InvoicesResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? {};
    final invoicesList = (data['invoices'] as List?)?.map((e) => Invoice.fromJson(e)).toList() ?? [];
    final pagination = data['pagination'] ?? {};

    final totalInvoices = data['summary']?['totalInvoices'] ?? data['totalCount'] ?? 0;
    final backendPaid = data['summary']?['paidInvoices'] ?? 0;
    final localPaid = invoicesList.where((inv) => inv.status.toUpperCase() == 'PAID').length;

    if (backendPaid != localPaid) {
      debugPrint('[InvoicesResponse] MISMATCH: backend paidInvoices=$backendPaid vs local PAID count=$localPaid');
    }

    return InvoicesResponse(
      invoices: invoicesList,
      totalCount: data['totalCount'] ?? (pagination['total'] ?? 0),
      totalPages: pagination['totalPages'] ?? 1,
      currentPage: pagination['page'] ?? 1,
      totalInvoices: totalInvoices,
      paidInvoices: localPaid,
    );
  }
}
