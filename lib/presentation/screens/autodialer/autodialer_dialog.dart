import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/autodialer_service.dart';
import '../../../data/models/autodialer_model.dart';
import '../../providers/autodialer_provider.dart';

class AutoDialerDialog extends ConsumerStatefulWidget {
  final AutoDialerQueueItem? initialItem;

  const AutoDialerDialog({super.key, this.initialItem});

  // Original:
  // static Future<void> show(BuildContext context, {AutoDialerQueueItem? initialItem}) async {
  //   AutoDialerService.instance.setDialogState(true);
  //   await showModalBottomSheet(
  //     context: context,
  //     isScrollControlled: true,
  //     backgroundColor: Colors.transparent,
  //     enableDrag: false,
  //     isDismissible: false,
  //     builder: (ctx) => AutoDialerDialog(initialItem: initialItem),
  //   );
  //   AutoDialerService.instance.setDialogState(false);
  // }
  static Future<void> show(BuildContext context, {AutoDialerQueueItem? initialItem}) async {
    AutoDialerService.instance.setDialogState(true);
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        enableDrag: false,
        isDismissible: false,
        useRootNavigator: true,
        builder: (ctx) => AutoDialerDialog(initialItem: initialItem),
      );
    } catch (e) {
      debugPrint('AutoDialerDialog show error: $e');
    } finally {
      AutoDialerService.instance.setDialogState(false);
    }
  }

  @override
  ConsumerState<AutoDialerDialog> createState() => _AutoDialerDialogState();
}

class _AutoDialerDialogState extends ConsumerState<AutoDialerDialog> with WidgetsBindingObserver {
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

  // Original:
  // @override
  // void initState() {
  //   super.initState();
  //   WidgetsBinding.instance.addObserver(this);
  //   _notesController = TextEditingController();
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     ref.read(autodialerProvider.notifier).setInitialItem(widget.initialItem);
  //   });
  // }
  // @override
  // void dispose() {
  //   WidgetsBinding.instance.removeObserver(this);
  //   _notesController.dispose();
  //   super.dispose();
  // }
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notesController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialItem != null) {
        ref.read(autodialerProvider.notifier).setInitialItem(widget.initialItem);
      } else {
        ref.read(autodialerProvider.notifier).fetchCurrentCall();
      }
    });
  }

  @override
  void dispose() {
    AutoDialerService.instance.setDialogState(false);
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

    // Sync controller if provider notes changed upon nextCall load
    if (state.notes != _notesController.text && state.notes.isEmpty) {
      _notesController.text = '';
    }

    // Original:
    // return Container(
    //   constraints: BoxConstraints(
    //     maxHeight: MediaQuery.of(context).size.height * 0.90,
    //   ),
    //   padding: EdgeInsets.only(
    //     bottom: MediaQuery.of(context).viewInsets.bottom,
    //   ),
    //   decoration: BoxDecoration(
    //     color: isDark ? const Color(0xFF0F172A) : Colors.white,
    //     borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    //     boxShadow: [
    //       BoxShadow(
    //         color: Colors.black.withValues(alpha: 0.3),
    //         blurRadius: 20,
    //         offset: const Offset(0, -5),
    //       ),
    //     ],
    //   ),
    //   child: SafeArea(
    //     top: false,
    //     child: state.isLoading
    //         ? const SizedBox(
    //             height: 300,
    //             child: Center(
    //               child: Column(
    //                 mainAxisAlignment: MainAxisAlignment.center,
    //                 children: [
    //                   CircularProgressIndicator(strokeWidth: 2.5),
    //                   SizedBox(height: 16),
    //                   Text('Claiming next contact from queue...'),
    //                 ],
    //               ),
    //             ),
    //           )
    //         : state.isQueueFinished || state.currentCall == null
    //             ? _buildQueueFinishedView(context, isDark)
    //             : _buildActiveCallView(context, state, isDark),
    //   ),
    // );
    final activeCall = state.currentCall ?? widget.initialItem;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: state.isLoading && activeCall == null
            ? const SizedBox(
                height: 300,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2.5),
                      SizedBox(height: 16),
                      Text('Claiming next contact from queue...'),
                    ],
                  ),
                ),
              )
            : activeCall != null
                ? _buildActiveCallView(context, state, isDark, item: activeCall)
                : _buildQueueFinishedView(context, isDark),
      ),
    );
  }

  Widget _buildQueueFinishedView(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: Color(0xFF16A34A),
              size: 56,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Campaign Queue Completed!',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All assigned contacts in this campaign have been processed. Great job!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Original:
  // Widget _buildActiveCallView(
  //   BuildContext context,
  //   AutoDialerState state,
  //   bool isDark,
  // ) {
  //   final item = state.currentCall!;
  Widget _buildActiveCallView(
    BuildContext context,
    AutoDialerState state,
    bool isDark, {
    required AutoDialerQueueItem item,
  }) {
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Top Header: Campaign Title, Queue Order & Dismiss Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Queue #${item.queueOrder}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isColdLead ? const Color(0xFF0284C7) : const Color(0xFF7C3AED))
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isColdLead ? 'Cold Lead' : 'Lead',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isColdLead ? const Color(0xFF0284C7) : const Color(0xFF7C3AED),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.campaignTitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 22),
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Contact Details Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
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
                      radius: 22,
                      backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
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
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          if (company != null && company.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              company,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 18),
                Row(
                  children: [
                    const Icon(Icons.phone_rounded, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Text(
                      phoneNo,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      tooltip: 'Copy Phone',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: phoneNo));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Phone number copied'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                if (email != null && email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 16, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ],
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Text(
                        location,
                        style: TextStyle(
                          fontSize: 12,
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

          // Primary "Call" Button / Active Call Status
          SizedBox(
            width: double.infinity,
            height: 48,
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
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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

          // Original:
          // // Call duration chip (if call ended)
          // if (state.callDuration != null && state.callDuration! > 0) ...[
          //   const SizedBox(height: 8),
          //   Container(
          //     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          //     decoration: BoxDecoration(
          //       color: const Color(0xFF16A34A).withValues(alpha: 0.1),
          //       borderRadius: BorderRadius.circular(8),
          //     ),
          //     child: Row(
          //       children: [
          //         const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
          //         const SizedBox(width: 6),
          //         Text(
          //           'Call Duration: ${state.callDuration}s • ${state.selectedCallResult}',
          //           style: const TextStyle(
          //             fontSize: 12,
          //             fontWeight: FontWeight.w600,
          //             color: Color(0xFF16A34A),
          //           ),
          //         ),
          //       ],
          //     ),
          //   ),
          // ],
          // Call duration & recording status chip (if call ended)
          if (state.callDuration != null && state.callDuration! > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Call Duration: ${state.callDuration}s • ${state.selectedCallResult}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ),
                  if (state.recordingUrl != null && state.recordingUrl!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mic, size: 12, color: Colors.white),
                          SizedBox(width: 3),
                          Text(
                            'Recorded',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ] else if (!state.isCalling) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF2563EB)),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Syncing Audio',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Call Result Selection
          Text(
            'Call Result',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _callResultOptions.map((result) {
                final isSelected = state.selectedCallResult == result;
                final color = _getStatusColor(result);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
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
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Update Status Selection
          Text(
            'Update Status (${isColdLead ? "Cold Lead" : "Lead"})',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: statusOptions.map((status) {
                final isSelected = state.selectedStatus.toLowerCase() == status.toLowerCase();
                final color = _getStatusColor(status);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
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
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

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
              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
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
          const SizedBox(height: 16),

          // Error banner (if any)
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

          // Bottom Action Row: Submit & Next
          Row(
            children: [
              OutlinedButton(
                onPressed: state.isCompleting ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Dismiss'),
              ),
              const SizedBox(width: 12),
              Expanded(
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
                                content: Text('Call logged & next contact loaded!'),
                                backgroundColor: Color(0xFF16A34A),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
