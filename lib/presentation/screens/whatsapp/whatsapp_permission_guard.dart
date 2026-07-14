import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/login_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/whatsapp_provider.dart';
import '../../widgets/access_denied_widget.dart';
import '../../widgets/global_app_bar.dart';
import '../../providers/navigation_provider.dart';

class WhatsAppPermissionGuard extends ConsumerStatefulWidget {
  final Widget child;
  final List<String> requiredModules;
  final String? requiredPermission;
  final String? permissionDeniedMessage;

  const WhatsAppPermissionGuard({
    super.key,
    required this.child,
    required this.requiredModules,
    this.requiredPermission,
    this.permissionDeniedMessage,
  });

  @override
  ConsumerState<WhatsAppPermissionGuard> createState() => _WhatsAppPermissionGuardState();
}

class _WhatsAppPermissionGuardState extends ConsumerState<WhatsAppPermissionGuard> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      ref.invalidate(whatsappIntegrationProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(permissionsProvider);
    final loginState = ref.watch(loginProvider);
    final userRole = loginState.user?.systemRole;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final integrationStatus = ref.watch(whatsappIntegrationProvider);

    if (permissions.userPermissions == null && !permissions.isLoading) {
      ref.read(permissionsProvider.notifier).fetchPermissions();
    }

    if (permissions.isLoading || permissions.userPermissions == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                "Loading permissions...",
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    String? missingModule;
    for (final module in widget.requiredModules) {
      debugPrint('[WhatsAppPermissionGuard] Checking module: $module, hasModule: ${permissions.hasModule(module)}');
      if (!permissions.hasModule(module, userRole: userRole)) {
        missingModule = module;
        break;
      }
    }

    bool hasPermissionCheck = true;
    if (widget.requiredPermission != null) {
      if (userRole == 'company_admin' || userRole == 'company') {
        hasPermissionCheck = true;
      } else {
        hasPermissionCheck = permissions.hasPermission(widget.requiredPermission!, userRole: userRole);
      }
    }

    if (missingModule != null || !hasPermissionCheck) {
      return const Scaffold(

        appBar: GlobalAppBar(title: 'WhatsApp'),
        body: AccessDeniedWidget(
          sectionName: "WhatsApp",
          showAppBar: false,
        ),
      );
    }
    
    // Check Integration status if permissions passed
    return integrationStatus.when(
      data: (isActive) {
        debugPrint('[WhatsAppPermissionGuard] Integration status data: isActive=$isActive');
        if (!isActive) {
           return _buildErrorState(context, isDark, "WhatsApp Not Connected", "Your company's WhatsApp integration is currently disconnected or inactive.", "Please contact your system administrator to reconnect the WhatsApp Business API.", true);
        }
        return widget.child;
      },
      loading: () => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                "Checking WhatsApp Integration...",
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
      error: (e, _) => _buildErrorState(context, isDark, "WhatsApp Integration Error", "Failed to check WhatsApp integration status.", e.toString(), true),
    );
  }

  Widget _buildErrorState(BuildContext context, bool isDark, String title, String reason, String resolution, bool isIntegrationError) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2130) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Premium Lock Icon Container with vibrant colors
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2D324A)
                          : (isIntegrationError ? Colors.orange.shade50 : Colors.red.shade50),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isIntegrationError ? (isDark ? Colors.orange : Colors.orange) : (isDark ? Colors.blue : Colors.red)).withValues(alpha: 0.15),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      isIntegrationError ? Icons.link_off_rounded : Icons.lock_outline_rounded,
                      size: 52,
                      color: isIntegrationError ? (isDark ? Colors.orange.shade400 : Colors.orange.shade600) : (isDark ? Colors.blue.shade400 : Colors.red.shade600),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    reason,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Divider(color: isDark ? Colors.white10 : Colors.grey[200]),
                  const SizedBox(height: 16),
                  Text(
                    resolution,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: () {
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
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.blue : Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "RETURN BACK",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }
}
