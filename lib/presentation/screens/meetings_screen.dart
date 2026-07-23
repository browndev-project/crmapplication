import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/login_provider.dart';
import '../providers/meeting_provider.dart';
import '../../data/models/meeting_model.dart';

import '../../core/utils/date_utils.dart';

import '../widgets/global_app_bar.dart';
import '../widgets/meeting_create_dialog.dart';
import '../../core/constants/permission_constants.dart';
import '../providers/permissions_provider.dart';
import '../widgets/access_denied_widget.dart';

class MeetingsScreen extends ConsumerStatefulWidget {
  const MeetingsScreen({super.key});

  @override
  ConsumerState<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends ConsumerState<MeetingsScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'All'; // Default filter
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final meetingState = ref.read(meetingsProvider);
      if (meetingState.meetings.isEmpty && !meetingState.isLoading) {
        final user = ref.read(loginProvider).user;
        final assignedTo = user?.systemRole == 'sales_executive' ? user?.id : null;
        ref.read(meetingsProvider.notifier).fetchMeetings(page: 1, assignedTo: assignedTo);
      }
    });

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final state = ref.read(meetingsProvider);
      if (!state.isLoading && state.currentPage < state.totalPages) {
        final user = ref.read(loginProvider).user;
        final assignedTo = user?.systemRole == 'sales_executive' ? user?.id : null;
        ref.read(meetingsProvider.notifier).fetchMeetings(
          page: state.currentPage + 1, 
          status: _selectedStatus,
          assignedTo: assignedTo,
        );
      }
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final user = ref.read(loginProvider).user;
      final assignedTo = user?.systemRole == 'sales_executive' ? user?.id : null;
      ref.read(meetingsProvider.notifier).fetchMeetings(
        page: 1,
        search: value,
        status: _selectedStatus,
        assignedTo: assignedTo,
      );
    });
    // Trigger local state rebuild for clear button visibility
    setState(() {});
  }

  void _onStatusChanged(String? value) {
    if (value != null) {
      setState(() {
        _selectedStatus = value;
      });
      final user = ref.read(loginProvider).user;
      final assignedTo = user?.systemRole == 'sales_executive' ? user?.id : null;
      ref.read(meetingsProvider.notifier).fetchMeetings(
        page: 1,
        search: _searchController.text,
        status: _selectedStatus,
        assignedTo: assignedTo,
      );
    }
  }

  Future<void> _refresh() async {
    // Clear search and filters on full refresh or keep them? 
    // Usually keep filters on pull-to-refresh
    await ref.read(meetingsProvider.notifier).fetchMeetings(
        page: 1,
        search: _searchController.text,
        status: _selectedStatus
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(meetingsProvider);
    final user = ref.watch(loginProvider).user;
    
    final permissions = ref.watch(permissionsProvider);
    if (!permissions.hasModule(PermissionModules.MEETING, userRole: user?.systemRole) ||
        !permissions.hasPermission(PermissionModules.MEETINGS_VIEW, userRole: user?.systemRole)) {
      return const Scaffold(
        extendBody: true,
        appBar: GlobalAppBar(title: 'Meetings'),
        body: AccessDeniedWidget(
          sectionName: "Meetings",
          showAppBar: false,
        ),
      );
    }

    // Use meetings directly, backend handles filtering by role
    final filteredMeetings = state.meetings;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      appBar: const GlobalAppBar(title: 'Meetings'),
      body: RefreshIndicator(
          onRefresh: _refresh,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Refresh
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meetings',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('View and manage meetings.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                  Row(
                      children: [
                        _buildTopAction(
                          context: context,
                          icon: Icons.refresh,
                          onTap: _refresh,
                          isDark: isDark,
                        ),
                      ]
                  )
                ],
              ),
              const SizedBox(height: 20),

              // Search & Filter Row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                          boxShadow: [
                            if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
                          ]
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                             // Simple real-time search 
                             _onSearchChanged(value);
                          },
                          decoration: InputDecoration(
                            hintText: 'Search meetings...',
                            hintStyle: TextStyle(color: theme.hintColor, fontSize: 14),
                            prefixIcon: Icon(Icons.search_rounded, color: theme.hintColor),
                            suffixIcon: _searchController.text.isNotEmpty 
                              ? IconButton(
                                  icon: Icon(Icons.close_rounded, size: 18, color: theme.hintColor),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildStatusFilter(context),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Meeting List
              if (state.isLoading && filteredMeetings.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              else if (state.error != null)
                Center(child: Text('Error: ${state.error}', style: const TextStyle(color: Colors.red)))
              else if (filteredMeetings.isEmpty)
                  const Center(child: Padding(padding: EdgeInsets.all(40.0), child: Text('No meetings found.')))
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredMeetings.length + (state.isLoading ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index >= filteredMeetings.length) {
                        return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()));
                      }
                      final meeting = filteredMeetings[index];
                      final permissions = ref.watch(permissionsProvider);
                      final userRole = user?.systemRole;

                      return _MeetingListItem(meeting: meeting,
                          onEdit: permissions.hasPermission(PermissionModules.MEETINGS_UPDATE, userRole: userRole)
                              ? () async {
                                  try {
                                    final service = ref.read(meetingServiceProvider);
                                    final fullMeeting = await service.getMeeting(meeting.id);
                                    debugPrint('MEETING_EDIT_TAB: got fullMeeting sendMail=${fullMeeting.sendMail} whatsappAutomation=${fullMeeting.whatsappAutomation}');
                                    if (context.mounted) {
                                      showDialog(context: context, builder: (c) => MeetingCreateDialog(meeting: fullMeeting));
                                    }
                                  } catch (e) {
                                    debugPrint('MEETING_EDIT_TAB: getMeeting failed with $e, falling back to list data');
                                    if (context.mounted) {
                                      showDialog(context: context, builder: (c) => MeetingCreateDialog(meeting: meeting));
                                    }
                                  }
                                }
                              : null,
                          onDelete: permissions.hasPermission(PermissionModules.MEETINGS_DELETE, userRole: userRole)
                              ? () => _confirmDelete(context, meeting.id)
                              : null
                      );
                    },
                  ),
            ],
          ),
        ),
      ),
    );
  }


  void _confirmDelete(BuildContext context, String meetingId) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Delete Meeting?', style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text('Are you sure you want to delete this meeting? This action cannot be undone.', style: TextStyle(fontSize: 13)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey),
                  child: const Text('Cancel')
              ),
              ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ref.read(meetingsProvider.notifier).deleteMeeting(meetingId);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meeting deleted successfully')));
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)
                  ),
                  child: const Text('Delete')
              ),
            ],
          );
        }
    );
  }
  Widget _buildStatusFilter(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
        ]
      ),
      child: PopupMenuButton<String>(
        initialValue: _selectedStatus,
        offset: const Offset(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: theme.cardColor,
        elevation: 8,
        onSelected: _onStatusChanged,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _selectedStatus, 
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)
              ),
              const SizedBox(width: 8),
              Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: theme.hintColor),
            ],
          ),
        ),
        itemBuilder: (context) => ['All', 'Scheduled', 'Completed', 'Cancelled'].map((String value) {
          final isSelected = _selectedStatus == value;
          return PopupMenuItem<String>(
            value: value,
            padding: EdgeInsets.zero,
            child: Container(
              width: 140,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? theme.primaryColor.withValues(alpha: 0.05) : Colors.transparent,
              ),
              child: Row(
                children: [
                  Text(
                    value, 
                    style: TextStyle(
                      fontSize: 13, 
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                      color: isSelected ? theme.primaryColor : theme.textTheme.bodyLarge?.color,
                    )
                  ),
                  if (isSelected) ...[
                    const Spacer(),
                    Icon(Icons.check_rounded, size: 14, color: theme.primaryColor),
                  ]
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopAction({
    required BuildContext context, 
    required IconData icon, 
    required VoidCallback onTap, 
    required bool isDark,
    bool isPrimary = false
  }) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isPrimary 
              ? theme.primaryColor
              : theme.cardColor,
            border: isPrimary ? null : Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              if (isPrimary && !isDark) BoxShadow(color: theme.primaryColor.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))
            ]
          ),
          child: Icon(
            icon, 
            size: 20, 
            color: isPrimary ? Colors.white : theme.iconTheme.color,
          ),
        ),
      ),
    );
  }
}

class _MeetingListItem extends StatelessWidget {
  final Meeting meeting;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _MeetingListItem({required this.meeting, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Parse Date
    final scheduledDate = DateTimeUtils.parseSafe(meeting.scheduledAt);

    Color statusColor = Colors.grey;
    if (meeting.status == 'Scheduled') {
      statusColor = Colors.blue;
    } else if (meeting.status == 'Completed') {
      statusColor = Colors.green;
    } else if (meeting.status == 'Cancelled') {
      statusColor = Colors.orange;
    }

    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: theme.cardColor,
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
                // Accent left border strip
                Container(
                  width: 5,
                  color: statusColor,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date Box
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                  color: isDark ? statusColor.withValues(alpha: 0.15) : statusColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    scheduledDate != null ? DateFormat('dd').format(scheduledDate) : '--',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                      color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  Text(
                                    scheduledDate != null ? DateFormat('MMM').format(scheduledDate).toUpperCase() : '--',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? Colors.grey[300] : const Color(0xFF1E3A8A),
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          meeting.subject, 
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold, 
                                            fontSize: 15, 
                                            color: isDark ? Colors.white : Colors.black87,
                                            letterSpacing: -0.3,
                                          ), 
                                          maxLines: 1, 
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: isDark ? 0.15 : 0.08), 
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: statusColor.withValues(alpha: 0.1)),
                                        ),
                                        child: Text(
                                          meeting.status.toUpperCase(), 
                                          style: TextStyle(
                                            color: isDark ? statusColor.withValues(alpha: 0.9) : statusColor, 
                                            fontSize: 9, 
                                            fontWeight: FontWeight.w900, 
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 4,
                                    children: [
                                      _buildInfoChip(context, Icons.access_time_filled_rounded, DateTimeUtils.formatTime(scheduledDate)),
                                      if (meeting.lead != null)
                                         _buildInfoChip(context, Icons.person_rounded, meeting.lead!.name),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (meeting.description.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            meeting.description, 
                            maxLines: 2, 
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13, 
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              fontStyle: FontStyle.italic,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade100),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (onEdit != null)
                               _buildSmallOutlineActionButton(
                                 icon: Icons.edit_outlined,
                                 color: Colors.blue,
                                 onTap: onEdit!,
                                 isDark: isDark,
                               ),
                            if (onEdit != null && onDelete != null)
                               const SizedBox(width: 8),
                            if (onDelete != null)
                               _buildSmallOutlineActionButton(
                                 icon: Icons.delete_outline_rounded,
                                 color: Colors.red,
                                 onTap: onDelete!,
                                 isDark: isDark,
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

  Widget _buildInfoChip(BuildContext context, IconData icon, String text) {
     final theme = Theme.of(context);
     final isDark = theme.brightness == Brightness.dark;
     return Row(
       mainAxisSize: MainAxisSize.min,
       children: [
         Icon(icon, size: 14, color: isDark ? Colors.grey[500] : theme.hintColor.withValues(alpha: 0.5)),
         const SizedBox(width: 6),
         Text(
           text, 
           style: TextStyle(
             fontSize: 12, 
             color: isDark ? Colors.grey[300] : theme.hintColor.withValues(alpha: 0.8), 
             fontWeight: FontWeight.w600,
           ),
         ),
       ],
     );
  }
}