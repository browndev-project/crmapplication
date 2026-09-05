import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// An animated, interactive Speech-to-Text Voice Input Dialog.
/// Listens to user speech in real time, displays live transcription with animated soundwaves,
/// and returns or directly applies the recognized text into a comment/note field.
class VoiceToTextDialog extends StatefulWidget {
  final String title;
  final String? initialText;
  final TextEditingController? targetController;
  final String hintText;

  const VoiceToTextDialog({
    super.key,
    this.title = 'Speak Comment',
    this.initialText,
    this.targetController,
    this.hintText = 'Listening... Speak now, your words will appear here.',
  });

  /// Convenient helper to show this dialog from anywhere in the app.
  static Future<String?> show({
    required BuildContext context,
    String title = 'Speak Comment',
    String? initialText,
    TextEditingController? targetController,
    String hintText = 'Listening... Speak now, your words will appear here.',
  }) {
    return showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'VoiceToTextDialog',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim1, anim2) {
        return VoiceToTextDialog(
          title: title,
          initialText: initialText ?? targetController?.text,
          targetController: targetController,
          hintText: hintText,
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<VoiceToTextDialog> createState() => _VoiceToTextDialogState();
}

class _VoiceToTextDialogState extends State<VoiceToTextDialog> with TickerProviderStateMixin {
  late final stt.SpeechToText _speech;
  bool _isInitialized = false;
  bool _isListening = false;
  bool _hasError = false;
  String _errorMessage = '';
  String _recognizedText = '';
  double _soundLevel = 0.0; // Typically -100 to 0 or 0 to 10

  // Animations
  late AnimationController _pulseController;
  late AnimationController _waveController;

  // Append vs Replace option if existing text exists
  bool _appendMode = true;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();

    // Concentric pulse animation for the mic ring
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    // Soundwave bar oscillating animation
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _initSpeechAndListen();
  }

  Future<void> _initSpeechAndListen() async {
    try {
      final available = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
      );

      if (!mounted) return;

      if (available) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
          _errorMessage = '';
        });
        _startListening();
      } else {
        setState(() {
          _isInitialized = false;
          _hasError = true;
          _errorMessage = 'Speech recognition is not available or microphone permission was denied.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitialized = false;
        _hasError = true;
        _errorMessage = 'Error initializing speech service: $e';
      });
    }
  }

  void _onStatus(String status) {
    if (!mounted) return;
    debugPrint('🎙️ [VoiceToText] Status: $status');
    if (status == 'listening') {
      setState(() => _isListening = true);
    } else if (status == 'notListening' || status == 'done') {
      setState(() => _isListening = false);
    }
  }

  void _onError(SpeechRecognitionError error) {
    if (!mounted) return;
    debugPrint('🎙️ [VoiceToText] Error: ${error.errorMsg} (permanent: ${error.permanent})');
    // Don't mark as fatal if user just finished speaking or paused
    if (error.errorMsg.contains('error_no_match') || error.errorMsg.contains('error_speech_timeout')) {
      setState(() => _isListening = false);
    } else {
      setState(() {
        _hasError = true;
        _errorMessage = error.errorMsg;
        _isListening = false;
      });
    }
  }

  Future<void> _startListening() async {
    if (!_isInitialized) return;

    try {
      HapticFeedback.lightImpact();
      setState(() {
        _hasError = false;
        _errorMessage = '';
        _isListening = true;
      });

      final options = stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
      );

      await _speech.listen(
        onResult: _onResult,
        onSoundLevelChange: (level) {
          if (!mounted) return;
          setState(() {
            _soundLevel = level;
          });
        },
        listenOptions: options,
      );
    } catch (e) {
      debugPrint('🎙️ [VoiceToText] Exception in listen: $e');
    }
  }

  Future<void> _stopListening() async {
    try {
      HapticFeedback.lightImpact();
      await _speech.stop();
      if (mounted) {
        setState(() => _isListening = false);
      }
    } catch (e) {
      debugPrint('🎙️ [VoiceToText] Exception in stop: $e');
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() {
      _recognizedText = result.recognizedWords;
    });
  }

  void _handleConfirm() {
    HapticFeedback.mediumImpact();
    final newText = _recognizedText.trim();
    if (newText.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    String finalText = newText;
    final initial = (widget.initialText ?? widget.targetController?.text ?? '').trim();

    if (initial.isNotEmpty) {
      if (_appendMode) {
        finalText = '$initial\n$newText';
      } else {
        finalText = newText;
      }
    }

    if (widget.targetController != null) {
      widget.targetController!.text = finalText;
      widget.targetController!.selection = TextSelection.fromPosition(
        TextPosition(offset: finalText.length),
      );
    }

    Navigator.of(context).pop(finalText);
  }

  @override
  void dispose() {
    _speech.stop();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasExistingText = (widget.initialText ?? widget.targetController?.text ?? '').trim().isNotEmpty;

    // return Dialog(
    //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    //   backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
    //   insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    //   elevation: 12,
    //   child: ConstrainedBox(
    //     constraints: const BoxConstraints(maxWidth: 420),
    //     child: Padding(
    //       padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
    //       child: Column(
    //         mainAxisSize: MainAxisSize.min,
    //         children: [
    //           // Header
    //           Row(
    //             children: [
    //               Container(
    //                 padding: const EdgeInsets.all(8),
    //                 decoration: BoxDecoration(
    //                   color: const Color(0xFF2563EB).withValues(alpha: 0.12),
    //                   shape: BoxShape.circle,
    //                 ),
    //                 child: const Icon(Icons.record_voice_over_rounded, color: Color(0xFF2563EB), size: 20),
    //               ),
    //               const SizedBox(width: 10),
    //               Expanded(
    //                 child: Text(
    //                   widget.title,
    //                   style: TextStyle(
    //                     fontSize: 18,
    //                     fontWeight: FontWeight.bold,
    //                     color: isDark ? Colors.white : const Color(0xFF0F172A),
    //                   ),
    //                 ),
    //               ),
    //               IconButton(
    //                 icon: const Icon(Icons.close_rounded, size: 22),
    //                 color: Colors.grey,
    //                 onPressed: () => Navigator.of(context).pop(),
    //                 padding: EdgeInsets.zero,
    //                 constraints: const BoxConstraints(),
    //               ),
    //             ],
    //           ),
    //           const SizedBox(height: 16),
    //           // Animated Pulsing Microphone Visualizer
    //           _buildAnimatedMicVisualizer(isDark),
    //           const SizedBox(height: 12),
    //           // Listening Status Badge
    //           _buildStatusBadge(isDark),
    //           const SizedBox(height: 16),
    //           // Transcription Display Box
    //           _buildTranscriptionBox(isDark),
    //           const SizedBox(height: 12),
    //           // Append vs Replace Toggle (only if existing text was present)
    //           if (hasExistingText && _recognizedText.isNotEmpty) ...[
    //             Row(
    //               mainAxisAlignment: MainAxisAlignment.center,
    //               children: [
    //                 ChoiceChip(
    //                   label: const Text('Append to Comment', style: TextStyle(fontSize: 12)),
    //                   selected: _appendMode,
    //                   selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
    //                   labelStyle: TextStyle(
    //                     color: _appendMode ? const Color(0xFF2563EB) : (isDark ? Colors.grey[400] : Colors.grey[700]),
    //                     fontWeight: _appendMode ? FontWeight.bold : FontWeight.normal,
    //                   ),
    //                   onSelected: (val) {
    //                     if (val) setState(() => _appendMode = true);
    //                   },
    //                 ),
    //                 const SizedBox(width: 8),
    //                 ChoiceChip(
    //                   label: const Text('Replace', style: TextStyle(fontSize: 12)),
    //                   selected: !_appendMode,
    //                   selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
    //                   labelStyle: TextStyle(
    //                     color: !_appendMode ? const Color(0xFF2563EB) : (isDark ? Colors.grey[400] : Colors.grey[700]),
    //                     fontWeight: !_appendMode ? FontWeight.bold : FontWeight.normal,
    //                   ),
    //                   onSelected: (val) {
    //                     if (val) setState(() => _appendMode = false);
    //                   },
    //                 ),
    //               ],
    //             ),
    //             const SizedBox(height: 8),
    //           ],
    //           // Action Buttons
    //           Row(
    //             children: [
    //               // Clear / Reset Button
    //               if (_recognizedText.isNotEmpty)
    //                 TextButton.icon(
    //                   onPressed: () {
    //                     HapticFeedback.lightImpact();
    //                     setState(() => _recognizedText = '');
    //                     if (!_isListening) _startListening();
    //                   },
    //                   icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.grey),
    //                   label: const Text('Clear', style: TextStyle(color: Colors.grey, fontSize: 13)),
    //                 ),
    //               const Spacer(),
    //               // Cancel Button
    //               TextButton(
    //                 onPressed: () => Navigator.of(context).pop(),
    //                 style: TextButton.styleFrom(
    //                   foregroundColor: isDark ? Colors.grey[400] : Colors.grey[600],
    //                 ),
    //                 child: const Text('CANCEL'),
    //               ),
    //               const SizedBox(width: 8),
    //               // Confirm / Add to Comment Button
    //               ElevatedButton.icon(
    //                 onPressed: _recognizedText.trim().isNotEmpty ? _handleConfirm : null,
    //                 icon: const Icon(Icons.check_rounded, size: 18),
    //                 label: const Text('Add to Comment', style: TextStyle(fontWeight: FontWeight.bold)),
    //                 style: ElevatedButton.styleFrom(
    //                   backgroundColor: const Color(0xFF2563EB),
    //                   foregroundColor: Colors.white,
    //                   disabledBackgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
    //                   disabledForegroundColor: Colors.grey,
    //                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    //                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    //                   elevation: 0,
    //                 ),
    //               ),
    //             ],
    //           ),
    //         ],
    //       ),
    //     ),
    //   ),
    // );
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      elevation: 12,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.record_voice_over_rounded, color: Color(0xFF2563EB), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      color: Colors.grey,
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Animated Pulsing Microphone Visualizer
                _buildAnimatedMicVisualizer(isDark),
                const SizedBox(height: 12),

                // Listening Status Badge
                _buildStatusBadge(isDark),
                const SizedBox(height: 16),

                // Transcription Display Box
                _buildTranscriptionBox(isDark),
                const SizedBox(height: 12),

                // Append vs Replace Toggle (only if existing text was present)
                if (hasExistingText && _recognizedText.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('Append to Comment', style: TextStyle(fontSize: 12)),
                        selected: _appendMode,
                        selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: _appendMode ? const Color(0xFF2563EB) : (isDark ? Colors.grey[400] : Colors.grey[700]),
                          fontWeight: _appendMode ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _appendMode = true);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Replace', style: TextStyle(fontSize: 12)),
                        selected: !_appendMode,
                        selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: !_appendMode ? const Color(0xFF2563EB) : (isDark ? Colors.grey[400] : Colors.grey[700]),
                          fontWeight: !_appendMode ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _appendMode = false);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Cancel Button
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      child: const Text('CANCEL'),
                    ),
                    const SizedBox(width: 8),
                    // Confirm / Add to Comment Button
                    Flexible(
                      child: ElevatedButton.icon(
                        onPressed: _recognizedText.trim().isNotEmpty ? _handleConfirm : null,
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text(
                          'Add to Comment',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          disabledForegroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Animated Concentric Ripples around Mic Button with Live Decibel Scale
  Widget _buildAnimatedMicVisualizer(bool isDark) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _waveController]),
      builder: (context, child) {
        // Calculate dynamic ripple scale based on sound level
        // Normalize sound level from [-100, 0] or [0, 10] into [0, 1]
        double normalizedLevel = 0.0;
        if (_soundLevel > 0) {
          normalizedLevel = math.min(1.0, _soundLevel / 10.0);
        } else if (_soundLevel < 0 && _soundLevel >= -100) {
          normalizedLevel = math.max(0.0, (_soundLevel + 60) / 60.0);
        }

        final pulseValue = _pulseController.value;
        final extraScale = _isListening ? (normalizedLevel * 0.25) : 0.0;

        return Center(
          child: SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer Pulse Ripple 2
                if (_isListening)
                  Container(
                    width: 70 + (70 * pulseValue) + (extraScale * 30),
                    height: 70 + (70 * pulseValue) + (extraScale * 30),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2563EB).withValues(
                        alpha: math.max(0.0, (1.0 - pulseValue) * 0.22),
                      ),
                    ),
                  ),

                // Outer Pulse Ripple 1
                if (_isListening)
                  Container(
                    width: 65 + (45 * ((pulseValue + 0.5) % 1.0)) + (extraScale * 20),
                    height: 65 + (45 * ((pulseValue + 0.5) % 1.0)) + (extraScale * 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF3B82F6).withValues(
                        alpha: math.max(0.0, (1.0 - ((pulseValue + 0.5) % 1.0)) * 0.28),
                      ),
                    ),
                  ),

                // Center Glowing Mic Button
                GestureDetector(
                  onTap: () {
                    if (_isListening) {
                      _stopListening();
                    } else {
                      _startListening();
                    }
                  },
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: _isListening
                            ? [const Color(0xFF2563EB), const Color(0xFF1D4ED8)]
                            : [Colors.grey[700]!, Colors.grey[800]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _isListening
                              ? const Color(0xFF2563EB).withValues(alpha: 0.45)
                              : Colors.black26,
                          blurRadius: _isListening ? 18 : 8,
                          spreadRadius: _isListening ? 3 : 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.mic_rounded : Icons.mic_off_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Status badge with animated wave bars
  Widget _buildStatusBadge(bool isDark) {
    if (_hasError) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _errorMessage.isNotEmpty ? _errorMessage : 'Recognition Error',
                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    if (_isListening) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Soundwave bars animation
            _buildSoundwaveBars(),
            const SizedBox(width: 8),
            const Text(
              'Listening... Speak now',
              style: TextStyle(
                color: Color(0xFF1D4ED8),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pause_circle_outline_rounded, size: 16, color: isDark ? Colors.grey[300] : const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            'Paused. Tap mic to speak again',
            style: TextStyle(
              color: isDark ? Colors.grey[300] : const Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 5 animated oscillating soundwave bars
  Widget _buildSoundwaveBars() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, _) {
        final val = _waveController.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final offset = (index * 0.2);
            final height = 5.0 + 12.0 * math.sin((val + offset) * math.pi).abs();
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3,
              height: height,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }

  /// Transcription text area
  Widget _buildTranscriptionBox(bool isDark) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 110, maxHeight: 180),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isListening
              ? const Color(0xFF3B82F6).withValues(alpha: 0.5)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: _isListening ? 1.5 : 1.0,
        ),
      ),
      child: SingleChildScrollView(
        child: _recognizedText.isNotEmpty
            ? Text(
                _recognizedText,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              )
            : Text(
                widget.hintText,
                style: TextStyle(
                  fontSize: 13.5,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
                  height: 1.4,
                ),
              ),
      ),
    );
  }
}
