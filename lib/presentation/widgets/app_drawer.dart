import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../providers/login_provider.dart';
import '../providers/permissions_provider.dart';
import '../../core/constants/permission_constants.dart';
import '../screens/login_screen.dart';
import '../screens/main_wrapper_screen.dart';
import '../providers/navigation_provider.dart';
// leads_screen.dart imported by main_wrapper_screen indirectly
// meetings_screen.dart imported via main_wrapper_screen

// import '../screens/master_listings_screen.dart';
// tasks_screen.dart imported via main_wrapper_screen

// visits_screen.dart imported via main_wrapper_screen
import '../../core/utils/roles.dart';

import '../screens/whatsapp/widgets/whatsapp_icon.dart';
import '../providers/invoice_provider.dart';
import '../providers/voucher_provider.dart';
import '../providers/quotation_provider.dart';
import '../providers/itinerary_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────

class _SidebarItem {
  final String label;
  final IconData icon;
  final Widget? iconWidget;
  final String? module;          // PermissionModules.XXX  (null = always show)
  final String? permission;      // PermissionModules.XXX_VIEW
  final bool expandable;
  final List<_SidebarItem> children;

  const _SidebarItem({
    required this.label,
    required this.icon,
    this.iconWidget,
    this.module,
    this.permission,
    this.expandable = false,
    this.children = const [],
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SIDEBAR CONFIGS — one list per role, matching web order exactly
// ─────────────────────────────────────────────────────────────────────────────

List<_SidebarItem> _buildConfig(String systemRole) {
  // ── Shared base items (same for all roles except Sales Executive) ──────────
  const baseItems = [
    _SidebarItem(label: 'Dashboard',        icon: Icons.dashboard,         module: PermissionModules.BASE),
    _SidebarItem(label: 'Leads',            icon: Icons.group_add,         module: PermissionModules.LEADS,     permission: PermissionModules.LEADS_VIEW),
    _SidebarItem(label: 'Lead Documents',   icon: Icons.description,       module: PermissionModules.LEAD_DOCS, permission: PermissionModules.LEAD_DOCS_VIEW),
    _SidebarItem(label: 'Meetings',         icon: Icons.meeting_room,      module: PermissionModules.MEETING,   permission: PermissionModules.MEETINGS_VIEW),
    _SidebarItem(label: 'Follow ups',       icon: Icons.checklist,         module: PermissionModules.TASK,      permission: PermissionModules.TASKS_VIEW),
    _SidebarItem(label: 'Visits',           icon: Icons.event,             module: PermissionModules.VISITS,    permission: PermissionModules.VISITS_VIEW),
    _SidebarItem(label: 'Calendar',         icon: Icons.calendar_month,    module: PermissionModules.LEADS,     permission: PermissionModules.LEADS_VIEW),
    _SidebarItem(label: 'Activity Tracker', icon: Icons.front_hand,        module: PermissionModules.TASK,      permission: PermissionModules.TASKS_VIEW),
  ];

  // ── Common items appended after base for Sales Manager / Team Leader ────
  const commonAfterBase = [
    _SidebarItem(label: 'Projects',         icon: Icons.home_work_outlined, module: PermissionModules.PROPERTY,  permission: PermissionModules.PROPERTY_VIEW),
    _SidebarItem(label: 'Properties',       icon: Icons.house,              module: PermissionModules.PROPERTY, permission: PermissionModules.PROPERTY_VIEW),
    _SidebarItem(label: 'Services',         icon: Icons.build,             module: PermissionModules.SERVICES,  permission: PermissionModules.SERVICES_VIEW),
    _SidebarItem(label: 'Assets Library',   icon: Icons.folder,            module: PermissionModules.ASSETS,    permission: PermissionModules.ASSETS_VIEW),
    _SidebarItem(label: 'Invoices',         icon: Icons.receipt_long,      module: PermissionModules.INVOICE,   permission: PermissionModules.INVOICE_VIEW),
    _SidebarItem(label: 'Itineraries',      icon: Icons.route,             module: PermissionModules.ITINERARY, permission: PermissionModules.ITINERARY_VIEW),
    // _SidebarItem(label: 'Master Listings',  icon: Icons.local_activity_outlined, module: PermissionModules.ITINERARY, permission: PermissionModules.ITINERARY_VIEW),
    _SidebarItem(label: 'Quotations',       icon: Icons.request_quote,     module: PermissionModules.QUOTATION, permission: PermissionModules.QUOTATION_VIEW),
    _SidebarItem(label: 'Vouchers',         icon: Icons.confirmation_number_outlined, module: PermissionModules.VOUCHER, permission: PermissionModules.VOUCHER_VIEW),
  ];

  // WhatsApp children per role
  const whatsappAdminChildren = [
    _SidebarItem(label: 'Chats',       icon: Icons.chat,              module: PermissionModules.WHATSAPP),
    _SidebarItem(label: 'Templates',   icon: Icons.description,       module: PermissionModules.WHATSAPP),
    _SidebarItem(label: 'Automation',  icon: Icons.insights,          module: PermissionModules.WHATSAPP),
    _SidebarItem(label: 'Marketing',   icon: Icons.campaign,          module: PermissionModules.WHATSAPP),
  ];

  const whatsappOtherChildren = [
    _SidebarItem(label: 'Chats',       icon: Icons.chat,              module: PermissionModules.WHATSAPP),
    _SidebarItem(label: 'Marketing',   icon: Icons.campaign,          module: PermissionModules.WHATSAPP),
  ];

  // ── COMPANY_ADMIN ──────────────────────────────────────────────────────────
  if (systemRole == SystemRoles.COMPANY_ADMIN || systemRole == SystemRoles.COMPANY) {
    return [
      ...baseItems,
      const _SidebarItem(label: 'Track Location',  icon: Icons.location_on,       module: PermissionModules.PROPERTY),
      const _SidebarItem(label: 'Projects',        icon: Icons.home_work_outlined, module: PermissionModules.PROPERTY,  permission: PermissionModules.PROPERTY_VIEW),
      const _SidebarItem(label: 'Properties',      icon: Icons.house,              module: PermissionModules.PROPERTY,  permission: PermissionModules.PROPERTY_VIEW),
      const _SidebarItem(label: 'Services',         icon: Icons.build,             module: PermissionModules.SERVICES,  permission: PermissionModules.SERVICES_VIEW),
      const _SidebarItem(label: 'Assets Library',   icon: Icons.folder,            module: PermissionModules.ASSETS,    permission: PermissionModules.ASSETS_VIEW),
      const _SidebarItem(label: 'Invoices',         icon: Icons.receipt_long,      module: PermissionModules.INVOICE,   permission: PermissionModules.INVOICE_VIEW),
      const _SidebarItem(label: 'Itineraries',      icon: Icons.route,             module: PermissionModules.ITINERARY, permission: PermissionModules.ITINERARY_VIEW),
      // const _SidebarItem(label: 'Master Listings',  icon: Icons.local_activity_outlined, module: PermissionModules.ITINERARY, permission: PermissionModules.ITINERARY_VIEW),
      const _SidebarItem(label: 'Quotations',       icon: Icons.request_quote,     module: PermissionModules.QUOTATION, permission: PermissionModules.QUOTATION_VIEW),
      const _SidebarItem(label: 'Vouchers',         icon: Icons.confirmation_number_outlined, module: PermissionModules.VOUCHER, permission: PermissionModules.VOUCHER_VIEW),
      // Reports
      _SidebarItem(
        label: 'Reports', icon: Icons.bar_chart,
        expandable: true, module: PermissionModules.REPORTS_BASE,
        children: [
          const _SidebarItem(label: 'Calls Summary',  icon: Icons.today,                    module: PermissionModules.REPORTS_BASE),
          const _SidebarItem(label: 'Performance',    icon: Icons.trending_up,              module: PermissionModules.REPORTS_BASE),
          const _SidebarItem(label: 'Overall Report', icon: Icons.analytics,                module: PermissionModules.REPORTS_BASE),
          const _SidebarItem(label: 'Services',       icon: Icons.miscellaneous_services,   module: PermissionModules.REPORTS_SERVICES),
          const _SidebarItem(label: 'Download Logs',  icon: Icons.file_download,            module: PermissionModules.REPORTS_BASE),
          const _SidebarItem(label: 'Email Logs',     icon: Icons.mark_email_read,          module: PermissionModules.REPORTS_BASE),
        ],
      ),
      // Staff
      _SidebarItem(
        label: 'Staff', icon: Icons.people,
        expandable: true, module: PermissionModules.BASE,
        children: [
          const _SidebarItem(label: 'Groups',          icon: Icons.diversity_1,              module: PermissionModules.STAFF_GROUP),
          const _SidebarItem(label: 'Teams',           icon: Icons.diversity_3,              module: PermissionModules.STAFF_TEAM),
          const _SidebarItem(label: 'Sales Managers',  icon: Icons.admin_panel_settings,     module: PermissionModules.STAFF_GROUP),
          const _SidebarItem(label: 'Team Leaders',    icon: Icons.supervised_user_circle,   module: PermissionModules.STAFF_TEAM),
          const _SidebarItem(label: 'Sales Executives',icon: Icons.person_2,                 module: PermissionModules.STAFF_BASE),
          const _SidebarItem(label: 'Flow Chart',      icon: Icons.account_tree),
        ],
      ),
      // WhatsApp
      _SidebarItem(
        label: 'WhatsApp', icon: Icons.chat_bubble,
        iconWidget: whatsAppIcon(size: 22, color: const Color(0xFF25D366)),
        expandable: true, module: PermissionModules.WHATSAPP, permission: PermissionModules.LEADS_WHATSAPP,
        children: whatsappAdminChildren,
      ),
      const _SidebarItem(label: 'Marketing',      icon: Icons.email,           module: PermissionModules.MARKETING),
      const _SidebarItem(label: 'About Company',  icon: Icons.business),
      const _SidebarItem(label: 'Settings',       icon: Icons.settings),
    ];
  }

  // ── SALES_MANAGER ──────────────────────────────────────────────────────────
  if (systemRole == SystemRoles.SALES_MANAGER) {
    return [
      ...baseItems,
      ...commonAfterBase,
      // Reports
      _SidebarItem(
        label: 'Reports', icon: Icons.bar_chart,
        expandable: true, module: PermissionModules.REPORTS_BASE,
        children: [
          const _SidebarItem(label: 'Calls Summary',  icon: Icons.today,  module: PermissionModules.REPORTS_BASE),
        ],
      ),
      // Staff
      _SidebarItem(
        label: 'Staff', icon: Icons.people,
        expandable: true, module: PermissionModules.BASE,
        children: [
          const _SidebarItem(label: 'Teams',           icon: Icons.diversity_3,             module: PermissionModules.STAFF_TEAM),
          const _SidebarItem(label: 'Team Leaders',    icon: Icons.supervised_user_circle,  module: PermissionModules.STAFF_TEAM),
          const _SidebarItem(label: 'Sales Executives',icon: Icons.person_2,                module: PermissionModules.STAFF_BASE),
        ],
      ),
      // WhatsApp
      _SidebarItem(
        label: 'WhatsApp', icon: Icons.chat_bubble,
        iconWidget: whatsAppIcon(size: 22, color: const Color(0xFF25D366)),
        expandable: true, module: PermissionModules.WHATSAPP, permission: PermissionModules.LEADS_WHATSAPP,
        children: whatsappOtherChildren,
      ),
      const _SidebarItem(label: 'Marketing', icon: Icons.email, module: PermissionModules.MARKETING),
    ];
  }

  // ── TEAM_LEADER ────────────────────────────────────────────────────────────
  if (systemRole == SystemRoles.TEAM_LEADER) {
    return [
      ...baseItems,
      ...commonAfterBase,
      // Reports
      _SidebarItem(
        label: 'Reports', icon: Icons.bar_chart,
        expandable: true, module: PermissionModules.REPORTS_BASE,
        children: [
          const _SidebarItem(label: 'Calls Summary',  icon: Icons.today,  module: PermissionModules.REPORTS_BASE),
        ],
      ),
      // Staff
      _SidebarItem(
        label: 'Staff', icon: Icons.people,
        expandable: true, module: PermissionModules.BASE,
        children: [
          const _SidebarItem(label: 'Sales Executives', icon: Icons.person_2, module: PermissionModules.STAFF_BASE),
        ],
      ),
      // WhatsApp
      _SidebarItem(
        label: 'WhatsApp', icon: Icons.chat_bubble,
        iconWidget: whatsAppIcon(size: 22, color: const Color(0xFF25D366)),
        expandable: true, module: PermissionModules.WHATSAPP, permission: PermissionModules.LEADS_WHATSAPP,
        children: whatsappOtherChildren,
      ),
      const _SidebarItem(label: 'Marketing', icon: Icons.email, module: PermissionModules.MARKETING),
    ];
  }

  // ── SALES_EXECUTIVE ────────────────────────────────────────────────────────
  return [
    const _SidebarItem(label: 'Dashboard',        icon: Icons.dashboard,        module: PermissionModules.BASE),
    const _SidebarItem(label: 'Leads',            icon: Icons.group_add,        module: PermissionModules.LEADS,     permission: PermissionModules.LEADS_VIEW),
    const _SidebarItem(label: 'Lead Documents',   icon: Icons.description,      module: PermissionModules.LEAD_DOCS, permission: PermissionModules.LEAD_DOCS_VIEW),
    const _SidebarItem(label: 'Meetings',         icon: Icons.meeting_room,     module: PermissionModules.MEETING,   permission: PermissionModules.MEETINGS_VIEW),
    const _SidebarItem(label: 'Visits',           icon: Icons.event,            module: PermissionModules.VISITS,    permission: PermissionModules.VISITS_VIEW),
    const _SidebarItem(label: 'Follow ups',       icon: Icons.checklist,        module: PermissionModules.TASK,      permission: PermissionModules.TASKS_VIEW),
    const _SidebarItem(label: 'Calendar',         icon: Icons.calendar_month,   module: PermissionModules.LEADS,     permission: PermissionModules.LEADS_VIEW),
    const _SidebarItem(label: 'Services',         icon: Icons.build,            module: PermissionModules.SERVICES,  permission: PermissionModules.SERVICES_VIEW),
    const _SidebarItem(label: 'Projects',         icon: Icons.home_work_outlined, module: PermissionModules.PROPERTY,  permission: PermissionModules.PROPERTY_VIEW),
    const _SidebarItem(label: 'Properties',       icon: Icons.house,              module: PermissionModules.PROPERTY,  permission: PermissionModules.PROPERTY_VIEW),
    const _SidebarItem(label: 'Invoices',         icon: Icons.receipt_long,     module: PermissionModules.INVOICE,   permission: PermissionModules.INVOICE_VIEW),
    const _SidebarItem(label: 'Itineraries',      icon: Icons.route,            module: PermissionModules.ITINERARY, permission: PermissionModules.ITINERARY_VIEW),
    // const _SidebarItem(label: 'Master Listings',  icon: Icons.local_activity_outlined, module: PermissionModules.ITINERARY, permission: PermissionModules.ITINERARY_VIEW),
    const _SidebarItem(label: 'Quotations',       icon: Icons.request_quote,    module: PermissionModules.INVOICE,   permission: PermissionModules.QUOTATION_VIEW),
    const _SidebarItem(label: 'Vouchers',         icon: Icons.confirmation_number_outlined, module: PermissionModules.INVOICE, permission: PermissionModules.VOUCHER_VIEW),
    _SidebarItem(
      label: 'WhatsApp', icon: Icons.chat_bubble,
      iconWidget: whatsAppIcon(size: 22, color: const Color(0xFF25D366)),
      expandable: true, module: PermissionModules.WHATSAPP, permission: PermissionModules.LEADS_WHATSAPP,
      children: whatsappOtherChildren,
    ),
    const _SidebarItem(label: 'Marketing',        icon: Icons.email,            module: PermissionModules.MARKETING),
    const _SidebarItem(label: 'Activity Tracker', icon: Icons.front_hand,       module: PermissionModules.ATTENDANCE),
    const _SidebarItem(label: 'Assets Library',   icon: Icons.folder,           module: PermissionModules.ASSETS,    permission: PermissionModules.ASSETS_VIEW),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// DRAWER WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class AppDrawer extends ConsumerWidget {
  final String? currentRoute;

  const AppDrawer({super.key, this.currentRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final backgroundColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final iconColor = Theme.of(context).iconTheme.color?.withValues(alpha: 0.7);
    final user = ref.watch(loginProvider).user;
    final permissions = ref.watch(permissionsProvider);

    final activeRoute = currentRoute ?? ref.watch(currentRouteProvider);

    final systemRole = user?.systemRole ?? SystemRoles.SALES_EXECUTIVE;
    final items = _buildConfig(systemRole);

    // ── Module/permission gate ──────────────────────────────────────────────
    bool isVisible(_SidebarItem item) {
      if (item.module == null) return true;
      final hasModule = permissions.hasModule(item.module!, userRole: systemRole);
      if (!hasModule) return false;
      if (item.permission != null) {
        return permissions.hasPermission(item.permission!, userRole: systemRole);
      }
      return true;
    }

    // ── Navigation handler ─────────────────────────────────────────────────
    void navigate(String label) {
      Navigator.pop(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;

        const coreTabs = ['Dashboard', 'Leads', 'Meetings', 'Visits', 'Follow ups'];

        switch (label) {
          case 'Dashboard':
            ref.read(currentRouteProvider.notifier).state = 'Dashboard';
            break;
          case 'Leads':
            ref.read(currentRouteProvider.notifier).state = 'Leads';
            break;
          case 'Meetings':
            ref.read(currentRouteProvider.notifier).state = 'Meetings';
            break;
          case 'Visits':
            ref.read(currentRouteProvider.notifier).state = 'Visits';
            break;
          case 'Follow ups':
            ref.read(currentRouteProvider.notifier).state = 'Tasks';
            break;
        }

        if (coreTabs.contains(label)) {
          if (!coreTabs.contains(activeRoute)) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MainWrapperScreen()),
            );
          }
          return;
        }

        switch (label) {
          case 'Lead Documents':
          case 'Calendar':
          case 'Activity Tracker':
          case 'Projects':
          case 'Properties':
          case 'Track Location':
          case 'Services':
          case 'Assets Library':
          // case 'Master Listings':
          case 'Marketing':
          case 'About Company':
          case 'Settings':
          case 'Privacy Policies':
          case 'Chats':
          case 'Templates':
          case 'Automation':
          case 'Groups':
          case 'Teams':
          case 'Sales Managers':
          case 'Team Leaders':
          case 'Sales Executives':
          case 'Calls Summary':
          case 'Performance':
          case 'Overall Report':
          case 'Download Logs':
          case 'Email Logs':
            ref.read(currentRouteProvider.notifier).state = label;
            break;
          case 'Invoices':
            ref.read(invoicesProvider.notifier).applyFilters({'lead': null});
            ref.read(currentRouteProvider.notifier).state = label;
            break;
          case 'Itineraries':
            ref.read(itineraryV2Provider.notifier).setLeadFilter(null);
            ref.read(currentRouteProvider.notifier).state = label;
            break;
          case 'Quotations':
            ref.read(quotationsProvider.notifier).setLeadFilter(null);
            ref.read(currentRouteProvider.notifier).state = label;
            break;
          case 'Vouchers':
            ref.read(vouchersProvider.notifier).applyFilters({'lead': null});
            ref.read(currentRouteProvider.notifier).state = label;
            break;
          case 'Flow Chart':
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Flow Chart — Coming Soon')),
            );
            break;
          default:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$label coming soon')),
            );
        }
      });
    }

    // ── Widget builders ────────────────────────────────────────────────────

    Widget buildSubItem(_SidebarItem sub, {bool isReportItem = false}) {
      if (!isVisible(sub)) return const SizedBox.shrink();
      final isSelected = activeRoute == sub.label;
      return ListTile(
        dense: true,
        leading: Icon(
          sub.icon,
          size: 20,
          color: isSelected
              ? (isDark ? Colors.blueAccent : Colors.blue)
              : iconColor,
        ),
        title: Text(
          sub.label,
          style: TextStyle(
            fontSize: 13,
            color: isSelected
                ? (isDark ? Colors.blueAccent : Colors.blue)
                : Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () {
          if (sub.label == 'Marketing' && sub.module == PermissionModules.WHATSAPP) {
            Navigator.pop(context);
            ref.read(currentRouteProvider.notifier).state = 'Marketing Campaigns';
            return;
          }
          if (sub.label == 'Services' && isReportItem) {
            Navigator.pop(context);
            ref.read(currentRouteProvider.notifier).state = 'Services Report';
            return;
          }
          navigate(sub.label);
        },
      );
    }

    Widget buildItem(_SidebarItem item) {
      if (!isVisible(item)) return const SizedBox.shrink();

      if (item.expandable) {
        final visibleChildren = item.children.where(isVisible).toList();
        if (visibleChildren.isEmpty) return const SizedBox.shrink();

        final isReportGroup = item.label == 'Reports';

        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: item.iconWidget ?? Icon(item.icon, size: 22, color: iconColor),
            title: Text(
              item.label,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 14,
              ),
            ),
            childrenPadding: const EdgeInsets.only(left: 16),
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            dense: true,
            children: visibleChildren
                .map((c) => buildSubItem(c, isReportItem: isReportGroup))
                .toList(),
          ),
        );
      }

      final isSelected = activeRoute == item.label;
      return Container(
        margin: const EdgeInsets.only(bottom: 4, right: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? Colors.blue.withValues(alpha: 0.15)
                  : Colors.blue.withValues(alpha: 0.1))
              : Colors.transparent,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
        ),
        child: Stack(
          children: [
            if (isSelected)
              Positioned(
                left: 0,
                top: 8,
                bottom: 8,
                width: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.blueAccent : Colors.blue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ListTile(
              leading: item.iconWidget ?? Icon(
                item.icon,
                size: 22,
                color: isSelected
                    ? (isDark ? Colors.blueAccent : Colors.blue)
                    : iconColor,
              ),
              title: Text(
                item.label,
                style: TextStyle(
                  color: isSelected
                      ? (isDark ? Colors.blueAccent : Colors.blue)
                      : Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              minLeadingWidth: 20,
              onTap: () => navigate(item.label),
            ),
          ],
        ),
      );
    }

    // ── DRAW ──────────────────────────────────────────────────────────────

    return Drawer(
      backgroundColor: backgroundColor,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                children: [
                  // Logo
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20, left: 8),
                    child: Image.asset(
                      isDark
                          ? 'assets/images/logo_full_light.png'
                          : 'assets/images/logo_full_dark.png',
                      height: 40,
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Company Panel — admin only
                  if (systemRole == SystemRoles.COMPANY_ADMIN ||
                      systemRole == SystemRoles.COMPANY) ...[
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        ref.read(currentRouteProvider.notifier).state = 'Company';
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.business_center_outlined,
                                size: 18, color: textColor),
                            const SizedBox(width: 8),
                            Text(
                              'Company Panel',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Sidebar items
                  ...items.map(buildItem),

                  const SizedBox(height: 12),

                  // Privacy Policies (always visible)
                  buildItem(const _SidebarItem(
                    label: 'Privacy Policies',
                    icon: Icons.policy_outlined,
                  )),

                  const SizedBox(height: 20),

                  // Dark Theme Toggle
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.brightness_4, size: 20, color: textColor),
                        const SizedBox(width: 8),
                        Text('Dark Theme',
                            style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .inverseSurface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Beta',
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onInverseSurface,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: isDark,
                          onChanged: (value) {
                            ref
                                .read(themeProvider.notifier)
                                .toggleTheme();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Footer — user profile + logout
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(
                        color: Theme.of(context).dividerColor)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    child: Text(
                      user?.name.isNotEmpty == true
                          ? user!.name[0].toUpperCase()
                          : 'U',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'User',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: textColor),
                        ),
                        Text(
                          user?.systemRole
                                  .replaceAll('_', ' ')
                                  .toUpperCase() ??
                              user?.email ??
                              'Member',
                          style: TextStyle(fontSize: 12, color: iconColor),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: iconColor),
                    onSelected: (value) {
                      if (value == 'logout') {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Logout'),
                            content: const Text(
                                'Are you sure you want to logout? This will clear your session data.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final navigator = Navigator.of(context);
                                  Navigator.pop(ctx);
                                  await ref
                                      .read(loginProvider.notifier)
                                      .logout();
                                  navigator.pushAndRemoveUntil(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const LoginScreen()),
                                    (route) => false,
                                  );
                                },
                                child: const Text('Logout',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text('Logout',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
