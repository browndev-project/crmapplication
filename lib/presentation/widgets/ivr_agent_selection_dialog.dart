import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/lead_provider.dart';

class IvrAgentSelectionDialog extends ConsumerStatefulWidget {
  final String leadId;
  final Function(String agentId) onAgentSelected;

  const IvrAgentSelectionDialog({
    super.key,
    required this.leadId,
    required this.onAgentSelected,
  });

  @override
  ConsumerState<IvrAgentSelectionDialog> createState() => _IvrAgentSelectionDialogState();
}

class _IvrAgentSelectionDialogState extends ConsumerState<IvrAgentSelectionDialog> {
  List<dynamic> _agents = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchIvrAgents());
  }

  Future<void> _fetchIvrAgents() async {
    try {
      final leadService = ref.read(leadServiceProvider);
      final config = await leadService.getIvrConfig();
      final agentsList = config['agents'] as List<dynamic>?;
      if (mounted) {
        setState(() {
          _agents = agentsList ?? [];
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E2130) : Colors.white,
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.phone_callback_rounded,
                  color: isDark ? Colors.blueAccent : const Color(0xFF4F46E5),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Select IVR Call Agent",
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
            const SizedBox(height: 8),
            Text(
              "Select an active telephony agent below to bridge the outbound connection.",
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: CircularProgressIndicator(
                    color: Color(0xFF4F46E5),
                  ),
                ),
              )
            else if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        "Error: $_error",
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _error = null;
                          });
                          _fetchIvrAgents();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text("Retry"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                        ),
                      )
                    ],
                  ),
                ),
              )
            else if (_agents.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Column(
                    children: [
                      Icon(Icons.phone_disabled_rounded, color: isDark ? Colors.white30 : Colors.black38, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        "No active telephony agents mapped",
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _agents.length,
                  itemBuilder: (context, index) {
                    final agent = _agents[index] as Map<String, dynamic>;
                    final name = agent['name'] ?? 'Unknown Agent';
                    final extension = agent['ivrExtension'] ?? 'N/A';
                    final did = agent['assignedDid'] ?? 'N/A';
                    final ivrAgentId = agent['ivrAgentId'] ?? '';
                    final mongoId = agent['_id'] ?? '';
                    
                    // CRM Mapped User detail
                    String? crmUserName;
                    if (agent['crmUser'] is Map<String, dynamic>) {
                      crmUserName = agent['crmUser']['name'] as String?;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[200]!,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: isDark ? const Color(0xFF3F3B85) : const Color(0xFFEEF2FF),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: isDark ? const Color(0xFFC7D2FE) : const Color(0xFF4F46E5),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.blueAccent.withValues(alpha: 0.15) : const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      "Ext: $extension",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.blue[300] : const Color(0xFF1D4ED8),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    "DID: $did",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white54 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                              if (crmUserName != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  "CRM Mapped: $crmUserName",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
                        onTap: () {
                          final targetId = mongoId.isNotEmpty ? mongoId : ivrAgentId;
                          widget.onAgentSelected(targetId);
                        },
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? Colors.white70 : Colors.black54,
                  ),
                  child: const Text(
                    "CANCEL",
                    style: TextStyle(fontWeight: FontWeight.w600),
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
