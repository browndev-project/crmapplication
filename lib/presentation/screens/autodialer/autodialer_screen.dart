import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/autodialer_provider.dart';
import '../../widgets/global_app_bar.dart';

class AutoDialerScreen extends ConsumerStatefulWidget {
  const AutoDialerScreen({super.key});

  @override
  ConsumerState<AutoDialerScreen> createState() => _AutoDialerScreenState();
}

class _AutoDialerScreenState extends ConsumerState<AutoDialerScreen> with WidgetsBindingObserver {
  late TextEditingController _notesController;

  static const List<String> _callResultOptions = [
    'Connected',
    'Not Connected',
    'No Answer',
    'Busy',
    'Wrong Number',
    'Qualified',
    'Unqualified',
  ];

  static const List<String> _coldLeadStatusOptions = [
    'New',
    'Connected',
    'Not Connected',
    'Invalid',
    'Qualified',
    'Unqualified',
  ];

  static const List<String> _leadStatusOptions = [
    'New',
    'Contacted',
    'Interested',
    'Follow Up',
    'Converted',
    'Lost',
    'Unqualified',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notesController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(autodialerProvider.notifier).fetchCurrentCall();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notesController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final dialerState = ref.read(autodialerProvider);
      if (dialerState.isCalling) {
        ref.read(autodialerProvider.notifier).captureCallCompleted();
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return const Color(0xFF2563EB); // Blue
      case 'connected':
      case 'converted':
        return const Color(0xFF16A34A); // Green
      case 'not connected':
      case 'follow up':
      case 'contacted':
        return const Color(0xFFEA580C); // Orange
      case 'invalid':
      case 'lost':
        return const Color(0xFFDC2626); // Red
      case 'qualified':
      case 'interested':
        return const Color(0xFF059669); // Emerald
      case 'unqualified':
      case 'no answer':
      case 'busy':
        return const Color(0xFF64748B); // Slate
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(autodialerProvider);

    if (state.notes != _notesController.text && state.notes.isEmpty) {
      _notesController.text = '';
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: const GlobalAppBar(title: 'Auto Dialer'),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(autodialerProvider.notifier).fetchCurrentCall();
        },
        child: state.isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(strokeWidth: 2.5),
                    SizedBox(height: 16),
                    Text('Claiming next queue item...'),
                  ],
                ),
              )
            : state.isQueueFinished || state.currentCall == null
                ? _buildEmptyQueueView(context, isDark)
                : _buildCallView(context, state, isDark),
      ),
    );
  }

  Widget _buildEmptyQueueView(BuildContext context, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                size: 64,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Active Calls in Queue',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When an Admin starts an outbound calling campaign, pending contacts will automatically appear here or pop up via push notification.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(autodialerProvider.notifier).fetchCurrentCall();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Check for Queue Items'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallView(
    BuildContext context,
    AutoDialerState state,
    bool isDark,
  ) {
    final item = state.currentCall!;
    final contact = item.contactInfo;
    final isColdLead = item.targetType.toLowerCase() == 'coldlead';

    final coldDetails = contact.coldLeadDetails;
    final leadDetails = contact.leadDetails;

    final name = contact.name.isNotEmpty
        ? contact.name
        : (isColdLead ? (coldDetails?.name ?? 'Unknown') : (leadDetails?.name ?? 'Unknown'));
    final phoneNo = contact.phoneNo.isNotEmpty
        ? contact.phoneNo
        : (isColdLead ? (coldDetails?.phoneNo ?? '') : (leadDetails?.phoneNo ?? ''));
    final email = isColdLead ? coldDetails?.email : null;
    final company = !isColdLead ? leadDetails?.company : null;
    final location = isColdLead
        ? [coldDetails?.city, coldDetails?.state].where((s) => s != null && s.isNotEmpty).join(', ')
        : [leadDetails?.city, leadDetails?.state].where((s) => s != null && s.isNotEmpty).join(', ');

    final statusOptions = isColdLead ? _coldLeadStatusOptions : _leadStatusOptions;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Campaign Info Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF2563EB).withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.campaign_rounded, color: Color(0xFF2563EB), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.campaignTitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Queue Order #${item.queueOrder} • ${isColdLead ? "Cold Outbound" : "Lead Outbound"}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Contact Info Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        if (company != null && company.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            company,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.phone_rounded, size: 18, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Text(
                    phoneNo,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    tooltip: 'Copy Number',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: phoneNo));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Phone number copied to clipboard'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
              if (email != null && email.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.email_outlined, size: 16, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ],
              if (location.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Text(
                      location,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Prominent Call Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () {
              ref.read(autodialerProvider.notifier).initiateCall();
            },
            icon: Icon(
              state.isCalling ? Icons.phone_in_talk_rounded : Icons.call_rounded,
              size: 20,
            ),
            label: Text(
              state.isCalling
                  ? 'Calling $name...'
                  : (state.callDuration != null && state.callDuration! > 0
                      ? 'Call Again (${state.callDuration}s recorded)'
                      : 'Call $name'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: state.isCalling ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        if (state.callDuration != null && state.callDuration! > 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF16A34A)),
                const SizedBox(width: 8),
                Text(
                  'Call Logged: ${state.callDuration}s duration • ${state.selectedCallResult}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 18),

        // Call Result Choice Chips
        Text(
          'Call Result',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _callResultOptions.map((result) {
            final isSelected = state.selectedCallResult == result;
            final color = _getStatusColor(result);
            return ChoiceChip(
              label: Text(result),
              selected: isSelected,
              onSelected: (_) {
                ref.read(autodialerProvider.notifier).setCallResult(result);
              },
              selectedColor: color.withValues(alpha: 0.2),
              side: BorderSide(
                color: isSelected ? color : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
              ),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : (isDark ? Colors.white70 : const Color(0xFF475569)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Status Choice Chips
        Text(
          'Update Status (${isColdLead ? "Cold Lead" : "Lead"})',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: statusOptions.map((status) {
            final isSelected = state.selectedStatus.toLowerCase() == status.toLowerCase();
            final color = _getStatusColor(status);
            return ChoiceChip(
              label: Text(status),
              selected: isSelected,
              onSelected: (_) {
                ref.read(autodialerProvider.notifier).setStatus(status);
              },
              selectedColor: color.withValues(alpha: 0.2),
              side: BorderSide(
                color: isSelected ? color : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
              ),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : (isDark ? Colors.white70 : const Color(0xFF475569)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Notes Input
        Text(
          'Notes & Remarks',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 3,
          onChanged: (val) {
            ref.read(autodialerProvider.notifier).setNotes(val);
          },
          decoration: InputDecoration(
            hintText: 'Enter notes about conversation, next steps, feedback...',
            hintStyle: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 20),

        if (state.error != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 18, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.error!,
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Submit & Next Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: state.isCompleting
                ? null
                : () async {
                    final success = await ref
                        .read(autodialerProvider.notifier)
                        .submitAndNext();
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Call saved & next contact loaded!'),
                          backgroundColor: Color(0xFF16A34A),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: state.isCompleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Submit & Next',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
