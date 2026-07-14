import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../providers/login_provider.dart';
import '../providers/permissions_provider.dart';
import '../../core/constants/permission_constants.dart';
import '../providers/navigation_provider.dart';
import '../screens/home_screen.dart';
import '../screens/leads_screen.dart';
import '../screens/tasks_screen.dart';
import '../screens/visits_screen.dart';
import '../screens/meetings_screen.dart';

// ─── Glassmorphism Color Tokens ──────────────────────────────────────────────
const _kNavbarBg = Color(0xFFFFFFFF); // Solid white background
const _kPillBg = Color(0xFFE5E7EB); // Selected Tab Pill (light gray)
const _kActiveColor = Color(0xFF374151); // Active Icon + Text (gray)
const _kInactiveColor = Color(0xFF9CA3AF); // Inactive Icon + Text
const _kBorderColor = Color(0xFFE5E7EB); // Light border

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
  // Drag tracking state
  double? _dragX;
  bool _isDragging = false;
  int _lastHoveredIndex = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(dockVisibilityProvider.notifier).update(true);
      }
    });
  }

  Widget _buildTabIcon(String title, bool isActive, Color color) {
    if (title == 'Visits') {
      return Icon(
        Icons.location_on_outlined,
        size: 26,
        color: color,
      );
    }
    String asset;
    switch (title) {
      case 'Home':
        asset = 'assets/icons/tab_home.svg';
      case 'Leads':
        asset = 'assets/icons/tab_people.svg';
      case 'Tasks':
        asset = 'assets/icons/tab_tasks.svg';
      case 'Meetings':
        asset = 'assets/icons/tab_calendar.svg';
      case 'Menu':
        asset = 'assets/icons/tab_menu.svg';
      default:
        asset = 'assets/icons/tab_home.svg';
    }
    return SvgPicture.asset(
      asset,
      width: 26,
      height: 26,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(loginProvider).user;
    final permissions = ref.watch(permissionsProvider);
    final userRole = user?.systemRole;
    final isVisible = ref.watch(dockVisibilityProvider);
    final currentRoute = ref.watch(currentRouteProvider);

    // ── Glassmorphism color overrides for dark mode ────────────────────────
    final navbarBg = isDark ? const Color(0xCC1A1A1A) : _kNavbarBg;
    final pillBg = isDark ? const Color(0xFF2C2C2C) : _kPillBg;
    final activeColor = isDark ? Colors.white : _kActiveColor;
    final inactiveColor = isDark ? const Color(0xFF888888) : _kInactiveColor;
    final borderColor = isDark ? const Color(0x1AFFFFFF) : _kBorderColor;

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
          title: 'Tasks',
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
      visibleTabs.add(const DockTabItem(title: 'Menu', routeName: 'Menu'));
    }

    if (visibleTabs.isEmpty) return const SizedBox.shrink();

    // Active index from current route
    final activeIndex = visibleTabs.indexWhere((t) {
      if (t.routeName == 'Meetings') return currentRoute == 'Meetings';
      if (t.routeName == 'Visits') return currentRoute == 'Visits';
      return currentRoute == t.routeName;
    });
    final targetIndex = activeIndex != -1 ? activeIndex : 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: AnimatedSlide(
              offset: isVisible ? Offset.zero : const Offset(0, 1.8),
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeInOutCubic,
              child: AnimatedOpacity(
                opacity: isVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 240),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Container(
                    decoration: BoxDecoration(
                      color: navbarBg,
                      borderRadius: BorderRadius.circular(36),
                      border: Border.all(color: borderColor, width: 0.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x26000000),
                          blurRadius: 12,
                          offset: Offset(0, -2),
                        ),
                        BoxShadow(
                          color: Color(0x10000000),
                          blurRadius: 24,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                        child: Stack(
                          children: [
                            // ── Glass reflection highlight ──────────────
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 36,
                              child: IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: isDark
                                          ? [
                                              Colors.white.withValues(
                                                alpha: 0.10,
                                              ),
                                              Colors.white.withValues(
                                                alpha: 0.02,
                                              ),
                                              Colors.transparent,
                                            ]
                                          : [
                                              Colors.white.withValues(
                                                alpha: 0.55,
                                              ),
                                              Colors.white.withValues(
                                                alpha: 0.12,
                                              ),
                                              Colors.transparent,
                                            ],
                                      stops: const [0.0, 0.35, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // ── Tab content ─────────────────────────────
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final totalWidth = constraints.maxWidth;
                                  final tabCount = visibleTabs.length;
                                  final tabWidth = totalWidth / tabCount;

                                  // Pill position and magnification sync
                                  final pillTargetIndex = _isDragging
                                      ? _lastHoveredIndex
                                      : targetIndex;
                                  final pillLeft =
                                      (pillTargetIndex * tabWidth) + 2;
                                  final pillWidth = tabWidth - 4;

                                  double pillScale = 1.0;
                                  double pillTranslateY = 0.0;

                                  if (_isDragging && _dragX != null) {
                                    final centerX =
                                        (pillTargetIndex + 0.5) * tabWidth;
                                    final distance = (_dragX! - centerX).abs();
                                    const sigma = 48.0;
                                    const maxScaleDelta = 0.28;
                                    pillScale =
                                        1.0 +
                                        maxScaleDelta *
                                            math.exp(
                                              -(distance * distance) /
                                                  (2 * sigma * sigma),
                                            );
                                    pillTranslateY = -(pillScale - 1.0) * 10.0;
                                  }

                                  return Listener(
                                    onPointerDown: (event) {
                                      setState(() {
                                        _isDragging = true;
                                        _dragX = event.localPosition.dx;
                                      });
                                      _handleHover(
                                        event.localPosition.dx,
                                        tabWidth,
                                        tabCount,
                                      );
                                    },
                                    onPointerMove: (event) {
                                      setState(() {
                                        _dragX = event.localPosition.dx;
                                      });
                                      _handleHover(
                                        event.localPosition.dx,
                                        tabWidth,
                                        tabCount,
                                      );
                                    },
                                    onPointerUp: (event) {
                                      final localX = event.localPosition.dx;
                                      final finalIndex = (localX / tabWidth)
                                          .floor()
                                          .clamp(0, tabCount - 1);
                                      setState(() {
                                        _isDragging = false;
                                        _dragX = null;
                                      });
                                      _onTabTap(visibleTabs[finalIndex]);
                                    },
                                    child: SizedBox(
                                      height: 64,
                                      child: Stack(
                                        children: [
                                          // ── Animated sliding pill background ──────
                                          AnimatedPositioned(
                                            duration: _isDragging
                                                ? Duration.zero
                                                : const Duration(
                                                    milliseconds: 280,
                                                  ),
                                            curve: Curves.easeOutCubic,
                                            left: pillLeft,
                                            width: pillWidth,
                                            top: 2,
                                            bottom: 2,
                                            child: AnimatedScale(
                                              scale: pillScale,
                                              duration: _isDragging
                                                  ? Duration.zero
                                                  : const Duration(
                                                      milliseconds: 280,
                                                    ),
                                              curve: Curves.easeOutBack,
                                              child: Transform.translate(
                                                offset: Offset(
                                                  0,
                                                  pillTranslateY,
                                                ),
                                                 child: Container(
                                                   decoration: BoxDecoration(
                                                     color: activeIndex == -1 ? Colors.transparent : pillBg,
                                                     borderRadius:
                                                         BorderRadius.circular(
                                                           28,
                                                         ),
                                                   ),
                                                 ),
                                              ),
                                            ),
                                          ),

                                          // ── Tab items row ─────────────────────────
                                          Row(
                                            children: List.generate(tabCount, (
                                              index,
                                            ) {
                                              final tab = visibleTabs[index];
                                              final bool isActive;
                                              if (tab.routeName == 'Meetings') {
                                                isActive = currentRoute == 'Meetings';
                                              } else if (tab.routeName == 'Visits') {
                                                isActive = currentRoute == 'Visits';
                                              } else {
                                                isActive = currentRoute == tab.routeName;
                                              }

                                              // Magnification
                                              double scale = 1.0;
                                              double translateY = 0.0;
                                              if (_isDragging &&
                                                  _dragX != null) {
                                                final centerX =
                                                    (index + 0.5) * tabWidth;
                                                final distance =
                                                    (_dragX! - centerX).abs();
                                                const sigma = 48.0;
                                                const maxScaleDelta = 0.28;
                                                scale =
                                                    1.0 +
                                                    maxScaleDelta *
                                                        math.exp(
                                                          -(distance *
                                                                  distance) /
                                                              (2 *
                                                                  sigma *
                                                                  sigma),
                                                        );
                                                translateY =
                                                    -(scale - 1.0) * 10.0;
                                              }

                                              return Expanded(
                                                child: AnimatedScale(
                                                  scale: scale,
                                                  duration: _isDragging
                                                      ? Duration.zero
                                                      : const Duration(
                                                          milliseconds: 280,
                                                        ),
                                                  curve: Curves.easeOutBack,
                                                  child: Transform.translate(
                                                    offset: Offset(
                                                      0,
                                                      translateY,
                                                    ),
                                                    child: SizedBox(
                                                      height: 64,
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          AnimatedSwitcher(
                                                            duration:
                                                                const Duration(
                                                                  milliseconds:
                                                                      200,
                                                                ),
                                                            child: SizedBox(
                                                              key: ValueKey(
                                                                '${tab.title}_$isActive',
                                                              ),
                                                              width: 26,
                                                              height: 26,
                                                              child: _buildTabIcon(
                                                                tab.title,
                                                                isActive,
                                                                isActive
                                                                    ? activeColor
                                                                    : inactiveColor,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 3,
                                                          ),
                                                          AnimatedDefaultTextStyle(
                                                            duration:
                                                                const Duration(
                                                                  milliseconds:
                                                                      200,
                                                                ),
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  isActive
                                                                  ? FontWeight
                                                                        .w700
                                                                  : FontWeight
                                                                        .w500,
                                                              letterSpacing:
                                                                  -0.3,
                                                              color: isActive
                                                                  ? activeColor
                                                                  : inactiveColor,
                                                            ),
                                                              child: Text(
                                                                tab.title,
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                      ),
                  ), // Container
                ), // ConstrainedBox
              ), // AnimatedOpacity
            ), // AnimatedSlide
          ), // Padding
        ), // SafeArea
      ],
    );
  }

  void _handleHover(double dx, double tabWidth, int tabCount) {
    final hoveredIndex = (dx / tabWidth).floor().clamp(0, tabCount - 1);
    if (hoveredIndex != _lastHoveredIndex) {
      setState(() {
        _lastHoveredIndex = hoveredIndex;
      });
      HapticFeedback.lightImpact();
    }
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
