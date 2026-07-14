// ignore_for_file: constant_identifier_names

enum VoucherType { HOTEL, TRAVEL }

double _parseDouble(dynamic val) {
  if (val == null) return 0.0;
  if (val is num) return val.toDouble();
  return double.tryParse(val.toString()) ?? 0.0;
}

int _parseInt(dynamic val) {
  if (val == null) return 0;
  if (val is num) return val.toInt();
  return int.tryParse(val.toString()) ?? 0;
}

int? _parseIntNullable(dynamic val) {
  if (val == null) return null;
  if (val is num) return val.toInt();
  return int.tryParse(val.toString());
}

String _parseStringOrList(dynamic val, {String joiner = ', '}) {
  if (val == null) return '';
  if (val is List) {
    return val.map((e) => e.toString()).join(joiner);
  }
  return val.toString();
}

class HotelDetails {
  final String name;
  final String address;
  final String contact;
  final String gstNo;
  final String imageUrl;

  HotelDetails({
    this.name = '',
    this.address = '',
    this.contact = '',
    this.gstNo = '',
    this.imageUrl = '',
  });

  factory HotelDetails.fromJson(Map<String, dynamic> json) {
    return HotelDetails(
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      contact: json['contact'] ?? '',
      gstNo: json['gstNo'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'address': address,
    'contact': contact,
    'gstNo': gstNo,
    'imageUrl': imageUrl,
  };
}

class VoucherItem {
  final String itemType;
  final String name;
  final String description;
  final double quantity;
  final double price;
  final double discount;
  final double tax;
  final double amount;

  VoucherItem({
    required this.itemType,
    this.name = '',
    this.description = '',
    required this.quantity,
    required this.price,
    this.discount = 0,
    this.tax = 0,
    required this.amount,
  });

  factory VoucherItem.fromJson(Map<String, dynamic> json) {
    return VoucherItem(
      itemType: json['itemType'] ?? 'HOTEL',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      quantity: _parseDouble(json['quantity']),
      price: _parseDouble(json['price']),
      discount: _parseDouble(json['discount']),
      tax: _parseDouble(json['tax']),
      amount: _parseDouble(json['amount']),
    );
  }

  Map<String, dynamic> toJson() => {
    'itemType': itemType,
    'name': name,
    'description': description,
    'quantity': quantity,
    'price': price,
    'discount': discount,
    'tax': tax,
    'amount': amount,
  };
}

class Guest {
  final String name;
  final int age;
  final String gender;
  final String type; // Adult, Child, etc.

  Guest({
    required this.name,
    required this.age,
    required this.gender,
    required this.type,
  });

  factory Guest.fromJson(Map<String, dynamic> json) {
    return Guest(
      name: json['name'] ?? '',
      age: _parseInt(json['age']),
      gender: json['gender'] ?? 'Male',
      type: json['type'] ?? 'Adult',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'age': age,
    'gender': gender,
    'type': type,
  };
}

class VoucherFinancials {
  final double subTotal;
  final double discountTotal;
  final double taxTotal;
  final double totalAmount;
  final double advancePaid;
  final double balanceAmount;

  VoucherFinancials({
    this.subTotal = 0,
    this.discountTotal = 0,
    this.taxTotal = 0,
    this.totalAmount = 0,
    this.advancePaid = 0,
    this.balanceAmount = 0,
  });

  factory VoucherFinancials.fromJson(Map<String, dynamic> json) {
    return VoucherFinancials(
      subTotal: _parseDouble(json['subTotal']),
      discountTotal: _parseDouble(json['discountTotal']),
      taxTotal: _parseDouble(json['taxTotal']),
      totalAmount: _parseDouble(json['totalAmount']),
      advancePaid: _parseDouble(json['advancePaid']),
      balanceAmount: _parseDouble(json['balanceAmount']),
    );
  }

  Map<String, dynamic> toJson() => {
    'subTotal': subTotal,
    'discountTotal': discountTotal,
    'taxTotal': taxTotal,
    'totalAmount': totalAmount,
    'advancePaid': advancePaid,
    'balanceAmount': balanceAmount,
  };
}

class Voucher {
  final String id;
  final String voucherType;
  final String voucherNo;
  final String voucherDate;
  final String clientName;
  final String clientPhone;
  final String clientEmail;
  final String clientAddress;
  final String? leadId;
  
  // Hotel fields
  final String? checkIn;
  final String? checkOut;
  final int? noOfRooms;
  final HotelDetails? hotelDetails;

  // Travel fields
  final String? travelStartDate;
  final String? travelEndDate;
  final double? travelTotalKms;

  final List<VoucherItem> items;
  final List<Guest> guestList;
  final VoucherFinancials financials;
  final String termsAndConditions;
  final String inclusions;
  final String status;
  final String? voucherLink;
  final String createdAt;
  final String updatedAt;

  Voucher({
    required this.id,
    required this.voucherType,
    required this.voucherNo,
    required this.voucherDate,
    required this.clientName,
    required this.clientPhone,
    required this.clientEmail,
    required this.clientAddress,
    this.leadId,
    this.checkIn,
    this.checkOut,
    this.noOfRooms,
    this.hotelDetails,
    this.travelStartDate,
    this.travelEndDate,
    this.travelTotalKms,
    required this.items,
    required this.guestList,
    required this.financials,
    this.termsAndConditions = '',
    this.inclusions = '',
    required this.status,
    this.voucherLink,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Voucher.fromJson(Map<String, dynamic> json) {
    return Voucher(
      id: json['_id'] ?? '',
      voucherType: json['voucherType'] ?? 'HOTEL',
      voucherNo: json['voucherNo'] ?? '',
      voucherDate: json['voucherDate'] ?? '',
      clientName: json['clientName'] ?? '',
      clientPhone: json['clientPhone'] ?? '',
      clientEmail: json['clientEmail'] ?? '',
      clientAddress: json['clientAddress'] ?? '',
      leadId: json['lead'] is Map ? json['lead']['_id'] : json['lead'],
      checkIn: json['checkIn'],
      checkOut: json['checkOut'],
      noOfRooms: _parseIntNullable(json['noOfRooms']),
      hotelDetails: json['hotelDetails'] != null ? HotelDetails.fromJson(json['hotelDetails']) : null,
      travelStartDate: json['travelStartDate'],
      travelEndDate: json['travelEndDate'],
      travelTotalKms: _parseDouble(json['travelTotalKms']),
      items: (json['items'] as List?)?.map((e) => VoucherItem.fromJson(e)).toList() ?? [],
      guestList: (json['guestList'] as List?)?.map((e) => Guest.fromJson(e)).toList() ?? [],
      financials: VoucherFinancials.fromJson(json['financials'] ?? {}),
      termsAndConditions: _parseStringOrList(json['termsAndConditions'], joiner: '\n'),
      inclusions: _parseStringOrList(json['inclusions'], joiner: ', '),
      status: json['status'] ?? 'ISSUED',
      voucherLink: json['voucherLink'],
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'voucherType': voucherType,
    'voucherNo': voucherNo,
    'voucherDate': voucherDate,
    'clientName': clientName,
    'clientPhone': clientPhone,
    'clientEmail': clientEmail,
    'clientAddress': clientAddress,
    'lead': leadId,
    if (voucherType == 'HOTEL') ...{
      'checkIn': checkIn,
      'checkOut': checkOut,
      'noOfRooms': noOfRooms,
      'hotelDetails': hotelDetails?.toJson(),
    },
    if (voucherType == 'TRAVEL') ...{
      'travelStartDate': travelStartDate,
      'travelEndDate': travelEndDate,
      'travelTotalKms': travelTotalKms,
    },
    'items': items.map((e) => e.toJson()).toList(),
    'guestList': guestList.map((e) => e.toJson()).toList(),
    'financials': financials.toJson(),
    'termsAndConditions': termsAndConditions,
    'inclusions': inclusions,
  };
}

class VouchersResponse {
  final List<Voucher> vouchers;
  final int totalCount;
  final int totalPages;
  final int currentPage;
  final double totalValue;
  final int uniqueClients;

  VouchersResponse({
    required this.vouchers,
    required this.totalCount,
    required this.totalPages,
    required this.currentPage,
    this.totalValue = 0,
    this.uniqueClients = 0,
  });

  factory VouchersResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? {};
    final list = (data['vouchers'] as List?)?.map((e) => Voucher.fromJson(e)).toList() ?? [];
    final pagination = data['pagination'] ?? {};

    return VouchersResponse(
      vouchers: list,
      totalCount: _parseInt(data['totalCount'] ?? pagination['total']),
      totalPages: _parseInt(pagination['totalPages'] ?? 1),
      currentPage: _parseInt(pagination['page'] ?? 1),
      totalValue: _parseDouble(data['summary']?['totalValue']),
      uniqueClients: _parseInt(data['summary']?['uniqueClients']),
    );
  }
}
