import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../providers/login_provider.dart';
import '../providers/permissions_provider.dart';
import '../../core/constants/permission_constants.dart';
import '../providers/navigation_provider.dart';
import '../screens/home_screen.dart';
import '../screens/leads_screen.dart';
import '../screens/tasks_screen.dart';
import '../screens/visits_screen.dart';
import '../screens/meetings_screen.dart';

// Riverpod provider to manage the shared dock visibility state
class DockVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void update(bool value) => state = value;
}

final dockVisibilityProvider = NotifierProvider<DockVisibilityNotifier, bool>(
  DockVisibilityNotifier.new,
);

final dockLockedHiddenProvider = StateProvider<bool>((ref) => false);

class DockTabItem {
  final String title;
  final String routeName;
  final Widget? screen;

  const DockTabItem({
    required this.title,
    required this.routeName,
    this.screen,
  });
}

class FloatingDockNavBar extends ConsumerStatefulWidget {
  const FloatingDockNavBar({super.key});

  @override
  ConsumerState<FloatingDockNavBar> createState() => _FloatingDockNavBarState();
}

class _FloatingDockNavBarState extends ConsumerState<FloatingDockNavBar> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(dockVisibilityProvider.notifier).update(true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(loginProvider).user;
    final permissions = ref.watch(permissionsProvider);
    final userRole = user?.systemRole;
    final isVisible = ref.watch(dockVisibilityProvider);
    final currentRoute = ref.watch(currentRouteProvider);

    // ── Build visible tab list ─────────────────────────────────────────────
    final List<DockTabItem> visibleTabs = [];

    visibleTabs.add(
      const DockTabItem(
        title: 'Home',
        routeName: 'Dashboard',
        screen: HomeScreen(),
      ),
    );

    final hasLeadsAccess =
        permissions.hasModule(PermissionModules.LEADS, userRole: userRole) &&
        permissions.hasPermission(
          PermissionModules.LEADS_VIEW,
          userRole: userRole,
        );
    if (hasLeadsAccess) {
      visibleTabs.add(
        const DockTabItem(
          title: 'Leads',
          routeName: 'Leads',
          screen: LeadsScreen(),
        ),
      );
    }

    final hasTasksAccess =
        permissions.hasModule(PermissionModules.TASK, userRole: userRole) &&
        permissions.hasPermission(
          PermissionModules.TASKS_VIEW,
          userRole: userRole,
        );
    if (hasTasksAccess) {
      visibleTabs.add(
        const DockTabItem(
          title: 'Followup',
          routeName: 'Tasks',
          screen: TasksScreen(),
        ),
      );
    }

    final hasVisitsAccess =
        permissions.hasModule(PermissionModules.VISITS, userRole: userRole) &&
        permissions.hasPermission(
          PermissionModules.VISITS_VIEW,
          userRole: userRole,
        );
    final hasMeetingsAccess =
        permissions.hasModule(PermissionModules.MEETING, userRole: userRole) &&
        permissions.hasPermission(
          PermissionModules.MEETINGS_VIEW,
          userRole: userRole,
        );

    if (hasVisitsAccess) {
      visibleTabs.add(
        const DockTabItem(
          title: 'Visits',
          routeName: 'Visits',
          screen: VisitsScreen(),
        ),
      );
    } else if (hasMeetingsAccess) {
      visibleTabs.add(
        const DockTabItem(
          title: 'Meetings',
          routeName: 'Meetings',
          screen: MeetingsScreen(),
        ),
      );
    }

    final isMeetingsAlreadyShown = visibleTabs.any((t) => t.routeName == 'Meetings');
    if (hasMeetingsAccess && !isMeetingsAlreadyShown) {
      visibleTabs.add(
        const DockTabItem(title: 'Meetings', routeName: 'Meetings', screen: MeetingsScreen()),
      );
    } else {
      visibleTabs.add(const DockTabItem(title: 'More', routeName: 'Menu'));
    }

    if (visibleTabs.isEmpty) return const SizedBox.shrink();

    // Active index from current route
    final activeIndex = visibleTabs.indexWhere((t) {
      if (t.routeName == 'Meetings') return currentRoute == 'Meetings';
      if (t.routeName == 'Visits') return currentRoute == 'Visits';
      return currentRoute == t.routeName;
    });
    final targetIndex = activeIndex != -1 ? activeIndex : 0;

    return AnimatedSlide(
      offset: isVisible ? Offset.zero : const Offset(0, 1.8),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeInOutCubic,
      child: AnimatedOpacity(
        opacity: isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 240),
        child: IosLiquidGlassNavBar(
          visibleTabs: visibleTabs,
          targetIndex: targetIndex,
          currentRoute: currentRoute,
        ),
      ),
    );
  }
}

class IosLiquidGlassNavBar extends ConsumerStatefulWidget {
  final List<DockTabItem> visibleTabs;
  final int targetIndex;
  final String currentRoute;

  const IosLiquidGlassNavBar({
    super.key,
    required this.visibleTabs,
    required this.targetIndex,
    required this.currentRoute,
  });

  @override
  ConsumerState<IosLiquidGlassNavBar> createState() => _IosLiquidGlassNavBarState();
}

class _IosLiquidGlassNavBarState extends ConsumerState<IosLiquidGlassNavBar> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabCount = widget.visibleTabs.length;
    if (tabCount == 0) return const SizedBox.shrink();

    // Color tokens
    final glassColor = isDark ? const Color(0xB31F2937) : const Color(0xCCFFFFFF);
    final activeTextColor = isDark ? Colors.white : Colors.black;
    final inactiveTextColor = isDark ? Colors.white60 : Colors.black;
    final activeIndicatorColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB); // Grey neomorphic pill
    final borderColor = isDark ? const Color(0x1AFFFFFF) : const Color(0x15000000);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28), // Shifted up slightly from the edge for home indicator clearance
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Liquid Glass Background Wrapper
            LiquidGlass.withOwnLayer(
              shape: LiquidRoundedRectangle(borderRadius: 28),
              settings: LiquidGlassSettings(
                thickness: 16.0,
                blur: 20.0,
                glassColor: glassColor,
                lightIntensity: 0.5,
                refractiveIndex: 1.4,
              ),
              child: Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: borderColor, width: 0.5),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = constraints.maxWidth / tabCount;

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Sliding Pill background (neomorphic glass capsule)
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 380),
                          curve: Curves.easeOutQuad,
                          alignment: Alignment(
                            tabCount > 1
                                ? -1.0 + (widget.targetIndex * 2.0 / (tabCount - 1))
                                : 0.0,
                            0,
                          ),
                          child: Container(
                            width: itemWidth - 4,
                            height: 48,
                            decoration: BoxDecoration(
                              color: activeIndicatorColor,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isDark ? const Color(0x26FFFFFF) : const Color(0x80FFFFFF),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Nav Items
                        Row(
                          children: List.generate(tabCount, (index) {
                            final tab = widget.visibleTabs[index];
                            final bool isActive = (widget.targetIndex == index);

                            // Icon selection (outlined when inactive, filled when active)
                            IconData icon;
                            switch (tab.title) {
                              case 'Home':
                                icon = isActive ? Icons.home : Icons.home_outlined;
                                break;
                              case 'Leads':
                                icon = isActive ? Icons.people : Icons.people_outline;
                                break;
                              case 'Followup':
                                icon = isActive ? Icons.assignment : Icons.assignment_outlined;
                                break;
                              case 'Visits':
                                icon = isActive ? Icons.location_on : Icons.location_on_outlined;
                                break;
                              case 'Meetings':
                                icon = isActive ? Icons.calendar_today : Icons.calendar_today_outlined;
                                break;
                              default:
                                icon = isActive ? Icons.more_horiz : Icons.more_horiz_outlined;
                                break;
                            }

                            // Magnifier scale calculation for icons only
                            final double scale = widget.targetIndex == index
                                ? 1.25
                                : ((widget.targetIndex - index).abs() == 1 ? 1.10 : 1.0);

                            return Expanded(
                              child: GestureDetector(
                                onTap: () => _onTabTap(tab),
                                behavior: HitTestBehavior.opaque,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    AnimatedScale(
                                      scale: scale,
                                      duration: const Duration(milliseconds: 280),
                                      curve: Curves.easeOutBack,
                                      child: Icon(
                                        icon,
                                        size: 21,
                                        color: isActive ? activeTextColor : inactiveTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      tab.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 9.5, // slightly smaller text
                                        fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                                        color: isActive ? activeTextColor : inactiveTextColor,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTabTap(DockTabItem tab) {
    if (tab.routeName == 'Menu') {
      Scaffold.of(context).openDrawer();
      HapticFeedback.mediumImpact();
      return;
    }

    final currentRoute = ref.read(currentRouteProvider);
    if (tab.routeName == 'Visits') {
      if (currentRoute == 'Visits') return;
    } else if (tab.routeName == 'Meetings') {
      if (currentRoute == 'Meetings') return;
    } else if (currentRoute == tab.routeName) {
      return;
    }

    HapticFeedback.mediumImpact();

    // Update the global navigation provider to switch tabs without rebuilding routes
    ref.read(currentRouteProvider.notifier).state = tab.routeName;
  }
}
