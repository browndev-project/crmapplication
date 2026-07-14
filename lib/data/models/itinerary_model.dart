import 'voucher_model.dart';

class MealsV2 {
  final bool breakfast;
  final bool lunch;
  final bool dinner;

  MealsV2({
    this.breakfast = false,
    this.lunch = false,
    this.dinner = false,
  });

  factory MealsV2.fromJson(Map<String, dynamic> json) {
    return MealsV2(
      breakfast: json['breakfast'] ?? false,
      lunch: json['lunch'] ?? false,
      dinner: json['dinner'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'breakfast': breakfast,
      'lunch': lunch,
      'dinner': dinner,
    };
  }

  MealsV2 copyWith({
    bool? breakfast,
    bool? lunch,
    bool? dinner,
  }) {
    return MealsV2(
      breakfast: breakfast ?? this.breakfast,
      lunch: lunch ?? this.lunch,
      dinner: dinner ?? this.dinner,
    );
  }
}

class DayPlan {
  final String name;
  final String title;
  final String description;
  final String image;
  final MealsV2 meals;
  final String notes;

  DayPlan({
    required this.name,
    required this.title,
    required this.description,
    required this.image,
    required this.meals,
    required this.notes,
  });

  factory DayPlan.fromJson(Map<String, dynamic> json) {
    return DayPlan(
      name: json['name'] ?? json['title'] ?? '',
      title: json['title'] ?? json['name'] ?? '',
      description: json['description'] ?? '',
      image: json['image'] ?? '',
      meals: MealsV2.fromJson(json['meals'] ?? {}),
      notes: json['notes'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'title': title,
      'description': description,
      'image': image,
      'meals': meals.toJson(),
      'notes': notes,
    };
  }

  DayPlan copyWith({
    String? name,
    String? title,
    String? description,
    String? image,
    MealsV2? meals,
    String? notes,
  }) {
    return DayPlan(
      name: name ?? this.name,
      title: title ?? this.title,
      description: description ?? this.description,
      image: image ?? this.image,
      meals: meals ?? this.meals,
      notes: notes ?? this.notes,
    );
  }
}

class StayV2 {
  final String id;
  final String name;
  final String checkIn;
  final String checkOut;
  final String category;
  final int noOfNights;
  final double pricePerNight;
  final String image;
  final String description;

  StayV2({
    this.id = '',
    required this.name,
    this.checkIn = '',
    this.checkOut = '',
    this.category = '',
    required this.noOfNights,
    required this.pricePerNight,
    required this.image,
    required this.description,
  });

  factory StayV2.fromJson(Map<String, dynamic> json) {
    return StayV2(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      checkIn: json['checkIn'] ?? '',
      checkOut: json['checkOut'] ?? '',
      category: json['category'] ?? '',
      noOfNights: json['noOfNights'] ?? json['nights'] ?? 0,
      pricePerNight: (json['pricePerNight'] ?? 0).toDouble(),
      image: json['image'] ?? '',
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'checkIn': checkIn,
      'checkOut': checkOut,
      'category': category,
      'noOfNights': noOfNights,
      'pricePerNight': pricePerNight,
      'image': image,
      'description': description,
    };
  }

  StayV2 copyWith({
    String? id,
    String? name,
    String? checkIn,
    String? checkOut,
    String? category,
    int? noOfNights,
    double? pricePerNight,
    String? image,
    String? description,
  }) {
    return StayV2(
      id: id ?? this.id,
      name: name ?? this.name,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      category: category ?? this.category,
      noOfNights: noOfNights ?? this.noOfNights,
      pricePerNight: pricePerNight ?? this.pricePerNight,
      image: image ?? this.image,
      description: description ?? this.description,
    );
  }
}

class TransportV2 {
  final String id;
  final String type;
  final String details;
  final double price;

  TransportV2({
    this.id = '',
    required this.type,
    required this.details,
    required this.price,
  });

  factory TransportV2.fromJson(Map<String, dynamic> json) {
    return TransportV2(
      id: json['id'] ?? json['_id'] ?? '',
      type: json['type'] ?? '',
      details: json['details'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'details': details,
      'price': price,
    };
  }

  TransportV2 copyWith({
    String? id,
    String? type,
    String? details,
    double? price,
  }) {
    return TransportV2(
      id: id ?? this.id,
      type: type ?? this.type,
      details: details ?? this.details,
      price: price ?? this.price,
    );
  }
}

class PolicyV2 {
  final String title;
  final String description;

  PolicyV2({
    required this.title,
    required this.description,
  });

  factory PolicyV2.fromJson(Map<String, dynamic> json) {
    return PolicyV2(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
    };
  }

  PolicyV2 copyWith({
    String? title,
    String? description,
  }) {
    return PolicyV2(
      title: title ?? this.title,
      description: description ?? this.description,
    );
  }
}

class ItineraryV2 {
  final String id;
  final String subject;
  final String customerName;
  final String customerCompany;
  final String customerEmail;
  final String customerPhone;
  final String startDate;
  final int noOfDays;
  final List<String> keyLocations;
  final String shortDescription;
  final String heroImage;
  final List<DayPlan> sections;
  final List<StayV2> stays;
  final List<TransportV2> transports;
  final double activitiesCost;
  final double totalPrice;
  final double pricePerAdult;
  final int adults;
  final int kids;
  final int rooms;
  final List<String> keyInclusions;
  final List<String> keyExclusions;
  final List<PolicyV2> termsAndConditions;
  final String createdAt;
  final String? templateKey;
  final String? templateName;
  final String? templateThumbnail;
  final String? leadId;
  final String? quotationId;
  final List<Guest> guestList;

  ItineraryV2({
    required this.id,
    required this.subject,
    required this.customerName,
    required this.customerCompany,
    required this.customerEmail,
    required this.customerPhone,
    required this.startDate,
    required this.noOfDays,
    required this.keyLocations,
    required this.shortDescription,
    required this.heroImage,
    required this.sections,
    required this.stays,
    required this.transports,
    required this.activitiesCost,
    required this.totalPrice,
    required this.pricePerAdult,
    required this.adults,
    this.kids = 0,
    required this.rooms,
    required this.keyInclusions,
    required this.keyExclusions,
    required this.termsAndConditions,
    required this.createdAt,
    this.templateKey,
    this.templateName,
    this.templateThumbnail,
    this.leadId,
    this.quotationId,
    this.guestList = const [],
  });

  // Getters for UI Compatibility
  String get clientName => customerName;
  String get clientEmail => customerEmail;
  String get clientPhoneNo => customerPhone;
  String get clientCompany => customerCompany;

  factory ItineraryV2.fromJson(Map<String, dynamic> json) {
    String extractName(dynamic field) {
      if (field == null) return '';
      if (field is String) return field;
      if (field is Map) return field['name']?.toString() ?? '';
      return field.toString();
    }

    return ItineraryV2(
      id: json['_id'] ?? json['id'] ?? '',
      subject: json['subject'] ?? json['title'] ?? '',
      customerName: extractName(json['customerName'] ?? json['clientName']),
      customerCompany: extractName(json['customerCompany'] ?? json['clientCompany']),
      customerEmail: json['customerEmail'] ?? json['clientEmail'] ?? '',
      customerPhone: json['customerPhone'] ?? json['clientPhoneNo'] ?? '',
      startDate: json['startDate'] ?? '',
      noOfDays: json['noOfDays'] ?? json['durationDays'] ?? 0,
      keyLocations: List<String>.from(json['keyLocations'] ?? json['destinations'] ?? []),
      shortDescription: json['shortDescription'] ?? json['overview'] ?? '',
      heroImage: json['heroImage'] ?? json['coverImage'] ?? '',
      sections: (json['sections'] as List? ?? json['timeline'] as List? ?? [])
          .map((s) => DayPlan.fromJson(s))
          .toList(),
      stays: (json['stays'] as List? ?? json['accommodations'] as List? ?? [])
          .map((s) => StayV2.fromJson(s))
          .toList(),
      transports: (json['transports'] as List? ?? json['transportation'] as List? ?? [])
          .map((t) => TransportV2.fromJson(t))
          .toList(),
      activitiesCost: (json['activitiesCost'] ?? 0).toDouble(),
      totalPrice: (json['totalPrice'] ?? json['totalValue'] ?? 0).toDouble(),
      pricePerAdult: (json['pricePerAdult'] ?? json['perGuestCost'] ?? 0).toDouble(),
      adults: json['adults'] ?? 0,
      kids: json['kids'] ?? 0,
      rooms: json['rooms'] ?? 0,
      keyInclusions: List<String>.from(json['keyInclusions'] ?? json['inclusions'] ?? []),
      keyExclusions: List<String>.from(json['keyExclusions'] ?? json['exclusions'] ?? []),
      termsAndConditions: (json['termsAndConditions'] as List? ?? json['policies'] as List? ?? [])
          .map((p) => PolicyV2.fromJson(p))
          .toList(),
      createdAt: json['createdAt'] ?? '',
      templateKey: json['templateKey'],
      templateName: json['templateName'],
      templateThumbnail: json['templateThumbnail'],
      leadId: json['lead'] is Map ? json['lead']['_id'] : json['lead'],
      quotationId: json['quotation'] is Map
          ? (json['quotation']['_id'] ?? json['quotation']['id'] ?? '').toString()
          : (json['quotation']?.toString() ?? json['quotationId']?.toString()),
      guestList: (json['guestList'] as List?)?.map((e) => Guest.fromJson(e)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subject': subject,
      'customerName': customerName,
      'customerCompany': customerCompany,
      'customerEmail': customerEmail,
      'customerPhone': customerPhone,
      'startDate': startDate,
      'noOfDays': noOfDays,
      'keyLocations': keyLocations,
      'shortDescription': shortDescription,
      'heroImage': heroImage,
      'sections': sections.map((s) => s.toJson()).toList(),
      'stays': stays.map((s) => s.toJson()).toList(),
      'transports': transports.map((t) => t.toJson()).toList(),
      'activitiesCost': activitiesCost,
      'totalPrice': totalPrice,
      'pricePerAdult': pricePerAdult,
      'adults': adults,
      'kids': kids,
      'rooms': rooms,
      'keyInclusions': keyInclusions,
      'keyExclusions': keyExclusions,
      'termsAndConditions': termsAndConditions.map((p) => p.toJson()).toList(),
      'templateKey': templateKey,
      'templateName': templateName,
      'templateThumbnail': templateThumbnail,
      'lead': leadId,
      'guestList': guestList.map((e) => e.toJson()).toList(),
    };
  }
}
