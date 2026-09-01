class ConstantItem {
  final String label;
  final String value;

  const ConstantItem({required this.label, required this.value});

  factory ConstantItem.fromJson(Map<String, dynamic> json) {
    return ConstantItem(
      label: json['label']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'value': value,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConstantItem &&
          runtimeType == other.runtimeType &&
          label == other.label &&
          value == other.value;

  @override
  int get hashCode => label.hashCode ^ value.hashCode;
}

class AppConstantsData {
  final List<ConstantItem> leadSources;
  final List<ConstantItem> leadSourcesAutomation;
  final List<ConstantItem> leadPipeline;
  final List<ConstantItem> propertyTypes;
  final List<ConstantItem> propertyCategories;
  final List<ConstantItem> propertyStatuses;
  final List<ConstantItem> projectStatuses;

  const AppConstantsData({
    this.leadSources = const [],
    this.leadSourcesAutomation = const [],
    this.leadPipeline = const [],
    this.propertyTypes = const [],
    this.propertyCategories = const [],
    this.propertyStatuses = const [],
    this.projectStatuses = const [],
  });

  factory AppConstantsData.fromJson(Map<String, dynamic> json) {
    List<ConstantItem> parseList(String key) {
      final list = json[key] as List?;
      if (list == null) return <ConstantItem>[];
      return list
          .map((item) => ConstantItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    return AppConstantsData(
      leadSources: parseList('lead_sources'),
      leadSourcesAutomation: parseList('lead_sources_automation'),
      leadPipeline: parseList('lead_pipeline'),
      propertyTypes: parseList('property_types'),
      propertyCategories: parseList('property_categories'),
      propertyStatuses: parseList('property_statuses'),
      projectStatuses: parseList('project_statuses'),
    );
  }

  Map<String, dynamic> toJson() => {
        'lead_sources': leadSources.map((e) => e.toJson()).toList(),
        'lead_sources_automation':
            leadSourcesAutomation.map((e) => e.toJson()).toList(),
        'lead_pipeline': leadPipeline.map((e) => e.toJson()).toList(),
        'property_types': propertyTypes.map((e) => e.toJson()).toList(),
        'property_categories':
            propertyCategories.map((e) => e.toJson()).toList(),
        'property_statuses': propertyStatuses.map((e) => e.toJson()).toList(),
        'project_statuses': projectStatuses.map((e) => e.toJson()).toList(),
      };

  /// Find display label for a pipeline stage value/label
  String getPipelineLabel(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final val = raw.trim();
    for (final item in leadPipeline) {
      if (item.value.toLowerCase() == val.toLowerCase() || item.label.toLowerCase() == val.toLowerCase()) {
        return item.label;
      }
    }
    return val;
  }

  /// Find API value for a pipeline stage label/value
  String getPipelineValue(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final val = raw.trim();
    for (final item in leadPipeline) {
      if (item.label.toLowerCase() == val.toLowerCase() || item.value.toLowerCase() == val.toLowerCase()) {
        return item.value;
      }
    }
    return val;
  }

  /// Find display label for a lead source value/label
  String getSourceLabel(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final val = raw.trim();
    for (final item in leadSources) {
      if (item.value.toLowerCase() == val.toLowerCase() || item.label.toLowerCase() == val.toLowerCase()) {
        return item.label;
      }
    }
    for (final item in leadSourcesAutomation) {
      if (item.value.toLowerCase() == val.toLowerCase() || item.label.toLowerCase() == val.toLowerCase()) {
        return item.label;
      }
    }
    return val;
  }

  /// Find API value for a lead source label/value
  String getSourceValue(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final val = raw.trim();
    for (final item in leadSources) {
      if (item.label.toLowerCase() == val.toLowerCase() || item.value.toLowerCase() == val.toLowerCase()) {
        return item.value;
      }
    }
    for (final item in leadSourcesAutomation) {
      if (item.label.toLowerCase() == val.toLowerCase() || item.value.toLowerCase() == val.toLowerCase()) {
        return item.value;
      }
    }
    return val;
  }

  /// Find display label for a property type value/label
  String getPropertyTypeLabel(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final val = raw.trim();
    for (final item in propertyTypes) {
      if (item.value.toLowerCase() == val.toLowerCase() || item.label.toLowerCase() == val.toLowerCase()) {
        return item.label;
      }
    }
    return val.replaceAll('_', ' ');
  }

  /// Find API value for a property type label/value
  String getPropertyTypeValue(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final val = raw.trim();
    for (final item in propertyTypes) {
      if (item.label.toLowerCase() == val.toLowerCase() || item.value.toLowerCase() == val.toLowerCase()) {
        return item.value;
      }
    }
    return val;
  }

  /// Find display label for a property category value/label
  String getPropertyCategoryLabel(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final val = raw.trim();
    for (final item in propertyCategories) {
      if (item.value.toLowerCase() == val.toLowerCase() || item.label.toLowerCase() == val.toLowerCase()) {
        return item.label;
      }
    }
    return val;
  }

  /// Find API value for a property category label/value
  String getPropertyCategoryValue(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final val = raw.trim();
    for (final item in propertyCategories) {
      if (item.label.toLowerCase() == val.toLowerCase() || item.value.toLowerCase() == val.toLowerCase()) {
        return item.value;
      }
    }
    return val;
  }

  /// Find display label for a property status value/label
  String getPropertyStatusLabel(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final val = raw.trim();
    for (final item in propertyStatuses) {
      if (item.value.toLowerCase() == val.toLowerCase() || item.label.toLowerCase() == val.toLowerCase()) {
        return item.label;
      }
    }
    return val.replaceAll('_', ' ');
  }

  /// Find API value for a property status label/value
  String getPropertyStatusValue(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final val = raw.trim();
    for (final item in propertyStatuses) {
      if (item.label.toLowerCase() == val.toLowerCase() || item.value.toLowerCase() == val.toLowerCase()) {
        return item.value;
      }
    }
    return val;
  }

  /// Find display label for a project status value/label
  String getProjectStatusLabel(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final val = raw.trim();
    for (final item in projectStatuses) {
      if (item.value.toLowerCase() == val.toLowerCase() || item.label.toLowerCase() == val.toLowerCase()) {
        return item.label;
      }
    }
    return val.replaceAll('_', ' ');
  }

  /// Find API value for a project status label/value
  String getProjectStatusValue(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final val = raw.trim();
    for (final item in projectStatuses) {
      if (item.label.toLowerCase() == val.toLowerCase() || item.value.toLowerCase() == val.toLowerCase()) {
        return item.value;
      }
    }
    return val;
  }

  /// Fallback defaults in case of offline launch without cache
  factory AppConstantsData.defaultValues() {
    return const AppConstantsData(
      leadSources: [
        ConstantItem(label: 'Website', value: 'Website'),
        ConstantItem(label: 'App', value: 'App'),
        ConstantItem(label: 'Manual Upload', value: 'Manual Upload'),
        ConstantItem(label: 'Bulk Upload', value: 'Bulk Upload'),
        ConstantItem(label: 'Meta Ads', value: 'Meta Ads'),
        ConstantItem(label: 'Whatsapp', value: 'Whatsapp'),
        ConstantItem(label: 'Justdial', value: 'Justdial'),
        ConstantItem(label: 'GMB', value: 'GMB'),
        ConstantItem(label: 'Google Ads', value: 'Google Ads'),
        ConstantItem(label: 'IndiaMart', value: 'IndiaMart'),
        ConstantItem(label: 'Tradeindia', value: 'Tradeindia'),
        ConstantItem(label: 'Sulekha', value: 'Sulekha'),
        ConstantItem(label: 'Housing.com', value: 'Housing.com'),
        ConstantItem(label: 'Swipe', value: 'Swipe'),
        ConstantItem(label: 'MagicBricks', value: 'MagicBricks'),
        ConstantItem(label: '99Acre', value: '99Acre'),
        ConstantItem(label: 'IVR', value: 'IVR'),
        ConstantItem(label: 'Leads API', value: 'Leads API'),
        ConstantItem(label: 'Referral', value: 'Referral'),
        ConstantItem(label: 'Other', value: 'Other'),
      ],
      leadSourcesAutomation: [
        ConstantItem(label: 'Website', value: 'Website'),
        ConstantItem(label: 'App', value: 'App'),
        ConstantItem(label: 'Manual Upload', value: 'Manual Upload'),
        ConstantItem(label: 'Meta Ads', value: 'Meta Ads'),
        ConstantItem(label: 'Whatsapp', value: 'Whatsapp'),
        ConstantItem(label: 'Justdial', value: 'Justdial'),
        ConstantItem(label: 'GMB', value: 'GMB'),
        ConstantItem(label: 'Google Ads', value: 'Google Ads'),
        ConstantItem(label: 'IndiaMart', value: 'IndiaMart'),
        ConstantItem(label: 'Tradeindia', value: 'Tradeindia'),
        ConstantItem(label: 'Sulekha', value: 'Sulekha'),
        ConstantItem(label: 'Housing.com', value: 'Housing.com'),
        ConstantItem(label: 'Swipe', value: 'Swipe'),
        ConstantItem(label: 'MagicBricks', value: 'MagicBricks'),
        ConstantItem(label: '99Acre', value: '99Acre'),
        ConstantItem(label: 'IVR', value: 'IVR'),
        ConstantItem(label: 'Leads API', value: 'Leads API'),
        ConstantItem(label: 'Referral', value: 'Referral'),
        ConstantItem(label: 'Other', value: 'Other'),
      ],
      leadPipeline: [
        ConstantItem(label: 'Hot', value: 'Hot'),
        ConstantItem(label: 'Warm', value: 'Warm'),
        ConstantItem(label: 'Cold', value: 'Cold'),
        ConstantItem(label: 'Closed', value: 'Closed'),
        ConstantItem(label: 'Lost', value: 'Lost'),
      ],
      propertyTypes: [
        ConstantItem(label: 'Plot', value: 'plot'),
        ConstantItem(label: 'Flat', value: 'flat'),
        ConstantItem(label: 'Floor', value: 'floor'),
        ConstantItem(label: 'Room', value: 'room'),
        ConstantItem(label: 'Farm House', value: 'farmhouse'),
        ConstantItem(label: 'Villa', value: 'villa'),
        ConstantItem(label: 'Duplex', value: 'duplex'),
        ConstantItem(label: 'Shop', value: 'shop'),
        ConstantItem(label: 'House', value: 'house'),
        ConstantItem(label: 'Green Land', value: 'green_land'),
        ConstantItem(label: 'Office', value: 'office'),
        ConstantItem(label: 'Warehouse', value: 'warehouse'),
        ConstantItem(label: 'Co-working Space', value: 'coworking_space'),
        ConstantItem(label: 'Studio Apartment', value: 'studio_apartment'),
        ConstantItem(label: 'Penthouse', value: 'penthouse'),
        ConstantItem(label: 'Restaurant', value: 'restaurant'),
        ConstantItem(label: 'Lodge', value: 'lodge'),
        ConstantItem(label: 'Hotel', value: 'hotel'),
        ConstantItem(label: 'Saloon', value: 'saloon'),
        ConstantItem(label: 'Spa', value: 'spa'),
        ConstantItem(label: 'Guest House', value: 'guest_house'),
        ConstantItem(label: 'Showroom', value: 'showroom'),
      ],
      propertyCategories: [
        ConstantItem(label: 'Residential', value: 'Residential'),
        ConstantItem(label: 'Commercial', value: 'Commercial'),
        ConstantItem(label: 'Industrial', value: 'Industrial'),
        ConstantItem(label: 'Land', value: 'Land'),
      ],
      propertyStatuses: [
        ConstantItem(label: 'Available', value: 'available'),
        ConstantItem(label: 'On Hold', value: 'on_hold'),
        ConstantItem(label: 'Token Received', value: 'token_received'),
        ConstantItem(label: 'Booked', value: 'booked'),
        ConstantItem(label: 'Sold', value: 'sold'),
        ConstantItem(label: 'Blocked', value: 'blocked'),
        ConstantItem(label: 'Ready to Move', value: 'Ready to Move'),
        ConstantItem(label: 'Rented', value: 'rented'),
        ConstantItem(label: 'Notice Period', value: 'notice_period'),
      ],
      projectStatuses: [
        ConstantItem(label: 'Pre Launch', value: 'pre_launch'),
        ConstantItem(label: 'Active', value: 'active'),
        ConstantItem(label: 'Under Construction', value: 'under_construction'),
        ConstantItem(label: 'Ready to Move', value: 'ready_to_move'),
        ConstantItem(label: 'Sold Out', value: 'sold_out'),
        ConstantItem(label: 'On Hold', value: 'on_hold'),
        ConstantItem(label: 'Blocked', value: 'blocked'),
      ],
    );
  }
}
