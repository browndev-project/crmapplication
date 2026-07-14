import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../core/services/attendance_service.dart';
import '../../core/services/settings_service.dart';
import '../../data/models/attendance_config_model.dart';

// Simple State Provider for local UI state (Active, Inactive, Break)
// In a real app, this should be synced with the server on load.
// For now, defaulting to 'Inactive' or checking shared prefs could be added.
final executiveStatusProvider = StateProvider<String>((ref) => 'inactive');

class AttendanceActionWidget extends ConsumerStatefulWidget {
  const AttendanceActionWidget({super.key});

  @override
  ConsumerState<AttendanceActionWidget> createState() => _AttendanceActionWidgetState();
}

class _AttendanceActionWidgetState extends ConsumerState<AttendanceActionWidget> {
  bool _isLoading = false;

  Future<void> _handleAction(String action, [String? reason]) async {
    setState(() => _isLoading = true);
    final service = AttendanceService();
    Map<String, dynamic>? response;
    bool success = false;

    try {
      // MAPPING ACTIONS
      if (action == 'start_attendance') {
        response = await service.startAttendance();
        if (response != null && response['success'] == true) {
          ref.read(executiveStatusProvider.notifier).state = 'active';
          _showSnack('Attendance Started! 🚀');
           success = true;
        }
      } else if (action == 'end_attendance') {
        response = await service.endAttendance();
        if (response != null && response['success'] == true) {
          ref.read(executiveStatusProvider.notifier).state = 'inactive';
          _showSnack('Attendance Ended. See you tomorrow! 👋');
           success = true;
        }
      } else if (action == 'start_break') {
        response = await service.startBreak(reason ?? 'personal'); 
        if (response != null && response['success'] == true) {
          ref.read(executiveStatusProvider.notifier).state = 'break';
          _showSnack('Break Started ($reason) ☕');
           success = true;
        }
      } else if (action == 'end_break') {
        response = await service.endBreak();
        if (response != null && response['success'] == true) {
          ref.read(executiveStatusProvider.notifier).state = 'active';
          _showSnack('Welcome Back! 💪');
           success = true;
        }
      }

      if (!success && response != null) {
         _showSnack(response['message'] ?? 'Action Failed', isError: true);
      }
    } catch (e) {
       _showSnack('Error: $e', isError: true);
    } finally {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  void _showOptions() {
    final status = ref.read(executiveStatusProvider);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Attendance Control", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _getStatusColor(status).withValues(alpha: 0.5))
                ),
                child: Text(
                  status.toUpperCase(), 
                  style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold, letterSpacing: 1)
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Logic: 
              // Inactive -> Start Day -> Active
              // Active -> Take Break OR End Day
              // Break -> End Break (Cannot End Day)
              
              if (status == 'inactive')
                _buildBtn("Start Day", Icons.wb_sunny, Colors.green, () { Navigator.pop(ctx); _handleAction('start_attendance'); }),
              
              if (status == 'active') ...[
                 _buildBtn("Take a Break", Icons.coffee, Colors.orange, () { 
                   Navigator.pop(ctx); 
                   _showBreakReasonPicker();
                 }),
                 const SizedBox(height: 16),
                 _buildBtn("End Day", Icons.logout, Colors.red, () { Navigator.pop(ctx); _handleAction('end_attendance'); }),
              ],

              if (status == 'break') ...[
                 Text("You are on break. End break to resume work or end day.", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                 const SizedBox(height: 12),
                 _buildBtn("Stop Break", Icons.play_arrow, Colors.blue, () { Navigator.pop(ctx); _handleAction('end_break'); }),
                 const SizedBox(height: 12),
                 // Disable End Day button visually via separate widget or just don't show it
                 // User request: "have to end the break to end the day"
              ],

              const SizedBox(height: 16),
            ],
          ),
        );
      }
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'active') return Colors.green;
    if (status == 'break') return Colors.orange;
    return Colors.grey;
  }

  Future<void> _showBreakReasonPicker() async {
    setState(() => _isLoading = true);
    
    try {
      final config = await ref.read(settingsServiceProvider).fetchAttendanceConfig();
      if (!mounted) return;
      setState(() => _isLoading = false);

      final List<BreakReason> reasons = config?.breakReasons ?? [
        BreakReason(key: 'personal', label: 'Personal', allowedMinutes: 15, notifyManager: false),
        BreakReason(key: 'tea', label: 'Tea Break', allowedMinutes: 15, notifyManager: false),
        BreakReason(key: 'lunch', label: 'Lunch Break', allowedMinutes: 45, notifyManager: false),
      ];

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Select Break Reason", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("How long will you be away?", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                const SizedBox(height: 24),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: reasons.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final r = reasons[index];
                      return ListTile(
                        onTap: () {
                          Navigator.pop(ctx);
                          _handleAction('start_break', r.key);
                        },
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                          child: const Icon(Icons.coffee_outlined, color: Colors.orange, size: 20),
                        ),
                        title: Text(r.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("${r.allowedMinutes} mins allowed"),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200)
                        ),
                        tileColor: Colors.grey.shade50,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        }
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('Failed to load break options: $e', isError: true);
      }
    }
  }

  Widget _buildBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white),
        label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        onPressed: onTap,
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final status = ref.watch(executiveStatusProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color iconColor;
    IconData iconData;
    
    if (status == 'active') {
       iconColor = Colors.green;
       iconData = Icons.back_hand_rounded; 
    } else if (status == 'break') {
       iconColor = Colors.orange;
       iconData = Icons.coffee_rounded;
    } else {
       iconColor = Colors.grey;
       iconData = Icons.fingerprint_rounded;
    }

    return Center(
      child: InkWell(
        onTap: _isLoading ? null : _showOptions,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: _isLoading 
            ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))) 
            : Icon(iconData, color: iconColor, size: 24),
        ),
      ),
    );
  }
}


