import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/whatsapp_provider.dart';
import '../../widgets/global_app_bar.dart';
import 'whatsapp_permission_guard.dart';

class WhatsAppCampaignDetailScreen extends ConsumerStatefulWidget {
  final String campaignId;

  const WhatsAppCampaignDetailScreen({
    super.key,
    required this.campaignId,
  });

  @override
  ConsumerState<WhatsAppCampaignDetailScreen> createState() => _WhatsAppCampaignDetailScreenState();
}

class _WhatsAppCampaignDetailScreenState extends ConsumerState<WhatsAppCampaignDetailScreen> {
  Map<String, dynamic>? _campaignDetails;
  List<Map<String, dynamic>> _recipientsList = [];
  bool _isLoadingDetails = false;
  bool _isLoadingRecipients = false;
  String _selectedStatusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoadingDetails = true);
    try {
      final res = await ref.read(whatsappServiceProvider).fetchCampaignDetails(widget.campaignId);
      if (res['success'] == true) {
        setState(() {
          _campaignDetails = Map<String, dynamic>.from(res['data']?['campaign'] ?? {});
        });
        _fetchRecipients();
      }
    } catch (e) {
      debugPrint('[CampaignDetails] Error fetching details: $e');
    } finally {
      setState(() => _isLoadingDetails = false);
    }
  }

  Future<void> _fetchRecipients() async {
    setState(() => _isLoadingRecipients = true);
    try {
      final statusParam = _selectedStatusFilter == 'ALL'
          ? null
          : _selectedStatusFilter.toLowerCase();
      final res = await ref.read(whatsappServiceProvider).fetchCampaignRecipients(
            widget.campaignId,
            status: statusParam,
          );
      final isSuccess = res['success'] == true || res['statusCode'] == 200;
      if (isSuccess) {
        final List<dynamic> list = res['data']?['recipients'] ?? res['data']?['data']?['recipients'] ?? [];
        setState(() {
          _recipientsList = list.map((item) => Map<String, dynamic>.from(item)).toList();
        });
      }
    } catch (e) {
      debugPrint('[CampaignDetails] Error fetching recipients: $e');
    } finally {
      setState(() => _isLoadingRecipients = false);
    }
  }

  Future<void> _triggerCampaignSend() async {
    try {
      await ref.read(whatsappCampaignsProvider.notifier).triggerCampaignSend(widget.campaignId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Campaign sending initialized!'), backgroundColor: Colors.black87),
        );
      }
      _fetchDetails();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e'), backgroundColor: Colors.grey[700]),
        );
      }
    }
  }

  Future<void> _updateCampaignStatus(String status) async {
    try {
      await ref.read(whatsappCampaignsProvider.notifier).updateCampaignStatus(widget.campaignId, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Campaign status set to $status'), backgroundColor: Colors.black87),
        );
      }
      _fetchDetails();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status update failed: $e'), backgroundColor: Colors.grey[700]),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoadingDetails && _campaignDetails == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              Text('Loading campaign...', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    final c = _campaignDetails ?? {};
    final String name = c['name'] ?? 'Campaign Audit';
    final String status = (c['status'] ?? 'DRAFT').toString().toUpperCase();
    final String templateName = c['templateName'] ?? c['template']?['name'] ?? 'Custom Message';
    final String dateStr = c['createdAt'] != null
        ? DateFormat.yMMMd().add_jm().format(DateTime.parse(c['createdAt']).toLocal())
        : '';

    final metrics = c['metrics'] as Map?;
    final int totalRecipients = c['recipientCount'] ?? c['totalRecipients'] ?? c['total'] ?? metrics?['total'] ?? _recipientsList.length;
    final int sent = c['sentCount'] ?? c['sent'] ?? metrics?['sent'] ?? 0;
    final int delivered = c['deliveredCount'] ?? c['delivered'] ?? metrics?['delivered'] ?? 0;
    final int read = c['readCount'] ?? c['read'] ?? metrics?['read'] ?? 0;
    final int failed = c['failedCount'] ?? c['failed'] ?? metrics?['failed'] ?? 0;
    final int exceeded = c['exceededCount'] ?? c['exceeded'] ?? metrics?['exceeded'] ?? 0;
    final int pending = c['pendingCount'] ?? c['pending'] ?? metrics?['pending'] ?? 0;
    final int invalid = c['invalidCount'] ?? c['invalid'] ?? metrics?['invalid'] ?? 0;
    final int rejected = c['rejectedCount'] ?? c['rejected'] ?? metrics?['rejected'] ?? 0;

    return WhatsAppPermissionGuard(
      requiredModules: const ['modules.integration', 'modules.whatsapp'],
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: const GlobalAppBar(title: 'Campaign Details', showBackButton: true),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Card ──
              _buildHeaderCard(name, status, templateName, dateStr, isDark),
              const SizedBox(height: 20),

              // ── Metrics Cards ──
              _buildMetricsGrid(totalRecipients, sent, delivered, read, failed, exceeded, pending, invalid, rejected, isDark),
              const SizedBox(height: 24),

              // ── Execution Logs ──
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "Execution Logs",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (_recipientsList.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_recipientsList.length}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // ── Filter Chips (Wrap to prevent overflow) ──
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFilterChip("ALL"),
                  _buildFilterChip("PENDING"),
                  _buildFilterChip("SENT"),
                  _buildFilterChip("DELIVERED"),
                  _buildFilterChip("READ"),
                  _buildFilterChip("FAILED"),
                  _buildFilterChip("EXCEEDED"),
                  _buildFilterChip("INVALID"),
                  _buildFilterChip("REJECTED"),
                ],
              ),
              const SizedBox(height: 16),

              // ── Recipients List ──
              _isLoadingRecipients
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    )
                  : _recipientsList.isEmpty
                      ? _buildEmptyLogs(isDark)
                      : _buildRecipientsList(isDark),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Header Card
  // ──────────────────────────────────────────────
  Widget _buildHeaderCard(String name, String status, String templateName, String dateStr, bool isDark) {
    final theme = Theme.of(context);
    final statusLabel = _statusLabel(status);
    final statusColor = _statusColor(status);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: statusColor,
                width: 4,
              ),
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusLabel,
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
              // Template + Date
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.article_rounded, size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Template: ',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      templateName,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Created: ',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      dateStr,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),
              const SizedBox(height: 16),
              // Action Buttons
              _buildActionButtons(status, isDark),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'DRAFT': return 'Draft';
      case 'SENDING': return 'Sending';
      case 'COMPLETED': return 'Completed';
      case 'PAUSED': return 'Paused';
      case 'CANCELLED': return 'Cancelled';
      default: return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'COMPLETED': return const Color(0xFF10B981);
      case 'FAILED': return const Color(0xFFEF4444);
      case 'SENDING':
      case 'SENT': return const Color(0xFF3B82F6);
      case 'SCHEDULED':
      case 'PENDING': return const Color(0xFFF97316);
      case 'DELIVERED': return const Color(0xFF10B981);
      case 'READ': return const Color(0xFF14B8A6);
      case 'EXCEEDED': return const Color(0xFF7C3AED);
      case 'INVALID': return const Color(0xFFDC2626);
      case 'REJECTED': return const Color(0xFF991B1B);
      default: return Colors.grey;
    }
  }

  Widget _buildActionButtons(String status, bool isDark) {
    final buttons = <Widget>[];

    if (status == 'DRAFT') {
      buttons.add(_buildActionBtn(
        icon: Icons.send_rounded,
        label: 'Launch Send',
        onTap: _triggerCampaignSend,
        filled: true,
      ));
    }
    if (status == 'SENDING') {
      buttons.add(_buildActionBtn(
        icon: Icons.pause_rounded,
        label: 'Pause',
        onTap: () => _updateCampaignStatus('PAUSED'),
        filled: true,
      ));
    }
    if (status == 'PAUSED') {
      buttons.add(_buildActionBtn(
        icon: Icons.play_arrow_rounded,
        label: 'Resume',
        onTap: _triggerCampaignSend,
        filled: true,
      ));
    }
    if (status == 'SENDING' || status == 'PAUSED') {
      buttons.add(_buildActionBtn(
        icon: Icons.cancel_outlined,
        label: 'Cancel',
        onTap: () => _updateCampaignStatus('CANCELLED'),
        filled: false,
      ));
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: buttons,
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool filled,
  }) {
    return Material(
      color: filled ? Colors.black87 : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: filled
              ? null
              : BoxDecoration(
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(8),
                ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: filled ? Colors.white : Colors.grey[700]),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: filled ? Colors.white : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Metrics Grid
  // ──────────────────────────────────────────────
  Widget _buildMetricsGrid(int total, int sent, int delivered, int read, int failed, int exceeded, int pending, int invalid, int rejected, bool isDark) {
    final metrics = [
      ('TOTAL', total, const Color(0xFF64748B)),
      ('SENT', sent, const Color(0xFF3B82F6)),
      ('DELIVERED', delivered, const Color(0xFF10B981)),
      ('READ', read, const Color(0xFF14B8A6)),
      ('FAILED', failed, const Color(0xFFEF4444)),
      ('PENDING', pending, const Color(0xFFF97316)),
      ('EXCEEDED', exceeded, const Color(0xFF7C3AED)),
      ('INVALID', invalid, const Color(0xFFDC2626)),
      ('REJECTED', rejected, const Color(0xFF991B1B)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width < 400 ? 2 : (width < 600 ? 3 : 4);
        final childAspectRatio = width < 400 ? 1.45 : 1.35;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, i) {
            final m = metrics[i];
            return _buildMetricCard(m.$1, m.$2, m.$3, isDark);
          },
        );
      },
    );
  }

  Widget _buildMetricCard(String label, int value, Color accentColor, bool isDark) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9, color: accentColor, fontWeight: FontWeight.w700, letterSpacing: 0.3),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Filter Chips
  // ──────────────────────────────────────────────
  Widget _buildFilterChip(String label) {
    final isSelected = _selectedStatusFilter == label;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isSelected ? Colors.black87 : (isDark ? Colors.grey[800] : Colors.grey[100]),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() => _selectedStatusFilter = label);
          _fetchRecipients();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? null
                : Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Icon(Icons.check_rounded, size: 14, color: Colors.white),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Empty State
  // ──────────────────────────────────────────────
  Widget _buildEmptyLogs(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inbox_rounded, size: 28, color: isDark ? Colors.grey[500] : Colors.grey[400]),
          ),
          const SizedBox(height: 14),
          Text(
            "No matching logs found",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            "Try changing the filter or check back later.",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Recipients List
  // ──────────────────────────────────────────────
  Widget _buildRecipientsList(bool isDark) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_recipientsList.length, (idx) {
            final log = _recipientsList[idx];
            final String rName = log['name'] ?? log['recipientName'] ?? 'Recipient';
            final String rPhone = log['phone'] ?? log['recipientPhone'] ?? log['phoneNo'] ?? '';
            final String rStatus = (log['status'] ?? 'pending').toString().toUpperCase();
            final errorMsg = log['error']?['message'] ?? log['errorMessage'] ?? log['failureReason'] ?? log['errorLog'] ?? '';

            final statusColor = _statusColor(rStatus);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (idx > 0) Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[100]),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                rName.isNotEmpty ? rName[0].toUpperCase() : '?',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: statusColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(rName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text(
                                  rPhone,
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(rStatus, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor)),
                          ),
                        ],
                      ),
                      if (errorMsg.isNotEmpty && errorMsg.toString().trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.error_outline, size: 14, color: Colors.red.shade400),
                              const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '$errorMsg',
                                      style: TextStyle(fontSize: 11, color: Colors.red.shade700, height: 1.3),
                                      softWrap: true,
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
