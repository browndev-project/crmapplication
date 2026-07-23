import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/login_provider.dart';
import '../providers/permissions_provider.dart';
import '../../core/constants/permission_constants.dart';
import '../providers/navigation_provider.dart';
import '../widgets/floating_dock_nav_bar.dart';
import '../widgets/app_drawer.dart';
import '../../core/services/app_update_service.dart';

import 'home_screen.dart';
import 'leads_screen.dart';
import 'tasks_screen.dart';
import 'visits_screen.dart';
import 'meetings_screen.dart';

import 'lead/lead_documents_screen.dart';
import 'invoices_screen.dart';
import 'vouchers_screen.dart';
import 'quotations_screen.dart';
import 'itineraries_v2_screen.dart';
// import 'master_listings_screen.dart';
import 'calendar_screen.dart';
import 'attendance/attendance_screen.dart';
import 'staff/groups_screen.dart';
import 'staff/teams_screen.dart';
import 'staff/sales_managers_screen.dart';
import 'staff/team_leaders_screen.dart';
import 'staff/sales_executives_screen.dart';
import 'company_screen.dart';
import 'about_company_screen.dart';
import 'marketing_screen.dart';
import 'reports/todays_report_screen.dart';
import 'reports/performance_report_screen.dart';
import 'reports/download_logs_screen.dart';
import 'reports/email_logs_screen.dart';
import 'reports/services_report_screen.dart';
import 'reports/overall_report_screen.dart';
import 'settings/settings_screen.dart';
import 'assets/assets_library_screen.dart';
import 'privacy_policies_screen.dart';
import 'properties_screen.dart';
import 'all_properties_screen.dart';
import 'live_location_screen.dart';
import 'whatsapp/whatsapp_chats_screen.dart';
import '../../core/services/whatsapp_state_tracker.dart';
import 'whatsapp/whatsapp_templates_screen.dart';
import 'whatsapp/whatsapp_automation_screen.dart';
import 'whatsapp/whatsapp_campaigns_screen.dart';
import 'services_screen.dart';

class MainWrapperScreen extends ConsumerStatefulWidget {
  const MainWrapperScreen({super.key});

  @override
  ConsumerState<MainWrapperScreen> createState() => _MainWrapperScreenState();
}

class _MainWrapperScreenState extends ConsumerState<MainWrapperScreen> {
  late PageController _pageController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateService.checkUpdate(context);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(loginProvider).user;
    final permissions = ref.watch(permissionsProvider);
    final userRole = user?.systemRole;
    final currentRoute = ref.watch(currentRouteProvider);

    // Show loading state while permissions are being fetched
    if (user != null && permissions.userPermissions == null) {
      if (permissions.error != null) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load permissions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    permissions.error ?? 'Unknown error occurred',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      ref.read(permissionsProvider.notifier).fetchPermissions();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                      foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF2563EB),
          ),
        ),
      );
    }

    // Build the list of screens
    final List<Widget> screens = [];
    final List<String> routes = [];

    screens.add(const HomeScreen());
    routes.add('Dashboard');

    final hasLeadsAccess =
        permissions.hasModule(PermissionModules.LEADS, userRole: userRole) &&
        permissions.hasPermission(PermissionModules.LEADS_VIEW, userRole: userRole);
    if (hasLeadsAccess) {
      screens.add(const LeadsScreen());
      routes.add('Leads');
    }

    final hasTasksAccess =
        permissions.hasModule(PermissionModules.TASK, userRole: userRole) &&
        permissions.hasPermission(PermissionModules.TASKS_VIEW, userRole: userRole);
    if (hasTasksAccess) {
      screens.add(const TasksScreen());
      routes.add('Tasks');
    }

    final hasVisitsAccess =
        permissions.hasModule(PermissionModules.VISITS, userRole: userRole) &&
        permissions.hasPermission(PermissionModules.VISITS_VIEW, userRole: userRole);
    final hasMeetingsAccess =
        permissions.hasModule(PermissionModules.MEETING, userRole: userRole) &&
        permissions.hasPermission(PermissionModules.MEETINGS_VIEW, userRole: userRole);

    if (hasVisitsAccess) {
      screens.add(const VisitsScreen());
      routes.add('Visits');
    }
    if (hasMeetingsAccess) {
      screens.add(const MeetingsScreen());
      routes.add('Meetings');
    }
    
    // Jump to current page if changed
    int activeIndex = -1;
    if (currentRoute == 'Meetings') {
      activeIndex = routes.indexOf('Meetings');
    } else if (currentRoute == 'Visits') {
      activeIndex = routes.indexOf('Visits');
    } else {
      activeIndex = routes.indexOf(currentRoute);
    }
    final targetIndex = activeIndex != -1 ? activeIndex : 0;

    // Use a post frame callback to animate without rebuilding during build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients && _pageController.page?.round() != targetIndex) {
        // Reset dock lock and make visible when changing pages
        ref.read(dockLockedHiddenProvider.notifier).state = false;
        ref.read(dockVisibilityProvider.notifier).update(true);
        _pageController.animateToPage(
          targetIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });

    ref.listen<String>(currentRouteProvider, (previous, next) {
      final history = ref.read(routeHistoryProvider);
      if (next == 'Dashboard') {
        ref.read(routeHistoryProvider.notifier).state = ['Dashboard'];
      } else {
        final newHistory = List<String>.from(history);
        if (newHistory.contains(next)) {
          final idx = newHistory.indexOf(next);
          ref.read(routeHistoryProvider.notifier).state = newHistory.sublist(0, idx + 1);
        } else {
          newHistory.add(next);
          ref.read(routeHistoryProvider.notifier).state = newHistory;
        }
      }
    });

    final coreRoutes = ['Dashboard', 'Leads', 'Tasks', 'Visits', 'Meetings'];
    final isCoreRoute = coreRoutes.contains(currentRoute);

    Widget bodyWidget;
    if (isCoreRoute) {
      bodyWidget = PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: screens,
      );
    } else {
      bodyWidget = _getNonCoreScreen(currentRoute);
    }

    return PopScope(
      canPop: currentRoute == 'Dashboard',
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (currentRoute != 'Dashboard') {
          final handler = ref.read(backHandlerProvider);
          if (handler != null && handler()) return;
          
          final history = ref.read(routeHistoryProvider);
          if (history.length > 1) {
            final newHistory = List<String>.from(history);
            newHistory.removeLast();
            final prevRoute = newHistory.last;
            ref.read(routeHistoryProvider.notifier).state = newHistory;
            ref.read(currentRouteProvider.notifier).state = prevRoute;
          } else {
            ref.read(currentRouteProvider.notifier).state = 'Dashboard';
          }
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: AppDrawer(currentRoute: currentRoute),
        onDrawerChanged: (isOpening) {
          if (isOpening) {
            ref.read(dockVisibilityProvider.notifier).update(false);
          } else {
            final isLocked = ref.read(dockLockedHiddenProvider);
            if (!isLocked) {
              ref.read(dockVisibilityProvider.notifier).update(true);
            }
          }
        },
        body: NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            final isLocked = ref.read(dockLockedHiddenProvider);
            if (!isLocked) {
              if (notification.direction == ScrollDirection.reverse) {
                ref.read(dockVisibilityProvider.notifier).update(false);
              } else if (notification.direction == ScrollDirection.forward) {
                ref.read(dockVisibilityProvider.notifier).update(true);
              }
            }
            return false;
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: bodyWidget,
              ),
              if (currentRoute != 'Chats')
                const Positioned.fill(
                  top: null,

                  child: FloatingDockNavBar(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getNonCoreScreen(String route) {
    switch (route) {
      case 'Lead Documents':
        return const LeadDocumentsScreen();
      case 'Calendar':
        return const CalendarScreen();
      case 'Activity Tracker':
        return const AttendanceScreen();
      case 'Projects':
        return const PropertiesScreen();
      case 'Properties':
        return AllPropertiesScreen();
      case 'Track Location':
        return const LiveLocationScreen();
      case 'Services':
        return ServicesScreen();
      case 'Assets Library':
        return const AssetsLibraryScreen();
      case 'Invoices':
        return const InvoicesScreen();
      case 'Itineraries':
        return const ItinerariesV2Screen();
      // case 'Master Listings':
      //   return const MasterListingsScreen();
      case 'Quotations':
        return const QuotationsScreen();
      case 'Vouchers':
        return const VouchersScreen();
      case 'Marketing':
        return const MarketingScreen();
      case 'About Company':
        return const AboutCompanyScreen();
      case 'Settings':
        return const SettingsScreen();
      case 'Privacy Policies':
        return const PrivacyPoliciesScreen();
      case 'Chats':
        return WhatsAppChatsScreen(initialConversationId: WhatsAppStateTracker.pendingConversationId);
      case 'Templates':
        return const WhatsAppTemplatesScreen();
      case 'Automation':
        return const WhatsAppAutomationScreen();
      case 'Groups':
        return const GroupsScreen();
      case 'Teams':
        return const TeamsScreen();
      case 'Sales Managers':
        return const SalesManagersScreen();
      case 'Team Leaders':
        return const TeamLeadersScreen();
      case 'Sales Executives':
        return const SalesExecutivesScreen();
      case 'Calls Summary':
        return const TodaysReportScreen();
      case 'Performance':
        return const PerformanceReportScreen();
      case 'Overall Report':
        return const OverallReportScreen();
      case 'Download Logs':
        return const DownloadLogsScreen();
      case 'Email Logs':
        return const EmailLogsScreen();
      case 'Services Report':
        return const ServicesReportScreen();
      case 'Company':
        return const CompanyScreen();
      case 'Marketing Campaigns':
        return const WhatsAppCampaignsScreen();
      default:
        return const HomeScreen();
    }
  }
}
