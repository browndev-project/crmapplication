
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../providers/visit_provider.dart';
import '../../data/models/visit_model.dart';
import '../../core/utils/date_utils.dart';
import '../../core/constants/permission_constants.dart';
import '../providers/permissions_provider.dart';
import '../providers/login_provider.dart';
import '../providers/property_provider.dart';
import 'lead_profile_screen.dart';
import '../widgets/global_app_bar.dart';
import '../widgets/visit_edit_dialog.dart';
import '../widgets/visit_status_update_dialog.dart';
import '../widgets/access_denied_widget.dart';

class VisitsScreen extends ConsumerStatefulWidget {
  const VisitsScreen({super.key});

  @override
  ConsumerState<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends ConsumerState<VisitsScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(loginProvider).user;
      final assignedTo = user?.systemRole == 'sales_executive' ? user?.id : null;
      ref.read(visitsProvider.notifier).fetchVisits(assignedTo: assignedTo);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final s = ref.read(visitsProvider);
      if (!s.isLoading && !s.isLoadingMore && s.currentPage < s.totalPages) {
        final user = ref.read(loginProvider).user;
        final assignedTo = user?.systemRole == 'sales_executive' ? user?.id : s.selectedUserId;
        ref.read(visitsProvider.notifier).fetchVisits(
          page: s.currentPage + 1,
          assignedTo: assignedTo,
          projectId: s.selectedProjectId,
          propertyId: s.selectedPropertyId,
          dateFrom: s.dateFrom,
          dateTo: s.dateTo,
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final permissions = ref.watch(permissionsProvider);
    final user = ref.watch(loginProvider).user;
    
    // Completely restrict access if the VISITS module or VISITS_VIEW permission is disabled
    if (!permissions.hasModule(PermissionModules.VISITS, userRole: user?.systemRole) ||
        !permissions.hasPermission(PermissionModules.VISITS_VIEW, userRole: user?.systemRole)) {
      return const Scaffold(
        extendBody: true,
        appBar: GlobalAppBar(title: 'Manage Visits'),
        body: AccessDeniedWidget(
          sectionName: "Visits",
          showAppBar: false,
        ),
      );
    }

    final state = ref.watch(visitsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      extendBody: true,
      appBar: const GlobalAppBar(title: 'Manage Visits'),
      body: RefreshIndicator(
          onRefresh: () => ref.read(visitsProvider.notifier).fetchVisits(page: 1),
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDark),
              const SizedBox(height: 20),
              _buildVisitsSection(state, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Visits',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Track and manage site visits',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            _buildFiltersButton(isDark),
            const SizedBox(width: 8),
            _buildIconButton(Icons.refresh_rounded, isDark, onTap: () {
              ref.read(visitsProvider.notifier).fetchVisits(page: 1);
            }),
            const SizedBox(width: 8),
            _buildIconButton(Icons.history_rounded, isDark, onTap: () {
              _searchController.clear();
              ref.read(visitsProvider.notifier).clearFilters();
            }, tooltip: 'Reset Filters & Search'),
          ],
        ),
        const SizedBox(height: 12),
        _buildSearchBar(isDark),
      ],
    );
  }

  Widget _buildIconButton(IconData icon, bool isDark, {VoidCallback? onTap, String? tooltip}) {
    Widget iconWidget = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: isDark ? Colors.white70 : const Color(0xFF1E293B)),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: iconWidget);
    }
    return iconWidget;
  }

  Widget _buildFiltersButton(bool isDark) {
    final state = ref.watch(visitsProvider);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _buildIconButton(Icons.filter_list, isDark, onTap: () => _showAdvancedFilters(context, isDark)),
        if (state.activeFilterCount > 1)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${state.activeFilterCount - 1}',
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 18, color: isDark ? Colors.grey[500] : Colors.grey[600]),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 500), () {
                  ref.read(visitsProvider.notifier).setSearch(value);
                });
              },
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87, height: 1.2),
              decoration: InputDecoration(
                hintText: 'Search description, comments, lead...',
                hintStyle: TextStyle(fontSize: 14, color: isDark ? Colors.grey[500] : Colors.grey[400], height: 1.2),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              textAlignVertical: TextAlignVertical.center,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded, size: 18, color: Color(0xFF2563EB)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => ref.read(visitsProvider.notifier).setSearch(_searchController.text),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitsSection(VisitsState state, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(60), child: CircularProgressIndicator()))
        else if (state.visits.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(60),
              child: Column(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 48, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No visits found', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.black54)),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: state.visits.length + (state.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= state.visits.length) {
                return const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()));
              }
              final visit = state.visits[index];
              return _buildVisitCard(visit, isDark);
            },
          ),
      ],
    );
  }

  Widget _buildVisitCard(Visit visit, bool isDark) {
    DateTime? dt;
    try {
      if (visit.dateTime.isNotEmpty) {
        dt = DateTimeUtils.parseSafe(visit.dateTime);
      }
    } catch (_) {}

    String updatedAgo = '';
    try {
      final updated = DateTime.tryParse(visit.updatedAt);
      if (updated != null) {
        final difference = DateTime.now().difference(updated).inDays;
        updatedAgo = difference == 0 ? 'today' : '$difference days ago';
      }
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.15),
          width: 1.0,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                color: const Color(0xFF2563EB),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              visit.lead?.name ?? 'Unknown Lead',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (visit.lead != null) ...[
                                _buildSmallOutlineActionButton(
                                  icon: Icons.remove_red_eye_outlined,
                                  color: isDark ? Colors.grey[400]! : Colors.grey[700]!,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => LeadProfileScreen(leadId: visit.lead!.id),
                                      ),
                                    );
                                  },
                                  isDark: isDark,
                                ),
                                const SizedBox(width: 8),
                              ],
                              _buildEditButton(visit, isDark),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (visit.project != null) ...[
                        Row(
                          children: [
                            Icon(Icons.apartment_outlined, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                visit.project!.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (visit.property != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                visit.property!.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.grey.shade100,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DESCRIPTION',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.grey[400] : Colors.black54,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              visit.description.isNotEmpty ? visit.description : 'No description',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.grey[300] : Colors.black87,
                                fontStyle: visit.description.isEmpty ? FontStyle.italic : FontStyle.normal,
                              ),
                            ),
                            if (visit.comments != null && visit.comments!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                'COMMENTS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.grey[400] : Colors.black54,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                visit.comments!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.grey[300] : Colors.black87,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 16, color: isDark ? Colors.grey[400] : Colors.black45),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(dt) : 'Date not set',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Scheduled time',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          _buildStatusChip(visit.status),
                          const Spacer(),
                          if (visit.createdBy != null) ...[
                            Icon(Icons.person_outline_rounded, size: 14, color: isDark ? Colors.grey[400] : Colors.black45),
                            const SizedBox(width: 4),
                            Text(
                              visit.createdBy!.name,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.grey[400] : Colors.grey[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),

                      Builder(
                        builder: (context) {
                          final permissions = ref.watch(permissionsProvider);
                          final user = ref.watch(loginProvider).user;
                          final canUpdateStatus = permissions.can(
                            PermissionModules.VISITS,
                            permission: PermissionModules.VISITS_UPDATE_STATUS,
                            userRole: user?.systemRole,
                          );
                          
                          if (!canUpdateStatus) return const SizedBox.shrink();
                          
                          return SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: ElevatedButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => VisitStatusUpdateDialog(visit: visit),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text(
                                'Update status',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade100),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 13, color: isDark ? Colors.grey[500] : Colors.black38),
                          const SizedBox(width: 4),
                          Text(
                            'Updated $updatedAgo',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                          const Spacer(),
                          Text(
                            '#${visit.id.length > 8 ? visit.id.substring(visit.id.length - 8) : visit.id}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallOutlineActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  Widget _buildEditButton(Visit visit, bool isDark) {
    final hasUpdatePermission = ref.watch(permissionsProvider).hasPermission(
      PermissionModules.VISITS_UPDATE,
      userRole: ref.watch(loginProvider).user?.systemRole,
    );
    if (!hasUpdatePermission) return const SizedBox.shrink();
    return _buildSmallOutlineActionButton(
      icon: Icons.edit_outlined,
      color: Colors.blue,
      onTap: () => _onEditVisit(visit),
      isDark: isDark,
    );
  }

  void _onEditVisit(Visit visit) {
    if (visit.lead != null) {
      showDialog(
        context: context,
        builder: (context) => VisitEditDialog(leadId: visit.lead!.id, visit: visit),
      );
    }
  }

  Color _getVisitColor(String status) {
    switch (status) {
      case 'Scheduled': return const Color(0xFF6366F1);
      case 'Completed': return const Color(0xFF10B981);
      case 'Cancelled': return const Color(0xFFF43F5E);
      default: return Colors.grey;
    }
  }

  void _showAdvancedFilters(BuildContext context, bool isDark) {
    final currentState = ref.read(visitsProvider);
    // Pre-trigger allPropertiesProvider so the property list is available when filter sheet opens
    ref.read(allPropertiesProvider.notifier).fetchProjectProperties(isRefresh: false);
    final projects = ref.read(propertyProvider).projects;
    final projectIds = projects.map((p) => p.id).toList();
    String? selectedProjectId = projectIds.contains(currentState.selectedProjectId) ? currentState.selectedProjectId : null;
    String? selectedPropertyId = currentState.selectedPropertyId;
    String? dateFrom = currentState.dateFrom;
    String? dateTo = currentState.dateTo;
    List<String> selectedStatuses = List.from(currentState.selectedStatuses);
    const sortLabels = [null, 'created_desc', 'created_asc', 'updated_desc', 'updated_asc', 'visit_date_desc', 'visit_date_asc'];
    String? sortBy = sortLabels.contains(currentState.sortBy) ? currentState.sortBy : null;

    final dateFromCtrl = TextEditingController(text: dateFrom ?? '');
    final dateToCtrl = TextEditingController(text: dateTo ?? '');

    String selectedQuickFilter = VisitsState.isTimeBasedFilter(currentState.selectedStatus)
        ? currentState.selectedStatus
        : 'Quick';
    const quickFilterOptions = ['Quick', 'Today', 'Tomorrow', 'Next 7 Days', 'Next 15 Days', 'Next 30 Days'];
    const statusOptions = ['Scheduled', 'Completed', 'Cancelled'];
    const sortOptions = [
      {'label': 'Default', 'value': null},
      {'label': 'Created Date (Latest)', 'value': 'created_desc'},
      {'label': 'Created Date (Oldest)', 'value': 'created_asc'},
      {'label': 'Updated Date (Latest)', 'value': 'updated_desc'},
      {'label': 'Updated Date (Oldest)', 'value': 'updated_asc'},
      {'label': 'Visit Date (Latest)', 'value': 'visit_date_desc'},
      {'label': 'Visit Date (Oldest)', 'value': 'visit_date_asc'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final properties = selectedProjectId != null
                ? ref.watch(projectPropertiesProvider(selectedProjectId!)).properties
                : ref.watch(allPropertiesProvider).properties;
            final propertyIds = properties.map((p) => p.id).toList();
            if (selectedPropertyId != null && !propertyIds.contains(selectedPropertyId)) {
              selectedPropertyId = null;
            }

            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Advanced Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    // Quick filter
                    const Text('Quick Filter', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedQuickFilter,
                      decoration: InputDecoration(
                        hintText: 'Quick',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                      isExpanded: true,
                      items: quickFilterOptions.map((opt) {
                        IconData icon;
                        switch (opt) {
                          case 'Quick': icon = Icons.bolt_rounded; break;
                          case 'Today': icon = Icons.today_rounded; break;
                          case 'Tomorrow': icon = Icons.event_rounded; break;
                          default: icon = Icons.date_range_rounded;
                        }
                        return DropdownMenuItem<String>(
                          value: opt,
                          child: Row(
                            children: [
                              Icon(icon, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 10),
                              Text(opt, style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() {
                            selectedQuickFilter = val;
                            dateFrom = null;
                            dateTo = null;
                            dateFromCtrl.clear();
                            dateToCtrl.clear();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Multi-select Status
                    const Text('Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: statusOptions.map((status) {
                        final selected = selectedStatuses.contains(status);
                        return FilterChip(
                          label: Text(status, style: const TextStyle(fontSize: 13)),
                          selected: selected,
                          selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                          checkmarkColor: const Color(0xFF6366F1),
                          side: BorderSide(
                            color: selected ? const Color(0xFF6366F1) : Colors.grey.shade300,
                          ),
                          onSelected: (val) {
                            setSheetState(() {
                              if (val) {
                                selectedStatuses.add(status);
                              } else {
                                selectedStatuses.remove(status);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Project
                    const Text('Project', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedProjectId,
                      decoration: InputDecoration(
                        hintText: 'All Projects',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('All Projects')),
                        ...projects.map((p) => DropdownMenuItem<String?>(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (val) {
                        setSheetState(() {
                          selectedProjectId = val;
                          selectedPropertyId = null;
                        });
                      },
                    ),
                    const SizedBox(height: 14),

                    // Property
                    const Text('Property', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedPropertyId,
                      decoration: InputDecoration(
                        hintText: 'All Properties',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('All Properties')),
                        ...properties.map((p) => DropdownMenuItem<String?>(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (val) {
                        setSheetState(() => selectedPropertyId = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Date Range
                    const Text('Visit Date Range', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: dateFromCtrl,
                            readOnly: true,
                            decoration: InputDecoration(
                              hintText: 'From',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              isDense: true,
                              suffixIcon: const Icon(Icons.date_range, size: 18),
                            ),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                final formatted = DateFormat('yyyy-MM-dd').format(picked);
                                dateFromCtrl.text = formatted;
                                setSheetState(() {
                                  dateFrom = formatted;
                                  selectedQuickFilter = 'Quick';
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: dateToCtrl,
                            readOnly: true,
                            decoration: InputDecoration(
                              hintText: 'To',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              isDense: true,
                              suffixIcon: const Icon(Icons.date_range, size: 18),
                            ),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                final formatted = DateFormat('yyyy-MM-dd').format(picked);
                                dateToCtrl.text = formatted;
                                setSheetState(() {
                                  dateTo = formatted;
                                  selectedQuickFilter = 'Quick';
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Sort By
                    const Text('Sort By', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      initialValue: sortBy,
                      decoration: InputDecoration(
                        hintText: 'Default',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                      isExpanded: true,
                      items: sortOptions.map((opt) => DropdownMenuItem<String?>(
                        value: opt['value'],
                        child: Text(opt['label'] as String, style: const TextStyle(fontSize: 14)),
                      )).toList(),
                      onChanged: (val) {
                        setSheetState(() => sortBy = val);
                      },
                    ),
                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      children: [
                        // Reset
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              ref.read(visitsProvider.notifier).clearFilters();
                              Navigator.pop(ctx);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Cancel
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Apply
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              ref.read(visitsProvider.notifier).setFilterPanelFilters(
                                statuses: selectedStatuses,
                                projectId: selectedProjectId,
                                propertyId: selectedPropertyId,
                                from: dateFrom,
                                to: dateTo,
                                sort: sortBy,
                                quickFilter: selectedQuickFilter,
                              );
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  Widget _buildStatusChip(String status) {
    final color = _getVisitColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        status, 
        style: TextStyle(
          fontSize: 11, 
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
