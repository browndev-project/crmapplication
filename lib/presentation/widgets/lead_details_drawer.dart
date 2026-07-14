import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/lead_model.dart';
import '../../data/models/call_log_model.dart';
import 'lead_calls_helper.dart';
import '../../core/services/lead_service.dart';
import '../../core/services/call_logger_service.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/date_utils.dart';

class _SourceInfo {
  final String label;
  final Color color;
  final IconData icon;
  const _SourceInfo(this.label, this.color, this.icon);
}

_SourceInfo _getSourceInfo(String? source) {
  final s = source?.toUpperCase() ?? '';
  if (s.contains('IVR')) {
    return const _SourceInfo('IVR Solutions', Colors.purple, Icons.phone);
  }
  if (s.contains('WEB')) {
    return const _SourceInfo('Web', Colors.orange, Icons.laptop_mac);
  }
  if (s.contains('APP')) {
    return const _SourceInfo('App', Colors.teal, Icons.smartphone);
  }
  return _SourceInfo(source ?? 'Unknown', Colors.grey, Icons.call);
}

String? _extractDid(CallLog log) {
  if (log.ivr case Map<String, dynamic> ivr) {
    final did =
        ivr['didNumber'] ?? ivr['did'] ?? ivr['DIDNumber'] ?? ivr['did_number'];
    if (did != null && did.toString().isNotEmpty) return did.toString();
  }
  if (log.callDetails case List<dynamic> details) {
    for (final d in details) {
      if (d is Map<String, dynamic>) {
        final did =
            d['didNumber'] ?? d['did'] ?? d['DIDNumber'] ?? d['did_number'];
        if (did != null && did.toString().isNotEmpty) return did.toString();
      }
    }
  }
  return null;
}

String? _extractSimSlot(CallLog log) {
  String? normalizeSim(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    final text = value.toString();
    final parsed = int.tryParse(text);
    if (parsed == null) return text;
    return parsed <= 0 ? '1' : parsed.toString();
  }

  // Check direct simSlot field first
  final directSim = normalizeSim(log.simSlot);
  if (directSim != null) return directSim;

  if (log.callDetails case List<dynamic> details) {
    for (final d in details) {
      if (d is Map<String, dynamic>) {
        final sim =
            d['simSlot'] ?? d['sim'] ?? d['simSlotIndex'] ?? d['simNumber'];
        final normalized = normalizeSim(sim);
        if (normalized != null) return normalized;
      }
    }
  }
  if (log.ivr case Map<String, dynamic> ivr) {
    final sim =
        ivr['simSlot'] ?? ivr['sim'] ?? ivr['simSlotIndex'] ?? ivr['simNumber'];
    final normalized = normalizeSim(sim);
    if (normalized != null) return normalized;
  }
  return null;
}

class LeadDetailsDrawer extends StatefulWidget {
  final String leadId;

  const LeadDetailsDrawer({super.key, required this.leadId});

  static void show(BuildContext context, String leadId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LeadDetailsDrawer(leadId: leadId),
    );
  }

  @override
  State<LeadDetailsDrawer> createState() => _LeadDetailsDrawerState();
}

class _LeadDetailsDrawerState extends State<LeadDetailsDrawer>
    with SingleTickerProviderStateMixin {
  final LeadService _leadService = LeadService();
  late TabController _tabController;

  bool _isLoading = true;
  String? _error;
  Lead? _lead;
  List<CallLog> _callLogs = [];
  StreamSubscription<String>? _webhookSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllDetails();
    
    // Refresh details immediately when a call webhook is successfully sent
    _webhookSubscription = CallLoggerService.webhookSentStream.listen((_) {
      if (mounted) {
        _loadAllDetails();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _webhookSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAllDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final leadDetail = await _leadService.fetchLeadDetails(widget.leadId);
      List<CallLog> calls = [];
      try {
        final callLogsResult = await _leadService.fetchCallLogs(widget.leadId);
        calls = callLogsResult.logs;
      } catch (e) {
        debugPrint('Error loading call logs: $e');
      }

      if (mounted) {
        setState(() {
          _lead = leadDetail;
          _callLogs = calls;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171923) : const Color(0xFFF7F9FC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.black87),
              )
            : _error != null
            ? _buildErrorView()
            : _lead == null
            ? const Center(child: Text("Lead details not found"))
            : Column(
                children: [
                  _buildHeader(isDark, theme),
                  _buildTabBar(isDark),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(isDark),
                        _buildStatusTab(isDark),
                        _buildTasksMeetingsTab(isDark),
                        _buildCallLogsTab(isDark),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              "Error loading lead: $_error",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAllDetails,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              child: const Text("RETRY", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, ThemeData theme) {
    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return Container(
      color: isDark ? const Color(0xFF1E2130) : Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _lead!.leadId.isNotEmpty ? _lead!.leadId : 'ID: N/A',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _lead!.name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.local_fire_department,
                size: 14,
                color: Colors.orange.shade800,
              ),
              const SizedBox(width: 4),
              Text(
                'Stage: ${_lead!.pipeline}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                currencyFormat.format(_lead!.amount),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1E2130) : Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: isDark ? Colors.white : Colors.black87,
        unselectedLabelColor: Colors.grey,
        indicatorColor: Colors.black87,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(text: "Overview"),
          Tab(text: "Status & Assign"),
          Tab(text: "Tasks & meets"),
          Tab(text: "Call Logs"),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard("Contact Information", [
            _buildDetailItem(Icons.phone_outlined, "Phone", _lead!.phoneNo),
            _buildDetailItem(
              Icons.email_outlined,
              "Email",
              _lead!.email.isNotEmpty ? _lead!.email : 'N/A',
            ),
            _buildDetailItem(
              Icons.calendar_today_outlined,
              "Date of Birth",
              _lead!.dob != null && _lead!.dob!.isNotEmpty
                  ? _lead!.dob!
                  : 'N/A',
            ),
          ], isDark),
          const SizedBox(height: 16),
          _buildInfoCard("Lead Source & Details", [
            _buildDetailItem(Icons.source_outlined, "Source", _lead!.source),
            _buildDetailItem(
              Icons.person_outline,
              "Referral Agent",
              _lead!.referralName != null && _lead!.referralName!.isNotEmpty
                  ? _lead!.referralName!
                  : 'N/A',
            ),
            _buildDetailItem(
              Icons.description_outlined,
              "Notes / Description",
              _lead!.description.isNotEmpty ? _lead!.description : 'N/A',
            ),
          ], isDark),
          const SizedBox(height: 16),
          _buildInfoCard("Address Details", [
            _buildDetailItem(
              Icons.location_on_outlined,
              "Street Address",
              _lead!.address?.address1 != null &&
                      _lead!.address!.address1.isNotEmpty
                  ? _lead!.address!.address1
                  : 'N/A',
            ),
            _buildDetailItem(
              Icons.location_city_outlined,
              "City / State",
              '${_lead!.address?.city ?? 'N/A'} / ${_lead!.address?.state ?? 'N/A'}',
            ),
            _buildDetailItem(
              Icons.pin_drop_outlined,
              "Pin Code",
              _lead!.address?.pinCode != null &&
                      _lead!.address!.pinCode.isNotEmpty
                  ? _lead!.address!.pinCode
                  : 'N/A',
            ),
          ], isDark),
        ],
      ),
    );
  }

  Widget _buildStatusTab(bool isDark) {
    final statusHist = _lead!.statusHistory ?? [];
    final assignHist = _lead!.assignHistory ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2130) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Current Status",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      toTitleCase(_lead!.status),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "STATUS CHANGE HISTORY",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          statusHist.isEmpty
              ? const Text(
                  "No status changes recorded.",
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: statusHist.length,
                  itemBuilder: (context, index) {
                    final hist = statusHist[index];
                    final date = DateTimeUtils.formatSafe(hist.createdAt);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2130) : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                toTitleCase(hist.status),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                date,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          if (hist.comment != null &&
                              hist.comment!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              hist.comment!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
          const SizedBox(height: 24),
          const Text(
            "ASSIGNMENT HISTORY",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          assignHist.isEmpty
              ? const Text(
                  "No assignments recorded.",
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: assignHist.length,
                  itemBuilder: (context, index) {
                    final hist = assignHist[index];
                    final date = DateTimeUtils.formatSafe(hist.createdAt);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2130) : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Assigned to: ${hist.toUser?.name ?? 'Unassigned'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                date,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Changed by: ${hist.changedBy?.name ?? 'System'}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildTasksMeetingsTab(bool isDark) {
    final tasks = _lead!.tasks ?? [];
    final meetings = _lead!.meetings ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "PENDING TASKS",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          tasks.isEmpty
              ? const Text(
                  "No tasks assigned to this lead.",
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final date = DateTimeUtils.formatSafe(
                      task.dueDate,
                      format: 'dd MMM yyyy',
                    );
                    return Card(
                      color: isDark ? const Color(0xFF1E2130) : Colors.white,
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          task.status == 'completed'
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: task.status == 'completed'
                              ? Colors.green
                              : Colors.grey,
                        ),
                        title: Text(
                          task.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'Due: $date | Status: ${task.status}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    );
                  },
                ),
          const SizedBox(height: 24),
          const Text(
            "SCHEDULED MEETINGS",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          meetings.isEmpty
              ? const Text(
                  "No meetings scheduled.",
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: meetings.length,
                  itemBuilder: (context, index) {
                    final meeting = meetings[index];
                    final date = DateTimeUtils.formatSafe(meeting.scheduledAt);
                    return Card(
                      color: isDark ? const Color(0xFF1E2130) : Colors.white,
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.event, color: Colors.blue),
                        title: Text(
                          meeting.subject,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'Scheduled: $date | Status: ${meeting.status}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildCallLogsTab(bool isDark) {
    if (_callLogs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.phone_missed, size: 40, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                "No IVR / click-to-call logs recorded.",
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _callLogs.length,
      itemBuilder: (context, index) {
        final log = _callLogs[index];
        final start = DateTime.tryParse(log.startTime ?? '') ?? DateTime.now();
        final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(start);
        final isIncoming = log.callType == 'INCOMING';
        final statusInfo = getLeadCallConnectionStatus(log);
        final statusColor = statusInfo.color;
        final sourceInfo = _getSourceInfo(log.source);
        final simSlot = _extractSimSlot(log);
        final did = _extractDid(log);

        final agentName = log.crmUserMapped?['name'] as String?;
        final initByName = log.initiatedBy?['name'] as String?;
        String agentLine;
        if (agentName != null) {
          if (initByName != null && initByName != agentName) {
            agentLine = 'Agent: $agentName (Init by: $initByName)';
          } else {
            agentLine = 'Agent: $agentName';
          }
        } else {
          agentLine = initByName != null ? 'Agent: $initByName' : '';
        }

        final displayNumber = isIncoming
            ? (log.callerNumber.isNotEmpty ? log.callerNumber : '-')
            : (log.receiverNumber.isNotEmpty
                  ? log.receiverNumber
                  : (log.callerNumber.isNotEmpty ? log.callerNumber : '-'));

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2130) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayNumber,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusInfo.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: sourceInfo.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: sourceInfo.color.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          sourceInfo.icon,
                          size: 10,
                          color: sourceInfo.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          sourceInfo.label,
                          style: TextStyle(
                            color: sourceInfo.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: (isIncoming ? Colors.green : Colors.blue)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: (isIncoming ? Colors.green : Colors.blue)
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isIncoming ? Colors.green : Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isIncoming ? 'Incoming' : 'Outgoing',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isIncoming ? Colors.green : Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isCallConnected(log))
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: isDark ? 0.15 : 0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 11,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 3),
                          Text(
                            formatCallDuration(log.duration),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: isDark ? 0.15 : 0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_off_outlined,
                            size: 11,
                            color: Colors.red[400],
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Not Connected',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.red[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (simSlot != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: isDark ? 0.15 : 0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sim_card,
                            size: 11,
                            color: Colors.blue[600],
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'SIM $simSlot',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (did != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.call_split,
                        size: 14,
                        color: Colors.purple.shade400,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'DID',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        did,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    formattedDate,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              if (agentLine.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 12,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        agentLine,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(String title, List<Widget> items, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2130) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Column(children: items),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
