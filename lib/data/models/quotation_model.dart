class Quotation {
  final String id;
  final String quotationNumber;
  final String quotationDate;
  final String validUntil;
  final String subject;
  final String status;
  final String clientName;
  final String clientEmail;
  final String clientPhoneNo;
  final String clientCompany;
  final String? itineraryId;
  final String? leadId;
  final BillingAddress billingAddress;
  final List<QuotationItem> items;
  final double subTotal;
  final double discountTotal;
  final double taxTotal;
  final double adjustment;
  final double grandTotal;
  final String termsAndConditions;

  Quotation({
    required this.id,
    required this.quotationNumber,
    required this.quotationDate,
    required this.validUntil,
    required this.subject,
    required this.status,
    required this.clientName,
    required this.clientEmail,
    required this.clientPhoneNo,
    required this.clientCompany,
    this.itineraryId,
    this.leadId,
    required this.billingAddress,
    required this.items,
    required this.subTotal,
    required this.discountTotal,
    required this.taxTotal,
    required this.adjustment,
    required this.grandTotal,
    required this.termsAndConditions,
  });

  factory Quotation.fromJson(Map<String, dynamic> json) {
    return Quotation(
      id: json['_id'] ?? json['id'] ?? '',
      quotationNumber: json['quotationNumber'] ?? '',
      quotationDate: json['quotationDate'] ?? '',
      validUntil: json['validUntil'] ?? '',
      subject: json['subject'] ?? '',
      status: json['status'] ?? 'CREATED',
      clientName: json['clientName'] ?? '',
      clientEmail: json['clientEmail'] ?? '',
      clientPhoneNo: json['clientPhoneNo'] ?? '',
      clientCompany: json['clientCompany'] ?? '',
      itineraryId: json['itinerary'] is Map ? json['itinerary']['_id'] : json['itinerary'],
      leadId: json['lead'] is Map ? json['lead']['_id'] : json['lead'],
      billingAddress: BillingAddress.fromJson(json['billingAddress'] ?? {}),
      items: (json['items'] as List? ?? []).map((i) => QuotationItem.fromJson(i)).toList(),
      subTotal: (json['subTotal'] ?? 0).toDouble(),
      discountTotal: (json['discountTotal'] ?? 0).toDouble(),
      taxTotal: (json['taxTotal'] ?? 0).toDouble(),
      adjustment: (json['adjustment'] ?? 0).toDouble(),
      grandTotal: (json['grandTotal'] ?? 0).toDouble(),
      termsAndConditions: json['termsAndConditions'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'quotationNumber': quotationNumber,
    'quotationDate': quotationDate,
    'validUntil': validUntil,
    'subject': subject,
    'status': status,
    'clientName': clientName,
    'clientEmail': clientEmail,
    'clientPhoneNo': clientPhoneNo,
    'clientCompany': clientCompany,
    'itinerary': itineraryId,
    'lead': leadId,
    'billingAddress': billingAddress.toJson(),
    'items': items.map((i) => i.toJson()).toList(),
    'subTotal': subTotal,
    'discountTotal': discountTotal,
    'taxTotal': taxTotal,
    'adjustment': adjustment,
    'grandTotal': grandTotal,
    'termsAndConditions': termsAndConditions,
  };
}

class BillingAddress {
  final String street;
  final String city;
  final String state;
  final String zip;
  final String country;

  BillingAddress({
    required this.street,
    required this.city,
    required this.state,
    required this.zip,
    required this.country,
  });

  factory BillingAddress.fromJson(Map<String, dynamic> json) {
    return BillingAddress(
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

class QuotationItem {
  final String itemId;
  final String name;
  final String description;
  final double quantity;
  final double unitPrice;
  final double discount;
  final double tax;
  final double amount;
  final double totalAmount;

  QuotationItem({
    required this.itemId,
    required this.name,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0,
    this.tax = 0,
    required this.amount,
    required this.totalAmount,
  });

  factory QuotationItem.fromJson(Map<String, dynamic> json) {
    return QuotationItem(
      itemId: json['itemId'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      quantity: (json['quantity'] ?? 0).toDouble(),
      unitPrice: (json['unitPrice'] ?? 0).toDouble(),
      discount: (json['discount'] ?? 0).toDouble(),
      tax: (json['tax'] ?? 0).toDouble(),
      amount: (json['amount'] ?? 0).toDouble(),
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'name': name,
    'description': description,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'discount': discount,
    'tax': tax,
    'amount': amount,
    'totalAmount': totalAmount,
  };
}
