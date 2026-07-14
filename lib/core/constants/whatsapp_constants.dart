class WhatsAppVariableSources {
  /// Matrix of supported variable mapping sources for each flow
  /// Based on backend API documentation - only include sources that are actually supported

  static const Map<String, String> commonLeads = {
    'Lead Name': 'lead.name',
    'Lead Phone': 'lead.phoneNo',
    'Lead Email': 'lead.email',
    'Lead Source': 'lead.source',
    'Lead Service': 'lead.service',
    'Custom Value': 'custom',
  };

  static const Map<String, String> incomingLeads = commonLeads;
  static const Map<String, String> statusAutomation = commonLeads;

  static const Map<String, String> visitsAutomation = {
    'Lead Name': 'lead.name',
    'Lead Phone': 'lead.phoneNo',
    'Lead Email': 'lead.email',
    'Lead Source': 'lead.source',
    'Visit Project': 'visit.project',
    'Visit Property': 'visit.property',
    'Visit Date/Time': 'visit.dateTime',
    'Custom Value': 'custom',
  };

  static const Map<String, String> meetingsAutomation = {
    'Lead Name': 'lead.name',
    'Lead Phone': 'lead.phoneNo',
    'Lead Email': 'lead.email',
    'Lead Source': 'lead.source',
    'Lead Service': 'lead.service',
    'Meeting Subject': 'meeting.subject',
    'Meeting Host': 'meeting.host',
    'Meeting Date/Time': 'meeting.scheduledAt',
    'Meeting Link': 'meeting.meetLink',
    'Custom Value': 'custom',
  };

  static const Map<String, String> marketingCampaigns = {
    'Recipient Name': 'recipient.name',
    'Recipient Phone': 'recipient.phone',
    'Custom Value': 'custom',
  };

  static Map<String, String> getSourcesForMode(String mode) {
    switch (mode) {
      case 'lead':
        return incomingLeads;
      case 'meeting':
        return meetingsAutomation;
      case 'visit':
        return visitsAutomation;
      case 'status':
        return statusAutomation;
      case 'marketing':
        return marketingCampaigns;
      case 'chat':
        return {'Custom Value': 'custom'};
      default:
        return {'Recipient Name': 'recipient.name', 'Custom Value': 'custom'};
    }
  }

  static String getLabelForValue(String value) {
    final allSources = {
      ...incomingLeads,
      ...visitsAutomation,
      ...meetingsAutomation,
      ...marketingCampaigns,
      ...statusAutomation,
    };
    return allSources.entries
        .firstWhere(
          (e) => e.value == value,
          orElse: () => MapEntry(value, value),
        )
        .key;
  }
}
