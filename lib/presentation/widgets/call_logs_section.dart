import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/lead_provider.dart';
import '../providers/login_provider.dart';
import '../providers/permissions_provider.dart';
import 'audio_player_widget.dart';
import '../../core/constants/permission_constants.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/call_log_model.dart';
import 'lead_calls_helper.dart';
import '../../core/services/call_logger_service.dart';

String? _extractDid(CallLog log) {
  // Check ivr map with various key formats
  if (log.ivr case Map<String, dynamic> ivr) {
    final did =
        ivr['didNumber'] ??
        ivr['did'] ??
        ivr['DIDNumber'] ??
        ivr['did_number'] ??
        ivr['DidNumber'] ??
        ivr['DID'] ??
        ivr['didNumber'];
    if (did != null && did.toString().isNotEmpty) return did.toString();
  }
  // Check if ivr is a string (some APIs return JSON string)
  if ((log.ivr as dynamic) case String ivrStr) {
    try {
      final decoded = jsonDecode(ivrStr);
      if (decoded is Map<String, dynamic>) {
        final did =
            decoded['didNumber'] ??
            decoded['did'] ??
            decoded['DIDNumber'] ??
            decoded['did_number'];
        if (did != null && did.toString().isNotEmpty) return did.toString();
      }
    } catch (_) {}
  }
  // Check callDetails array
  if (log.callDetails case List<dynamic> details) {
    for (final d in details) {
      if (d is Map<String, dynamic>) {
        final did =
            d['didNumber'] ??
            d['did'] ??
            d['DIDNumber'] ??
            d['did_number'] ??
            d['DidNumber'] ??
            d['DID'] ??
            d['didNumber'];
        if (did != null && did.toString().isNotEmpty) return did.toString();
      }
    }
  }
  // Check root level fields
  final rootDid =
      log.toJson()['didNumber'] ??
      log.toJson()['did'] ??
      log.toJson()['DIDNumber'];
  if (rootDid != null && rootDid.toString().isNotEmpty) {
    return rootDid.toString();
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

  // Check callDetails array for simSlot
  if (log.callDetails case List<dynamic> details) {
    for (final d in details) {
      if (d is Map<String, dynamic>) {
        final sim =
            d['simSlot'] ??
            d['sim'] ??
            d['simSlotIndex'] ??
            d['simNumber'] ??
            d['SimSlot'] ??
            d['SIM'] ??
            d['sim_slot'] ??
            d['sim_card'];
        final normalized = normalizeSim(sim);
        if (normalized != null) return normalized;
      }
    }
  }
  // Check ivr map
  if (log.ivr case Map<String, dynamic> ivr) {
    final sim =
        ivr['simSlot'] ??
        ivr['sim'] ??
        ivr['simSlotIndex'] ??
        ivr['simNumber'] ??
        ivr['SimSlot'] ??
        ivr['SIM'] ??
        ivr['sim_slot'] ??
        ivr['sim_card'];
    final normalized = normalizeSim(sim);
    if (normalized != null) return normalized;
  }
  // Check if ivr is a string
  if ((log.ivr as dynamic) case String ivrStr) {
    try {
      final decoded = jsonDecode(ivrStr);
      if (decoded is Map<String, dynamic>) {
        final sim =
            decoded['simSlot'] ??
            decoded['sim'] ??
            decoded['simSlotIndex'] ??
            decoded['simNumber'];
        final normalized = normalizeSim(sim);
        if (normalized != null) return normalized;
      }
    } catch (_) {}
  }
  // Check root level
  final rootSim =
      log.toJson()['simSlot'] ??
      log.toJson()['sim'] ??
      log.toJson()['simSlotIndex'];
  final normalized = normalizeSim(rootSim);
  if (normalized != null) return normalized;
  return null;
}



class SourceInfo {
  final String label;
  final Color color;
  final IconData icon;
  const SourceInfo(this.label, this.color, this.icon);
}

SourceInfo _getSourceInfo(String? source) {
  final s = source?.toUpperCase() ?? '';
  if (s.contains('IVR')) {
    return const SourceInfo('IVR Solutions', Colors.purple, Icons.phone);
  }
  if (s.contains('WEB')) {
    return const SourceInfo('Web', Colors.orange, Icons.laptop_mac);
  }
  if (s.contains('APP')) {
    return const SourceInfo('App', Colors.teal, Icons.smartphone);
  }
  return SourceInfo(source ?? 'Unknown', Colors.grey, Icons.call);
}

class CallLogsSection extends ConsumerStatefulWidget {
  final String leadId;
  const CallLogsSection({super.key, required this.leadId});

  @override
  ConsumerState<CallLogsSection> createState() => _CallLogsSectionState();
}

class _CallLogsSectionState extends ConsumerState<CallLogsSection> {
  StreamSubscription<String>? _webhookSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(callLogsProvider.notifier).fetchCallLogs(widget.leadId);
      }
    });

    // Refresh call logs list when webhook event indicates a call log is stored
    _webhookSubscription = CallLoggerService.webhookSentStream.listen((_) {
      if (mounted) {
        ref.read(callLogsProvider.notifier).fetchCallLogs(widget.leadId);
      }
    });
  }

  @override
  void dispose() {
    _webhookSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logsState = ref.watch(callLogsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userRole = ref.watch(loginProvider).user?.systemRole;
    final permissions = ref.watch(permissionsProvider);
    final canPlay = permissions.hasPermission(
      PermissionModules.LEADS_CALL_PLAY,
      userRole: userRole,
    );
    final canDownload = permissions.hasPermission(
      PermissionModules.LEADS_CALL_DOWNLOAD,
      userRole: userRole,
    );

    final logs = logsState.logs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.blue.withValues(alpha: 0.2)
                        : Colors.blue[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.call, color: Colors.blue, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  'Call Logs',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            if (logs.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white10
                      : Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Total: ${logsState.totalCount}',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white70
                        : Theme.of(context).textTheme.bodyMedium?.color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (logsState.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (logsState.error != null)
          Text(
            'Error loading logs: ${logsState.error}',
            style: const TextStyle(color: Colors.red),
          )
        else if (logs.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1E1E)
                  : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white10 : Theme.of(context).dividerColor,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.history,
                  size: 48,
                  color: isDark
                      ? Colors.white12
                      : Theme.of(context).disabledColor,
                ),
                const SizedBox(height: 8),
                Text(
                  "No call logs found",
                  style: TextStyle(
                    color: isDark
                        ? Colors.white38
                        : Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          )
        else
          NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              if (scrollInfo.metrics.pixels >=
                  scrollInfo.metrics.maxScrollExtent - 200) {
                ref.read(callLogsProvider.notifier).loadMore(widget.leadId);
              }
              return false;
            },
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == logs.length) {
                  if (logsState.isLoadingMore) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  if (logsState.currentPage >= logsState.totalPages &&
                      logs.isNotEmpty) {
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
                              "All calls loaded",
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return const SizedBox(height: 16);
                }

                final log = logs[index];
                final connected = isLeadCallConnected(log);
                final activeDuration = getLeadCallDuration(log);
                final callDate =
                    DateTimeUtils.parseSafe(log.startTime) ??
                    DateTimeUtils.parseSafe(log.createdAt);
                final isIncoming = log.callType == 'INCOMING';
                final statusInfo = getLeadCallConnectionStatus(log);
                final statusColor = statusInfo.color;

                // Agent display logic
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

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1E1E)
                        : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white10
                          : Theme.of(context).dividerColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Line 1: Phone number + Info icon
                      Row(
                        children: [
                          Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isIncoming
                                  ? (log.callerNumber )
                                  : (log.receiverNumber ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                _showCallInfo(context, log, isDark),
                            icon: Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Colors.grey[500],
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Call details',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Line 2: Badges (wrapped)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          // Source badge
                          Builder(
                            builder: (context) {
                              final srcInfo = _getSourceInfo(log.source);
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: srcInfo.color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: srcInfo.color.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      srcInfo.icon,
                                      size: 10,
                                      color: srcInfo.color,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      srcInfo.label,
                                      style: TextStyle(
                                        color: srcInfo.color,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          // Direction badge (pill)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: (isIncoming ? Colors.green : Colors.blue)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
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
                                    color: isIncoming
                                        ? Colors.green
                                        : Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isIncoming ? 'Incoming' : 'Outgoing',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isIncoming
                                        ? Colors.green
                                        : Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Duration badge (only for connected calls)
                          if (connected) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 
                                  isDark ? 0.15 : 0.08,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.grey.withValues(alpha: 0.4),
                                ),
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
                                    formatCallDuration(activeDuration),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 
                                  isDark ? 0.15 : 0.08,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.3),
                                ),
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
                          ],
                          // SIM badge
                          ...switch (_extractSimSlot(log)) {
                            String sim => [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 
                                    isDark ? 0.15 : 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.blue.withValues(alpha: 0.3),
                                  ),
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
                                      'SIM $sim',
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
                            _ => [],
                          },
                        ],
                      ),
                      ...switch (_extractDid(log)) {
                        String did => [
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white10
                                  : const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white10
                                    : Colors.grey.shade200,
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
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        _ => [],
                      },
                      const SizedBox(height: 10),

                      // Status line
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusInfo.label,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Date + Agent line
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            callDate != null
                                ? DateFormat(
                                    'dd MMM yyyy, hh:mm a',
                                  ).format(callDate.toLocal())
                                : '-',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
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
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Recording sub-card
                      if (log.recordingUrl != null &&
                          log.recordingUrl!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top row: Recording label + download
                              Row(
                                children: [
                                  Icon(
                                    Icons.play_circle_outline,
                                    size: 16,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Recording Available',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (canDownload) ...[
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Downloading recording...',
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.download,
                                        size: 14,
                                      ),
                                      label: const Text(
                                        'Download',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.blue,
                                        side: BorderSide(
                                          color: Colors.blue.withValues(alpha: 0.3),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (canPlay) ...[
                                const SizedBox(height: 8),
                                AudioPlayerWidget(url: log.recordingUrl!),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _showCallInfo(BuildContext context, dynamic log, bool isDark) {
    final sourceLabel = _getSourceInfo(log.source).label;
    final simSlot = _extractSimSlot(log);

    String callerSourceInfo;
    if (simSlot != null) {
      callerSourceInfo = 'SIM $simSlot - ${log.callerNumber ?? '-'}';
    } else if (sourceLabel == 'IVR Solutions') {
      callerSourceInfo =
          'IVR - ${log.callerNumber ?? log.ivr?['callerNumber'] ?? '-'}';
    } else if (sourceLabel == 'Web') {
      callerSourceInfo = 'Web Call - ${log.callerNumber ?? '-'}';
    } else if (sourceLabel == 'App') {
      callerSourceInfo = 'App Call - ${log.callerNumber ?? '-'}';
    } else {
      callerSourceInfo = '${log.callerNumber ?? '-'}';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Call Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _infoRow('Call ID', log.id, isDark),
            _infoRow('Status', formatCallStatus(log.status), isDark),
            _infoRow('Source', sourceLabel, isDark),
            _infoRow('Type', log.callType, isDark),
            _infoRow(
              'Duration',
              formatCallDuration(log.duration),
              isDark,
            ),
            _infoRow('Caller', callerSourceInfo, isDark),
            _infoRow('Receiver', log.receiverNumber ?? '-', isDark),
            if (simSlot != null) _infoRow('SIM Slot', 'SIM $simSlot', isDark),
            if (_extractDid(log) != null)
              _infoRow('DID Number', _extractDid(log)!, isDark),
            if (log.ivr?['callId'] != null)
              _infoRow('IVR Call ID', '${log.ivr!['callId']}', isDark),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
