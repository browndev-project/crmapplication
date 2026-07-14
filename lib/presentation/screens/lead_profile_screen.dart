import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/services/call_service.dart';
import '../../data/models/visit_model.dart';
import '../providers/lead_provider.dart';
import '../providers/login_provider.dart';
import '../providers/task_provider.dart';
import '../providers/meeting_provider.dart';
import '../providers/visit_provider.dart';
import '../providers/invoice_provider.dart';
import '../providers/quotation_provider.dart';
import '../providers/itinerary_provider.dart';
import '../providers/voucher_provider.dart';
import '../providers/staff_provider.dart';
import '../providers/whatsapp_provider.dart';
import '../widgets/document_selector_bottom_sheet.dart';
import '../../data/models/lead_model.dart';
import '../../data/models/task_model.dart' as tm;
import '../../data/models/meeting_model.dart' as mm;
import '../../data/models/invoice_model.dart';
import '../../data/models/quotation_model.dart';
import '../../data/models/itinerary_model.dart';
import '../../data/models/voucher_model.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/utils/date_utils.dart';
import '../../core/constants/permission_constants.dart';
import '../providers/permissions_provider.dart';


import '../widgets/task_create_dialog.dart'; // Generic Dialog
import '../widgets/meeting_create_dialog.dart'; // Generic Dialog
import '../widgets/visit_create_dialog.dart';
import '../widgets/visit_edit_dialog.dart';
import '../widgets/itinerary_create_dialog.dart';
import '../widgets/lead_create_dialog.dart';
import '../widgets/lead_status_update_dialog.dart';
import '../widgets/call_logs_section.dart';
import '../widgets/invoice_create_dialog.dart';
import '../widgets/itinerary_template_gallery_dialog.dart';
import '../widgets/quotation_create_dialog.dart';
import '../widgets/voucher_create_dialog.dart';
import '../widgets/ivr_agent_selection_dialog.dart';

import '../widgets/invoice_share_dialog.dart';
import '../widgets/quotation_share_dialog.dart';
import '../widgets/itinerary_share_dialog.dart';
import '../widgets/voucher_share_dialog.dart';
import 'marketing/widgets/send_email_dialog.dart';
import '../providers/lead_document_provider.dart';
import '../widgets/lead/document_upload_dialog.dart';
import '../widgets/lead/request_documents_dialog.dart';
import 'whatsapp/widgets/whatsapp_chat_panel.dart';
import '../../data/models/lead_document_model.dart';
import '../../core/utils/formatters.dart';
import '../widgets/access_denied_widget.dart';
import '../widgets/assignment_history_section.dart';

// Card widgets for Documents, Invoices, Quotations, Vouchers, etc.
import '../widgets/itinerary_explorer_dialog.dart';
import 'quotation_detail_screen.dart';
import 'invoice_detail_screen.dart';
import 'voucher_detail_screen.dart';

class LeadProfileScreen extends ConsumerStatefulWidget {
  final String leadId;
  final String? name;
  final String? phone;
  final String? details;

  const LeadProfileScreen({
    super.key,
    required this.leadId,
    this.name,
    this.phone,
    this.details,
  });

  @override
  ConsumerState<LeadProfileScreen> createState() => _LeadProfileScreenState();
}

class _LeadProfileScreenState extends ConsumerState<LeadProfileScreen> {
  final CallService _callService = CallService();
  String? pendingCallNumber;

  // Sidebar Tab state
  String _selectedTabName = 'Quick';
  int _visibleLeadHistoryCount = 20;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(leadDetailProvider.notifier).fetchLeadDetails(widget.leadId);
      ref.read(leadDocumentsProvider(widget.leadId).notifier).fetchDocuments();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _fetchDataIfNeeded(String tabName) {
    switch (tabName) {
      case 'Invoice':
        final s = ref.read(invoicesProvider);
        if (s.filters['lead'] != widget.leadId) {
          ref.read(invoicesProvider.notifier).applyFilters({
            'lead': widget.leadId,
          });
        }
        break;
      case 'Quotation':
        final s = ref.read(quotationsProvider);
        if (s.leadFilter != widget.leadId) {
          ref.read(quotationsProvider.notifier).setLeadFilter(widget.leadId);
        }
        break;
      case 'Itinerary':
        final s = ref.read(itineraryV2Provider);
        if (s.leadFilter != widget.leadId) {
          ref.read(itineraryV2Provider.notifier).setLeadFilter(widget.leadId);
        }
        break;
      case 'Voucher':
        final s = ref.read(vouchersProvider);
        if (s.filters['lead'] != widget.leadId) {
          ref.read(vouchersProvider.notifier).applyFilters({
            'lead': widget.leadId,
          });
        }
        break;
    }
  }

  void loadMoreForCurrentTab() {
    switch (_selectedTabName) {
      case 'Calls':
        final s = ref.read(callLogsProvider);
        if (s.currentPage < s.totalPages && !s.isLoadingMore) {
          ref.read(callLogsProvider.notifier).loadMore(widget.leadId);
        }
        break;
      case 'Invoice':
        final s = ref.read(invoicesProvider);
        if (s.currentPage < s.totalPages && !s.isLoading) {
          ref.read(invoicesProvider.notifier).loadMore();
        }
        break;
      case 'Quotation':
        final s = ref.read(quotationsProvider);
        if (s.quotations.length < s.totalCount &&
            !s.isMoreLoading &&
            !s.isLoading) {
          ref.read(quotationsProvider.notifier).fetchQuotations(refresh: false);
        }
        break;
      case 'Itinerary':
        final s = ref.read(itineraryV2Provider);
        if (s.itineraries.length < s.totalCount &&
            !s.isMoreLoading &&
            !s.isLoading) {
          ref
              .read(itineraryV2Provider.notifier)
              .fetchItineraries(refresh: false);
        }
        break;
      case 'Voucher':
        final s = ref.read(vouchersProvider);
        if (s.currentPage < s.totalPages && !s.isLoading) {
          ref.read(vouchersProvider.notifier).loadMore();
        }
        break;
    }
  }

  Widget _buildPageStatus({
    required bool hasMore,
    required bool isLoadingMore,
    required bool hasItems,
    required String loadedLabel,
  }) {
    if (isLoadingMore) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (!hasMore && hasItems) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 24,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Text(
                loadedLabel,
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox(height: 16);
  }

  Future<void> _makeCall(Lead? lead) async {
    if (lead == null) return;

    final hasPermission = await _callService.requestPermissions();
    if (hasPermission) {
      setState(() {
        pendingCallNumber = lead.phoneNo;
      });
      try {
        final user = ref.read(loginProvider).user;
        final context = {
          'leadId': lead.id,
          'userId': user?.id,
          'companyId': lead.company,
        };

        await _callService.makeCall(lead.phoneNo, callContext: context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
        if (mounted) {
          setState(() {
            pendingCallNumber = null;
          });
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissions denied. Check settings.')),
        );
      }
    }
  }

  void _sendEmail(Lead? lead) {
    if (lead == null || lead.email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email address for this lead.')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => SendEmailDialog(recipients: [lead]),
    );
  }

  Future<void> _initiateIvrCall(Lead lead) async {
    final user = ref.read(loginProvider).user;
    if (user == null) return;

    if (user.systemRole == 'company_admin') {
      _showIvrAgentSelectionDialog(lead);
    } else {
      _placeIvrCall(lead, null);
    }
  }

  void _showIvrAgentSelectionDialog(Lead lead) {
    showDialog(
      context: context,
      builder: (context) {
        return IvrAgentSelectionDialog(
          leadId: lead.id,
          onAgentSelected: (agentId) {
            Navigator.pop(context);
            _placeIvrCall(lead, agentId);
          },
        );
      },
    );
  }

  Future<void> _placeIvrCall(Lead lead, String? agentId) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Connecting IVR call... Please wait.'),
              ],
            ),
            backgroundColor: Colors.blueAccent,
            duration: Duration(seconds: 2),
          ),
        );
      }

      final leadService = ref.read(leadServiceProvider);
      final response = await leadService.initiateClickToCall(
        targetPhone: lead.phoneNo,
        leadId: lead.id,
        agentId: agentId,
      );

      if (mounted) {
        final message = response['message'] ?? 'Call initiated successfully';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initiate IVR call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _launchCrmWhatsApp(Lead? lead) {
    if (lead == null) return;
    final whatsappState = ref.read(whatsappChatsProvider);
    if (!whatsappState.integrationActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WhatsApp is not connected for this account'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    WhatsAppChatPanel.show(context, lead);
  }

  Future<void> launchWhatsApp(Lead? lead) async {
    if (lead == null) return;
    final phone = lead.phoneNo.replaceAll(RegExp(r'[^\d+]'), '');
    if (phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid phone number for this lead.')),
        );
      }
      return;
    }
    final urlStr = kIsWeb
        ? 'https://wa.me/$phone'
        : 'whatsapp://send?phone=$phone';
    final uri = Uri.parse(urlStr);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        final webUri = Uri.parse('https://wa.me/$phone');
        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not launch WhatsApp. Ensure it is installed.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _deleteLead(BuildContext context, Lead? lead) async {
    if (lead == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Lead"),
        content: Text(
          "Are you sure you want to delete lead '${lead.name}'? This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ref
          .read(leadDetailProvider.notifier)
          .deleteLead(lead.id);
      if (success && context.mounted) {
        ref.read(leadsProvider.notifier).deleteLead(lead.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lead deleted successfully")),
        );
        Navigator.of(context).pop();
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to delete lead")));
      }
    }
  }

  // --- Dynamic Tab Renderers ---

  Widget _buildQuickTab(Lead? lead, bool isDark, ThemeData theme) {
    final now = DateTime.now();
    final user = ref.watch(loginProvider).user;
    final userRole = user?.systemRole;
    final userId = user?.id;
    final permissions = ref.watch(permissionsProvider);

  permissions.hasPermission(PermissionModules.LEADS_CALL, userRole: userRole);
 permissions.can(PermissionModules.WHATSAPP, permission: PermissionModules.LEADS_WHATSAPP, userRole: userRole);
 permissions.hasPermission(PermissionModules.LEADS_UPDATE_STATUS, userRole: userRole) && permissions.canEditLead(lead, userRole: userRole, userId: userId);
 permissions.can(PermissionModules.INTEGRATION_IVR, permission: PermissionModules.INTEGRATION_IVR_CALL, userRole: userRole);
 permissions.can(PermissionModules.TASK, permission: PermissionModules.TASKS_CREATE, userRole: userRole) && permissions.canEditLead(lead, userRole: userRole, userId: userId);
    permissions.can(PermissionModules.MEETING, permission: PermissionModules.MEETINGS_CREATE, userRole: userRole) && permissions.canEditLead(lead, userRole: userRole, userId: userId);
   permissions.can(PermissionModules.VISITS, permission: PermissionModules.VISITS_CREATE, userRole: userRole) && permissions.canEditLead(lead, userRole: userRole, userId: userId);
    // Uncompleted Tasks in the future
    final upcomingTasks =
        lead?.tasks?.where((t) {
          if (t.status == 'Completed' || t.status == 'Cancelled') return false;
          final dt = DateTimeUtils.parseSafe(t.dueDate);
          return dt != null && dt.isAfter(now);
        }).toList() ??
        [];
    // Uncompleted Meetings in the future
    final upcomingMeetings =
        lead?.meetings?.where((m) {
          if (m.status == 'Completed' || m.status == 'Cancelled') return false;
          final dt = DateTimeUtils.parseSafe(m.scheduledAt);
          return dt != null && dt.isAfter(now);
        }).toList() ??
        [];
    // Uncompleted Visits in the future
    final upcomingVisits =
        lead?.visits?.where((v) {
          if (v.status == 'Completed' || v.status == 'Cancelled') return false;
          final dt = DateTimeUtils.parseSafe(v.dateTime);
          return dt != null && dt.isAfter(now);
        }).toList() ??
        [];

    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        if (permissions.hasModule(
          PermissionModules.TASK,
          userRole: userRole,
        )) ...[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha:isDark ? 0.2 : 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  color: Colors.red,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Upcoming Tasks',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (upcomingTasks.isEmpty)
            _buildEmptyState("No upcoming tasks", Icons.check_circle_outline)
          else
            ...upcomingTasks.map(
              (t) => _buildMockupCard(
                title: t.title,
                subtitle: t.description ?? 'Call tomorrow',
                status: t.status,
                dueText: _formatDueCountdown(
                  DateTimeUtils.parseSafe(t.dueDate),
                ),
                onUpdate: () {
                  final tmTask = tm.Task(
                    id: t.id,
                    title: t.title,
                    status: t.status,
                    description: t.description,
                    dueDate: t.dueDate,
                    createdAt: t.createdAt,
                  );
                  showDialog(
                    context: context,
                    builder: (_) => TaskCreateDialog(task: tmTask),
                  ).then(
                    (_) => ref
                        .read(leadDetailProvider.notifier)
                        .fetchLeadDetails(widget.leadId),
                  );
                },
                onDelete: () => _confirmDeleteTask(t.id),
                isDark: isDark,
                showUpdate:
                    ref
                        .watch(permissionsProvider)
                        .can(
                          PermissionModules.TASK,
                          permission: PermissionModules.TASKS_UPDATE,
                          userRole: ref.watch(loginProvider).user?.systemRole,
                        ) &&
                    ref
                        .watch(permissionsProvider)
                        .canEditLead(
                          lead,
                          userRole: ref.watch(loginProvider).user?.systemRole,
                          userId: ref.watch(loginProvider).user?.id,
                        ),
                showDelete: ref
                    .watch(permissionsProvider)
                    .can(
                      PermissionModules.TASK,
                      permission: PermissionModules.TASKS_DELETE,
                      userRole: ref.watch(loginProvider).user?.systemRole,
                    ),
              ),
            ),
        ], // end Task permissions
        if (permissions.hasModule(
          PermissionModules.MEETING,
          userRole: userRole,
        )) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha:isDark ? 0.2 : 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.video_call_outlined,
                  color: Colors.blue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Upcoming Meetings',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (upcomingMeetings.isEmpty)
            _buildEmptyState(
              "No upcoming meetings",
              Icons.calendar_today_outlined,
            )
          else
            ...upcomingMeetings.map(
              (m) => _buildMockupCard(
                title: m.subject,
                subtitle: m.description,
                status: m.status,
                dueText: _formatDueCountdown(
                  DateTimeUtils.parseSafe(m.scheduledAt),
                ),
                onUpdate: () async {
                  await ref
                      .read(leadDetailProvider.notifier)
                      .fetchLeadDetails(widget.leadId);
                  if (!mounted) return;
                  final freshLead = ref.read(leadDetailProvider).lead;
                  final freshMeeting = freshLead?.meetings?.firstWhere(
                    (fm) => fm.id == m.id,
                    orElse: () => m,
                  );
                  if (freshMeeting != null && mounted) {
                    final mmMeeting = mm.Meeting(
                      id: freshMeeting.id,
                      subject: freshMeeting.subject,
                      description: freshMeeting.description,
                      status: freshMeeting.status,
                      scheduledAt: freshMeeting.scheduledAt ?? '',
                      isMailSent: freshMeeting.isMailSent,
                      sendMail: freshMeeting.sendMail,
                      whatsappAutomation: freshMeeting.whatsappAutomation,
                      host: freshMeeting.host,
                      meetLink: freshMeeting.meetLink,
                      clientEmail: freshMeeting.clientEmail,
                      employeeEmail: freshMeeting.employeeEmail,
                      type: freshMeeting.type,
                      createdAt: freshMeeting.createdAt,
                      lead: mm.MeetingLeadShort(
                        id: freshLead?.id ?? widget.leadId,
                        name: freshLead?.name ?? widget.name ?? '',
                      ),
                    );
                    showDialog(
                      context: context,
                      builder: (_) => MeetingCreateDialog(
                        meeting: mmMeeting,
                        clientEmail: freshLead?.email,
                      ),
                    ).then(
                      (_) => ref
                          .read(leadDetailProvider.notifier)
                          .fetchLeadDetails(widget.leadId),
                    );
                  }
                },
                onDelete: () => _confirmDeleteMeeting(m.id),
                isDark: isDark,
                showUpdate:
                    ref
                        .watch(permissionsProvider)
                        .can(
                          PermissionModules.MEETING,
                          permission: PermissionModules.MEETINGS_UPDATE,
                          userRole: ref.watch(loginProvider).user?.systemRole,
                        ) &&
                    ref
                        .watch(permissionsProvider)
                        .canEditLead(
                          lead,
                          userRole: ref.watch(loginProvider).user?.systemRole,
                          userId: ref.watch(loginProvider).user?.id,
                        ),
                showDelete: ref
                    .watch(permissionsProvider)
                    .can(
                      PermissionModules.MEETING,
                      permission: PermissionModules.MEETINGS_DELETE,
                      userRole: ref.watch(loginProvider).user?.systemRole,
                    ),
              ),
            ),
        ], // end Meeting permissions
        if (permissions.hasModule(
          PermissionModules.VISITS,
          userRole: userRole,
        )) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha:isDark ? 0.2 : 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.home_work_outlined,
                  color: Colors.green,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Upcoming Visits',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (upcomingVisits.isEmpty)
            _buildEmptyState("No upcoming visits", Icons.home_work_outlined)
          else
            ...upcomingVisits.map(
              (v) => _buildMockupCard(
                title: v.property?.name ?? v.project?.name ?? 'Site Visit',
                subtitle: v.description,
                status: v.status,
                dueText: _formatDueCountdown(
                  DateTimeUtils.parseSafe(v.dateTime),
                ),
                onUpdate: () {
                  showDialog(
                    context: context,
                    builder: (_) =>
                        VisitEditDialog(leadId: widget.leadId, visit: v),
                  ).then(
                    (_) => ref
                        .read(leadDetailProvider.notifier)
                        .fetchLeadDetails(widget.leadId),
                  );
                },
                onDelete: () => _confirmDeleteVisit(v.id),
                isDark: isDark,
                showUpdate:
                    ref
                        .watch(permissionsProvider)
                        .can(
                          PermissionModules.VISITS,
                          permission: PermissionModules.VISITS_UPDATE,
                          userRole: ref.watch(loginProvider).user?.systemRole,
                        ) &&
                    ref
                        .watch(permissionsProvider)
                        .canEditLead(
                          lead,
                          userRole: ref.watch(loginProvider).user?.systemRole,
                          userId: ref.watch(loginProvider).user?.id,
                        ),
                showDelete: ref
                    .watch(permissionsProvider)
                    .can(
                      PermissionModules.VISITS,
                      permission: PermissionModules.VISITS_DELETE,
                      userRole: ref.watch(loginProvider).user?.systemRole,
                    ),
              ),
            ),
        ], // end Visit permissions
      ],
    );
  }

  Widget _buildActivitiesTab(Lead? lead, bool isDark, ThemeData theme) {
    final history = [...(lead?.statusHistory ?? [])]
      ..sort((a, b) {
        final aDate =
            DateTimeUtils.parseSafe(a.createdAt) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate =
            DateTimeUtils.parseSafe(b.createdAt) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    final visibleHistory = history.take(_visibleLeadHistoryCount).toList();
    final hasOlder = visibleHistory.length < history.length;
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 90),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha:isDark ? 0.2 : 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.history_rounded,
                color: Colors.blue,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Lead History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (history.isEmpty)
          _buildEmptyState("No activities recorded yet", Icons.history_rounded)
        else
          Column(
            children: [
              ...visibleHistory.map(
                (h) => _buildLeadHistoryItem(h, isDark, theme),
              ),
              if (hasOlder)
                Center(
                  child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _visibleLeadHistoryCount += 20),
                    icon: const Icon(Icons.history, size: 16),
                    label: Text(
                      'Load older comments (${history.length - visibleHistory.length})',
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildTasksTab(Lead? lead, bool isDark, ThemeData theme) {
    final tasks = lead?.tasks ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tasks',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            if (ref
                    .watch(permissionsProvider)
                    .can(
                      PermissionModules.TASK,
                      permission: PermissionModules.TASKS_CREATE,
                      userRole: ref.watch(loginProvider).user?.systemRole,
                    ) &&
                ref
                    .watch(permissionsProvider)
                    .canEditLead(
                      lead,
                      userRole: ref.watch(loginProvider).user?.systemRole,
                      userId: ref.watch(loginProvider).user?.id,
                    ))
              _buildAddButton('New Task', () {
                if (lead != null) {
                  showDialog(
                    context: context,
                    builder: (_) => TaskCreateDialog(leadId: lead.id),
                  ).then(
                    (_) => ref
                        .read(leadDetailProvider.notifier)
                        .fetchLeadDetails(widget.leadId),
                  );
                }
              }, theme),
          ],
        ),
        const SizedBox(height: 16),
        tasks.isEmpty
            ? _buildEmptyState("No tasks scheduled", Icons.task_alt_rounded)
            : ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  ...tasks.map(
                    (t) => _buildMockupCard(
                      title: t.title,
                      subtitle: t.description ?? 'No description provided',
                      status: t.status,
                      dueText: _formatDueCountdown(
                        DateTimeUtils.parseSafe(t.dueDate),
                      ),
                      onUpdate: () {
                        final tmTask = tm.Task(
                          id: t.id,
                          title: t.title,
                          status: t.status,
                          description: t.description,
                          dueDate: t.dueDate,
                          createdAt: t.createdAt,
                        );
                        showDialog(
                          context: context,
                          builder: (_) => TaskCreateDialog(task: tmTask),
                        ).then(
                          (_) => ref
                              .read(leadDetailProvider.notifier)
                              .fetchLeadDetails(widget.leadId),
                        );
                      },
                      onDelete: () => _confirmDeleteTask(t.id),
                      isDark: isDark,
                      showUpdate:
                          ref
                              .watch(permissionsProvider)
                              .can(
                                PermissionModules.TASK,
                                permission: PermissionModules.TASKS_UPDATE,
                                userRole: ref
                                    .watch(loginProvider)
                                    .user
                                    ?.systemRole,
                              ) &&
                          ref
                              .watch(permissionsProvider)
                              .canEditLead(
                                lead,
                                userRole: ref
                                    .watch(loginProvider)
                                    .user
                                    ?.systemRole,
                                userId: ref.watch(loginProvider).user?.id,
                              ),
                      showDelete: ref
                          .watch(permissionsProvider)
                          .can(
                            PermissionModules.TASK,
                            permission: PermissionModules.TASKS_DELETE,
                            userRole: ref.watch(loginProvider).user?.systemRole,
                          ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
      ],
    );
  }

  Widget _buildMeetingsTab(Lead? lead, bool isDark, ThemeData theme) {
    final meetings = lead?.meetings ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Meetings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            if (ref
                    .watch(permissionsProvider)
                    .can(
                      PermissionModules.MEETING,
                      permission: PermissionModules.MEETINGS_CREATE,
                      userRole: ref.watch(loginProvider).user?.systemRole,
                    ) &&
                ref
                    .watch(permissionsProvider)
                    .canEditLead(
                      lead,
                      userRole: ref.watch(loginProvider).user?.systemRole,
                      userId: ref.watch(loginProvider).user?.id,
                    ))
              _buildAddButton('New Meeting', () {
                if (lead != null) {
                  showDialog(
                    context: context,
                    builder: (_) => MeetingCreateDialog(
                      leadId: lead.id,
                      clientEmail: lead.email,
                    ),
                  ).then(
                    (_) => ref
                        .read(leadDetailProvider.notifier)
                        .fetchLeadDetails(widget.leadId),
                  );
                }
              }, theme),
          ],
        ),
        const SizedBox(height: 16),
        meetings.isEmpty
            ? _buildEmptyState(
                "No meetings scheduled",
                Icons.calendar_today_outlined,
              )
            : ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  ...meetings.map(
                    (m) => _buildMockupCard(
                      title: m.subject,
                      subtitle: m.description,
                      status: m.status,
                      dueText: _formatDueCountdown(
                        DateTimeUtils.parseSafe(m.scheduledAt),
                      ),
                      onUpdate: () async {
                        await ref
                            .read(leadDetailProvider.notifier)
                            .fetchLeadDetails(widget.leadId);
                        if (!mounted) return;
                        final freshLead = ref.read(leadDetailProvider).lead;
                        final freshMeeting = freshLead?.meetings?.firstWhere(
                          (fm) => fm.id == m.id,
                          orElse: () => m,
                        );
                        if (freshMeeting != null) {
                          final mmMeeting = mm.Meeting(
                            id: freshMeeting.id,
                            subject: freshMeeting.subject,
                            description: freshMeeting.description,
                            status: freshMeeting.status,
                            scheduledAt: freshMeeting.scheduledAt ?? '',
                            isMailSent: freshMeeting.isMailSent,
                            sendMail: freshMeeting.sendMail,
                            whatsappAutomation: freshMeeting.whatsappAutomation,
                            host: freshMeeting.host,
                            meetLink: freshMeeting.meetLink,
                            clientEmail: freshMeeting.clientEmail,
                            employeeEmail: freshMeeting.employeeEmail,
                            type: freshMeeting.type,
                            createdAt: freshMeeting.createdAt,
                            lead: mm.MeetingLeadShort(
                              id: freshLead?.id ?? widget.leadId,
                              name: freshLead?.name ?? widget.name ?? '',
                            ),
                          );
                          if (mounted) {
                            showDialog(
                              context: context,
                              builder: (_) => MeetingCreateDialog(
                                meeting: mmMeeting,
                                clientEmail: freshLead?.email,
                              ),
                            ).then(
                              (_) => ref
                                  .read(leadDetailProvider.notifier)
                                  .fetchLeadDetails(widget.leadId),
                            );
                          }
                        }
                      },
                      onDelete: () => _confirmDeleteMeeting(m.id),
                      isDark: isDark,
                      showUpdate:
                          ref
                              .watch(permissionsProvider)
                              .can(
                                PermissionModules.MEETING,
                                permission: PermissionModules.MEETINGS_UPDATE,
                                userRole: ref
                                    .watch(loginProvider)
                                    .user
                                    ?.systemRole,
                              ) &&
                          ref
                              .watch(permissionsProvider)
                              .canEditLead(
                                lead,
                                userRole: ref
                                    .watch(loginProvider)
                                    .user
                                    ?.systemRole,
                                userId: ref.watch(loginProvider).user?.id,
                              ),
                      showDelete: ref
                          .watch(permissionsProvider)
                          .can(
                            PermissionModules.MEETING,
                            permission: PermissionModules.MEETINGS_DELETE,
                            userRole: ref.watch(loginProvider).user?.systemRole,
                          ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
      ],
    );
  }

  Widget _buildCallLogsTab(Lead? lead, bool isDark, ThemeData theme) {
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [CallLogsSection(leadId: widget.leadId)],
    );
  }

  Widget _buildFilesTab(Lead? lead, bool isDark, ThemeData theme) {
    final docsAsync = ref.watch(leadDocumentsProvider(widget.leadId));
    final permissions = ref.watch(permissionsProvider);
    final userRole = ref.watch(loginProvider).user?.systemRole;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Files',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            Row(
              children: [
                if (permissions.can(
                  PermissionModules.LEAD_DOCS,
                  permission: PermissionModules.LEAD_DOCS_REQUEST,
                  userRole: userRole,
                ))
                  _buildHeaderBtn('Request', Icons.send_rounded, () {
                    showDialog(
                      context: context,
                      builder: (_) =>
                          RequestDocumentsDialog(leadId: widget.leadId),
                    );
                  }),
                const SizedBox(width: 6),
                if (permissions.can(
                  PermissionModules.LEAD_DOCS,
                  permission: PermissionModules.LEAD_DOCS_UPLOAD,
                  userRole: userRole,
                ))
                  _buildHeaderBtn('Upload', Icons.upload_rounded, () {
                    showDialog(
                      context: context,
                      builder: (_) =>
                          DocumentUploadDialog(leadId: widget.leadId),
                    );
                  }),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        docsAsync.when(
          data: (docs) {
            if (docs.isEmpty) {
              return _buildEmptyState(
                "No files uploaded yet",
                Icons.folder_open_outlined,
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _DocumentCard(doc: docs[index], leadId: widget.leadId),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ],
    );
  }

  String _formatDob(String? dob) {
    if (dob == null || dob.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dob);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return dob;
    }
  }

  String _capitalize(String? value) {
    if (value == null || value.isEmpty) return '-';
    return value[0].toUpperCase() + value.substring(1);
  }

  Widget _buildDetailsTab(Lead? lead, bool isDark, ThemeData theme) {
    final permissions = ref.watch(permissionsProvider);
    final userRole = ref.watch(loginProvider).user?.systemRole;

    final amountText = lead != null && lead.amount > 0
        ? '\u{20B9}${NumberFormat('#,##,###').format(lead.amount)}'
        : '-';

    final serviceDesc = lead?.service?.description;

    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // (1) Contact Details (Always visible)
        _buildInfoGridCard(
          'Contact Details',
          [
            _buildInfoItem('Name', lead?.name ?? '-'),
            _buildInfoItem(
              'Email',
              lead?.email ?? '-',
              isLink: permissions.hasPermission(
                PermissionModules.LEADS_MAIL,
                userRole: userRole,
              ),
              onTap:
                  permissions.hasPermission(
                    PermissionModules.LEADS_MAIL,
                    userRole: userRole,
                  )
                  ? () => _sendEmail(lead)
                  : null,
            ),
            _buildInfoItem('Phone', lead?.phoneNo ?? widget.phone ?? '-'),
            _buildInfoItem('Amount', amountText),
            _buildInfoItem('DOB', _formatDob(lead?.dob)),
            _buildInfoItem('Gender', _capitalize(lead?.gender)),
            _buildInfoItem('Source', lead?.source ?? '-'),
            if (lead?.referralName != null && lead!.referralName!.isNotEmpty)
              _buildInfoItem('Referral Name', lead.referralName!),
          ],
          isDark,
          theme,
        ),


        // (2) Service Details (Gated)
        if (permissions.can(
          PermissionModules.SERVICES,
          permission: PermissionModules.SERVICES_VIEW,
          userRole: userRole,
        )) ...[
          _buildInfoGridCard(
            'Service Details',
            [
              _buildInfoItem('Service Interest', lead?.service?.name ?? '-'),
              if (serviceDesc != null && serviceDesc.isNotEmpty)
                _buildInfoItem('Description', serviceDesc),
            ],
            isDark,
            theme,
          ),
          const SizedBox(height: 10),
        ],

        // (3) Project Details (Gated)
        if (permissions.can(
          PermissionModules.PROPERTY,
          permission: PermissionModules.PROJECT_VIEW,
          userRole: userRole,
        )) ...[
          _buildInfoGridCard(
            'Project Details',
            [_buildInfoItem('Project', lead?.project?.name ?? '-')],
            isDark,
            theme,
          ),
          const SizedBox(height: 10),
        ],

        // (4) Property Unit Details (Gated)
        if (permissions.can(
          PermissionModules.PROPERTY,
          permission: PermissionModules.PROPERTY_VIEW,
          userRole: userRole,
        )) ...[
          _buildInfoGridCard(
            'Property Unit Details',
            [_buildInfoItem('Property Unit', lead?.property?.name ?? '-')],
            isDark,
            theme,
          ),
          const SizedBox(height: 10),
        ],

        // (5) Trip/Travel Details
        if (permissions.can(
          PermissionModules.TRIP,
          permission: PermissionModules.TRIP_VIEW,
          userRole: userRole,
        )) ...[
          _buildInfoGridCard(
            'Trip & Travel Details',
            [
              _buildInfoItem('Traveler Type', _capitalize(lead?.travelerType)),
              _buildInfoItem('Destination', lead?.destination ?? '-'),
              _buildInfoItem(
                'Travel Start',
                _formatTravelDate(lead?.travelStartDate),
              ),
              _buildInfoItem(
                'Travel End',
                _formatTravelDate(lead?.travelEndDate),
              ),
              _buildInfoItem(
                'Travellers',
                lead?.travellers != null
                    ? '${lead!.travellers} Guests${(lead.adultCount != null || lead.childrenCount != null) ? ' (${lead.adultCount ?? 0} Adults, ${lead.childrenCount ?? 0} Children)' : ''}'
                    : '-',
              ),
              _buildInfoItem('Hotel Pref.', lead?.hotelPreference ?? '-'),
              _buildInfoItem('Vehicle Pref.', lead?.vehiclePreference ?? '-'),
              _buildInfoItem('Travel Budget', lead?.travelBudget ?? '-'),
              _buildInfoItem('Pickup', lead?.pickup ?? lead?.pickupDrop ?? '-'),
              _buildInfoItem('Drop', lead?.drop ?? '-'),
              _buildInfoItem('Special Requests', lead?.specialRequests ?? '-'),
            ],
            isDark,
            theme,
          ),
          const SizedBox(height: 10),
        ],

        // (6) Address Details (Always visible)
        _buildInfoGridCard(
          'Address Details',
          [
            _buildInfoItem('Address 1', lead?.address?.address1 ?? '-'),
            _buildInfoItem('Address 2', lead?.address?.address2 ?? '-'),
            _buildInfoItem('City', lead?.address?.city ?? '-'),
            _buildInfoItem('State', lead?.address?.state ?? '-'),
            _buildInfoItem('Pin Code', lead?.address?.pinCode ?? '-'),
            _buildInfoItem('Country', lead?.address?.country ?? '-'),
          ],
          isDark,
          theme,
        ),
        if (lead?.description != null && lead!.description.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildInfoGridCard(
            'Description',
            [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: _ExpandableDescriptionText(
                  text: lead.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black87,
                    height: 1.4,
                  ),
                  isDark: isDark,
                ),
              ),
            ],
            isDark,
            theme,
          ),
        ],
      ],
    );
  }

  Widget _buildVisitTab(Lead? lead, bool isDark, ThemeData theme) {
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Visits List (${lead?.visits?.length ?? 0})',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            if (ref
                    .watch(permissionsProvider)
                    .can(
                      PermissionModules.VISITS,
                      permission: PermissionModules.VISITS_CREATE,
                      userRole: ref.watch(loginProvider).user?.systemRole,
                    ) &&
                ref
                    .watch(permissionsProvider)
                    .canEditLead(
                      lead,
                      userRole: ref.watch(loginProvider).user?.systemRole,
                      userId: ref.watch(loginProvider).user?.id,
                    ))
              _buildAddButton('New Visit', () {
                if (lead != null) {
                  showDialog(
                    context: context,
                    builder: (_) => VisitCreateDialog(leadId: lead.id),
                  ).then(
                    (_) => ref
                        .read(leadDetailProvider.notifier)
                        .fetchLeadDetails(widget.leadId),
                  );
                }
              }, theme),
          ],
        ),
        const SizedBox(height: 16),
        if (lead?.visits?.isEmpty ?? true)
          _buildEmptyState(
            "No site visits scheduled yet",
            Icons.home_work_outlined,
          )
        else
          ...lead!.visits!.map(
            (v) => _VisitCard(visit: v, leadId: widget.leadId),
          ),
      ],
    );
  }

  Widget _buildItineraryTab(Lead? lead, bool isDark, ThemeData theme) {
    final itineraryState = ref.watch(itineraryV2Provider);
    final itineraries = itineraryState.itineraries
        .where((item) => item.leadId == widget.leadId)
        .toList();
    final permissions = ref.watch(permissionsProvider);
    final userRole = ref.watch(loginProvider).user?.systemRole;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Itineraries',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            if (permissions.can(
              PermissionModules.ITINERARY,
              permission: PermissionModules.ITINERARY_CREATE,
              userRole: userRole,
            ))
              _buildAddButton('New Itinerary', () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) =>
                      ItineraryTemplateGalleryDialog(prefilledLead: lead),
                );
              }, theme),
          ],
        ),
        const SizedBox(height: 16),
        itineraryState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : itineraries.isEmpty
            ? _buildEmptyState("No itineraries created", Icons.map_outlined)
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: itineraries.length + 1,
                itemBuilder: (context, index) {
                  if (index == itineraries.length) {
                    return _buildPageStatus(
                      hasMore: itineraries.length < itineraryState.totalCount,
                      isLoadingMore: itineraryState.isMoreLoading,
                      hasItems: itineraries.isNotEmpty,
                      loadedLabel: "All itineraries loaded",
                    );
                  }
                  return _buildDocumentMockupCard(
                    number: itineraries[index].subject,
                    clientName: itineraries[index].clientName,
                    date: itineraries[index].clientCompany.isNotEmpty
                        ? itineraries[index].clientCompany
                        : itineraries[index].createdAt,
                    amount: itineraries[index].totalPrice.toDouble(),
                    status: '${itineraries[index].noOfDays} Days',
                    onView: () => showDialog(
                      context: context,
                      builder: (ctx) => ItineraryExplorerDialog(
                        itineraryId: itineraries[index].id,
                      ),
                    ),
                    onShare: () => _showItineraryShareDialog(
                      context,
                      itineraries[index],
                      lead,
                    ),
                    isDark: isDark,
                    theme: theme,
                    showShare: permissions.can(
                      PermissionModules.ITINERARY,
                      permission: PermissionModules.ITINERARY_SEND,
                      userRole: userRole,
                    ),
                    showEdit: permissions.can(
                      PermissionModules.ITINERARY,
                      permission: PermissionModules.ITINERARY_UPDATE,
                      userRole: userRole,
                    ),
                    onEdit: () {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => ItineraryCreateDialog(
                          itinerary: itineraries[index],
                        ),
                      ).then((_) {
                        ref
                            .read(itineraryV2Provider.notifier)
                            .setLeadFilter(widget.leadId);
                      });
                    },
                  );
                },
              ),
      ],
    );
  }

  Widget _buildQuotationTab(Lead? lead, bool isDark, ThemeData theme) {
    final quotationsState = ref.watch(quotationsProvider);
    final quotations = quotationsState.quotations
        .where((item) => item.leadId == widget.leadId)
        .toList();
    final permissions = ref.watch(permissionsProvider);
    final userRole = ref.watch(loginProvider).user?.systemRole;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Quotations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            if (permissions.can(
              PermissionModules.QUOTATION,
              permission: PermissionModules.QUOTATION_CREATE,
              userRole: userRole,
            ))
              _buildAddButton('New Quotation', () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => QuotationCreateDialog(prefilledLead: lead),
                );
              }, theme),
          ],
        ),
        const SizedBox(height: 16),
        quotationsState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : quotations.isEmpty
            ? _buildEmptyState(
                "No quotations found",
                Icons.request_quote_outlined,
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: quotations.length + 1,
                itemBuilder: (context, index) {
                  if (index == quotations.length) {
                    return _buildPageStatus(
                      hasMore: quotations.length < quotationsState.totalCount,
                      isLoadingMore: quotationsState.isMoreLoading,
                      hasItems: quotations.isNotEmpty,
                      loadedLabel: "All quotations loaded",
                    );
                  }
                  return _buildDocumentMockupCard(
                    number:
                        '#${quotations[index].quotationNumber} - ${quotations[index].subject}',
                    clientName: quotations[index].clientName,
                    date: quotations[index].quotationDate,
                    amount: quotations[index].grandTotal.toDouble(),
                    status: quotations[index].status,
                    onView: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QuotationDetailScreen(
                          quotationId: quotations[index].id,
                        ),
                      ),
                    ),
                    onShare: () => _showQuotationShareDialog(
                      context,
                      quotations[index],
                      lead,
                    ),
                    isDark: isDark,
                    theme: theme,
                    showShare: permissions.can(
                      PermissionModules.QUOTATION,
                      permission: PermissionModules.QUOTATION_SEND,
                      userRole: userRole,
                    ),
                    showEdit: permissions.can(
                      PermissionModules.QUOTATION,
                      permission: PermissionModules.QUOTATION_UPDATE,
                      userRole: userRole,
                    ),
                    onEdit: () {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => QuotationCreateDialog(
                          quotation: quotations[index],
                          prefilledLead: lead,
                        ),
                      ).then((_) {
                        ref
                            .read(quotationsProvider.notifier)
                            .setLeadFilter(widget.leadId);
                        ref
                            .read(quotationsProvider.notifier)
                            .fetchQuotations(refresh: true);
                      });
                    },
                  );
                },
              ),
      ],
    );
  }

  Widget _buildInvoiceTab(Lead? lead, bool isDark, ThemeData theme) {
    final invoiceState = ref.watch(invoicesProvider);
    final invoices = invoiceState.invoices
        .where((item) => item.leadId == widget.leadId)
        .toList();
    final permissions = ref.watch(permissionsProvider);
    final userRole = ref.watch(loginProvider).user?.systemRole;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Invoices',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            if (permissions.can(
              PermissionModules.INVOICE,
              permission: PermissionModules.INVOICE_CREATE,
              userRole: userRole,
            ))
              _buildAddButton('New Invoice', () {
                if (lead != null) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => InvoiceCreateDialog(prefilledLead: lead),
                  ).then(
                    (_) => ref.read(invoicesProvider.notifier).applyFilters({
                      'lead': widget.leadId,
                    }),
                  );
                }
              }, theme),
          ],
        ),
        const SizedBox(height: 16),
        invoiceState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : invoices.isEmpty
            ? _buildEmptyState("No invoices found", Icons.receipt_long_outlined)
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: invoices.length + 1,
                itemBuilder: (context, index) {
                  if (index == invoices.length) {
                    return _buildPageStatus(
                      hasMore:
                          invoiceState.currentPage < invoiceState.totalPages,
                      isLoadingMore: false,
                      hasItems: invoices.isNotEmpty,
                      loadedLabel: "All invoices loaded",
                    );
                  }
                  return _buildDocumentMockupCard(
                    number:
                        invoices[index].subject != null &&
                            invoices[index].subject!.isNotEmpty
                        ? '#${invoices[index].invoiceNumber} - ${invoices[index].subject}'
                        : '#${invoices[index].invoiceNumber}',
                    clientName: invoices[index].clientName,
                    date: invoices[index].invoiceDate,
                    amount: invoices[index].grandTotal.toDouble(),
                    status: invoices[index].status,
                    onView: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            InvoiceDetailScreen(invoiceId: invoices[index].id),
                      ),
                    ),
                    onShare: () =>
                        _showInvoiceShareDialog(context, invoices[index], lead),
                    isDark: isDark,
                    theme: theme,
                    showShare: permissions.can(
                      PermissionModules.INVOICE,
                      permission: PermissionModules.INVOICE_SEND,
                      userRole: userRole,
                    ),
                    showEdit: permissions.can(
                      PermissionModules.INVOICE,
                      permission: PermissionModules.INVOICE_UPDATE,
                      userRole: userRole,
                    ),
                    onEdit: () {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) =>
                            InvoiceCreateDialog(invoice: invoices[index]),
                      ).then(
                        (_) => ref.read(invoicesProvider.notifier).applyFilters(
                          {'lead': widget.leadId},
                        ),
                      );
                    },
                  );
                },
              ),
      ],
    );
  }

  Widget _buildVouchersTab(Lead? lead, bool isDark, ThemeData theme) {
    final vouchersState = ref.watch(vouchersProvider);
    final vouchers = vouchersState.vouchers
        .where((item) => item.leadId == widget.leadId)
        .toList();
    final permissions = ref.watch(permissionsProvider);
    final userRole = ref.watch(loginProvider).user?.systemRole;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Vouchers',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            if (permissions.can(
              PermissionModules.VOUCHER,
              permission: PermissionModules.VOUCHER_CREATE,
              userRole: userRole,
            ))
              _buildAddButton('New Voucher', () {
                if (lead != null) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => VoucherCreateDialog(prefilledLead: lead),
                  ).then(
                    (_) => ref.read(vouchersProvider.notifier).applyFilters({
                      'lead': widget.leadId,
                    }),
                  );
                }
              }, theme),
          ],
        ),
        const SizedBox(height: 16),
        vouchersState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : vouchers.isEmpty
            ? _buildEmptyState(
                "No vouchers found",
                Icons.card_giftcard_outlined,
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: vouchers.length + 1,
                itemBuilder: (context, index) {
                  if (index == vouchers.length) {
                    return _buildPageStatus(
                      hasMore:
                          vouchersState.currentPage < vouchersState.totalPages,
                      isLoadingMore: false,
                      hasItems: vouchers.isNotEmpty,
                      loadedLabel: "All vouchers loaded",
                    );
                  }
                  return _buildDocumentMockupCard(
                    number: '#${vouchers[index].voucherNo}',
                    clientName: vouchers[index].clientName,
                    date: vouchers[index].voucherDate,
                    amount: vouchers[index].financials.totalAmount.toDouble(),
                    status: vouchers[index].voucherType,
                    onView: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            VoucherDetailScreen(voucherId: vouchers[index].id),
                      ),
                    ),
                    onShare: () =>
                        _showVoucherShareDialog(context, vouchers[index], lead),
                    isDark: isDark,
                    theme: theme,
                    showShare: permissions.can(
                      PermissionModules.VOUCHER,
                      permission: PermissionModules.VOUCHER_SEND,
                      userRole: userRole,
                    ),
                    showEdit: permissions.can(
                      PermissionModules.VOUCHER,
                      permission: PermissionModules.VOUCHER_UPDATE,
                      userRole: userRole,
                    ),
                    onEdit: () {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) =>
                            VoucherCreateDialog(voucher: vouchers[index]),
                      ).then(
                        (_) => ref.read(vouchersProvider.notifier).applyFilters(
                          {'lead': widget.leadId},
                        ),
                      );
                    },
                  );
                },
              ),
      ],
    );
  }

  Widget _buildSystemTab(Lead? lead, bool isDark, ThemeData theme) {
    final userRole = ref.watch(loginProvider).user?.systemRole;
 ref
        .watch(permissionsProvider)
        .hasPermission(PermissionModules.LEADS_ASSIGN, userRole: userRole);
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 90),
      children: [
        // --- Assignment History Section ---
        AssignmentHistorySection(
          assignHistory: lead?.assignHistory ?? [],
          isDark: isDark,
        ),
        const SizedBox(height: 24),

        // --- Timeline Section ---
        Text(
          'Timeline',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoGridCard(
          'Activity Info',
          [
            _buildInfoItem(
              'Created At',
              lead?.createdAt != null
                  ? DateTimeUtils.formatSafe(lead!.createdAt)
                  : '-',
            ),
            _buildInfoItem(
              'Last Updated At',
              lead?.updatedAt != null
                  ? DateTimeUtils.formatSafe(lead!.updatedAt)
                  : '-',
            ),
          ],
          isDark,
          theme,
        ),
        const SizedBox(height: 24),

        // --- Lead Information Section ---
        Text(
          'Lead Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoGridCard(
          'Administrative Metadata',
          [
            _buildInfoItem('Created by', lead?.createdBy?.name ?? '-'),
            _buildInfoItem('Source Channels', lead?.source ?? '-'),
            _buildInfoItem('Referral Name', lead?.referralName ?? '-'),
          ],
          isDark,
          theme,
        ),
      ],
    );
  }

  void showAssignLeadDialog(Lead lead) {
    showDialog(
      context: context,
      builder: (ctx) => _AssignLeadDialog(lead: lead),
    );
  }

  void _showSubAssigneeDialog(BuildContext context, Lead lead) {
    showDialog(
      context: context,
      builder: (ctx) => SubAssigneeDialog(lead: lead),
    ).then((_) {
      ref.read(leadDetailProvider.notifier).fetchLeadDetails(widget.leadId);
    });
  }

  // --- Card Styling & Subcomponents ---

  Widget _buildMockupCard({
    required String title,
    required String subtitle,
    required String status,
    required String dueText,
    required VoidCallback onUpdate,
    required VoidCallback onDelete,
    required bool isDark,
    bool showUpdate = true,
    bool showDelete = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.01),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              _buildStatusBadgeOnly(status, isDark),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.grey[600],
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha:0.05)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  dueText,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          if (showUpdate || showDelete) ...[
            const SizedBox(height: 8),
            Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha:0.05)
                  : Colors.grey.shade100,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (showUpdate)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 12),
                      label: const Text(
                        'Update',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: onUpdate,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark
                            ? Colors.white70
                            : Colors.black87,
                        side: BorderSide(
                          color: isDark ? Colors.white10 : Colors.grey.shade300,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                if (showUpdate && showDelete) const SizedBox(width: 6),
                if (showDelete)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 12),
                      label: const Text(
                        'Delete',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: onDelete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark
                            ? Colors.white70
                            : Colors.black87,
                        side: BorderSide(
                          color: isDark ? Colors.white10 : Colors.grey.shade300,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadgeOnly(String status, bool isDark) {
    final displayStatus = toTitleCase(status);
    Color col = _getStatusColor(displayStatus);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: col.withValues(alpha:isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        displayStatus,
        style: TextStyle(
          color: isDark ? col.withValues(alpha:0.9) : col,
          fontWeight: FontWeight.w800,
          fontSize: 9,
        ),
      ),
    );
  }

  // Lead History item widget (timeline style)
  Widget _buildLeadHistoryItem(StatusHistory h, bool isDark, ThemeData theme) {
    final lineColor = theme.dividerColor.withValues(alpha:0.5);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line and dot
          Column(
            children: [
              Container(width: 2, height: 8, color: lineColor),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
              Container(width: 2, height: 40, color: lineColor),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusBadgeOnly(toTitleCase(h.status), isDark),
                if (h.comment != null && h.comment!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    h.comment!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'By ${h.updatedBy?.name ?? "System"}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeago.format(
                    DateTimeUtils.parseSafe(h.createdAt) ?? DateTime.now(),
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.hintColor.withValues(alpha:0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPaginatorPill({required int currentPage, required int totalPages, required VoidCallback? onPrev, required VoidCallback? onNext, required bool isDark,}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 14),
            onPressed: onPrev,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 10),
          Text(
            '$currentPage / $totalPages',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(
              Icons.chevron_right,
              color: Colors.white,
              size: 14,
            ),
            onPressed: onNext,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget buildQuickActionButton(IconData icon, String label, Color color, VoidCallback onTap, bool isDark, {Widget? iconWidget,}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha:0.08)
                : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget ??
                Icon(
                  icon,
                  color: isDark ? Colors.white : Colors.black,
                  size: 24,
                ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getDocStatusColor(String status) {
    final s = status.toUpperCase();
    switch (s) {
      case 'CREATED':
      case 'DRAFT':
        return const Color(0xFF6366F1);
      case 'SENT':
      case 'ISSUED':
        return const Color(0xFF3B82F6);
      case 'PAID':
      case 'COMPLETED':
      case 'ACCEPTED':
      case 'APPROVED':
        return const Color(0xFF10B981);
      case 'PARTIALLY_PAID':
      case 'PENDING':
        return const Color(0xFFF59E0B);
      case 'OVERDUE':
      case 'EXPIRED':
      case 'CANCELLED':
      case 'REJECTED':
        return const Color(0xFFEF4444);
      case 'CONFIRMED':
        return const Color(0xFF06B6D4);
      case 'REFUNDED':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF64748B);
    }
  }

  Widget _buildDocStatusBadge(String status, bool isDark) {
    final color = _getDocStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha:isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: isDark ? color.withValues(alpha:0.9) : color,
          fontWeight: FontWeight.w800,
          fontSize: 9,
        ),
      ),
    );
  }

  Widget _buildDocumentMockupCard({
    required String number,
    required String clientName,
    required String date,
    required double amount,
    required String status,
    required VoidCallback onView,
    required VoidCallback onShare,
    required bool isDark,
    required ThemeData theme,
    bool showView = true,
    bool showShare = true,
    bool showEdit = false,
    VoidCallback? onEdit,
  }) {
    final formattedAmount =
        '\u{20B9}${NumberFormat('#,##,###.##').format(amount)}';
    String formattedDate = date;
    try {
      DateTime dt = DateTime.parse(date);
      formattedDate = DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha:0.08) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.01),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  number,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: -0.3,
                  ),
                  softWrap: true,
                ),
              ),
              const SizedBox(width: 6),
              _buildDocStatusBadge(status, isDark),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha:0.05)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  formattedAmount,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          if (showView || showShare || showEdit) ...[
            const SizedBox(height: 8),
            Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha:0.05)
                  : Colors.grey.shade100,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (showEdit && onEdit != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 12),
                      label: const Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: onEdit,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark
                            ? Colors.white70
                            : Colors.black87,
                        side: BorderSide(
                          color: isDark ? Colors.white10 : Colors.grey.shade300,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                if (showEdit && onEdit != null && (showView || showShare))
                  const SizedBox(width: 6),
                if (showView)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.visibility_outlined, size: 12),
                      label: const Text(
                        'View Details',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: onView,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark
                            ? Colors.white70
                            : Colors.black87,
                        side: BorderSide(
                          color: isDark ? Colors.white10 : Colors.grey.shade300,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                if (showView && showShare) const SizedBox(width: 6),
                if (showShare)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.share_outlined, size: 12),
                      label: const Text(
                        'Share',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: onShare,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark
                            ? Colors.white70
                            : Colors.black87,
                        side: BorderSide(
                          color: isDark ? Colors.white10 : Colors.grey.shade300,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget buildCuratedBadge(
    String label,
    String value,
    Color primaryColor,
    bool isDark, {
    Color? textCol,
  }) {
    final bgColor = isDark
        ? primaryColor.withValues(alpha: 0.15)
        : primaryColor.withValues(alpha:0.12);
    final textColor =
        textCol ?? (isDark ? primaryColor.withValues(alpha:0.9) : primaryColor);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white54 : Colors.grey[600],
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildDetailItemRow(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: isDark ? Colors.white54 : Colors.grey[500]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey[800],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderBtn(String label, IconData icon, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.cardColor,
          border: Border.all(color: theme.dividerColor.withValues(alpha:0.1)),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: theme.iconTheme.color),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(String label, VoidCallback onTap, ThemeData theme) {
    return _buildHeaderBtn(label, Icons.add_rounded, onTap);
  }

  Widget _buildInfoGridCard(
    String title,
    List<Widget> children,
    bool isDark,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha:0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    String label,
    String value, {
    bool isLink = false,
    VoidCallback? onTap,
    String? subtext,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                softWrap: true,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.hintColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isLink
                          ? Colors.blue
                          : theme.textTheme.bodyLarge?.color,
                      decoration: isLink ? TextDecoration.underline : null,
                    ),
                  ),
                  if (subtext != null)
                    Text(
                      subtext,
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.hintColor.withValues(alpha:0.6),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String text, IconData icon) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.dividerColor.withValues(alpha:0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: theme.hintColor.withValues(alpha:0.3)),
          const SizedBox(height: 6),
          Text(
            text,
            style: TextStyle(
              color: theme.hintColor,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildLeadCard({required Lead? lead, required String displayName, required String displayPhone, required Color statusColor, required Color pipelineColor, required bool isDark, required ThemeData theme, required String? userRole, required String? userId, required dynamic permissions,}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              CircleAvatar(
                radius: 27,
                backgroundColor: isDark
                    ? Colors.blue.withValues(alpha: 0.15)
                    : const Color(0xFFEFF6FF),
                child: Text(
                  _getInitials(displayName),
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Name and Phone
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 14,
                          color: isDark ? Colors.white60 : Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          displayPhone,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Badges
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildCardBadge(
                    toTitleCase(lead?.status ?? 'New'),
                    statusColor,
                    isDark,
                  ),
                  const SizedBox(height: 6),
                  _buildCardBadge(
                    lead?.pipeline ?? 'Cold',
                    pipelineColor,
                    isDark,
                  ),
                ],
              ),
            ],
          ),
          Divider(
            height: 24,
            color: theme.dividerColor.withValues(alpha: 0.08),
          ),
          // Bottom row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBottomCardInfoItem(
                Icons.storefront_outlined,
                lead?.service?.name ?? 'Sales CRM',
                isDark,
              ),
              _buildBottomCardInfoItem(
                Icons.access_time_rounded,
                lead != null
                    ? timeago.format(DateTime.parse(lead.updatedAt))
                    : 'Just now',
                isDark,
              ),
              _buildBottomCardInfoItem(
                Icons.person_outline_rounded,
                lead?.assignedTo?.name ?? 'Unassigned',
                isDark,
              ),
            ],
          ),
          // Sub assignees block
          if (lead?.subAssignees != null && lead!.subAssignees!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.indigo.withValues(alpha: 0.15)
                    : const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? Colors.indigo.withValues(alpha: 0.3)
                      : const Color(0xFFE0E7FF),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.group_outlined,
                        size: 14,
                        color: isDark
                            ? const Color(0xFF818CF8)
                            : const Color(0xFF3730A3),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Sub-assignees:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? const Color(0xFF818CF8)
                              : const Color(0xFF3730A3),
                        ),
                      ),
                      if (permissions.canEditLead(
                        lead,
                        userRole: userRole,
                        userId: userId,
                      )) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _showSubAssigneeDialog(context, lead),
                          child: Icon(
                            Icons.edit_outlined,
                            size: 14,
                            color: isDark
                                ? const Color(0xFF818CF8)
                                : const Color(0xFF3730A3),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lead.subAssignees!.map((sa) => sa.name).join(', '),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.grey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (permissions.canEditLead(
            lead,
            userRole: userRole,
            userId: userId,
          )) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showSubAssigneeDialog(context, lead!),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_add_outlined,
                    size: 14,
                    color: isDark
                        ? const Color(0xFF818CF8)
                        : const Color(0xFF3730A3),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Add Sub-assignees',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFF818CF8)
                          : const Color(0xFF3730A3),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardBadge(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.15)
            : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? color.withValues(alpha: 0.9) : color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildBottomCardInfoItem(IconData icon, String text, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark ? Colors.white54 : Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget buildHorizontalTabRow(List<String> activeTabs, bool isDark, ThemeData theme) {
    return Container(
      height: 48,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: activeTabs.length,
        itemBuilder: (context, index) {
          final tab = activeTabs[index];
          final isSelected = _selectedTabName == tab;
          return InkWell(
            onTap: () {
              setState(() {
                _selectedTabName = tab;
              });
              _fetchDataIfNeeded(tab);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                    width: 2.0,
                  ),
                ),
              ),
              child: Text(
                tab,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : (isDark ? Colors.white60 : Colors.grey[600]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildBottomBarButton({required IconData icon, required String label, required Color color, required VoidCallback onTap, required bool isDark, Widget? iconWidget,}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.shade200,
              width: 1,
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconWidget ??
                  Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }



  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'L';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length > 1 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    if (parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'L';
  }

  Color _getStatusColor(String status) {
    final lower = status.toLowerCase();
    // Task statuses
    if (lower.contains('not started')) return const Color(0xFFF59E0B);
    if (lower.contains('in progress')) return const Color(0xFF3B82F6);
    // Meeting/Visit statuses
    if (lower.contains('scheduled')) return const Color(0xFF6366F1);
    if (lower.contains('completed')) return const Color(0xFF10B981);
    if (lower.contains('cancelled')) return const Color(0xFFEF4444);
    if (lower.contains('rescheduled')) return const Color(0xFFF97316);
    if (lower.contains('no show')) return const Color(0xFFDC2626);
    // Lead statuses
    if (lower.contains('new')) return Colors.blue;
    if (lower.contains('no answer')) return Colors.red;
    if (lower.contains('contacted') || lower.contains('connected')) {
      return Colors.green;
    }
    if (lower.contains('negotiation')) return Colors.purple;
    if (lower.contains('lost')) return Colors.red;
    if (lower.contains('won') || lower.contains('convert')) return Colors.teal;
    if (lower.contains('junk')) return Colors.grey;
    return Colors.orange;
  }

  Color _getPipelineColor(String pipe) {
    if (pipe == 'Hot') return Colors.red;
    if (pipe == 'Warm') return Colors.orange;
    return Colors.blue;
  }

  String _formatDueCountdown(DateTime? due) {
    if (due == null) return 'No due date';
    final now = DateTime.now();
    final diff = due.difference(now);

    if (diff.isNegative) {
      final past = diff.abs();
      if (past.inDays > 0) return '${past.inDays}d ago';
      if (past.inHours > 0) return '${past.inHours}h ago';
      if (past.inMinutes > 0) return '${past.inMinutes}m ago';
      return 'Just now';
    } else {
      if (diff.inDays > 0) return '${diff.inDays}d left';
      if (diff.inHours > 0) return '${diff.inHours}h left';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m left';
      return 'Due soon';
    }
  }

  void _confirmDeleteTask(String id) {
    showDialog(
      context: context,
      builder: (ctx) => _DeleteDialog(
        title: "Delete Task",
        content: "Are you sure you want to delete this task?",
        onConfirm: () async {
          Navigator.pop(ctx);
          await ref.read(tasksProvider.notifier).deleteTask(id);
          ref.read(leadDetailProvider.notifier).fetchLeadDetails(widget.leadId);
        },
      ),
    );
  }

  void _confirmDeleteVisit(String id) {
    showDialog(
      context: context,
      builder: (ctx) => _DeleteDialog(
        title: "Delete Visit",
        content: "Are you sure you want to delete this visit?",
        onConfirm: () async {
          Navigator.pop(ctx);
          await ref.read(visitsProvider.notifier).deleteVisit(id);
          if (mounted) {
            await ref
                .read(leadDetailProvider.notifier)
                .fetchLeadDetails(widget.leadId);
          }
        },
      ),
    );
  }

  void _confirmDeleteMeeting(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteDialog(
        title: "Delete Meeting",
        content: "Are you sure you want to delete this meeting?",
        onConfirm: () => Navigator.pop(ctx, true),
      ),
    );
    if (confirmed == true) {
      await ref.read(meetingsProvider.notifier).deleteMeeting(id);
      if (mounted) {
        await ref
            .read(leadDetailProvider.notifier)
            .fetchLeadDetails(widget.leadId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(leadDetailProvider);
    final lead = detailState.lead;
    final userRole = ref.watch(loginProvider).user?.systemRole;
    final userId = ref.watch(loginProvider).user?.id;
    final permissions = ref.watch(permissionsProvider);

    // â”€â”€ GLOBAL GUARD: User must have LEADS_VIEW to see this screen â”€â”€
    if (!permissions.hasModule(PermissionModules.LEADS, userRole: userRole) ||
        !permissions.hasPermission(
          PermissionModules.LEADS_VIEW,
          userRole: userRole,
        )) {
      return const Scaffold(
        body: AccessDeniedWidget(sectionName: 'Lead Details', showAppBar: true),
      );
    }

    final displayPhone = lead?.phoneNo ?? widget.phone ?? '';
    final displayName = lead?.name ?? widget.name ?? '';

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.cardColor;
     theme.dividerColor.withValues(alpha:0.1);

    // Status colors
    final statusColor = _getStatusColor(lead?.status ?? 'New');
    final pipelineColor = _getPipelineColor(lead?.pipeline ?? 'Hot');

    // Sidebar navigation colors
 isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
   isDark
        ? Colors.blue.withValues(alpha: 0.15)
        : const Color(0xFFEFF6FF);
     const Color(0xFF2563EB);

    final List<String> activeTabs = [
      'Quick',
      'Details',
      'Activities',
      'System',
    ];

    if (permissions.can(
      PermissionModules.TASK,
      permission: PermissionModules.TASKS_VIEW,
      userRole: userRole,
    )) {
      activeTabs.add('Tasks');
    }
    if (permissions.can(
      PermissionModules.MEETING,
      permission: PermissionModules.MEETINGS_VIEW,
      userRole: userRole,
    )) {
      activeTabs.add('Meetings');
    }
    if (permissions.can(
      PermissionModules.VISITS,
      permission: PermissionModules.VISITS_VIEW,
      userRole: userRole,
    )) {
      activeTabs.add('Visit');
    }
    activeTabs.add('Calls');
    if (permissions.can(
      PermissionModules.LEAD_DOCS,
      permission: PermissionModules.LEAD_DOCS_VIEW,
      userRole: userRole,
    )) {
      activeTabs.add('Files');
    }
    if (permissions.hasModule(PermissionModules.INVOICE, userRole: userRole) &&
        permissions.can(
          PermissionModules.INVOICE,
          permission: PermissionModules.INVOICE_VIEW,
          userRole: userRole,
        )) {
      activeTabs.add('Invoice');
    }
    if (permissions.hasModule(
          PermissionModules.ITINERARY,
          userRole: userRole,
        ) &&
        permissions.can(
          PermissionModules.ITINERARY,
          permission: PermissionModules.ITINERARY_VIEW,
          userRole: userRole,
        )) {
      activeTabs.add('Itinerary');
    }
    if (permissions.hasModule(
          PermissionModules.QUOTATION,
          userRole: userRole,
        ) &&
        permissions.can(
          PermissionModules.QUOTATION,
          permission: PermissionModules.QUOTATION_VIEW,
          userRole: userRole,
        )) {
      activeTabs.add('Quotation');
    }
    if (permissions.hasModule(PermissionModules.VOUCHER, userRole: userRole) &&
        permissions.can(
          PermissionModules.VOUCHER,
          permission: PermissionModules.VOUCHER_VIEW,
          userRole: userRole,
        )) {
      activeTabs.add('Voucher');
    }

    if (!activeTabs.contains(_selectedTabName)) {
      _selectedTabName = 'Quick';
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'Lead details',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.blueAccent.withValues(alpha: 0.12),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : const Color(0xFF1E3A8A)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (lead != null &&
              permissions.canEditLead(
                lead,
                userRole: userRole,
                userId: userId,
              ))
            IconButton(
              icon: Icon(Icons.edit_outlined, color: isDark ? Colors.white : const Color(0xFF1E3A8A)),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => LeadCreateDialog(lead: lead),
                ).then(
                  (_) => ref
                      .read(leadDetailProvider.notifier)
                      .fetchLeadDetails(widget.leadId),
                );
              },
            ),
          if (permissions.canDeleteLead(userRole: userRole))
            IconButton(
              icon: Icon(Icons.delete_outline, color: isDark ? Colors.redAccent : Colors.red),
              onPressed: () => _deleteLead(context, lead),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: detailState.isLoading && lead == null
          ? const Center(child: CircularProgressIndicator())
          : detailState.error != null
          ? Center(child: Text('Error: ${detailState.error}'))
          : Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // --- LEAD INFO CARD ---
                      SliverToBoxAdapter(
                        child: Stack(
                          children: [
                            Container(
                              height: 60,
                              color: isDark ? const Color(0xFF1E293B) : Colors.blueAccent.withValues(alpha:0.12),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark ? Colors.white12 : Colors.black.withValues(alpha:0.04),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha:0.04),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        // Avatar initials circle
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.blueAccent.withValues(alpha:0.2) : Colors.blueAccent.withValues(alpha:0.12),
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            _getInitials(displayName),
                                            style: TextStyle(
                                              color: isDark ? Colors.blueAccent : const Color(0xFF1E3A8A),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        // Name & Phone
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                displayName,
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: theme.textTheme.bodyLarge?.color,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.phone_outlined,
                                                    size: 14,
                                                    color: isDark ? Colors.white60 : Colors.grey[600],
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    displayPhone,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: isDark ? Colors.white60 : Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Badges (Status, Stage) stacked vertically
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            _buildCuratedBadgeCompact(
                                              toTitleCase(lead?.status ?? 'New'),
                                              statusColor,
                                              isDark,
                                            ),
                                            const SizedBox(height: 6),
                                            _buildCuratedBadgeCompact(
                                              lead?.pipeline ?? 'Cold',
                                              pipelineColor,
                                              isDark,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 24),
                                    // Bottom Grid: Interest, Updated, Assigned To
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildDetailItemCompact(
                                            Icons.business_outlined,
                                            lead?.service?.name ?? 'Sales CRM',
                                            isDark,
                                          ),
                                        ),
                                        Expanded(
                                          child: _buildDetailItemCompact(
                                            Icons.access_time_rounded,
                                            lead != null
                                                ? timeago.format(DateTime.parse(lead.updatedAt))
                                                : 'Just now',
                                            isDark,
                                          ),
                                        ),
                                        Expanded(
                                          child: _buildDetailItemCompact(
                                            Icons.person_outline_rounded,
                                            lead?.assignedTo?.name ?? 'Unassigned',
                                            isDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    // Sub-assignees
                                    if (lead?.subAssignees != null &&
                                        lead!.subAssignees!.isNotEmpty) ...[
                                      const Divider(height: 20),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.indigo.withValues(alpha:0.15)
                                              : const Color(0xFFEEF2FF),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isDark
                                                ? Colors.indigo.withValues(alpha:0.3)
                                                : const Color(0xFFE0E7FF),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.group_outlined,
                                                  size: 14,
                                                  color: isDark
                                                      ? const Color(0xFF818CF8)
                                                      : const Color(0xFF3730A3),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Sub-assignees:',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark
                                                        ? const Color(0xFF818CF8)
                                                        : const Color(0xFF3730A3),
                                                  ),
                                                ),
                                                if (permissions.canEditLead(
                                                  lead,
                                                  userRole: userRole,
                                                  userId: userId,
                                                )) ...[
                                                  const SizedBox(width: 6),
                                                  GestureDetector(
                                                    onTap: () => _showSubAssigneeDialog(
                                                      context,
                                                      lead,
                                                    ),
                                                    child: Icon(
                                                      Icons.edit_outlined,
                                                      size: 14,
                                                      color: isDark
                                                          ? const Color(0xFF818CF8)
                                                          : const Color(0xFF3730A3),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              lead.subAssignees!
                                                  .map((sa) => sa.name)
                                                  .join(', '),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? Colors.white70
                                                    : Colors.grey[800],
                                                fontWeight: FontWeight.w500,
                                                height: 1.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ] else if (permissions.canEditLead(
                                      lead,
                                      userRole: userRole,
                                      userId: userId,
                                    )) ...[
                                      const Divider(height: 20),
                                      GestureDetector(
                                        onTap: () => _showSubAssigneeDialog(context, lead!),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.person_add_outlined,
                                              size: 14,
                                              color: isDark
                                                  ? const Color(0xFF818CF8)
                                                  : const Color(0xFF3730A3),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Add Sub-assignees',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? const Color(0xFF818CF8)
                                                    : const Color(0xFF3730A3),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // --- HORIZONTAL STICKY TABS ---
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _StickyTabBarDelegate(
                          height: 54.0,
                          child: Container(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark ? Colors.white12 : Colors.black.withValues(alpha:0.04),
                                ),
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  children: activeTabs.map((tab) {
                                    final isSelected = _selectedTabName == tab;
                                    return InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedTabName = tab;
                                        });
                                        _fetchDataIfNeeded(tab);
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              tab,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                                                color: isSelected
                                                    ? const Color(0xFF2563EB)
                                                    : (isDark ? Colors.white70 : Colors.black87),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              height: 2,
                                              width: 16,
                                              color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // --- TAB DETAIL CONTENT ---
                      SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          child: _getWidgetForTab(
                            _selectedTabName,
                            lead,
                            isDark,
                            theme,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // --- PINNED BOTTOM ACTION BAR ---
                _buildBottomActionButtons(lead, isDark, theme),
              ],
            ),
    );
  }

  Widget _buildCuratedBadgeCompact(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha:0.24), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildDetailItemCompact(IconData icon, String text, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: isDark ? Colors.white60 : Colors.grey[600],
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _showAllActionsBottomSheet(BuildContext context, Lead lead) {
    final permissions = ref.read(permissionsProvider);
    final userRole = ref.read(loginProvider).user?.systemRole;
    final userId = ref.read(loginProvider).user?.id;

    final canCall = permissions.hasPermission(PermissionModules.LEADS_CALL, userRole: userRole);
    final canWhatsApp = permissions.can(PermissionModules.WHATSAPP, permission: PermissionModules.LEADS_WHATSAPP, userRole: userRole);
    final canStatus = permissions.hasPermission(PermissionModules.LEADS_UPDATE_STATUS, userRole: userRole) && permissions.canEditLead(lead, userRole: userRole, userId: userId);
    final canIvrCall = permissions.can(PermissionModules.INTEGRATION_IVR, permission: PermissionModules.INTEGRATION_IVR_CALL, userRole: userRole);
    final canTask = permissions.can(PermissionModules.TASK, permission: PermissionModules.TASKS_CREATE, userRole: userRole) && permissions.canEditLead(lead, userRole: userRole, userId: userId);
    final canMeeting = permissions.can(PermissionModules.MEETING, permission: PermissionModules.MEETINGS_CREATE, userRole: userRole) && permissions.canEditLead(lead, userRole: userRole, userId: userId);
    final canVisit = permissions.can(PermissionModules.VISITS, permission: PermissionModules.VISITS_CREATE, userRole: userRole) && permissions.canEditLead(lead, userRole: userRole, userId: userId);
    final canEmail = permissions.hasPermission(PermissionModules.LEADS_MAIL, userRole: userRole);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'All Actions',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (canCall)
                      ListTile(
                        leading: const Icon(Icons.phone_outlined, color: Colors.green),
                        title: const Text('Call'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _makeCall(lead);
                        },
                      ),
                    if (canWhatsApp)
                      ListTile(
                        leading: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366)),
                        title: const Text('WhatsApp'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _launchCrmWhatsApp(lead);
                        },
                      ),
                    if (canStatus)
                      ListTile(
                        leading: const Icon(Icons.playlist_add_rounded, color: Colors.purple),
                        title: const Text('Update Status'),
                        onTap: () {
                          Navigator.pop(ctx);
                          showDialog(
                            context: context,
                            builder: (_) => LeadStatusUpdateDialog(lead: lead),
                          ).then(
                            (_) => ref
                                .read(leadDetailProvider.notifier)
                                .fetchLeadDetails(widget.leadId),
                          );
                        },
                      ),
                    if (canIvrCall)
                      ListTile(
                        leading: const Icon(Icons.settings_phone_outlined, color: Colors.blue),
                        title: const Text('IVR Call'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _initiateIvrCall(lead);
                        },
                      ),
                    if (canTask)
                      ListTile(
                        leading: const Icon(Icons.task_alt_rounded, color: Colors.indigo),
                        title: const Text('Create Task'),
                        onTap: () {
                          Navigator.pop(ctx);
                          showDialog(
                            context: context,
                            builder: (_) => TaskCreateDialog(leadId: lead.id),
                          ).then(
                            (_) => ref
                                .read(leadDetailProvider.notifier)
                                .fetchLeadDetails(widget.leadId),
                          );
                        },
                      ),
                    if (canMeeting)
                      ListTile(
                        leading: const Icon(Icons.video_call_outlined, color: Colors.deepOrange),
                        title: const Text('Schedule Meeting'),
                        onTap: () {
                          Navigator.pop(ctx);
                          showDialog(
                            context: context,
                            builder: (_) => MeetingCreateDialog(
                              leadId: lead.id,
                              clientEmail: lead.email,
                            ),
                          ).then(
                            (_) => ref
                                .read(leadDetailProvider.notifier)
                                .fetchLeadDetails(widget.leadId),
                          );
                        },
                      ),
                    if (canVisit)
                      ListTile(
                        leading: const Icon(Icons.location_on_outlined, color: Colors.teal),
                        title: const Text('Schedule Visit'),
                        onTap: () {
                          Navigator.pop(ctx);
                          showDialog(
                            context: context,
                            builder: (_) => VisitCreateDialog(leadId: lead.id),
                          ).then(
                            (_) => ref
                                .read(leadDetailProvider.notifier)
                                .fetchLeadDetails(widget.leadId),
                          );
                        },
                      ),
                    if (canEmail)
                      ListTile(
                        leading: const Icon(Icons.mail_outline_rounded, color: Colors.blueGrey),
                        title: const Text('Email'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _sendEmail(lead);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomActionButtons(Lead? lead, bool isDark, ThemeData theme) {
    if (lead == null) return const SizedBox.shrink();
    
    final permissions = ref.watch(permissionsProvider);
    final userRole = ref.watch(loginProvider).user?.systemRole;
    final userId = ref.watch(loginProvider).user?.id;

    final canCall = permissions.hasPermission(PermissionModules.LEADS_CALL, userRole: userRole);
    final canWhatsApp = permissions.can(PermissionModules.WHATSAPP, permission: PermissionModules.LEADS_WHATSAPP, userRole: userRole);
    final canStatus = permissions.hasPermission(PermissionModules.LEADS_UPDATE_STATUS, userRole: userRole) && permissions.canEditLead(lead, userRole: userRole, userId: userId);

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: _buildBottomActionButtonItem(
                  label: 'All Actions',
                  icon: Icons.apps_rounded,
                  color: Colors.blueAccent,
                  onTap: () => _showAllActionsBottomSheet(context, lead),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBottomActionButtonItem(
                  label: 'Call',
                  icon: Icons.phone_outlined,
                  color: Colors.green,
                  onTap: canCall ? () => _makeCall(lead) : null,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBottomActionButtonItem(
                  label: 'WhatsApp',
                  icon: Icons.chat_bubble_outline_rounded,
                  color: Colors.teal,
                  onTap: canWhatsApp ? () => _launchCrmWhatsApp(lead) : null,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBottomActionButtonItem(
                  label: 'Status',
                  icon: Icons.playlist_add_rounded,
                  color: Colors.purple,
                  onTap: canStatus ? () {
                    showDialog(
                      context: context,
                      builder: (_) => LeadStatusUpdateDialog(lead: lead),
                    ).then(
                      (_) => ref
                          .read(leadDetailProvider.notifier)
                          .fetchLeadDetails(widget.leadId),
                    );
                  } : null,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionButtonItem({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    required bool isDark,
  }) {
    final isDisabled = onTap == null;
    final buttonColor = isDisabled
        ? (isDark ? Colors.white10 : Colors.grey[200]!)
        : color.withValues(alpha:0.08);
    final iconColor = isDisabled
        ? (isDark ? Colors.white30 : Colors.grey[400]!)
        : color;
    final textColor = isDisabled
        ? (isDark ? Colors.white30 : Colors.grey[400]!)
        : (isDark ? Colors.white : Colors.black87);

    return Material(
      color: buttonColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDisabled
                  ? Colors.transparent
                  : color.withValues(alpha:0.15),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getWidgetForTab(
    String tabName,
    Lead? lead,
    bool isDark,
    ThemeData theme,
  ) {
    switch (tabName) {
      case 'Quick':
        return _buildQuickTab(lead, isDark, theme);
      case 'Details':
        return _buildDetailsTab(lead, isDark, theme);
      case 'Activities':
        return _buildActivitiesTab(lead, isDark, theme);
      case 'System':
        return _buildSystemTab(lead, isDark, theme);
      case 'Tasks':
        return _buildTasksTab(lead, isDark, theme);
      case 'Meetings':
        return _buildMeetingsTab(lead, isDark, theme);
      case 'Visit':
        return _buildVisitTab(lead, isDark, theme);
      case 'Calls':
        return _buildCallLogsTab(lead, isDark, theme);
      case 'Files':
        return _buildFilesTab(lead, isDark, theme);
      case 'Invoice':
        return _buildInvoiceTab(lead, isDark, theme);
      case 'Itinerary':
        return _buildItineraryTab(lead, isDark, theme);
      case 'Quotation':
        return _buildQuotationTab(lead, isDark, theme);
      case 'Voucher':
        return _buildVouchersTab(lead, isDark, theme);
      default:
        return _buildQuickTab(lead, isDark, theme);
    }
  }

  Future<void> fetchAndShowDocuments<T>({required BuildContext context, required String title, required String Function(T) itemLabel, required void Function(T) onItemSelected, required Future<List<T>> Function() fetchDocuments, Lead? lead,}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final documents = await fetchDocuments();

    if (!context.mounted) return;
    Navigator.pop(context);

    _showDocumentSelectionBottomSheet<T>(
      context: context,
      title: title,
      itemLabel: itemLabel,
      onItemSelected: onItemSelected,
      documents: documents,
      lead: lead,
    );
  }

  void _showDocumentSelectionBottomSheet<T>({required BuildContext context, required String title, required String Function(T) itemLabel, required void Function(T) onItemSelected, required List<T> documents, Lead? lead,}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DocumentSelectorBottomSheet<T>(
        title: title,
        documents: documents,
        onItemSelected: onItemSelected,
        lead: lead,
        parentContext: context,
      ),
    );
  }

  void _showQuotationShareDialog(
    BuildContext context,
    Quotation quotation, [
    Lead? lead,
  ]) {
    showDialog(
      context: context,
      builder: (ctx) => QuotationShareDialog(quotation: quotation, lead: lead),
    );
  }

  void _showInvoiceShareDialog(
    BuildContext context,
    Invoice invoice, [
    Lead? lead,
  ]) {
    showDialog(
      context: context,
      builder: (ctx) => InvoiceShareDialog(invoice: invoice, lead: lead),
    );
  }

  void _showItineraryShareDialog(
    BuildContext context,
    ItineraryV2 itinerary, [
    Lead? lead,
  ]) {
    showDialog(
      context: context,
      builder: (ctx) => ItineraryShareDialog(itinerary: itinerary, lead: lead),
    );
  }

  void _showVoucherShareDialog(
    BuildContext context,
    Voucher voucher, [
    Lead? lead,
  ]) {
    showDialog(
      context: context,
      builder: (ctx) => VoucherShareDialog(voucher: voucher, lead: lead),
    );
  }

  String _formatTravelDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final date = DateTimeUtils.parseSafe(raw);
    if (date != null) return DateFormat('dd MMM yyyy').format(date);
    return raw;
  }
}

class _ExpandableDescriptionText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final bool isDark;

  const _ExpandableDescriptionText({
    required this.text,
    required this.style,
    required this.isDark,
  });

  @override
  State<_ExpandableDescriptionText> createState() => _ExpandableDescriptionTextState();
}

class _ExpandableDescriptionTextState extends State<_ExpandableDescriptionText> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 5,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout(maxWidth: constraints.maxWidth);

        final isTruncated = textPainter.didExceedMaxLines;

        if (!isTruncated) {
          return Text(
            widget.text,
            style: widget.style,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: widget.style,
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () {
                _showFullDescriptionDialog(context);
              },
              child: const Text(
                'see more',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showFullDescriptionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = widget.isDark;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDark ? const Color(0xFF1E2130) : Colors.white,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      color: isDark ? Colors.blueAccent : const Color(0xFF4F46E5),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Lead Description",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Text(
                      widget.text,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.blueAccent : const Color(0xFF4F46E5),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text("Close"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  SliverAppBarDelegate({required this.child});

  @override
  double get minExtent => 48.0;

  @override
  double get maxExtent => 48.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(SliverAppBarDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}


class HistoryItem extends StatelessWidget {
  final StatusHistory history;
  const HistoryItem({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    Color barColor;
    final status = history.status;
    final lower = status.toLowerCase();

    if (lower.contains('new')) {
      barColor = Colors.blue;
    } else if (lower.contains('contacted') || lower.contains('connected')) {
      barColor = Colors.green;
    } else if (lower.contains('negotiation')) {
      barColor = Colors.purple;
    } else if (lower.contains('lost')) {
      barColor = Colors.red;
    } else if (lower.contains('won') || lower.contains('convert')) {
      barColor = Colors.teal;
    } else if (lower.contains('junk')) {
      barColor = Colors.grey;
    } else if (lower.contains('future') ||
        lower.contains('attempt') ||
        lower.contains('fail')) {
      barColor = Colors.orange;
    } else {
      final palette = [
        Colors.blue,
        Colors.green,
        Colors.purple,
        Colors.orange,
        Colors.teal,
        Colors.pink,
        Colors.indigo,
        Colors.lime,
      ];
      barColor = palette[status.hashCode.abs() % palette.length];
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: barColor,
                boxShadow: [
                  BoxShadow(
                    color: barColor.withValues(alpha:0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            Container(
              width: 2,
              height: 60,
              color: theme.dividerColor.withValues(alpha:0.1),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                toTitleCase(history.status),
                style: TextStyle(
                  color: isDark ? barColor.withValues(alpha:0.9) : barColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              if (history.comment != null && history.comment!.isNotEmpty)
                Text(
                  history.comment!,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.textTheme.bodyLarge?.color,
                    height: 1.4,
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.hintColor.withValues(alpha:0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      history.updatedBy?.name ?? "System",
                      style: TextStyle(
                        color: theme.textTheme.bodySmall?.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    timeago.format(
                      DateTimeUtils.parseSafe(history.createdAt) ??
                          DateTime.now(),
                    ),
                    style: TextStyle(
                      color: theme.hintColor.withValues(alpha:0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}

class _DeleteDialog extends StatelessWidget {
  final String title;
  final String content;
  final VoidCallback onConfirm;

  const _DeleteDialog({
    required this.title,
    required this.content,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:isDark ? 0.3 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: theme.dividerColor.withValues(alpha:0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: theme.textTheme.bodyLarge?.color,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              content,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha:0.7),
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.hintColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitCard extends ConsumerWidget {
  final Visit visit;
  final String leadId;

  const _VisitCard({required this.visit, required this.leadId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    DateTime? dt;
    dt = DateTimeUtils.parseSafe(visit.dateTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha:0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  visit.property?.name ?? visit.project?.name ?? 'Site Visit',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: theme.textTheme.bodyLarge?.color,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              _buildStatusBadge(visit.status, isDark),
            ],
          ),
          if (dt != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 12,
                  color: theme.hintColor,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${DateFormat('dd MMM yyyy, hh:mm a').format(dt)} (${timeago.format(dt)})',
                    style: TextStyle(
                      color: theme.hintColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          if (visit.project != null)
            Text(
              'Project: ${visit.project!.name}',
              style: TextStyle(
                color: theme.hintColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            visit.description,
            style: TextStyle(
              fontSize: 13,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha:0.8),
              height: 1.4,
            ),
          ),
          const Divider(height: 20),
          Text(
            'Comments',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (visit.comments != null && visit.comments!.isNotEmpty)
                ? visit.comments!
                : 'No comments provided',
            style: TextStyle(
              fontSize: 13,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha:0.8),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (ref
                  .watch(permissionsProvider)
                  .can(
                    PermissionModules.VISITS,
                    permission: PermissionModules.VISITS_UPDATE,
                    userRole: ref.watch(loginProvider).user?.systemRole,
                  ))
                _buildCardBtn(
                  Icons.edit,
                  'Update',
                  theme,
                  isDark,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) =>
                          VisitEditDialog(leadId: leadId, visit: visit),
                    ).then((_) {
                      ref
                          .read(leadDetailProvider.notifier)
                          .fetchLeadDetails(leadId);
                    });
                  },
                ),
              if (ref
                      .watch(permissionsProvider)
                      .can(
                        PermissionModules.VISITS,
                        permission: PermissionModules.VISITS_UPDATE,
                        userRole: ref.watch(loginProvider).user?.systemRole,
                      ) &&
                  ref
                      .watch(permissionsProvider)
                      .can(
                        PermissionModules.VISITS,
                        permission: PermissionModules.VISITS_DELETE,
                        userRole: ref.watch(loginProvider).user?.systemRole,
                      ))
                const SizedBox(width: 12),
              if (ref
                  .watch(permissionsProvider)
                  .can(
                    PermissionModules.VISITS,
                    permission: PermissionModules.VISITS_DELETE,
                    userRole: ref.watch(loginProvider).user?.systemRole,
                  ))
                _buildCardBtn(
                  Icons.delete_outline,
                  'Delete',
                  theme,
                  isDark,
                  isDelete: true,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => _DeleteDialog(
                        title: 'Delete Visit',
                        content:
                            'Are you sure you want to delete this visit schedule? This action cannot be undone.',
                        onConfirm: () async {
                          try {
                            await ref
                                .read(visitsProvider.notifier)
                                .deleteVisit(visit.id);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Visit deleted successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              ref
                                  .read(leadDetailProvider.notifier)
                                  .fetchLeadDetails(leadId);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              Navigator.pop(context);
                            }
                          }
                        },
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isDark) {
    final displayStatus = toTitleCase(status);
    Color color;
    Color bgColor;

    switch (displayStatus) {
      case 'Scheduled':
        color = const Color(0xFF6366F1);
        bgColor = color.withValues(alpha:0.1);
        break;
      case 'Completed':
        color = const Color(0xFF10B981);
        bgColor = color.withValues(alpha:0.1);
        break;
      case 'Cancelled':
        color = const Color(0xFFF43F5E);
        bgColor = color.withValues(alpha:0.1);
        break;
      default:
        color = isDark ? Colors.white70 : const Color(0xFF475569);
        bgColor = isDark
            ? Colors.white.withValues(alpha:0.05)
            : const Color(0xFFF1F5F9);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        displayStatus,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildCardBtn(
    IconData icon,
    String label,
    ThemeData theme,
    bool isDark, {
    bool isDelete = false,
    VoidCallback? onTap,
  }) {
    final color = isDelete
        ? Colors.redAccent
        : (isDark ? Colors.white70 : const Color(0xFF1E293B));
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDelete
                ? Colors.redAccent.withValues(alpha:0.3)
                : theme.dividerColor.withValues(alpha:0.1),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends ConsumerWidget {
  final LeadDocument doc;
  final String leadId;
  const _DocumentCard({required this.doc, required this.leadId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final permissions = ref.watch(permissionsProvider);
    final userRole = ref.watch(loginProvider).user?.systemRole;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha:0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getFileIcon(doc.fileType),
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${doc.fileType.toUpperCase()} â€¢ ${formatBytes(doc.size)} â€¢ ${doc.uploadedBy}',
                      style: TextStyle(fontSize: 11, color: theme.hintColor),
                    ),
                  ],
                ),
              ),
              if (doc.isLocked)
                const Icon(Icons.lock_rounded, size: 16, color: Colors.orange)
              else
                const Icon(
                  Icons.lock_open_rounded,
                  size: 16,
                  color: Colors.green,
                ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (permissions.can(
                PermissionModules.LEAD_DOCS,
                permission: PermissionModules.LEAD_DOCS_DOWNLOAD,
                userRole: userRole,
              ))
                _buildActionBtn(Icons.download_rounded, 'Download', () async {
                  final url = Uri.parse(
                    'https://treviondocs.browndevs.com/${doc.r2Key}',
                  );
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                }),
              if (permissions.can(
                PermissionModules.LEAD_DOCS,
                permission: PermissionModules.LEAD_DOCS_DOWNLOAD,
                userRole: userRole,
              ))
                const SizedBox(width: 8),
              if (permissions.can(
                PermissionModules.LEAD_DOCS,
                permission: PermissionModules.LEAD_DOCS_LOCK,
                userRole: userRole,
              ))
                _buildActionBtn(
                  doc.isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                  doc.isLocked ? 'Unlock' : 'Lock',
                  () => ref
                      .read(leadDocumentsProvider(leadId).notifier)
                      .toggleLock(doc.id),
                ),
              const SizedBox(width: 8),
              if (permissions.can(
                PermissionModules.LEAD_DOCS,
                permission: PermissionModules.LEAD_DOCS_DELETE,
                userRole: userRole,
              ))
                _buildActionBtn(Icons.delete_outline, 'Delete', () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Document?'),
                      content: const Text(
                        'Are you sure you want to delete this document?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('CANCEL'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'DELETE',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    ref
                        .read(leadDocumentsProvider(leadId).notifier)
                        .deleteDocument(doc.id);
                  }
                }, isDelete: true),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String ext) {
    ext = ext.toLowerCase();
    if (ext == 'pdf') return Icons.picture_as_pdf_rounded;
    if (['jpg', 'jpeg', 'png'].contains(ext)) return Icons.image_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Widget _buildActionBtn(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDelete = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isDelete ? Colors.red : Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDelete ? Colors.red : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignLeadDialog extends ConsumerStatefulWidget {
  final Lead lead;
  const _AssignLeadDialog({required this.lead});

  @override
  ConsumerState<_AssignLeadDialog> createState() => _AssignLeadDialogState();
}

class _AssignLeadDialogState extends ConsumerState<_AssignLeadDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedUserId;
  bool _isLoading = false;

  static const _roles = [
    'company_admin',
    'sales_manager',
    'team_leader',
    'sales_executive',
  ];
  static const _roleLabels = [
    'Company Admin',
    'Sales Manager',
    'Team Leader',
    'Sales Executive',
  ];
  static const _roleIcons = [
    Icons.admin_panel_settings_outlined,
    Icons.manage_accounts_outlined,
    Icons.groups_outlined,
    Icons.person_outline,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _roles.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _buildHandle(isDark),
            _buildHeader(theme, isDark),
            _buildTabBar(isDark),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _roles
                    .map(
                      (role) => _SingleAssignUserListTab(
                        role: role,
                        selectedUserId: _selectedUserId,
                        onSelect: (id) => setState(() => _selectedUserId = id),
                      ),
                    )
                    .toList(),
              ),
            ),
            _buildBottomButton(isDark),
            SizedBox(height: bottomInset > 0 ? bottomInset : 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: isDark ? Colors.white30 : Colors.black26,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha:0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.person_add_alt_1,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assign Lead',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.lead.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: 20,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha:0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Colors.white,
        unselectedLabelColor: theme.textTheme.bodySmall?.color,
        indicator: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        dividerColor: Colors.transparent,
        tabAlignment: TabAlignment.center,
        tabs: _roleLabels
            .asMap()
            .entries
            .map(
              (e) => Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_roleIcons[e.key], size: 14),
                    const SizedBox(width: 4),
                    Text(e.value),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildBottomButton(bool isDark) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: (_selectedUserId != null && !_isLoading) ? _assign : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Assign',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_selectedUserId != null) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'to ${_selectedUserId == '' ? 'Unassigned' : _getSelectedUserName()}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onPrimary.withValues(alpha:0.8),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  String _getSelectedUserName() {
    if (_selectedUserId == '') return 'Unassigned';
    for (final role in _roles) {
      final users = ref.read(staffProvider(role)).users;
      final match = users.where((u) => u.id == _selectedUserId).firstOrNull;
      if (match != null) return match.name;
    }
    return '';
  }

  Future<void> _assign() async {
    if (_selectedUserId == null) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(leadsProvider.notifier)
          .assignLead(widget.lead.id, _selectedUserId!);
      if (mounted) {
        ref.read(leadDetailProvider.notifier).fetchLeadDetails(widget.lead.id);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to assign: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _SingleAssignUserListTab extends ConsumerStatefulWidget {
  final String role;
  final String? selectedUserId;
  final Function(String) onSelect;

  const _SingleAssignUserListTab({
    required this.role,
    required this.selectedUserId,
    required this.onSelect,
  });

  @override
  ConsumerState<_SingleAssignUserListTab> createState() =>
      _SingleAssignUserListTabState();
}

class _SingleAssignUserListTabState
    extends ConsumerState<_SingleAssignUserListTab>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(staffProvider(widget.role).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(staffProvider(widget.role));
    final users = state.users
        .where((u) => u.status.toLowerCase() == 'active' && u.active == true)
        .toList();
    final theme = Theme.of(context);

    if (state.isLoading && users.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }

    return TextSelectionTheme(
      data: TextSelectionThemeData(selectionColor: Colors.transparent),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        itemCount:
            users.length + 1 + (state.isLoading ? 1 : 0), // +1 for Unassigned
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          if (index == 0) {
            // Unassigned Option
            final isSelected = widget.selectedUserId == '';
            return GestureDetector(
              onTap: () => widget.onSelect(''),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha:0.06)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha:0.3)
                        : theme.colorScheme.outlineVariant.withValues(alpha:0.5),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey.withValues(alpha:0.12),
                      child: const Icon(
                        Icons.person_off,
                        size: 18,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Unassigned',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                          width: 2,
                        ),
                        color: isSelected
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            );
          }

          if (index == users.length + 1) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final user = users[index - 1];
          final isSelected = widget.selectedUserId == user.id;
          return GestureDetector(
            onTap: () => widget.onSelect(user.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha:0.06)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha:0.3)
                      : theme.colorScheme.outlineVariant.withValues(alpha:0.5),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: _getAvatarColor(
                      user.name,
                    ).withValues(alpha:0.12),
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _getAvatarColor(user.name),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        if (user.email != '-')
                          Text(
                            user.email,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        width: 2,
                      ),
                      color: isSelected
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getAvatarColor(String name) {
    const colors = [
      Color(0xFF1976D2),
      Color(0xFF388E3C),
      Color(0xFFF57C00),
      Color(0xFF7B1FA2),
      Color(0xFF00796B),
      Color(0xFFC2185B),
      Color(0xFF455A64),
    ];
    return colors[name.length % colors.length];
  }

  /// Formats a raw date string (ISO or yyyy-MM-dd) into "dd MMM yyyy"
  String formatTravelDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final date = DateTimeUtils.parseSafe(raw);
    if (date != null) return DateFormat('dd MMM yyyy').format(date);
    return raw; // Return as-is if parsing fails
  }

  /// Capitalizes first letter of a nullable string
  String capitalize(String? value) {
    if (value == null || value.isEmpty) return '-';
    return value[0].toUpperCase() + value.substring(1);
  }
}

class SubAssigneeDialog extends ConsumerStatefulWidget {
  final Lead lead;
  const SubAssigneeDialog({super.key, required this.lead});

  @override
  ConsumerState<SubAssigneeDialog> createState() => SubAssigneeDialogState();
}

class SubAssigneeDialogState extends ConsumerState<SubAssigneeDialog> {
  List<Map<String, dynamic>> _assignableUsers = [];
  List<String> _selectedUserIds = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedUserIds =
        widget.lead.subAssignees?.map((sa) => sa.id).toList() ?? [];
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final users = await ref.read(leadServiceProvider).fetchAssignableUsers();
      if (mounted) {
        setState(() {
          _assignableUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(leadServiceProvider)
          .updateSubAssignees(widget.lead.id, _selectedUserIds);
      if (mounted) {
        Navigator.pop(context);
        try {
          ref.read(leadDetailProvider.notifier).fetchLeadDetails(widget.lead.id);
        } catch (_) {}
        try {
          ref.read(leadsProvider.notifier).refresh();
        } catch (_) {}
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _toggleUser(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ownerId = widget.lead.assignedTo?.id;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          minWidth: 320,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.group_outlined,
                    size: 20,
                    color: const Color(0xFF3730A3),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sub-assignees',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.lead.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 20,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(
              height: 1,
              color: isDark ? Colors.white10 : Colors.grey[200],
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _fetchUsers,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _assignableUsers.length,
                  itemBuilder: (context, index) {
                    final user = _assignableUsers[index];
                    final userId = user['_id'] ?? '';
                    final userName = user['name'] ?? '';
                    final userRole = user['systemRole'] ?? '';
                    final isSelected = _selectedUserIds.contains(userId);
                    final isOwner = userId == ownerId;

                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: isSelected
                            ? const Color(0xFF3730A3).withValues(alpha:0.12)
                            : (isDark ? Colors.white10 : Colors.grey[100]),
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? const Color(0xFF3730A3)
                                : (isDark ? Colors.white54 : Colors.grey[600]),
                          ),
                        ),
                      ),
                      title: Text(
                        userName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isOwner && !isSelected ? Colors.grey : null,
                        ),
                      ),
                      subtitle: Text(
                        userRole.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                      trailing: isOwner
                          ? (isSelected
                                ? null
                                : Text(
                                    'Owner',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[400],
                                    ),
                                  ))
                          : GestureDetector(
                              onTap: () => _toggleUser(userId),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF3730A3)
                                        : Colors.grey,
                                    width: 1.5,
                                  ),
                                  color: isSelected
                                      ? const Color(0xFF3730A3)
                                      : Colors.transparent,
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        size: 13,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                      enabled: !isOwner,
                      onTap: isOwner ? null : () => _toggleUser(userId),
                    );
                  },
                ),
              ),
            Divider(
              height: 1,
              color: isDark ? Colors.white10 : Colors.grey[200],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3730A3),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _selectedUserIds.isNotEmpty
                                  ? 'Save (${_selectedUserIds.length})'
                                  : 'Save',
                            ),
                    ),
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

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _StickyTabBarDelegate({required this.child, this.height = 54.0});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Align(
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _StickyTabBarDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}


