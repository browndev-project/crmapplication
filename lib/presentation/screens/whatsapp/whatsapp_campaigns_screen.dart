import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/whatsapp_provider.dart';
import 'whatsapp_campaign_detail_screen.dart';
import '../../widgets/global_app_bar.dart';
import 'whatsapp_permission_guard.dart';
import 'widgets/whatsapp_icon.dart';

class WhatsAppCampaignsScreen extends ConsumerStatefulWidget {
  const WhatsAppCampaignsScreen({super.key});

  @override
  ConsumerState<WhatsAppCampaignsScreen> createState() => _WhatsAppCampaignsScreenState();
}

class _WhatsAppCampaignsScreenState extends ConsumerState<WhatsAppCampaignsScreen> {
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(whatsappCampaignsProvider.notifier).fetchCampaigns();
      ref.read(whatsappCampaignsProvider.notifier).fetchMessagingLimit();
    });

    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final campState = ref.read(whatsappCampaignsProvider);
      final hasProcessing = campState.campaigns.any((c) {
        final status = (c['status'] ?? '').toString().toUpperCase();
        return status == 'PROCESSING' || status == 'PENDING' || status == 'SENDING';
      });
      if (hasProcessing && mounted) {
        ref.read(whatsappCampaignsProvider.notifier).fetchCampaignsSilent();
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final campState = ref.watch(whatsappCampaignsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final int capLimit = campState.limits['messagingLimit'] ?? 1000;
    final int todaySent = campState.limits['messagesToday'] ?? 0;
    final int remaining = campState.limits['remaining'] ?? (capLimit - todaySent);

    return WhatsAppPermissionGuard(
      requiredModules: const ['modules.integration', 'modules.whatsapp'],
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: const GlobalAppBar(title: 'WhatsApp Marketing'),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  whatsAppIcon(size: 26, color: const Color(0xFF25D366)),
                  const SizedBox(width: 8),
                  const Text("WhatsApp Marketing", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Text("Manage and track your WhatsApp bulk campaigns.", style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref.read(whatsappCampaignsProvider.notifier).fetchCampaigns();
                        ref.read(whatsappCampaignsProvider.notifier).fetchMessagingLimit();
                      },
                      icon: const Icon(Icons.refresh, size: 16, color: Colors.black),
                      label: const Text("REFRESH", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.black26),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.of(context).pushNamed('/dashboard/whatsapp/campaigns/create');
                        if (mounted) {
                          ref.read(whatsappCampaignsProvider.notifier).fetchCampaigns();
                          ref.read(whatsappCampaignsProvider.notifier).fetchMessagingLimit();
                        }
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text("NEW CAMPAIGN", style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Daily Limit Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text("Daily Messaging Limit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _showLimitEditorDialog(context, capLimit, isDark),
                                  child: Icon(Icons.edit, size: 14, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Resets on ${DateFormat('MMM d, yyyy').format(DateTime.now().add(const Duration(days: 1)))} 12:00 AM",
                              style: const TextStyle(fontSize: 11, color: Colors.blue),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("TOTAL LIMIT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                              const SizedBox(height: 4),
                              Text(capLimit.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("TODAY'S USAGE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                              const SizedBox(height: 4),
                              Text(todaySent.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("REMAINING", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                              const SizedBox(height: 4),
                              Text(remaining.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Campaigns List
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: "Search campaigns...",
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: () {
                            ref.read(whatsappCampaignsProvider.notifier).fetchCampaigns();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(12),
                            side: const BorderSide(color: Colors.black26),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          child: const Icon(Icons.refresh, color: Colors.black, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (campState.isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (campState.error != null)
                      Center(child: Text(campState.error!, style: const TextStyle(color: Colors.red)))
                    else if (campState.campaigns.isEmpty)
                      Center(
                        child: Text(
                          "No campaigns found. Create your first campaign to get started!",
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: campState.campaigns.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _buildCampaignCard(context, isDark, campState.campaigns[index]);
                        },
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCampaignCard(BuildContext context, bool isDark, Map<String, dynamic> c) {
    final String id = c['_id'] ?? c['id'] ?? '';
    final String name = c['name'] ?? 'Untitled Campaign';
    final String status = (c['status'] ?? 'DRAFT').toString().toUpperCase();
    final String source = c['recipientSource'] ?? 'leads';
    final String sourceLabel = source == 'excel' ? 'From Excel' : 'From leads';

    final String createdDate = c['createdAt'] != null
        ? 'Created: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(c['createdAt']).toLocal())}'
        : '';

    String? scheduledDate;
    if (c['scheduledAt'] != null && c['scheduledAt'].toString().isNotEmpty) {
      try {
        scheduledDate = 'Scheduled: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(c['scheduledAt']).toLocal())}';
      } catch (_) {}
    }

    final int recipients = c['recipientCount'] ?? c['totalRecipients'] ?? 0;
    final int sent = c['sentCount'] ?? c['sent'] ?? 0;
    final int delivered = c['deliveredCount'] ?? c['delivered'] ?? 0;
    final int read = c['readCount'] ?? c['read'] ?? 0;
    final int failed = c['failedCount'] ?? c['failed'] ?? 0;

    final createdBy = c['createdBy'];
    final String creatorName = createdBy is Map
        ? (createdBy['name'] ?? 'Unknown')
        : (createdBy?.toString() ?? 'Unknown');

    Color statusColor;
    String displayStatus;
    switch (status) {
      case 'COMPLETED':
        statusColor = const Color(0xFF10B981);
        displayStatus = 'Completed';
        break;
      case 'SENDING':
      case 'RUNNING':
        statusColor = const Color(0xFF3B82F6);
        displayStatus = 'Running';
        break;
      case 'SCHEDULED':
        statusColor = const Color(0xFFF59E0B);
        displayStatus = 'Scheduled';
        break;
      case 'FAILED':
        statusColor = const Color(0xFFEF4444);
        displayStatus = 'Failed';
        break;
      case 'PAUSED':
        statusColor = Colors.amber;
        displayStatus = 'Paused';
        break;
      case 'CANCELLED':
        statusColor = Colors.red;
        displayStatus = 'Cancelled';
        break;
      default:
        statusColor = Colors.grey;
        displayStatus = status;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2130) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WhatsAppCampaignDetailScreen(campaignId: id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Name + Solid Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      displayStatus,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Source label in teal
              Text(
                sourceLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF14B8A6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),

              // Created date
              if (createdDate.isNotEmpty)
                Text(createdDate, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              if (scheduledDate != null)
                Text(scheduledDate, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              const SizedBox(height: 12),

              // Stats Row: label on top, number below
              Row(
                children: [
                  _buildStatItem('Recipients', recipients, isDark),
                  const SizedBox(width: 20),
                  _buildStatItem('Sent', sent, isDark),
                  const SizedBox(width: 20),
                  _buildStatItem('Delivered', delivered, isDark),
                  const SizedBox(width: 20),
                  _buildStatItem('Read', read, isDark),
                  const SizedBox(width: 20),
                  _buildStatItem('Failed', failed, isDark),
                ],
              ),
              const SizedBox(height: 10),

              // Created By + Action Icons
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'Created by $creatorName',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WhatsAppCampaignDetailScreen(campaignId: id),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.visibility_outlined, size: 18, color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _confirmDeleteCampaign(context, id, name),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  void _confirmDeleteCampaign(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Campaign'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.black87)),
          ),
          TextButton(
            onPressed: () {
              ref.read(whatsappCampaignsProvider.notifier).deleteCampaign(id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showLimitEditorDialog(BuildContext context, int currentLimit, bool isDark) {
    final TextEditingController limitCtrl = TextEditingController(text: '$currentLimit');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E2130) : Colors.white,
          title: const Text("Edit Meta Daily Send Limit", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: limitCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Daily Cap',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL"),
            ),
            ElevatedButton(
              onPressed: () {
                final int? val = int.tryParse(limitCtrl.text);
                if (val != null && val > 0) {
                  ref.read(whatsappCampaignsProvider.notifier).updateMessagingLimit(val);
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.blue : Colors.black),
              child: const Text("SAVE", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
