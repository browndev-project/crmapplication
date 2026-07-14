// ignore_for_file: constant_identifier_names

class SystemRoles {
  static const String SALES_MANAGER = 'sales_manager';
  static const String SALES_EXECUTIVE = 'sales_executive';
  static const String TEAM_LEADER = 'team_leader';
  static const String COMPANY_ADMIN = 'company_admin';
  static const String COMPANY = 'company'; // Role from API may be just "company"

  // ─── Role → allowed routes (used for quick route-level checks) ─────────────
  // NOTE: The primary permission/visibility logic lives in AppDrawer via the
  // PermissionsProvider. This map is kept for legacy compatibility only.
  static const Map<String, List<String>> ALLOWED_SCREENS = {
    SALES_EXECUTIVE: [
      'Dashboard', 'Leads', 'Lead Documents', 'Meetings', 'Visits', 'Tasks',
      'Calendar', 'Services', 'Properties', 'Invoices', 'Vouchers',
      'Quotations', 'Itineraries', // 'Master Listings',
      'WhatsApp', 'Chats',
      'Marketing', 'Activity Tracker', 'Assets Library',
    ],
    TEAM_LEADER: [
      'Dashboard', 'Leads', 'Lead Documents', 'Meetings', 'Tasks', 'Visits',
      'Calendar', 'Activity Tracker', 'Properties', 'Services', 'Assets Library',
      'Invoices', 'Vouchers', 'Quotations', 'Itineraries', // 'Master Listings',
      'Staff', 'Sales Executives', 'WhatsApp', 'Chats', 'Marketing',
      'Reports', 'Calls Summary',
    ],
    SALES_MANAGER: [
      'Dashboard', 'Leads', 'Lead Documents', 'Meetings', 'Tasks', 'Visits',
      'Calendar', 'Activity Tracker', 'Properties', 'Services', 'Assets Library',
      'Invoices', 'Vouchers', 'Quotations', 'Itineraries', // 'Master Listings',
      'Staff', 'Teams', 'Team Leaders', 'Sales Executives',
      'WhatsApp', 'Chats', 'Marketing',
      'Reports', 'Calls Summary',
    ],
    COMPANY_ADMIN: [
      'Dashboard', 'Leads', 'Lead Documents', 'Meetings', 'Tasks', 'Visits',
      'Calendar', 'Activity Tracker', 'Properties', 'Track Location',
      'Services', 'Assets Library', 'Invoices', 'Vouchers', 'Quotations',
      'Itineraries', // 'Master Listings',
      'Reports', 'Calls Summary', 'Performance', 'Overall Report',
      'Download Logs', 'Email Logs',
      'Staff', 'Groups', 'Teams', 'Sales Managers', 'Team Leaders',
      'Sales Executives', 'Flow Chart',
      'WhatsApp', 'Chats', 'Templates', 'Automation', 'Marketing',
      'About Company', 'Settings', 'Privacy Policies',
    ],
    COMPANY: [
      'Dashboard', 'Leads', 'Lead Documents', 'Meetings', 'Tasks', 'Visits',
      'Calendar', 'Activity Tracker', 'Properties', 'Track Location',
      'Services', 'Assets Library', 'Invoices', 'Vouchers', 'Quotations',
      'Itineraries', // 'Master Listings',
      'Reports', 'Calls Summary', 'Performance', 'Overall Report',
      'Download Logs', 'Email Logs',
      'Staff', 'Groups', 'Teams', 'Sales Managers', 'Team Leaders',
      'Sales Executives', 'Flow Chart',
      'WhatsApp', 'Chats', 'Templates', 'Automation', 'Marketing',
      'About Company', 'Settings', 'Privacy Policies',
    ],
  };

  /// Returns true if [screenName] is accessible for [userRole].
  /// Company Admin / Company always return true.
  static bool hasAccess(String? userRole, String screenName) {
    if (userRole == null) return false;
    if (userRole == COMPANY_ADMIN || userRole == COMPANY) return true;
    final allowed = ALLOWED_SCREENS[userRole];
    // Handle legacy "Itinerary" alias
    final target =
        (screenName == 'Itinerary' || screenName == 'Itineraries V2')
            ? 'Itineraries'
            : screenName;
    return allowed != null && allowed.contains(target);
  }

  static bool canViewCompanyPanel(String? userRole) {
    return userRole == COMPANY_ADMIN || userRole == COMPANY;
  }
}
