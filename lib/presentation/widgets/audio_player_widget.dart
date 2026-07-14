import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class AudioPlayerWidget extends StatefulWidget {
  final String url;
  const AudioPlayerWidget({super.key, required this.url});

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _audioPlayer;
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _playerStateSubscription;

  bool _isBufferring = false;
  String? _errorMessage;

  bool get _isPlaying => _playerState == PlayerState.playing;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
    _setSource();

    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });

    _durationSubscription = _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });

    _positionSubscription = _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });

    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _playerState = PlayerState.stopped;
          _position = Duration.zero;
        });
      }
    });

    // Listen for log messages/errors
    _audioPlayer.onLog.listen((msg) {
        debugPrint('AudioPlayer Log: $msg');
    });

    // Handle errors from the native side
    _audioPlayer.eventStream.listen((event) {}, onError: (error) {
        debugPrint('AudioPlayer Native Error: $error');
        if (mounted) {
            setState(() {
                _errorMessage = "Playback Error (-38)";
                _isBufferring = false;
                _playerState = PlayerState.stopped;
            });
        }
    });
  }

  Future<void> _setSource() async {
    if (!mounted) return;
    setState(() {
        _isBufferring = true;
        _errorMessage = null;
    });
    try {
      // Use UrlSource with potential mimeType hint for wav files
      final source = UrlSource(widget.url);
      await _audioPlayer.setSource(source);
      if (mounted) setState(() => _isBufferring = false);
    } catch (e) {
      debugPrint('Error setting audio source: $e');
      if (mounted) {
          setState(() {
              _isBufferring = false;
              _errorMessage = "Failed to load audio";
          });
      }
    }
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPause() async {
    if (_errorMessage != null) {
        _setSource();
        return;
    }
    
    try {
        if (_isPlaying) {
          await _audioPlayer.pause();
        } else {
          if (_playerState == PlayerState.completed || _playerState == PlayerState.stopped) {
             await _audioPlayer.play(UrlSource(widget.url));
          } else {
             await _audioPlayer.resume();
          }
        }
    } catch (e) {
        debugPrint('Error during play/pause: $e');
        if (mounted) {
            setState(() => _errorMessage = "Playback error");
        }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _playPause,
            icon: _isBufferring 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue))
                : Icon(
                    _errorMessage != null ? Icons.error_outline : (_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                    color: _errorMessage != null ? Colors.red : Colors.blue,
                    size: 32,
                  ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_errorMessage != null)
                   Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold))
                else
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: Colors.blue,
                    inactiveTrackColor: Colors.blue.withValues(alpha: 0.1),
                    thumbColor: Colors.blue,
                  ),
                  child: Slider(
                    min: 0,
                    max: _duration.inMilliseconds.toDouble() > 0 
                        ? _duration.inMilliseconds.toDouble() 
                        : 1.0,
                    value: _position.inMilliseconds.toDouble().clamp(0, _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0),
                    onChanged: (value) async {
                      final position = Duration(milliseconds: value.toInt());
                      await _audioPlayer.seek(position);
                    },
                  ),
                ),
                if (_errorMessage == null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
