import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/task_provider.dart';
import '../providers/lead_provider.dart';
import '../providers/login_provider.dart';
import '../../data/models/task_model.dart';
import '../../core/utils/date_utils.dart';
import '../../core/services/r2_service.dart';

class TaskCreateDialog extends ConsumerStatefulWidget {
  final String? leadId; // Optional: If provided, pre-selects lead and hides dropdown
  final Task? task;

  const TaskCreateDialog({super.key, this.leadId, this.task});

  @override
  ConsumerState<TaskCreateDialog> createState() => _TaskCreateDialogState();
}

class VoiceNoteItem {
  final String? localPath;
  final String? remoteUrl;
  final bool isPlaying;

  VoiceNoteItem({this.localPath, this.remoteUrl, this.isPlaying = false});

  VoiceNoteItem copyWith({String? localPath, String? remoteUrl, bool? isPlaying}) {
    return VoiceNoteItem(
      localPath: localPath ?? this.localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}

class _TaskCreateDialogState extends ConsumerState<TaskCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _dueDateController;
  
  DateTime? _selectedDate;
  String? _selectedLeadId;
  String _selectedStatus = 'Not Started';
  bool _isLoading = false;

  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  List<VoiceNoteItem> _voiceNotes = [];
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? 'Follow up');
    _descriptionController = TextEditingController(text: widget.task?.description ?? '');
    
    // Initialize Status
    if (widget.task?.status != null) {
        _selectedStatus = widget.task!.status;
    }

    // Initialize Lead ID
    if (widget.leadId != null) {
        _selectedLeadId = widget.leadId;
    } else if (widget.task?.lead?.id != null) {
        _selectedLeadId = widget.task!.lead!.id;
    }

    // Initialize Date
    if (widget.task?.dueDate != null) {
        _selectedDate = DateTimeUtils.parseSafe(widget.task!.dueDate);
        _dueDateController = TextEditingController(text: DateTimeUtils.formatDisplay(_selectedDate));
    } else {
        _dueDateController = TextEditingController();
    }

    // Initialize voice notes
    if (widget.task?.voiceNotes != null) {
      _voiceNotes = widget.task!.voiceNotes.map((url) => VoiceNoteItem(remoteUrl: url)).toList();
    }

    // Listen to player completion
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _voiceNotes = _voiceNotes.map((vn) => vn.copyWith(isPlaying: false)).toList();
        });
      }
    });

    // Fetch leads if we need to show the dropdown
    WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.leadId == null && ref.read(leadsProvider).leads.isEmpty) {
            ref.read(leadsProvider.notifier).fetchLeads();
        }
    });
  }

  void _startTimer() {
    _recordingSeconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        setState(() {
          _recordingSeconds++;
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
        
        setState(() {
          _isRecording = true;
        });
        _startTimer();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Microphone permission denied"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _stopTimer();
      
      setState(() {
        _isRecording = false;
      });

      if (path != null) {
        setState(() {
          _voiceNotes.add(VoiceNoteItem(localPath: path));
        });
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  Future<void> _playPauseVoiceNote(int index) async {
    final note = _voiceNotes[index];
    if (note.isPlaying) {
      await _audioPlayer.pause();
      setState(() {
        _voiceNotes[index] = note.copyWith(isPlaying: false);
      });
    } else {
      // Stop any other playing note
      await _audioPlayer.stop();
      setState(() {
        _voiceNotes = _voiceNotes.asMap().entries.map((entry) {
          return entry.value.copyWith(isPlaying: entry.key == index);
        }).toList();
      });

      if (note.localPath != null) {
        await _audioPlayer.play(DeviceFileSource(note.localPath!));
      } else if (note.remoteUrl != null) {
        await _audioPlayer.play(UrlSource(note.remoteUrl!));
      }
    }
  }

  void _deleteVoiceNote(int index) {
    if (_voiceNotes[index].isPlaying) {
      _audioPlayer.stop();
    }
    setState(() {
      _voiceNotes.removeAt(index);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dueDateController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2101),
      builder: (context, child) {
         final isDark = Theme.of(context).brightness == Brightness.dark;
         return Theme(
           data: Theme.of(context).copyWith(
             colorScheme: isDark ? const ColorScheme.dark(primary: Colors.black) : const ColorScheme.light(primary: Colors.black),
           ),
           child: child!,
         );
      }
    );
    if (picked != null) {
      if (context.mounted) {
         final TimeOfDay? time = await showTimePicker(
             context: context,
             initialTime: TimeOfDay.fromDateTime(_selectedDate ?? DateTime.now()),
             builder: (context, child) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: isDark ? const ColorScheme.dark(primary: Colors.black) : const ColorScheme.light(primary: Colors.black),
                  ),
                  child: child!,
                );
             }
         );
         
         if (time != null) {
             setState(() {
                _selectedDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
                _dueDateController.text = DateTimeUtils.formatDisplay(_selectedDate!);
             });
         }
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (widget.task == null && _selectedLeadId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please assign a lead")));
        return;
    }

    setState(() => _isLoading = true);

    try {
      final List<String> finalUrls = [];
      final loginState = ref.read(loginProvider);
      final companyId = loginState.user?.company;
      final userId = loginState.user?.id;
      final r2Service = R2Service();

      for (var vn in _voiceNotes) {
        if (vn.remoteUrl != null) {
          finalUrls.add(vn.remoteUrl!);
        } else if (vn.localPath != null) {
          final file = File(vn.localPath!);
          final uniqueId = 'voice_note_${DateTime.now().millisecondsSinceEpoch}_${vn.hashCode}';
          final url = await r2Service.uploadAudio(file, uniqueId, companyId: companyId, userId: userId);
          if (url != null) {
            finalUrls.add(url);
          } else {
            throw 'Failed to upload voice note';
          }
        }
      }

      final Map<String, dynamic> taskData = {
        "title": _titleController.text.trim(),
        "description": _descriptionController.text.trim(),
        "status": _selectedStatus,
        "voiceNotes": finalUrls,
      };
      
      if (_selectedDate != null) {
          taskData["dueDate"] = DateTimeUtils.toApiString(_selectedDate);
      }

      if (widget.task != null) {
          await ref.read(tasksProvider.notifier).updateTask(widget.task!.id, taskData);
      } else {
          taskData["leadId"] = _selectedLeadId;
          await ref.read(tasksProvider.notifier).createTask(taskData);
      }

      // Refresh lead list screen state
      ref.read(leadsProvider.notifier).refresh();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.task != null ? 'Follow up updated' : 'Follow up created'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = widget.task != null;
    final leadsState = ref.watch(leadsProvider);

    return Dialog(
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), 
       backgroundColor: Theme.of(context).cardColor,
       insetPadding: const EdgeInsets.all(16),
       child: ConstrainedBox(
         constraints: const BoxConstraints(maxWidth: 600),
         child: SingleChildScrollView(
           child: Padding(
             padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
             child: Column(
               mainAxisSize: MainAxisSize.min,
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 // Header
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text(isEdit ? "Update Follow up" : "Create Follow up", style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.bodyLarge?.color)),
                     InkWell(
                       onTap: () => Navigator.pop(context),
                       borderRadius: BorderRadius.circular(20),
                       child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Theme.of(context).dividerColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: Icon(Icons.close, size: 20, color: Theme.of(context).iconTheme.color),
                       ),
                     )
                   ],
                 ),

                 SizedBox(height: 20,),
                 // Form
                 Form(
                   key: _formKey,
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       _buildTextField("Title *", _titleController, isDark, required: true),
                       const SizedBox(height: 16),
                       
                       _buildTextField("Description", _descriptionController, isDark, maxLines: 3),
                       const SizedBox(height: 16),
                       
                       // Lead Dropdown (Show only if leadId was NOT provided in constructor)
                       if (widget.leadId == null && !isEdit) ...[
                           DropdownButtonFormField<String>(
                               initialValue: _selectedLeadId,
                               decoration: _inputDecoration("Assign Lead", isDark),
                               items: leadsState.leads.map((lead) {
                                   return DropdownMenuItem(value: lead.id, child: Text(lead.name, overflow: TextOverflow.ellipsis));
                               }).toList(), 
                               onChanged: (val) => setState(() => _selectedLeadId = val),
                               hint: const Text('Select a Lead'),
                               icon: const Icon(Icons.keyboard_arrow_down),
                           ),
                           const SizedBox(height: 16),
                       ],

                        DropdownButtonFormField<String>(
                            initialValue: _selectedStatus,
                            decoration: _inputDecoration("Status", isDark),
                            items: ['Not Started', 'In Progress', 'Completed'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (val) => setState(() => _selectedStatus = val!),
                            icon: const Icon(Icons.keyboard_arrow_down),
                        ),
                       const SizedBox(height: 16),

                        TextFormField(
                          controller: _dueDateController,
                          readOnly: true,
                          onTap: () => _selectDate(context),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          validator: (val) => val == null || val.isEmpty ? 'Due Date is required' : null,
                          decoration: _inputDecoration("Due Date *", isDark).copyWith(
                              hintText: "mm/dd/yyyy --:--",
                              suffixIcon: const Icon(Icons.calendar_today, size: 20)
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Voice Notes",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            if (_isRecording)
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "${(_recordingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_recordingSeconds % 60).toString().padLeft(2, '0')}",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_isRecording)
                          ElevatedButton.icon(
                            onPressed: _stopRecording,
                            icon: const Icon(Icons.stop, color: Colors.white),
                            label: const Text("Stop Recording"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          )
                        else
                          OutlinedButton.icon(
                            onPressed: _startRecording,
                            icon: const Icon(Icons.mic, color: Color(0xFF2563EB)),
                            label: const Text("Record Voice Note"),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF2563EB)),
                              foregroundColor: const Color(0xFF2563EB),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        const SizedBox(height: 16),
                        if (_voiceNotes.isNotEmpty)
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _voiceNotes.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final vn = _voiceNotes[index];
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.audiotrack,
                                      color: isDark ? Colors.white70 : Colors.black54,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        vn.remoteUrl != null
                                            ? "Saved Voice Note ${index + 1}"
                                            : "Recorded Voice Note ${index + 1}",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark ? Colors.white70 : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        vn.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                        color: const Color(0xFF2563EB),
                                      ),
                                      onPressed: () => _playPauseVoiceNote(index),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () => _deleteVoiceNote(index),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Footer
                  Row(
                     mainAxisAlignment: MainAxisAlignment.end,
                     children: [
                         TextButton(
                             onPressed: () => Navigator.pop(context),
                             style: TextButton.styleFrom(foregroundColor: Colors.grey),
                             child: const Text("Cancel"),
                         ),
                         const SizedBox(width: 16),
                         ElevatedButton(
                             onPressed: _isLoading ? null : _submit,
                             style: ElevatedButton.styleFrom(
                                 backgroundColor: isDark ? const Color(0xFF4C6EF5) : Colors.black,
                                 foregroundColor: Colors.white,
                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                 elevation: 0
                             ),
                             child: _isLoading 
                                 ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                 : Text(isEdit ? "Update Follow Up" : "Create Follow Up"),
                         )
                     ],
                  )
               ],
             ),
           ),
         ),
       )
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, bool isDark, {
      bool required = false, 
      int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0), 
      child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 14),
          validator: required ? (val) => val == null || val.isEmpty ? 'Required' : null : null,
          decoration: _inputDecoration(label, isDark),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, bool isDark) {
      return InputDecoration(
          labelText: label,
          hintText: 'Enter $label',
          hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.5), fontSize: 13),
          labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: 14),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          filled: false,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.4))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.4))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? Colors.white : Colors.black, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
  }
}
