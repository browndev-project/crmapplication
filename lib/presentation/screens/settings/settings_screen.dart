import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/global_app_bar.dart';
import 'widgets/attendance_config_view.dart';
import 'widgets/role_labels_config_view.dart';
import 'widgets/lead_status_config_view.dart';
import 'widgets/company_settings_view.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/login_provider.dart';
import '../../../core/constants/permission_constants.dart';
import '../../../core/utils/roles.dart';
import '../../widgets/access_denied_widget.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  const SettingsScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // 0: Attendance, 1: Role, 2: Lead Status, 3: Company Settings
  late int _activeIndex;

  @override
  void initState() {
    super.initState();
    _activeIndex = widget.initialIndex;
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _activeIndex = widget.initialIndex;
    }
  }

  bool _canAccessTab(int index, dynamic permissions, String? userRole) {
    bool hasAccess(String module) {
      return permissions.hasModule(module, userRole: userRole);
    }

    switch (index) {
      case 0: // Attendance Configuration
        return hasAccess(PermissionModules.ATTENDANCE) ||
            userRole == SystemRoles.COMPANY_ADMIN ||
            userRole == SystemRoles.COMPANY;
      case 1: // Role Labels Configuration
        return userRole == SystemRoles.COMPANY_ADMIN ||
            userRole == SystemRoles.COMPANY;
      case 2: // Lead Status Configuration
        return hasAccess(PermissionModules.LEADS) &&
            permissions.hasPermission(PermissionModules.LEADS_VIEW, userRole: userRole);
      case 3: // Company Settings
        return userRole == SystemRoles.COMPANY_ADMIN ||
            userRole == SystemRoles.COMPANY;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(permissionsProvider);
    final user = ref.watch(loginProvider).user;
    final userRole = user?.systemRole;

    final List<int> accessibleTabs = [0, 1, 2, 3]
        .where((i) => _canAccessTab(i, permissions, userRole))
        .toList();

    if (accessibleTabs.isEmpty) {
      return const Scaffold(

        appBar: GlobalAppBar(title: 'Settings'),
        body: AccessDeniedWidget(
          sectionName: "Settings",
          showAppBar: false,
        ),
      );
    }

    int effectiveIndex = _activeIndex;
    if (!_canAccessTab(effectiveIndex, permissions, userRole)) {
      if (accessibleTabs.isNotEmpty) {
        effectiveIndex = accessibleTabs.first;
        Future.microtask(() {
          if (mounted) setState(() => _activeIndex = effectiveIndex);
        });
      }
    }

    String title = 'Settings';
    if (effectiveIndex == 0) title = 'Attendance Configuration';
    if (effectiveIndex == 1) title = 'Role Labels Configuration';
    if (effectiveIndex == 2) title = 'Lead Status Configuration';
    if (effectiveIndex == 3) title = 'Company Settings';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: GlobalAppBar(title: title),

      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        child: _buildContent(effectiveIndex),
      ),
    );
  }

  Widget _buildContent(int index) {
    switch (index) {
      case 0:
        return const AttendanceConfigView();
      case 1:
        return const RoleLabelsConfigView();
      case 2:
        return const LeadStatusConfigView();
      case 3:
        return const CompanySettingsView();
      default:
        return const Center(child: Text("Select an option"));
    }
  }
}
