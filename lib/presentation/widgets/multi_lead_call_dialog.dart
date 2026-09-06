import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/lead_model.dart';
import '../providers/constants_provider.dart';
import '../providers/lead_provider.dart';
import 'lead_status_update_dialog.dart';

class MultiLeadCallDialog extends ConsumerStatefulWidget {
  final List<Lead> leads;
  final Future<void> Function(Lead lead) onCallLead;

  const MultiLeadCallDialog({
    super.key,
    required this.leads,
    required this.onCallLead,
  });

  @override
  ConsumerState<MultiLeadCallDialog> createState() => _MultiLeadCallDialogState();
}

class _MultiLeadCallDialogState extends ConsumerState<MultiLeadCallDialog> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final Set<String> _calledLeadIds = {};
  late List<Lead> _currentLeads;
  bool _isCalling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentLeads = List<Lead>.from(widget.leads);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check if all calls completed after user returns from system dialer
      _checkIfAllCallsDone();
    }
  }

  void _checkIfAllCallsDone() {
    if (_calledLeadIds.length >= _currentLeads.length && mounted) {
      // All calls completed - auto-close popup with slight delay for smooth transition
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All selected leads have been called successfully!'),
              backgroundColor: Color(0xFF16A34A),
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.of(context).pop(true);
        }
      });
    }
  }

  Future<void> _handleClose() async {
    if (_calledLeadIds.length < _currentLeads.length) {
      final shouldClose = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Incomplete Calling',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            content: Text(
              'You did not complete call on all ${_currentLeads.length} leads (${_calledLeadIds.length}/${_currentLeads.length} called).\n\nAre you sure you want to close this dialog?',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep Calling', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Close Anyway', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
      if (shouldClose == true && mounted) {
        Navigator.of(context).pop(false);
      }
    } else {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  Future<void> _callCurrentLead(Lead lead) async {
    setState(() => _isCalling = true);
    try {
      await widget.onCallLead(lead);
      if (mounted) {
        setState(() {
          _calledLeadIds.add(lead.id);
        });
        _checkIfAllCallsDone();
      }
    } finally {
      if (mounted) {
        setState(() => _isCalling = false);
      }
    }
  }

  Future<void> _updateLeadStatus(Lead lead) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => LeadStatusUpdateDialog(lead: lead),
    );

    if (updated == true && mounted) {
      ref.read(leadsProvider.notifier).refresh();
      // Update local lead in list
      final allLeads = ref.read(leadsProvider).leads;
      try {
        final refreshedLead = allLeads.firstWhere((l) => l.id == lead.id);
        setState(() {
          _currentLeads[_currentIndex] = refreshedLead;
        });
      } catch (_) {}
    }
  }

  void _nextLead() {
    if (_currentIndex < _currentLeads.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      // Last lead reached
      if (_calledLeadIds.length >= _currentLeads.length) {
        Navigator.of(context).pop(true);
      } else {
        // _handleClose(context);
        _handleClose();
      }
    }
  }

  String _toTitleCase(String text) {
    if (text.trim().isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.trim().isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Color _getStatusBg(String status, bool isDark) {
    final lower = status.toLowerCase();
    if (lower == 'new') return isDark ? Colors.blue.withValues(alpha: 0.15) : const Color(0xFFEFF6FF);
    if (lower == 'hot' || lower == 'lost') return isDark ? Colors.red.withValues(alpha: 0.15) : const Color(0xFFFEF2F2);
    if (lower == 'warm' || lower.contains('follow')) return isDark ? Colors.orange.withValues(alpha: 0.15) : const Color(0xFFFFF7ED);
    if (lower.contains('converted') || lower.contains('won')) return isDark ? Colors.green.withValues(alpha: 0.15) : const Color(0xFFF0FDF4);
    return isDark ? Colors.grey.withValues(alpha: 0.15) : Colors.grey[100]!;
  }

  Color _getStatusTextColor(String status, bool isDark) {
    final lower = status.toLowerCase();
    if (lower == 'new') return isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
    if (lower == 'hot' || lower == 'lost') return isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);
    if (lower == 'warm' || lower.contains('follow')) return isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C);
    if (lower.contains('converted') || lower.contains('won')) return isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D);
    return isDark ? Colors.grey[300]! : Colors.grey[800]!;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final constants = ref.watch(constantsProvider).value;

    if (_currentLeads.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentLead = _currentLeads[_currentIndex];
    final isCalled = _calledLeadIds.contains(currentLead.id);
    final totalLeads = _currentLeads.length;
    final isLastLead = _currentIndex == totalLeads - 1;

    final statusBg = _getStatusBg(currentLead.status, isDark);
    final statusTextColor = _getStatusTextColor(currentLead.status, isDark);

    // Accent color based on pipeline / status
    Color accentColor = const Color(0xFF2563EB);
    final lowerPipeline = currentLead.pipeline.toLowerCase();
    if (lowerPipeline == 'hot') {
      accentColor = const Color(0xFFEF4444);
    } else if (lowerPipeline == 'warm') {
      accentColor = const Color(0xFFF97316);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // _handleClose(context);
          _handleClose();
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.phone_in_talk_rounded,
                        color: Color(0xFF16A34A),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Calling Leads',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Lead ${_currentIndex + 1} of $totalLeads',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Counter Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.grey[300]!,
                        ),
                      ),
                      child: Text(
                        '${_calledLeadIds.length}/$totalLeads Called',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _calledLeadIds.length == totalLeads
                              ? const Color(0xFF16A34A)
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? Colors.white70 : Colors.black54,
                        size: 22,
                      ),
                      // onPressed: () => _handleClose(context),
                      onPressed: _handleClose,
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),

              // Progress indicator line
              ClipRRect(
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / totalLeads,
                  backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _calledLeadIds.length == totalLeads ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                  ),
                  minHeight: 3,
                ),
              ),

              // Step indicator dots / stepper
              if (totalLeads > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(totalLeads, (index) {
                      final lead = _currentLeads[index];
                      final isCurrent = index == _currentIndex;
                      final isLeadCalled = _calledLeadIds.contains(lead.id);

                      return InkWell(
                        onTap: () => setState(() => _currentIndex = index),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: EdgeInsets.symmetric(
                            horizontal: isCurrent ? 8 : 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? const Color(0xFF2563EB)
                                : (isLeadCalled
                                    ? (isDark ? const Color(0xFF16A34A).withValues(alpha: 0.2) : const Color(0xFFDCFCE7))
                                    : (isDark ? Colors.white10 : Colors.grey[200])),
                            borderRadius: BorderRadius.circular(10),
                            border: isCurrent
                                ? null
                                : (isLeadCalled
                                    ? Border.all(color: const Color(0xFF16A34A), width: 1)
                                    : null),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isLeadCalled) ...[
                                Icon(
                                  Icons.check,
                                  size: 11,
                                  color: isCurrent ? Colors.white : const Color(0xFF16A34A),
                                ),
                                const SizedBox(width: 2),
                              ],
                              Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                  color: isCurrent
                                      ? Colors.white
                                      : (isLeadCalled
                                          ? (isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D))
                                          : (isDark ? Colors.white60 : Colors.black54)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),

              // 2. Lead Detail Card
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[200]!,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar + Name + Phone Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: isDark ? 0.2 : 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _getInitials(currentLead.name),
                              style: TextStyle(
                                color: isDark ? Colors.white : accentColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentLead.name.isNotEmpty ? currentLead.name : 'Unknown Lead',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : Colors.black87,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.phone_outlined,
                                      size: 14,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      currentLead.phoneNo.isNotEmpty ? currentLead.phoneNo : 'No phone',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white70 : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Status & Pipeline & Called Badges Row
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _toTitleCase(currentLead.status.isEmpty ? 'New' : currentLead.status),
                              style: TextStyle(
                                color: statusTextColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),

                          // Pipeline Stage Badge
                          if (currentLead.pipeline.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                constants != null
                                    ? constants.getPipelineLabel(currentLead.pipeline)
                                    : _toTitleCase(currentLead.pipeline),
                                style: TextStyle(
                                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),

                          // Called Status Badge
                          if (isCalled)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF16A34A).withValues(alpha: 0.2)
                                    : const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF16A34A), width: 0.8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, size: 12, color: Color(0xFF16A34A)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Called',
                                    style: TextStyle(
                                      color: Color(0xFF16A34A),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      // Optional metadata details (omitted if missing or "not added yet")
                      _buildMetadataGrid(currentLead, isDark),
                    ],
                  ),
                ),
              ),

              // 3. Action Buttons in Column (1. Update Status, 2. Call, 3. Next)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Button 1: Update Status
                    OutlinedButton.icon(
                      onPressed: () => _updateLeadStatus(currentLead),
                      icon: const Icon(Icons.edit_note_rounded, size: 20),
                      label: const Text(
                        'Update Status',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.5) : const Color(0xFF2563EB),
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Button 2: Call
                    ElevatedButton.icon(
                      onPressed: _isCalling ? null : () => _callCurrentLead(currentLead),
                      icon: _isCalling
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.call_rounded, size: 20),
                      label: Text(
                        isCalled ? 'Call Again' : 'Call',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Button 3: Next / Finish
                    ElevatedButton.icon(
                      onPressed: _nextLead,
                      icon: Icon(
                        isLastLead ? Icons.check_circle_outline_rounded : Icons.arrow_forward_rounded,
                        size: 18,
                      ),
                      label: Text(
                        isLastLead ? 'Finish' : 'Next',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                        foregroundColor: isDark ? Colors.white : Colors.black87,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataGrid(Lead lead, bool isDark) {
    final chips = <Widget>[];

    // final serviceName = lead.service?.name?.trim();
    final serviceName = lead.service?.name.trim();
    if (serviceName != null && serviceName.isNotEmpty && !serviceName.toLowerCase().contains('not added')) {
      chips.add(_buildMetaChip(Icons.business_center_outlined, serviceName, isDark));
    }

    // final city = lead.city?.trim();
    final city = (lead.address?.city != null && lead.address!.city.trim().isNotEmpty)
        ? lead.address!.city.trim()
        : (lead.destination != null && lead.destination!.trim().isNotEmpty ? lead.destination!.trim() : null);
    if (city != null && city.isNotEmpty && !city.toLowerCase().contains('not added')) {
      chips.add(_buildMetaChip(Icons.location_on_outlined, city, isDark));
    }

    // final project = lead.project?.title?.trim();
    final project = lead.project?.name.trim();
    if (project != null && project.isNotEmpty && !project.toLowerCase().contains('not added')) {
      chips.add(_buildMetaChip(Icons.apartment_rounded, project, isDark));
    }

    // final assignedTo = lead.assignedTo?.name?.trim();
    final assignedTo = lead.assignedTo?.name.trim();
    if (assignedTo != null && assignedTo.isNotEmpty) {
      chips.add(_buildMetaChip(Icons.person_outline, 'Assigned: $assignedTo', isDark));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: chips,
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey[300]!,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: isDark ? Colors.white60 : Colors.black54),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white70 : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
