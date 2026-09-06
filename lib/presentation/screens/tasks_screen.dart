/*
// ORIGINAL CODE PRESERVED BELOW FOR REFERENCE:
// import 'package:flutter/material.dart';
// import '../widgets/common_shimmer_skeleton.dart';
// import 'package:google_fonts/google_fonts.dart';
// import '../widgets/voice_to_text_dialog.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../widgets/global_app_bar.dart';
// import '../providers/task_provider.dart';
// import '../widgets/task_create_dialog.dart';
// import '../../data/models/task_model.dart';
// import '../../data/models/notification_model.dart';
// import 'lead_profile_screen.dart';
// import '../../core/utils/date_utils.dart';
// import '../providers/login_provider.dart';
// import '../../core/constants/permission_constants.dart';
// import '../providers/permissions_provider.dart';
// import '../widgets/access_denied_widget.dart';
*/

// import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../widgets/common_shimmer_skeleton.dart';
import '../widgets/voice_to_text_dialog.dart';
import '../widgets/global_app_bar.dart';
import '../widgets/task_create_dialog.dart';
import '../widgets/access_denied_widget.dart';
import '../../data/models/task_model.dart';
import '../../data/models/notification_model.dart';
import '../../data/models/staff_model.dart';
import '../../core/utils/date_utils.dart';
import '../../core/services/call_service.dart';
import '../../core/constants/permission_constants.dart';
import '../providers/task_provider.dart';
import '../providers/login_provider.dart';
import '../providers/permissions_provider.dart';
import '../providers/staff_provider.dart';
import '../providers/lead_provider.dart';
import 'lead_profile_screen.dart';
import 'reminders_screen.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // final TextEditingController _searchController = TextEditingController();
  // bool _isSearchVisible = false;
  // String _localSearchQuery = '';
  // double _horizontalDragDistance = 0;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _tabScrollController = ScrollController();
  bool _isSearchVisible = false;
  String _localSearchQuery = '';
  double _horizontalDragDistance = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ref.read(tasksProvider.notifier).fetchTasks(page: 1);
      ref.read(tasksProvider.notifier).fetchTasks(page: 1);
      ref.read(tasksProvider.notifier).fetchTabCounts();
      // Pre-load staff for Admin/Manager filter dropdowns
      try {
        ref.read(staffProvider('sales_executive').notifier).fetchUsers();
        ref.read(staffProvider('team_leader').notifier).fetchUsers();
        ref.read(staffProvider('sales_manager').notifier).fetchUsers();
        ref.read(staffProvider('admin').notifier).fetchUsers();
      } catch (e) {
        debugPrint("Error fetching staff for tasks filter: $e");
      }
    });
  }

  // @override
  // void dispose() {
  //   _searchController.dispose();
  //   super.dispose();
  // }
  @override
  void dispose() {
    _searchController.dispose();
    _tabScrollController.dispose();
    super.dispose();
  }

  void _scrollToTab(int index) {
    if (!_tabScrollController.hasClients) return;
    final targetOffset = (index * 110.0 - 40.0).clamp(0.0, _tabScrollController.position.maxScrollExtent);
    _tabScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _loadMore() {
    final state = ref.read(tasksProvider);
    final pagination = state.pagination;
    if (!state.isLoading && 
        !state.isLoadingMore && 
        pagination != null && 
        pagination.hasNextPage) {
      debugPrint("TasksScreen: Loading more... next page: ${pagination.page + 1}");
      ref.read(tasksProvider.notifier).fetchTasks(page: pagination.page + 1);
    }
  }

  void _openDrawer(BuildContext context) {
    ScaffoldState? scaffoldState;
    context.visitAncestorElements((element) {
      if (element.widget is Scaffold) {
        final scaffold = element.widget as Scaffold;
        if (scaffold.drawer != null) {
          scaffoldState = (element as StatefulElement).state as ScaffoldState;
          return false;
        }
      }
      return true;
    });

    if (scaffoldState != null) {
      scaffoldState!.openDrawer();
    } else {
      try {
        Scaffold.of(context).openDrawer();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(tasksProvider);
    ref.listen<TasksState>(tasksProvider, (prev, next) {
      if (prev?.selectedCategory != next.selectedCategory) {
        const categories = ['overdue', 'upcoming', 'completed', 'all'];
        final idx = categories.indexOf(next.selectedCategory);
        if (idx != -1) {
          _scrollToTab(idx);
        }
      }
    });
    final user = ref.watch(loginProvider).user;
    final topBarColor = isDark ? theme.scaffoldBackgroundColor : Colors.white;

    final permissions = ref.watch(permissionsProvider);
    if (!permissions.hasModule(PermissionModules.TASK, userRole: user?.systemRole) ||
        !permissions.hasPermission(PermissionModules.TASKS_VIEW, userRole: user?.systemRole)) {
      return const Scaffold(
        extendBody: true,
        appBar: GlobalAppBar(title: 'Tasks'),
        body: AccessDeniedWidget(
          sectionName: "Tasks",
          showAppBar: false,
        ),
      );
    }

    // final canCreateTask = permissions.can(
    //   PermissionModules.TASK,
    //   permission: PermissionModules.TASKS_CREATE,
    //   userRole: user?.systemRole,
    // );

    // Filter tasks locally by search query as an instant, responsive layer
    // final filteredTasks = state.tasks.where((task) {
    //   if (_localSearchQuery.isEmpty) return true;
    //   final q = _localSearchQuery.toLowerCase();
    //   final titleMatch = task.title.toLowerCase().contains(q);
    //   final descMatch = task.description != null && task.description!.toLowerCase().contains(q);
    //   final leadNameMatch = task.lead != null && task.lead!.name.toLowerCase().contains(q);
    //   final phoneMatch = (task.phone != null && task.phone!.contains(q)) ||
    //       (task.lead?.phone != null && task.lead!.phone!.contains(q));
    //   return titleMatch || descMatch || leadNameMatch || phoneMatch;
    // }).toList();

    final filteredTasks = state.tasks.where((task) {
      if (_localSearchQuery.isEmpty) return true;
      final q = _localSearchQuery.toLowerCase();
      final titleMatch = task.title.toLowerCase().contains(q);
      final descMatch = task.description != null && task.description!.toLowerCase().contains(q);
      final leadNameMatch = task.lead != null && task.lead!.name.toLowerCase().contains(q);
      final phoneMatch = (task.phone != null && task.phone!.contains(q)) ||
          (task.lead?.phone != null && task.lead!.phone!.contains(q));
      return titleMatch || descMatch || leadNameMatch || phoneMatch;
    }).toList();

    // Local sorting layer to guarantee immediate UI updates matching state.sortBy
    int compareDates(String? d1, String? d2, bool asc) {
      if (d1 == null && d2 == null) return 0;
      if (d1 == null) return 1;
      if (d2 == null) return -1;
      final dt1 = DateTime.tryParse(d1);
      final dt2 = DateTime.tryParse(d2);
      if (dt1 != null && dt2 != null) {
        return asc ? dt1.compareTo(dt2) : dt2.compareTo(dt1);
      }
      return asc ? d1.compareTo(d2) : d2.compareTo(d1);
    }

    filteredTasks.sort((a, b) {
      switch (state.sortBy) {
        case 'dueDate_asc':
          return compareDates(a.dueDate, b.dueDate, true);
        case 'dueDate_desc':
          return compareDates(a.dueDate, b.dueDate, false);
        case 'createdAt_desc':
          return compareDates(a.createdAt, b.createdAt, false);
        case 'createdAt_asc':
          return compareDates(a.createdAt, b.createdAt, true);
        case 'updatedAt_desc':
          return compareDates(a.updatedAt, b.updatedAt, false);
        case 'updatedAt_asc':
          return compareDates(a.updatedAt, b.updatedAt, true);
        default:
          return 0;
      }
    });

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      extendBody: true,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(
              Icons.menu_rounded,
              color: isDark ? Colors.white : Colors.black87,
              size: 26,
            ),
            onPressed: () => _openDrawer(ctx),
          ),
        ),
        titleSpacing: 0,
        // title: Text(
        //   'Tasks',
        //   style: GoogleFonts.plusJakartaSans(
        //     fontSize: 22,
        //     fontWeight: FontWeight.w800,
        //     color: isDark ? Colors.white : Colors.black87,
        //     letterSpacing: -0.5,
        //   ),
        // ),
        title: Text(
          'Follow Ups',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearchVisible ? Icons.search_off_rounded : Icons.search_rounded,
              color: _isSearchVisible ? const Color(0xFF2563EB) : (isDark ? Colors.white70 : Colors.black87),
              size: 24,
            ),
            tooltip: 'Search Follow Ups',
            onPressed: () {
              setState(() {
                _isSearchVisible = !_isSearchVisible;
                if (!_isSearchVisible) {
                  _searchController.clear();
                  _localSearchQuery = '';
                  ref.read(tasksProvider.notifier).setSearchQuery('');
                }
              });
            },
          ),
          IconButton(
            icon: Icon(
              Icons.notifications_none_rounded,
              color: isDark ? Colors.white70 : Colors.black87,
              size: 24,
            ),
            tooltip: 'Reminders & Notifications',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RemindersScreen()),
              );
            },
          ),
          // if (canCreateTask)
          //   Padding(
          //     padding: const EdgeInsets.only(right: 14, left: 4),
          //     child: Center(
          //       child: InkWell(
          //         onTap: () {
          //           showDialog(
          //             context: context,
          //             builder: (context) => const TaskCreateDialog(),
          //           );
          //         },
          //         borderRadius: BorderRadius.circular(8),
          //         child: Container(
          //           width: 36,
          //           height: 36,
          //           decoration: BoxDecoration(
          //             color: const Color(0xFF2563EB),
          //             borderRadius: BorderRadius.circular(8),
          //           ),
          //           child: const Icon(
          //             Icons.add_rounded,
          //             color: Colors.white,
          //             size: 22,
          //           ),
          //         ),
          //       ),
          //     ),
          //   ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Top Controls Area
          // Container(
          //   color: topBarColor,
          //   width: double.infinity,
          //   child: Column(
          //     crossAxisAlignment: CrossAxisAlignment.start,
          //     children: [
          //       // Expandable Search Bar (when search icon in AppBar is toggled)
          //       if (_isSearchVisible)
          //         _buildSearchBar(isDark),
          //
          //       const SizedBox(height: 8),
          //
          //       // 4 Permanent Tabs (Overdue, Upcoming, Completed, All)
          //       _buildPermanentTabs(state, isDark),
          //
          //       const SizedBox(height: 10),
          //
          //       // 4 Controls Row (Filters, Sort, Refresh, Quick Date)
          //       _buildControlsRow(state, isDark),
          //
          //       // Removable Active Filter Chips (if any filters active)
          //       if (_hasActiveFilters(state))
          //         _buildActiveFilterChips(state, isDark),
          //
          //       const SizedBox(height: 10),
          //     ],
          //   ),
          // ),
          //
          // // Divider below controls
          // Divider(height: 1, thickness: 1, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),

          // Top Header Area (Search Bar + Horizontally Scrollable Tabs)
          Container(
            color: topBarColor,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isSearchVisible) _buildSearchBar(isDark),
                _buildPermanentTabs(state, isDark),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),

          // Task List View
          // Expanded(
          //   child: _buildTaskList(filteredTasks, state, context, isDark),
          // ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (_) {
                _horizontalDragDistance = 0;
              },
              onHorizontalDragUpdate: (details) {
                _horizontalDragDistance += details.primaryDelta ?? 0;
              },
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                const categories = ['overdue', 'upcoming', 'completed', 'all'];
                final currentIndex = categories.indexOf(state.selectedCategory);
                if (currentIndex == -1) return;

                // Swipe Right-to-Left (finger moved left) -> Next Tab
                if ((velocity < -250 || _horizontalDragDistance < -60) && currentIndex < categories.length - 1) {
                  ref.read(tasksProvider.notifier).setCategory(categories[currentIndex + 1]);
                }
                // Swipe Left-to-Right (finger moved right) -> Previous Tab
                else if ((velocity > 250 || _horizontalDragDistance > 60) && currentIndex > 0) {
                  ref.read(tasksProvider.notifier).setCategory(categories[currentIndex - 1]);
                }
                _horizontalDragDistance = 0;
              },
              onHorizontalDragCancel: () {
                _horizontalDragDistance = 0;
              },
              child: _buildTaskList(filteredTasks, state, context, isDark),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // SEARCH BAR
  // --------------------------------------------------------------------------
  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(
              Icons.search,
              size: 20,
              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (val) {
                  setState(() {
                    _localSearchQuery = val;
                  });
                  ref.read(tasksProvider.notifier).setSearchQuery(val);
                },
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: 'Search by title, lead, phone...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _localSearchQuery = '';
                  });
                  ref.read(tasksProvider.notifier).setSearchQuery('');
                },
              ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withValues(alpha: 0.12),
                ),
                child: const Icon(Icons.mic_rounded, size: 16, color: Colors.blue),
              ),
              tooltip: 'Voice Search',
              onPressed: () async {
                final text = await VoiceToTextDialog.show(
                  context: context,
                  title: 'Search Tasks',
                  targetController: _searchController,
                );
                if (text != null && text.isNotEmpty) {
                  setState(() {
                    _localSearchQuery = text;
                  });
                  ref.read(tasksProvider.notifier).setSearchQuery(text);
                }
              },
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 4 PERMANENT TABS (Overdue, Upcoming, Completed, All)
  // --------------------------------------------------------------------------
  // Widget _buildPermanentTabs(TasksState state, bool isDark) {
  //   final currentCategory = state.selectedCategory;
  //   final tabs = [ ... ];
  //   return Container(
  //     height: 44,
  //     padding: const EdgeInsets.symmetric(horizontal: 16),
  //     child: Row(
  //       children: tabs.map((tab) {
  //         return Expanded(
  //           child: GestureDetector(
  //             onTap: () { ref.read(tasksProvider.notifier).setCategory(tab['key'] as String); },
  //             child: AnimatedContainer(...),
  //           ),
  //         );
  //       }).toList(),
  //     ),
  //   );
  // }
  Widget _buildPermanentTabs(TasksState state, bool isDark) {
    final currentCategory = state.selectedCategory;

    final tabs = [
      {
        'key': 'overdue',
        'label': 'Overdue',
        'count': state.overdueCount,
        'activeColor': const Color(0xFFEF4444),
      },
      {
        'key': 'upcoming',
        'label': 'Upcoming',
        'count': state.upcomingCount,
        'activeColor': const Color(0xFF2563EB),
      },
      {
        'key': 'completed',
        'label': 'Completed',
        'count': state.completedCount,
        'activeColor': const Color(0xFF059669),
      },
      {
        'key': 'all',
        'label': 'All',
        'count': state.allCount,
        'activeColor': const Color(0xFF2563EB),
      },
    ];

    return SizedBox(
      height: 44,
      child: SingleChildScrollView(
        controller: _tabScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: tabs.map((tab) {
            final isSelected = currentCategory == tab['key'];
            final activeColor = tab['activeColor'] as Color;
            final count = tab['count'] as int;

            return InkWell(
              onTap: () {
                ref.read(tasksProvider.notifier).setCategory(tab['key'] as String);
              },
              splashColor: activeColor.withValues(alpha: 0.08),
              highlightColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? activeColor : Colors.transparent,
                      width: 3.0,
                    ),
                  ),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tab['label'] as String,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? (tab['key'] == 'overdue'
                                ? const Color(0xFFDC2626)
                                : (tab['key'] == 'completed'
                                    ? const Color(0xFF059669)
                                    : const Color(0xFF2563EB)))
                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Badge Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? activeColor.withValues(alpha: 0.14)
                            : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? activeColor
                              : (isDark ? Colors.white70 : const Color(0xFF475569)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 4 CONTROLS ROW (Filters, Sort, Refresh, Quick Date)
  // --------------------------------------------------------------------------
  Widget _buildControlsRow(TasksState state, bool isDark) {
    // final hasFiltersApplied = (state.fromDue != null && state.fromDue!.isNotEmpty) ||
    //     (state.assignedTo != null && state.assignedTo!.isNotEmpty) ||
    //     (state.statusFilter != null && state.statusFilter != 'all');
    final hasFiltersApplied = (state.fromDue != null && state.fromDue!.isNotEmpty) ||
        (state.toDue != null && state.toDue!.isNotEmpty) ||
        (state.assignedTo != null && state.assignedTo!.isNotEmpty) ||
        (state.statusFilter != null &&
            state.statusFilter!.isNotEmpty &&
            state.statusFilter!.toLowerCase() != 'all');

    // final hasSortApplied = (state.selectedCategory == 'overdue' && state.sortBy != 'due_asc') ||
    //     (state.selectedCategory == 'upcoming' && state.sortBy != 'due_asc') ||
    //     (state.selectedCategory == 'completed' && state.sortBy != 'updated_desc') ||
    //     (state.selectedCategory == 'all' && state.sortBy != 'due_asc');
    //
    // final hasQuickDateApplied = (state.quickDate ?? 'all') != 'all';

    final hasSortApplied = (state.selectedCategory == 'overdue' && state.sortBy != 'dueDate_asc') ||
        (state.selectedCategory == 'upcoming' && state.sortBy != 'dueDate_asc') ||
        (state.selectedCategory == 'completed' && state.sortBy != 'updatedAt_desc') ||
        (state.selectedCategory == 'all' && state.sortBy != 'dueDate_asc');

    final hasQuickDateApplied = _isQuickDateActive(state.selectedCategory, state.quickDate);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // 1. Filters Button
          Expanded(
            child: _buildControlItem(
              icon: Icons.tune_rounded,
              label: 'Filters',
              hasActiveDot: hasFiltersApplied,
              isDark: isDark,
              onTap: () => _showFiltersSheet(context, ref, state),
            ),
          ),
          const SizedBox(width: 8),

          // 2. Sort Button
          Expanded(
            child: _buildControlItem(
              icon: Icons.swap_vert_rounded,
              label: 'Sort',
              hasActiveDot: hasSortApplied,
              isDark: isDark,
              onTap: () => _showSortSheet(context, ref, state),
            ),
          ),
          const SizedBox(width: 8),

          // 3. Quick Date Dropdown / Sheet
          Expanded(
            child: _buildControlItem(
              icon: Icons.bolt_rounded,
              label: _getQuickDateButtonLabel(state.selectedCategory, state.quickDate ?? 'all', dateField: state.dateField),
              hasActiveDot: hasQuickDateApplied,
              isDark: isDark,
              onTap: () => _showQuickDateSheet(context, ref, state),
            ),
          ),
          const SizedBox(width: 8),

          // 4. Refresh Button
          Expanded(
            child: _buildControlItem(
              icon: Icons.refresh_rounded,
              label: 'Refresh',
              hasActiveDot: false,
              isDark: isDark,
              onTap: () => ref.read(tasksProvider.notifier).refresh(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlItem({
    required IconData icon,
    required String label,
    required bool hasActiveDot,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasActiveDot
                  ? const Color(0xFF2563EB)
                  : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: hasActiveDot
                        ? const Color(0xFF2563EB)
                        : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                  ),
                  if (hasActiveDot)
                    Positioned(
                      top: -2,
                      right: -3,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: hasActiveDot
                        ? const Color(0xFF2563EB)
                        : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // ACTIVE FILTER CHIPS (Removable)
  // --------------------------------------------------------------------------
  // bool _hasActiveFilters(TasksState state) {
  //   final hasDateRange = state.fromDue != null && state.fromDue!.isNotEmpty;
  //   final hasQuickDate = (state.quickDate ?? 'all') != 'all';
  //   final hasAssigned = state.assignedTo != null && state.assignedTo!.isNotEmpty;
  //   final hasStatus = state.statusFilter != null && state.statusFilter != 'all';
  //   return hasDateRange || hasQuickDate || hasAssigned || hasStatus;
  // }
  bool _isQuickDateActive(String category, String? quickDate) {
    if (quickDate == null) return false;
    if (category == 'overdue') {
      return quickDate != 'overdue' && quickDate != 'all';
    }
    return quickDate != 'all';
  }

  // bool _hasActiveFilters(TasksState state) {
  //   final hasDateRange = (state.fromDue != null && state.fromDue!.isNotEmpty) ||
  //       (state.toDue != null && state.toDue!.isNotEmpty);
  //   final hasQuickDate = (state.quickDate ?? 'all') != 'all';
  //   final hasAssigned = state.assignedTo != null && state.assignedTo!.isNotEmpty;
  //   final hasStatus = state.statusFilter != null &&
  //       state.statusFilter!.isNotEmpty &&
  //       state.statusFilter!.toLowerCase() != 'all';
  //   return hasDateRange || hasQuickDate || hasAssigned || hasStatus;
  // }
  bool _hasActiveFilters(TasksState state) {
    final hasDateRange = (state.fromDue != null && state.fromDue!.isNotEmpty) ||
        (state.toDue != null && state.toDue!.isNotEmpty);
    final hasQuickDate = _isQuickDateActive(state.selectedCategory, state.quickDate);
    final hasAssigned = state.assignedTo != null && state.assignedTo!.isNotEmpty;
    final hasStatus = state.statusFilter != null &&
        state.statusFilter!.isNotEmpty &&
        state.statusFilter!.toLowerCase() != 'all';
    return hasDateRange || hasQuickDate || hasAssigned || hasStatus;
  }

  // Widget _buildActiveFilterChips(TasksState state, bool isDark) {
  //   return Padding(
  //     padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
  //     child: SingleChildScrollView(
  //       scrollDirection: Axis.horizontal,
  //       child: Row( ... ),
  //     ),
  //   );
  // }
  Widget _buildActiveFilterChips(TasksState state, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 28,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Quick Date Chip
              // if ((state.quickDate ?? 'all') != 'all')
              //   _buildFilterChip(
              //     label: 'Date: ${_getQuickDateButtonLabel(state.selectedCategory, state.quickDate ?? 'all')}',
              //     onRemove: () => ref.read(tasksProvider.notifier).setQuickDate('all'),
              //     isDark: isDark,
              //   ),
              if (_isQuickDateActive(state.selectedCategory, state.quickDate))
                _buildFilterChip(
                  label: 'Date: ${_getQuickDateButtonLabel(state.selectedCategory, state.quickDate ?? 'all', dateField: state.dateField)}',
                  onRemove: () => ref.read(tasksProvider.notifier).setQuickDate(
                    state.selectedCategory == 'overdue' ? 'overdue' : 'all',
                  ),
                  isDark: isDark,
                ),

              // Date Range Chip
              if (state.fromDue != null && state.fromDue!.isNotEmpty)
                _buildFilterChip(
                  label: '${state.fromDue} → ${state.toDue ?? 'Now'}',
                  onRemove: () {
                    ref.read(tasksProvider.notifier).setFilters(
                      dateField: state.dateField,
                      fromDue: null,
                      toDue: null,
                      assignedTo: state.assignedTo,
                      assignedToName: state.assignedToName,
                      statusFilter: state.statusFilter,
                    );
                  },
                  isDark: isDark,
                ),

              // Assigned Member Chip
              if (state.assignedTo != null && state.assignedTo!.isNotEmpty)
                _buildFilterChip(
                  label: 'Assigned: ${state.assignedToName ?? 'User'}',
                  onRemove: () {
                    ref.read(tasksProvider.notifier).setFilters(
                      dateField: state.dateField,
                      fromDue: state.fromDue,
                      toDue: state.toDue,
                      assignedTo: null,
                      assignedToName: null,
                      statusFilter: state.statusFilter,
                    );
                  },
                  isDark: isDark,
                ),

              // Status Filter Chip (on All Tab)
              // if (state.statusFilter != null && state.statusFilter != 'all')
              if (state.statusFilter != null &&
                  state.statusFilter!.isNotEmpty &&
                  state.statusFilter!.toLowerCase() != 'all')
                _buildFilterChip(
                  label: 'Status: ${state.statusFilter}',
                  onRemove: () {
                    ref.read(tasksProvider.notifier).setFilters(
                      dateField: state.dateField,
                      fromDue: state.fromDue,
                      toDue: state.toDue,
                      assignedTo: state.assignedTo,
                      assignedToName: state.assignedToName,
                      statusFilter: 'all',
                    );
                  },
                  isDark: isDark,
                ),

              // Clear All Button
              // ORIGINAL:
              // GestureDetector(
              //   onTap: () => ref.read(tasksProvider.notifier).clearFilters(),
              //   child: Container(
              //     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              //     decoration: BoxDecoration(
              //       color: Colors.red.withValues(alpha: 0.1),
              //       borderRadius: BorderRadius.circular(16),
              //     ),
              //     child: const Text(
              //       'Clear All',
              //       style: TextStyle(
              //         color: Colors.red,
              //         fontSize: 11,
              //         fontWeight: FontWeight.w700,
              //       ),
              //     ),
              //   ),
              // ),
              GestureDetector(
                onTap: () => ref.read(tasksProvider.notifier).clearFilters(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : const Color(0xFF0F172A).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Clear All',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required VoidCallback onRemove,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.only(left: 10, right: 6, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2563EB).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: Color(0xFF2563EB),
            ),
          ),
        ],
      ),
    );
  }

  // String _getQuickDateButtonLabel(String category, String quickDate) {
  //   if (quickDate == 'all') {
  //     return category == 'all' ? 'All Time' : 'Quick';
  //   }
  //   switch (quickDate) {
  //     case 'yesterday': return 'Yesterday';
  //     case 'last_7_days': return 'Last 7d';
  //     case 'older_7_days': return 'Older >7d';
  //     case 'today': return 'Today';
  //     case 'tomorrow': return 'Tomorrow';
  //     case 'this_week': return 'This Week';
  //     case 'next_week': return 'Next Week';
  //     case 'last_week': return 'Last Week';
  //     case 'this_month': return 'This Month';
  //     case 'last_month': return 'Last Month';
  //     default: return quickDate;
  //   }
  // }

  String _getQuickDateButtonLabel(String category, String quickDate, {String? dateField}) {
    if (quickDate == 'all' || (category == 'overdue' && quickDate == 'overdue')) {
      return 'Quick';
    }
    if (category == 'all') {
      if (dateField == 'updatedAt' && quickDate == 'today') return 'Updated Today';
      if (dateField == 'createdAt' && quickDate == 'today') return 'Created Today';
      if (dateField == 'createdAt' && quickDate == 'yesterday') return 'Created Yday';
      if (dateField == 'createdAt' && quickDate == 'last_7_days') return 'Created 7d';
    }
    if (category == 'completed') {
      if (quickDate == 'today') return 'Today';
      if (quickDate == 'yesterday') return 'Yesterday';
      if (quickDate == 'this_week') return 'This Week';
      if (quickDate == 'last_7_days') return 'Last 7 Days';
    }
    switch (quickDate) {
      case 'yesterday': return 'Yesterday';
      case 'last_7_days': return 'Last 7 Days';
      case 'today': return 'Today';
      case 'tomorrow': return 'Tomorrow';
      case 'this_week': return 'This Week';
      default: return quickDate;
    }
  }

  // --------------------------------------------------------------------------
  // STICKY FILTER HEADER & DELEGATE
  // --------------------------------------------------------------------------
  Widget _buildStickyFilterHeader(TasksState state, bool isDark, bool overlapsContent) {
    final hasFilters = _hasActiveFilters(state);
    final screenBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Container(
      color: screenBg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _buildControlsRow(state, isDark),
          if (hasFilters) ...[
            const SizedBox(height: 6),
            _buildActiveFilterChips(state, isDark),
          ],
          const SizedBox(height: 7),
          Container(
            height: 1,
            color: overlapsContent
                ? (isDark ? Colors.white10 : const Color(0xFFE2E8F0))
                : Colors.transparent,
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TASK LIST
  // --------------------------------------------------------------------------
  // Widget _buildTaskList(
  //   List<Task> tasks,
  //   TasksState state,
  //   BuildContext context,
  //   bool isDark,
  // ) {
  //   if (state.isLoading && tasks.isEmpty) {
  //     return const AppShimmerListSkeleton(itemCount: 5);
  //   }
  //   if (tasks.isEmpty) {
  //     return Center(...);
  //   }
  //   return RefreshIndicator(
  //     onRefresh: () async => ref.read(tasksProvider.notifier).refresh(),
  //     child: NotificationListener<ScrollNotification>(
  //       child: ListView.separated(...),
  //     ),
  //   );
  // }
  Widget _buildTaskList(
    List<Task> tasks,
    TasksState state,
    BuildContext context,
    bool isDark,
  ) {
    final double headerHeight = _hasActiveFilters(state) ? 88.0 : 54.0;

    return RefreshIndicator(
      onRefresh: () async => ref.read(tasksProvider.notifier).refresh(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 300) {
            _loadMore();
          }
          return false;
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Sticky Filter Header pinned on Grey Background
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyFilterDelegate(
                height: headerHeight,
                builder: (ctx, overlaps) => _buildStickyFilterHeader(state, isDark, overlaps),
              ),
            ),

            if (state.isLoading && tasks.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: AppShimmerListSkeleton(itemCount: 5),
                ),
              )
            else if (tasks.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.assignment_outlined,
                            size: 36,
                            color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No follow ups found",
                          style: GoogleFonts.plusJakartaSans(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "There are no tasks matching this tab or filter.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 90),
                sliver: SliverList.separated(
                  itemCount: tasks.length + 1,
                  separatorBuilder: (c, i) => const SizedBox(height: 12),
                  itemBuilder: (c, i) {
                    if (i == tasks.length) {
                      if (state.isLoadingMore) {
                        return const AppShimmerListSkeleton(itemCount: 2);
                      }
                      if (state.pagination != null && !state.pagination!.hasNextPage && tasks.isNotEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: Theme.of(context).hintColor.withValues(alpha: 0.2),
                                  size: 24,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "All tasks loaded",
                                  style: TextStyle(
                                    color: Theme.of(context).hintColor.withValues(alpha: 0.5),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return const SizedBox(height: 12);
                    }
                    return _TaskItem(task: tasks[i]);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // BOTTOM SHEETS: QUICK DATE, SORT, FILTERS
  // --------------------------------------------------------------------------
  void _showQuickDateSheet(BuildContext context, WidgetRef ref, TasksState state) {
    final category = state.selectedCategory;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Build tab-specific quick date options
    // final List<Map<String, String>> options = [];
    // if (category == 'overdue') {
    //   options.addAll([
    //     {'key': 'all', 'label': 'All Overdue'},
    //     {'key': 'yesterday', 'label': 'Yesterday'},
    //     {'key': 'last_7_days', 'label': 'Last 7 Days'},
    //     {'key': 'older_7_days', 'label': 'Older than 7 Days'},
    //   ]);
    // } else if (category == 'upcoming') {
    //   options.addAll([
    //     {'key': 'all', 'label': 'All Upcoming'},
    //     {'key': 'today', 'label': 'Today'},
    //     {'key': 'tomorrow', 'label': 'Tomorrow'},
    //     {'key': 'this_week', 'label': 'This Week'},
    //     {'key': 'next_week', 'label': 'Next Week'},
    //   ]);
    // } else if (category == 'completed') {
    //   options.addAll([
    //     {'key': 'all', 'label': 'All Completed'},
    //     {'key': 'today', 'label': 'Completed Today'},
    //     {'key': 'yesterday', 'label': 'Completed Yesterday'},
    //     {'key': 'this_week', 'label': 'Completed This Week'},
    //     {'key': 'last_week', 'label': 'Completed Last Week'},
    //     {'key': 'this_month', 'label': 'Completed This Month'},
    //   ]);
    // } else {
    //   // category == 'all'
    //   options.addAll([
    //     {'key': 'all', 'label': 'All Time'},
    //     {'key': 'today', 'label': 'Today'},
    //     {'key': 'this_week', 'label': 'This Week'},
    //     {'key': 'this_month', 'label': 'This Month'},
    //     {'key': 'last_month', 'label': 'Last Month'},
    //   ]);
    // }

    final List<Map<String, dynamic>> options = [];
    if (category == 'overdue') {
      // Original:
      // options.addAll([
      //   {'key': 'overdue', 'label': 'All Overdue (Default)'},
      //   {'key': 'yesterday', 'label': 'Yesterday'},
      //   {'key': 'last_7_days', 'label': 'Pichle 7 Din (Last 7 Days)'},
      // ]);
      options.addAll([
        {'key': 'overdue', 'label': 'All Overdue (Default)'},
        {'key': 'yesterday', 'label': 'Yesterday'},
        {'key': 'last_7_days', 'label': 'Last 7 Days'},
      ]);
    } else if (category == 'upcoming') {
      // Original:
      // options.addAll([
      //   {'key': 'all', 'label': 'All Upcoming (Default)'},
      //   {'key': 'today', 'label': 'Today (Aaj)'},
      //   {'key': 'tomorrow', 'label': 'Tomorrow (Kal)'},
      //   {'key': 'this_week', 'label': 'This Week (Is Hafte)'},
      // ]);
      options.addAll([
        {'key': 'all', 'label': 'All Upcoming (Default)'},
        {'key': 'today', 'label': 'Today'},
        {'key': 'tomorrow', 'label': 'Tomorrow'},
        {'key': 'this_week', 'label': 'This Week'},
      ]);
    } else if (category == 'completed') {
      options.addAll([
        {'key': 'all', 'label': 'All Completed (Default)'},
        {'key': 'today', 'label': 'Completed Today', 'dateField': 'updatedAt'},
        {'key': 'yesterday', 'label': 'Completed Yesterday', 'dateField': 'updatedAt'},
        {'key': 'this_week', 'label': 'Completed This Week', 'dateField': 'updatedAt'},
        {'key': 'last_7_days', 'label': 'Completed Last 7 Days', 'dateField': 'updatedAt'},
      ]);
    } else {
      // category == 'all'
      options.addAll([
        {'key': 'all', 'label': 'All Tasks (Default)'},
        {'key': 'today', 'label': 'Created Today', 'dateField': 'createdAt'},
        {'key': 'yesterday', 'label': 'Created Yesterday', 'dateField': 'createdAt'},
        {'key': 'last_7_days', 'label': 'Created Last 7 Days', 'dateField': 'createdAt'},
        {'key': 'today', 'label': 'Updated Today', 'dateField': 'updatedAt'},
      ]);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quick Date Filter',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ...options.map((opt) {
                  final optKey = opt['key'] as String;
                  final optDateField = opt['dateField'] as String?;
                  final bool isSelected;
                  if (category == 'overdue') {
                    if (optKey == 'overdue') {
                      isSelected = (state.quickDate == 'overdue' || state.quickDate == 'all' || state.quickDate == null);
                    } else {
                      isSelected = state.quickDate == optKey;
                    }
                  } else {
                    if (optKey == 'all') {
                      isSelected = (state.quickDate == null || state.quickDate == 'all');
                    } else if (optDateField != null) {
                      isSelected = state.quickDate == optKey && state.dateField == optDateField;
                    } else {
                      isSelected = state.quickDate == optKey;
                    }
                  }

                  return ListTile(
                    dense: true,
                    title: Text(
                      opt['label'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFF2563EB)
                            : (isDark ? Colors.white : const Color(0xFF1E293B)),
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 20)
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      ref.read(tasksProvider.notifier).setQuickDate(
                        optKey,
                        dateField: optDateField,
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSortSheet(BuildContext context, WidgetRef ref, TasksState state) {
    final category = state.selectedCategory;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // final List<Map<String, String>> sortOptions = [];
    // if (category == 'overdue') {
    //   sortOptions.addAll([
    //     {'key': 'due_asc', 'label': 'Oldest Overdue First (Urgent)'},
    //     {'key': 'due_desc', 'label': 'Most Recent Overdue First'},
    //     {'key': 'priority_desc', 'label': 'Priority: High to Low'},
    //     {'key': 'title_asc', 'label': 'Task Name: A to Z'},
    //   ]);
    // } else if (category == 'upcoming') {
    //   sortOptions.addAll([
    //     {'key': 'due_asc', 'label': 'Due Soonest First'},
    //     {'key': 'due_desc', 'label': 'Due Later First'},
    //     {'key': 'priority_desc', 'label': 'Priority: High to Low'},
    //     {'key': 'title_asc', 'label': 'Task Name: A to Z'},
    //   ]);
    // } else if (category == 'completed') {
    //   sortOptions.addAll([
    //     {'key': 'updated_desc', 'label': 'Recently Completed First'},
    //     {'key': 'updated_asc', 'label': 'Oldest Completed First'},
    //     {'key': 'due_asc', 'label': 'Original Due Date: Oldest First'},
    //     {'key': 'priority_desc', 'label': 'Priority: High to Low'},
    //   ]);
    // } else {
    //   // all tab
    //   sortOptions.addAll([
    //     {'key': 'due_asc', 'label': 'Due Date: Nearest First'},
    //     {'key': 'due_desc', 'label': 'Due Date: Furthest First'},
    //     {'key': 'created_desc', 'label': 'Recently Created First'},
    //     {'key': 'priority_desc', 'label': 'Priority: High to Low'},
    //     {'key': 'status_asc', 'label': 'Status: Pending → Completed'},
    //   ]);
    // }

    final List<Map<String, String>> sortOptions = [];
    if (category == 'overdue') {
      sortOptions.addAll([
        {'key': 'dueDate_asc', 'label': 'Due Date: Urgency First (Oldest Overdue First)'},
        {'key': 'dueDate_desc', 'label': 'Due Date: Recent Overdue First'},
        {'key': 'createdAt_desc', 'label': 'Created Date: Recently Added'},
      ]);
    } else if (category == 'upcoming') {
      // Original:
      // sortOptions.addAll([
      //   {'key': 'dueDate_asc', 'label': 'Due Date: Soonest First (Aaj/Jaldi waale pehle)'},
      //   {'key': 'dueDate_desc', 'label': 'Due Date: Far Future First'},
      //   {'key': 'createdAt_desc', 'label': 'Created Date: Recently Added'},
      // ]);
      sortOptions.addAll([
        {'key': 'dueDate_asc', 'label': 'Due Date: Earliest First'},
        {'key': 'dueDate_desc', 'label': 'Due Date: Latest First'},
        {'key': 'createdAt_desc', 'label': 'Created Date: Recently Added'},
      ]);
    } else if (category == 'completed') {
      sortOptions.addAll([
        {'key': 'updatedAt_desc', 'label': 'Completion Date: Recently Completed'},
        {'key': 'updatedAt_asc', 'label': 'Completion Date: Oldest Completed'},
        {'key': 'createdAt_desc', 'label': 'Created Date: Recently Created'},
      ]);
    } else {
      // all tab
      sortOptions.addAll([
        {'key': 'dueDate_asc', 'label': 'Due Date: Ascending'},
        {'key': 'dueDate_desc', 'label': 'Due Date: Descending'},
        {'key': 'createdAt_desc', 'label': 'Created Date: Descending (Recently Created)'},
        {'key': 'updatedAt_desc', 'label': 'Updated Date: Descending (Recently Updated)'},
      ]);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sort Tasks',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ...sortOptions.map((opt) {
                  final isSelected = state.sortBy == opt['key'];
                  return ListTile(
                    dense: true,
                    title: Text(
                      opt['label']!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFF2563EB)
                            : (isDark ? Colors.white : const Color(0xFF1E293B)),
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.radio_button_checked_rounded, color: Color(0xFF2563EB), size: 20)
                        : const Icon(Icons.radio_button_off_rounded, color: Colors.grey, size: 20),
                    onTap: () {
                      Navigator.pop(ctx);
                      ref.read(tasksProvider.notifier).setSort(opt['key']!);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFiltersSheet(BuildContext context, WidgetRef ref, TasksState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final category = state.selectedCategory;
    final user = ref.read(loginProvider).user;
    final isAdminOrManager = user?.systemRole == 'admin' ||
        user?.systemRole == 'company_admin' ||
        user?.systemRole == 'sales_manager' ||
        user?.systemRole == 'team_leader';

    // Temporary filter state for bottom sheet
    String? selectedDateField = state.dateField ?? (category == 'completed' ? 'updatedAt' : 'dueDate');
    String? selectedFrom = state.fromDue;
    String? selectedTo = state.toDue;
    String? selectedAssigned = state.assignedTo;
    String? selectedAssignedName = state.assignedToName;
    String selectedStatus = state.statusFilter ?? 'all';

    // Staff list
    final executives = ref.read(staffProvider('sales_executive')).users;
    final leaders = ref.read(staffProvider('team_leader')).users;
    final managers = ref.read(staffProvider('sales_manager')).users;
    final admins = ref.read(staffProvider('admin')).users;
    final allStaff = <StaffUser>{...admins, ...managers, ...leaders, ...executives}.toList();

    // Date target options per category
    final List<Map<String, String>> dateFieldOptions = [];
    // if (category == 'completed') {
    //   dateFieldOptions.addAll([
    //     {'key': 'updatedAt', 'label': 'Completion Date'},
    //     {'key': 'dueDate', 'label': 'Due Date'},
    //     {'key': 'createdAt', 'label': 'Created Date'},
    //   ]);
    if (category == 'completed') {
      dateFieldOptions.addAll([
        {'key': 'updatedAt', 'label': 'Completion Date'},
        {'key': 'createdAt', 'label': 'Created Date'},
      ]);
    } else if (category == 'all') {
      dateFieldOptions.addAll([
        {'key': 'dueDate', 'label': 'Due Date'},
        {'key': 'createdAt', 'label': 'Created Date'},
        {'key': 'updatedAt', 'label': 'Updated Date'},
      ]);
    } else {
      dateFieldOptions.addAll([
        {'key': 'dueDate', 'label': 'Due Date'},
        {'key': 'createdAt', 'label': 'Created Date'},
      ]);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(modalContext).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Filter Tasks',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            // TextButton(
                            //   onPressed: () {
                            //     setModalState(() {
                            //       selectedDateField = category == 'completed' ? 'updatedAt' : 'dueDate';
                            //       selectedFrom = null;
                            //       selectedTo = null;
                            //       selectedAssigned = null;
                            //       selectedAssignedName = null;
                            //       selectedStatus = 'all';
                            //     });
                            //   },
                            //   child: const Text('Reset', style: TextStyle(color: Colors.red)),
                            // ),
                            TextButton(
                              onPressed: () {
                                setModalState(() {
                                  selectedDateField = category == 'completed' ? 'updatedAt' : 'dueDate';
                                  selectedFrom = null;
                                  selectedTo = null;
                                  selectedAssigned = null;
                                  selectedAssignedName = null;
                                  selectedStatus = 'all';
                                });
                                ref.read(tasksProvider.notifier).clearFilters();
                                Navigator.pop(ctx);
                              },
                              // ORIGINAL:
                              // child: const Text(
                              //   'Clear all',
                              //   style: TextStyle(
                              //     color: Colors.redAccent,
                              //     fontWeight: FontWeight.w700,
                              //     fontSize: 13,
                              //   ),
                              // ),
                              child: Text(
                                'Clear all',
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // Section 1: Date Target
                        Text(
                          'Filter Date By',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: dateFieldOptions.map((opt) {
                            final isSel = selectedDateField == opt['key'];
                            return ChoiceChip(
                              label: Text(opt['label']!),
                              selected: isSel,
                              selectedColor: const Color(0xFF2563EB),
                              backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSel ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                              ),
                              onSelected: (_) {
                                setModalState(() {
                                  selectedDateField = opt['key']!;
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Section 2: Date Range Pickers
                        Text(
                          'Custom Date Range',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // From Date
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final now = DateTime.now();
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedFrom != null
                                        ? (DateTime.tryParse(selectedFrom!) ?? now)
                                        : now,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                  );
                                  if (picked != null) {
                                    setModalState(() {
                                      selectedFrom = DateFormat('yyyy-MM-dd').format(picked);
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF2563EB)),
                                      const SizedBox(width: 8),
                                      Text(
                                        selectedFrom ?? 'From Date',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: selectedFrom != null ? FontWeight.w600 : FontWeight.normal,
                                          color: selectedFrom != null
                                              ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // To Date
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  final now = DateTime.now();
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedTo != null
                                        ? (DateTime.tryParse(selectedTo!) ?? now)
                                        : now,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                  );
                                  if (picked != null) {
                                    setModalState(() {
                                      selectedTo = DateFormat('yyyy-MM-dd').format(picked);
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF2563EB)),
                                      const SizedBox(width: 8),
                                      Text(
                                        selectedTo ?? 'To Date',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: selectedTo != null ? FontWeight.w600 : FontWeight.normal,
                                          color: selectedTo != null
                                              ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Section 3: Status Filter (Only for All Tab)
                        if (category == 'all') ...[
                          const SizedBox(height: 16),
                          Text(
                            'Status',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: ['all', 'overdue', 'pending', 'completed'].map((st) {
                              final isSel = selectedStatus == st;
                              final label = st == 'all'
                                  ? 'All Statuses'
                                  : (st[0].toUpperCase() + st.substring(1));
                              return ChoiceChip(
                                label: Text(label),
                                selected: isSel,
                                selectedColor: const Color(0xFF2563EB),
                                backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSel ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                ),
                                onSelected: (_) {
                                  setModalState(() {
                                    selectedStatus = st;
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],

                        // Section 4: Assigned Team Member (For Admin/Manager)
                        if (isAdminOrManager && allStaff.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Assigned Team Member',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: selectedAssigned,
                                isExpanded: true,
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                hint: const Text('All Team Members', style: TextStyle(fontSize: 13)),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('All Team Members', style: TextStyle(fontSize: 13)),
                                  ),
                                  ...allStaff.map((staff) {
                                    return DropdownMenuItem<String?>(
                                      value: staff.id,
                                      child: Text(
                                        '${staff.name} (${staff.systemRole})',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (val) {
                                  setModalState(() {
                                    selectedAssigned = val;
                                    selectedAssignedName = val != null
                                        ? allStaff.where((s) => s.id == val).firstOrNull?.name
                                        : null;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Apply Filters Button
                        // SizedBox(
                        //   width: double.infinity,
                        //   height: 48,
                        //   child: ElevatedButton(
                        //     onPressed: () {
                        //       Navigator.pop(ctx);
                        //       ref.read(tasksProvider.notifier).setFilters(
                        //         dateField: selectedDateField,
                        //         fromDue: selectedFrom,
                        //         toDue: selectedTo,
                        //         assignedTo: selectedAssigned,
                        //         assignedToName: selectedAssignedName,
                        //         statusFilter: selectedStatus,
                        //       );
                        //     },
                        //     style: ElevatedButton.styleFrom(
                        //       backgroundColor: const Color(0xFF2563EB),
                        //       foregroundColor: Colors.white,
                        //       shape: RoundedRectangleBorder(
                        //         borderRadius: BorderRadius.circular(10),
                        //       ),
                        //     ),
                        //     child: const Text(
                        //       'Apply Filters',
                        //       style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        //     ),
                        //   ),
                        // ),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: () {
                                    setModalState(() {
                                      selectedDateField = category == 'completed' ? 'updatedAt' : 'dueDate';
                                      selectedFrom = null;
                                      selectedTo = null;
                                      selectedAssigned = null;
                                      selectedAssignedName = null;
                                      selectedStatus = 'all';
                                    });
                                    ref.read(tasksProvider.notifier).clearFilters();
                                    Navigator.pop(ctx);
                                  },
                                  // ORIGINAL:
                                  // style: OutlinedButton.styleFrom(
                                  //   side: const BorderSide(color: Colors.redAccent, width: 1.2),
                                  //   foregroundColor: Colors.redAccent,
                                  //   shape: RoundedRectangleBorder(
                                  //     borderRadius: BorderRadius.circular(10),
                                  //   ),
                                  // ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: isDark
                                          ? Colors.white24
                                          : const Color(0xFF0F172A),
                                      width: 1.2,
                                    ),
                                    foregroundColor: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'Clear all',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    ref.read(tasksProvider.notifier).setFilters(
                                      dateField: selectedDateField,
                                      fromDue: selectedFrom,
                                      toDue: selectedTo,
                                      assignedTo: selectedAssigned,
                                      assignedToName: selectedAssignedName,
                                      statusFilter: selectedStatus,
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'Apply Filters',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ----------------------------------------------------------------------------
// STICKY FILTER HEADER DELEGATE
// ----------------------------------------------------------------------------
class _StickyFilterDelegate extends SliverPersistentHeaderDelegate {
  final Widget Function(BuildContext context, bool overlapsContent) builder;
  final double height;

  _StickyFilterDelegate({
    required this.builder,
    required this.height,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return builder(context, overlapsContent);
  }

  @override
  bool shouldRebuild(covariant _StickyFilterDelegate oldDelegate) {
    return true;
  }
}

// ----------------------------------------------------------------------------
// HIGH-FIDELITY TASK CARD WIDGET (_TaskItem)
// ----------------------------------------------------------------------------
class _TaskItem extends ConsumerWidget {
  final Task task;
  const _TaskItem({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dueDate = DateTimeUtils.parseSafe(task.dueDate);
    final isCompleted = task.status == 'Completed' || task.status == 'Done';
    final isOverdue = dueDate != null && dueDate.isBefore(DateTime.now()) && !isCompleted;

    // -------------------------------------------------------------------------
    // Previous task card implementation with priority strip & checkbox
    // final priority = task.priority.toLowerCase();
    // Color accentColor;
    // Color priorityBg;
    // Color priorityText;
    // String priorityLabel;
    // if (isCompleted) {
    //   accentColor = const Color(0xFF10B981);
    //   priorityBg = isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFDCFCE7);
    //   priorityText = const Color(0xFF059669);
    //   priorityLabel = 'Completed';
    // } else if (priority == 'high') {
    //   accentColor = const Color(0xFFEF4444);
    //   priorityBg = isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.4) : const Color(0xFFFEE2E2);
    //   priorityText = const Color(0xFFDC2626);
    //   priorityLabel = 'High';
    // } else if (priority == 'low') {
    //   accentColor = const Color(0xFFEAB308);
    //   priorityBg = isDark ? const Color(0xFF713F12).withValues(alpha: 0.4) : const Color(0xFFFEF9C3);
    //   priorityText = const Color(0xFFCA8A04);
    //   priorityLabel = 'Low';
    // } else {
    //   accentColor = const Color(0xFFF59E0B);
    //   priorityBg = isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFEF3C7);
    //   priorityText = const Color(0xFFD97706);
    //   priorityLabel = 'Medium';
    // }
    // -------------------------------------------------------------------------

    final leadName = task.lead?.name ?? 'No Lead Assigned';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0).withValues(alpha: 0.6),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      // padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Task Title + Three Dots Menu
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Three dots ⋮ Popup Menu
              // PopupMenuButton<String>(
              //   icon: Icon(
              //     Icons.more_vert_rounded,
              //     size: 20,
              //     color: isDark ? Colors.grey[400] : const Color(0xFF0F172A),
              //   ),
              //   padding: EdgeInsets.zero,
              //   constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                onSelected: (val) {
                  if (val == 'toggle') {
                    ref.read(tasksProvider.notifier).updateTask(task.id, {
                      'status': isCompleted ? 'Pending' : 'Completed',
                    });
                  } else if (val == 'edit') {
                    showDialog(
                      context: context,
                      builder: (_) => TaskCreateDialog(task: task),
                    );
                  } else if (val == 'delete') {
                    _confirmDelete(context, ref, task.id);
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem<String>(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          isCompleted ? Icons.undo_rounded : Icons.check_circle_outline_rounded,
                          size: 18,
                          color: isCompleted ? Colors.orange : const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 8),
                        Text(isCompleted ? 'Mark as Pending' : 'Mark as Complete'),
                      ],
                    ),
                  ),
                  if (ref.watch(permissionsProvider).can(
                    PermissionModules.TASK,
                    permission: PermissionModules.TASKS_UPDATE,
                    userRole: ref.watch(loginProvider).user?.systemRole,
                  ))
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: const Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Edit Task'),
                        ],
                      ),
                    ),
                  if (ref.watch(permissionsProvider).can(
                    PermissionModules.TASK,
                    permission: PermissionModules.TASKS_DELETE,
                    userRole: ref.watch(loginProvider).user?.systemRole,
                  ))
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: const Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete Task', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                ],
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: isDark ? Colors.grey[400] : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),

          // Row 2: Subtitle / Description
          if (task.description != null && task.description!.trim().isNotEmpty) ...[
            // const SizedBox(height: 4),
            const SizedBox(height: 2),
            Text(
              task.description!.trim(),
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontSize: 13,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Row 3: Clock + Relative Due Time
          if (dueDate != null) ...[
            // const SizedBox(height: 8),
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: isOverdue
                      ? const Color(0xFFEF4444)
                      : (isCompleted ? const Color(0xFF10B981) : const Color(0xFF64748B)),
                ),
                const SizedBox(width: 5),
                Text(
                  _getRelativeDueDate(dueDate, isCompleted),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: isOverdue
                        ? const Color(0xFFEF4444)
                        : (isCompleted ? const Color(0xFF10B981) : const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ],

          // const SizedBox(height: 14),
          //
          // // Horizontal Divider
          // Divider(
          //   height: 1,
          //   thickness: 1,
          //   color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
          // ),
          //
          // const SizedBox(height: 12),

          // Compact Horizontal Divider
          Divider(
            height: 16,
            thickness: 1,
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),

          // Bottom Row: [Avatar Initials] [Lead Name]  [📞 Phone] [💬 WhatsApp] [→ View]
          Row(
            children: [
              // Lead Avatar Initials
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _getAvatarBg(leadName),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _getInitials(leadName),
                  style: TextStyle(
                    color: _getAvatarTextColor(leadName),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Lead Name
              // Expanded(
              //   child: Text(
              //     leadName,
              //     maxLines: 1,
              //     overflow: TextOverflow.ellipsis,
              //     style: GoogleFonts.plusJakartaSans(
              //       fontSize: 14,
              //       fontWeight: FontWeight.w600,
              //       color: isDark ? Colors.white : const Color(0xFF0F172A),
              //     ),
              //   ),
              // ),
              Expanded(
                child: Text(
                  leadName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    height: 1.2,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Action Buttons: Phone Call, View Profile
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Phone Call Action
                  _buildActionIconButton(
                    icon: Icon(
                      Icons.call_outlined,
                      size: 20,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                    onTap: () => _initiateCall(context, ref, task),
                    tooltip: 'Call Lead',
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),

                  // 2. WhatsApp Action
                  // _buildActionIconButton(
                  //   icon: const FaIcon(
                  //     FontAwesomeIcons.whatsapp,
                  //     size: 21,
                  //     color: Color(0xFF25D366),
                  //   ),
                  //   onTap: () => _openWhatsApp(context, ref, task),
                  //   tooltip: 'Chat on WhatsApp',
                  //   isDark: isDark,
                  // ),
                  // const SizedBox(width: 10),

                  // 3. '→ View' Pill Button
                  _buildViewLeadButton(context, ref, task, isDark),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // ACTION HELPERS: CALL, WHATSAPP, VIEW LEAD
  // --------------------------------------------------------------------------
  Widget _buildActionIconButton({
    required Widget icon,
    required VoidCallback onTap,
    required String tooltip,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          child: icon,
        ),
      ),
    );
  }

  // Widget _buildViewLeadButton(BuildContext context, WidgetRef ref, Task task, bool isDark) {
  //   return Material(
  //     color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
  //     borderRadius: BorderRadius.circular(8),
  //     child: InkWell(
  //       onTap: () => _openLeadProfile(context, ref, task),
  //       borderRadius: BorderRadius.circular(8),
  //       child: Container(
  //         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
  //         child: const Row(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF2563EB)),
  //             SizedBox(width: 4),
  //             Text(
  //               'View',
  //               style: TextStyle(
  //                 color: Color(0xFF2563EB),
  //                 fontWeight: FontWeight.w700,
  //                 fontSize: 12,
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }
  Widget _buildViewLeadButton(BuildContext context, WidgetRef ref, Task task, bool isDark) {
    return Material(
      color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _openLeadProfile(context, ref, task),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF2563EB)),
              SizedBox(width: 6),
              Text(
                'View',
                style: TextStyle(
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _resolveTaskPhone(WidgetRef ref, Task task) {
    if (task.phone != null && task.phone!.trim().isNotEmpty) {
      return task.phone!.trim();
    }
    if (task.lead?.phone != null && task.lead!.phone!.trim().isNotEmpty) {
      return task.lead!.phone!.trim();
    }
    // Fallback: check leads provider
    if (task.lead != null && task.lead!.id.isNotEmpty) {
      final leads = ref.read(leadsProvider).leads;
      final match = leads.where((l) => l.id == task.lead!.id).firstOrNull;
      if (match != null && match.phoneNo.isNotEmpty) {
        return match.phoneNo;
      }
    }
    return '';
  }

  Future<void> _initiateCall(BuildContext context, WidgetRef ref, Task task) async {
    final phone = _resolveTaskPhone(ref, task);
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number available for this lead')),
      );
      return;
    }
    await CallService().makeCall(
      phone,
      callContext: {
        'name': task.lead?.name,
        'leadId': task.lead?.id,
        'taskId': task.id,
      },
    );
  }

  // Future<void> _openWhatsApp(BuildContext context, WidgetRef ref, Task task) async {
  //   final phone = _resolveTaskPhone(ref, task);
  //   if (phone.isEmpty) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('No phone number available for this lead')),
  //     );
  //     return;
  //   }
  //
  //   final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
  //   final urlStr = kIsWeb ? 'https://wa.me/$cleanPhone' : 'whatsapp://send?phone=$cleanPhone';
  //   final uri = Uri.parse(urlStr);
  //
  //   try {
  //     if (await canLaunchUrl(uri)) {
  //       await launchUrl(uri, mode: LaunchMode.externalApplication);
  //     } else {
  //       final webUri = Uri.parse('https://wa.me/$cleanPhone');
  //       if (await canLaunchUrl(webUri)) {
  //         await launchUrl(webUri, mode: LaunchMode.externalApplication);
  //       } else {
  //         if (context.mounted) {
  //           ScaffoldMessenger.of(context).showSnackBar(
  //             const SnackBar(content: Text('Could not launch WhatsApp. Ensure it is installed.')),
  //           );
  //         }
  //       }
  //     }
  //   } catch (e) {
  //     debugPrint("WhatsApp launch error: $e");
  //   }
  // }

  void _openLeadProfile(BuildContext context, WidgetRef ref, Task task) {
    if (task.lead == null || task.lead!.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No lead associated with this task')),
      );
      return;
    }

    final permissions = ref.read(permissionsProvider);
    final user = ref.read(loginProvider).user;
    if (!permissions.can(PermissionModules.LEADS, permission: PermissionModules.LEADS_VIEW, userRole: user?.systemRole)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not have permission to view leads')),
      );
      return;
    }

    final phone = _resolveTaskPhone(ref, task);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LeadProfileScreen(
          leadId: task.lead!.id,
          name: task.lead?.name,
          phone: phone,
          details: 'Task Ref: ${task.title}',
          initialTab: 'Reminder Detail',
          reminderNotification: AppNotification(
            id: task.id,
            title: task.title,
            message: task.description ?? '',
            dueAt: task.dueDate,
            entityId: task.id,
            entityType: 'task',
            sourceType: 'task',
            relationId: task.lead!.id,
            createdAt: DateTime.tryParse(task.createdAt ?? '') ?? DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String taskId) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Delete Task?', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
            'Are you sure you want to delete this task? This action cannot be undone.',
            style: TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(tasksProvider.notifier).deleteTask(taskId);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Task deleted successfully')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // RELATIVE DUE DATE & AVATAR GENERATION HELPERS
  // --------------------------------------------------------------------------
  String _getRelativeDueDate(DateTime dateTime, bool isCompleted) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);
    final isPast = difference.isNegative;
    final absDiff = difference.abs();

    final days = absDiff.inDays;
    final hours = absDiff.inHours;

    if (isCompleted) {
      if (days == 0) return 'Completed today';
      if (days == 1) return 'Completed 1 day ago';
      return 'Completed $days days ago';
    }

    if (isPast) {
      if (days > 0) {
        return '$days day${days > 1 ? 's' : ''} ago';
      } else if (hours > 0) {
        return '$hours hour${hours > 1 ? 's' : ''} ago';
      } else {
        final minutes = absDiff.inMinutes;
        return '$minutes min${minutes > 1 ? 's' : ''} ago';
      }
    } else {
      // Future
      if (days == 0) {
        if (hours == 0) {
          final minutes = absDiff.inMinutes;
          return 'In $minutes min${minutes > 1 ? 's' : ''}';
        }
        return 'Today at ${DateFormat('h:mm a').format(dateTime)}';
      } else if (days == 1) {
        return 'Tomorrow at ${DateFormat('h:mm a').format(dateTime)}';
      } else if (days < 7) {
        return 'In $days days';
      } else {
        return DateFormat('d MMM, h:mm a').format(dateTime);
      }
    }
  }

  Color _getAvatarBg(String name) {
    final hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    final colors = [
      const Color(0xFFDBEAFE), // soft blue
      const Color(0xFFDCFCE7), // soft green
      const Color(0xFFFEF3C7), // soft amber
      const Color(0xFFF3E8FF), // soft purple
      const Color(0xFFFCE7F3), // soft pink
      const Color(0xFFE0E7FF), // soft indigo
      const Color(0xFFCCFBF1), // soft teal
    ];
    return colors[hash % colors.length];
  }

  Color _getAvatarTextColor(String name) {
    final hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    final colors = [
      const Color(0xFF1D4ED8),
      const Color(0xFF15803D),
      const Color(0xFFB45309),
      const Color(0xFF7E22CE),
      const Color(0xFFBE185D),
      const Color(0xFF4338CA),
      const Color(0xFF0F766E),
    ];
    return colors[hash % colors.length];
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}
