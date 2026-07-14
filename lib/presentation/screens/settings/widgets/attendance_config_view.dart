import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/settings_service.dart';
import '../../../../data/models/attendance_config_model.dart';

class AttendanceConfigView extends ConsumerStatefulWidget {
  const AttendanceConfigView({super.key});

  @override
  ConsumerState<AttendanceConfigView> createState() => _AttendanceConfigViewState();
}

class _AttendanceConfigViewState extends ConsumerState<AttendanceConfigView> {
  bool _isLoading = false;
  AttendanceConfigModel? _config;
  
  // Local state for editing
  bool _notifyOnInactivity = false;
  int _inactivityMinutes = 15;
  List<BreakReason> _breaks = [];

  @override
  void initState() {
    super.initState();
    _fetchConfig();
  }

  Future<void> _fetchConfig() async {
    setState(() => _isLoading = true);
    try {
      final config = await ref.read(settingsServiceProvider).fetchAttendanceConfig();
      if (config != null) {
        setState(() {
          _config = config;
          _notifyOnInactivity = config.notifyOnInactivity;
          _inactivityMinutes = config.inactivityAlertMinutes;
          _breaks = List.from(config.breakReasons);
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading settings: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    try {
      final newConfig = AttendanceConfigModel(
        inactivityAlertMinutes: _inactivityMinutes,
        notifyOnInactivity: _notifyOnInactivity,
        breakReasons: _breaks,
      );
      
      if (_config != null) {
        await ref.read(settingsServiceProvider).updateAttendanceConfig(newConfig);
      } else {
        await ref.read(settingsServiceProvider).createAttendanceConfig(newConfig);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuration Saved!')));
        _fetchConfig();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _config == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool useMobileLayout = screenWidth < 700; // Increased threshold for better desktop layout space

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader("Attendance Settings"),
              if (_isLoading) 
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else
                ElevatedButton(
                  onPressed: _saveConfig,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.blue : Colors.black, 
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
                )
            ],
          ),
          const SizedBox(height: 16),
          
          // Main Config Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInputLabel("Inactivity Timeout (Minutes)", isDark),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: _inactivityMinutes.toString(),
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                  decoration: _getInputDecoration(isDark),
                  onChanged: (val) => setState(() => _inactivityMinutes = int.tryParse(val) ?? 15),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Switch(
                      value: _notifyOnInactivity, 
                      onChanged: (val) => setState(() => _notifyOnInactivity = val),
                      activeThumbColor: Colors.green,
                      inactiveTrackColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300,
                    ),
                    const SizedBox(width: 12),
                    Text("Notify on Inactivity", style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
                  ],
                )
              ],
            ),
          ),

          const SizedBox(height: 32),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader("Break Reasons"),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _breaks.add(BreakReason(
                      key: 'break_${DateTime.now().millisecondsSinceEpoch}',
                      label: 'New Break',
                      allowedMinutes: 10,
                      notifyManager: false
                    ));
                  });
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text("ADD BREAK", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5)),
                style: TextButton.styleFrom(
                  foregroundColor: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _breaks.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final breakItem = _breaks[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: [
                    if (useMobileLayout) ...[
                      // Mobile Vertical Layout
                      _buildBreakFormField(
                        label: "Key (e.g. tea)",
                        initialValue: breakItem.key,
                        isDark: isDark,
                        onChanged: (val) => _updateBreak(index, breakItem, key: val),
                      ),
                      const SizedBox(height: 12),
                      _buildBreakFormField(
                        label: "Label (e.g. Tea Break)",
                        initialValue: breakItem.label,
                        isDark: isDark,
                        onChanged: (val) => _updateBreak(index, breakItem, label: val),
                      ),
                      const SizedBox(height: 12),
                      _buildBreakFormField(
                        label: "Allowed Time (Min)",
                        initialValue: breakItem.allowedMinutes.toString(),
                        isDark: isDark,
                        keyboardType: TextInputType.number,
                        onChanged: (val) => _updateBreak(index, breakItem, minutes: int.tryParse(val) ?? 0),
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      // Desktop Horizontal Layout
                      Row(
                        children: [
                          Expanded(
                            child: _buildBreakFormField(
                              label: "Key",
                              initialValue: breakItem.key,
                              isDark: isDark,
                              onChanged: (val) => _updateBreak(index, breakItem, key: val),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildBreakFormField(
                              label: "Label",
                              initialValue: breakItem.label,
                              isDark: isDark,
                              onChanged: (val) => _updateBreak(index, breakItem, label: val),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildBreakFormField(
                              label: "Allowed Time",
                              initialValue: breakItem.allowedMinutes.toString(),
                              isDark: isDark,
                              keyboardType: TextInputType.number,
                              onChanged: (val) => _updateBreak(index, breakItem, minutes: int.tryParse(val) ?? 0),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    Row(
                      children: [
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: breakItem.notifyManager, 
                            onChanged: (val) => _updateBreak(index, breakItem, notify: val),
                            activeThumbColor: isDark ? Colors.blue : Colors.black,
                          ),
                        ),
                        Flexible(child: Text("Notify Manager", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87), overflow: TextOverflow.ellipsis)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          onPressed: () => setState(() => _breaks.removeAt(index)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                        )
                      ],
                    )
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _updateBreak(int index, BreakReason item, {String? key, String? label, int? minutes, bool? notify}) {
    setState(() {
      _breaks[index] = BreakReason(
        id: item.id,
        key: key ?? item.key,
        label: label ?? item.label,
        allowedMinutes: minutes ?? item.allowedMinutes,
        notifyManager: notify ?? item.notifyManager
      );
    });
  }

  Widget _buildSectionHeader(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87));
  }

  Widget _buildInputLabel(String label, bool isDark) {
    return Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey[600]));
  }

  InputDecoration _getInputDecoration(bool isDark) {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _buildBreakFormField({
    required String label,
    required String initialValue,
    required bool isDark,
    required Function(String) onChanged,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel(label, isDark),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: initialValue,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
          keyboardType: keyboardType,
          decoration: _getInputDecoration(isDark).copyWith(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
