class ServiceReportModel {
  final DateTime from;
  final DateTime to;
  final ServiceTotals totals;
  final List<ServiceReportItem> services;

  ServiceReportModel({
    required this.from,
    required this.to,
    required this.totals,
    required this.services,
  });

  factory ServiceReportModel.fromJson(Map<String, dynamic> json) {
    return ServiceReportModel(
      from: DateTime.tryParse(json['from'] ?? '') ?? DateTime.now(),
      to: DateTime.tryParse(json['to'] ?? '') ?? DateTime.now(),
      totals: ServiceTotals.fromJson(json['totals'] ?? {}),
      services: (json['services'] as List?)
              ?.map((e) => ServiceReportItem.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class ServiceTotals {
  final int leadsReceived;
  final int leadsClosed;
  final int totalRevenue;

  ServiceTotals({
    required this.leadsReceived,
    required this.leadsClosed,
    required this.totalRevenue,
  });

  factory ServiceTotals.fromJson(Map<String, dynamic> json) {
    return ServiceTotals(
      leadsReceived: json['leadsReceived'] ?? 0,
      leadsClosed: json['leadsClosed'] ?? 0,
      totalRevenue: json['totalRevenue'] ?? 0,
    );
  }
}

class ServiceReportItem {
  final String serviceId;
  final String serviceName;
  final int leadsReceived;
  final int leadsClosed;
  final num conversionRate; // num to handle int or double
  final num conversionShare;
  final num amountShare;
  final MaxDeal? maxDeal;
  final dynamic topPerformerByConversion; // Keeping dynamic or String? based on null in screenshot
  final dynamic topPerformerByAmount;

  ServiceReportItem({
    required this.serviceId,
    required this.serviceName,
    required this.leadsReceived,
    required this.leadsClosed,
    required this.conversionRate,
    required this.conversionShare,
    required this.amountShare,
    this.maxDeal,
    this.topPerformerByConversion,
    this.topPerformerByAmount,
  });

  factory ServiceReportItem.fromJson(Map<String, dynamic> json) {
    return ServiceReportItem(
      serviceId: json['serviceId'] ?? '',
      serviceName: json['serviceName'] ?? 'Unknown',
      leadsReceived: json['leadsReceived'] ?? 0,
      leadsClosed: json['leadsClosed'] ?? 0,
      conversionRate: json['conversionRate'] ?? 0,
      conversionShare: json['conversionShare'] ?? 0,
      amountShare: json['amountShare'] ?? 0,
      maxDeal: json['maxDeal'] != null ? MaxDeal.fromJson(json['maxDeal']) : null,
      topPerformerByConversion: json['topPerformerByConversion'],
      topPerformerByAmount: json['topPerformerByAmount'],
    );
  }
}

class MaxDeal {
  final String? leadId;
  final String? leadName;
  final int amount;

  MaxDeal({this.leadId, this.leadName, required this.amount});

  factory MaxDeal.fromJson(Map<String, dynamic> json) {
    return MaxDeal(
      leadId: json['leadId'],
      leadName: json['leadName'],
      amount: json['amount'] ?? 0,
    );
  }
}
