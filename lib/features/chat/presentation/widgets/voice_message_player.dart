import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
<<<<<<< HEAD
import 'package:project_test2/core/theme/theme.dart';
=======
import '../../../../core/theme.dart';
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c

class VoiceMessagePlayer extends StatefulWidget {
  final String audioUrl;
  final int durationSeconds;
  final bool isMe;
  final bool isDark;
  final VoidCallback? onPlay;
  final bool compact;

  const VoiceMessagePlayer({
    super.key,
    required this.audioUrl,
    required this.durationSeconds,
    required this.isMe,
    required this.isDark,
    this.onPlay,
    this.compact = false,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> with SingleTickerProviderStateMixin {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // For playback speed
  double _playbackSpeed = 1.0;

  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _stateSub;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Static realistic waveform pattern
  final List<double> _waveformHeights = [
    4, 7, 11, 16, 22, 14, 8, 5, 
    10, 18, 26, 18, 12, 6, 4,
    9, 15, 20, 14, 8, 12, 19, 
    24, 16, 10, 6, 9, 14, 8, 4
  ];

  @override
  void initState() {
    super.initState();
    _duration = Duration(seconds: widget.durationSeconds);
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initAudioPlayer();
  }

  Future<void> _initAudioPlayer() async {
    _audioPlayer = AudioPlayer();

    _positionSub = _audioPlayer.positionStream.listen((pos) {
      if (mounted) {
        setState(() => _position = pos);
      }
    });

    _durationSub = _audioPlayer.durationStream.listen((dur) {
      if (dur != null && mounted) {
        setState(() => _duration = dur);
      }
    });

    _stateSub = _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing &&
              state.processingState != ProcessingState.completed;
          _isLoading = state.processingState == ProcessingState.loading ||
              state.processingState == ProcessingState.buffering;
        });

        if (_isPlaying) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
          _pulseController.value = 0.0;
        }

        if (state.processingState == ProcessingState.completed) {
          _audioPlayer.seek(Duration.zero);
          _audioPlayer.pause();
          setState(() => _position = Duration.zero);
          _pulseController.stop();
          _pulseController.value = 0.0;
        }
      }
    });

    try {
      await _audioPlayer.setUrl(widget.audioUrl);
    } catch (e) {
      debugPrint("Error loading audio: $e");
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _audioPlayer.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      widget.onPlay?.call();
      await _audioPlayer.play();
    }
  }

  Future<void> _togglePlaybackSpeed() async {
    if (_playbackSpeed == 1.0) {
      _playbackSpeed = 1.5;
    } else if (_playbackSpeed == 1.5) {
      _playbackSpeed = 2.0;
    } else {
      _playbackSpeed = 1.0;
    }
    await _audioPlayer.setSpeed(_playbackSpeed);
    setState(() {});
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.isMe ? Colors.white : AppTheme.primary;
    final inactiveColor = widget.isMe 
        ? Colors.white.withValues(alpha: 0.4) 
        : (widget.isDark ? Colors.white38 : Colors.black26);
    final fgColor = widget.isMe ? Colors.white : (widget.isDark ? Colors.white : Colors.black87);
    final isCompact = widget.compact;

    return Container(
      width: isCompact ? 230 : 270,
      padding: EdgeInsets.only(
        top: isCompact ? 6 : 8,
        bottom: isCompact ? 2 : 4,
        left: 4,
        right: 4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Play/Pause button with pulse effect
          GestureDetector(
            onTap: _togglePlayPause,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_isPlaying)
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: isCompact ? 40 : 46,
                          height: isCompact ? 40 : 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: activeColor.withValues(alpha: 0.2),
                          ),
                        ),
                      );
                    },
                  ),
                Container(
                  width: isCompact ? 40 : 46,
                  height: isCompact ? 40 : 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.isMe 
                          ? [Colors.white, Colors.white.withValues(alpha: 0.9)]
                          : [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, 
                              color: widget.isMe ? AppTheme.primary : Colors.white,
                            ),
                          ),
                        )
                      : Icon(
                          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: widget.isMe ? AppTheme.primary : Colors.white,
                          size: isCompact ? 24 : 28,
                        ),
                ),
              ],
            ),
          ),
          SizedBox(width: isCompact ? 10 : 14),

          // Waveform & Controls
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Waveform Slider
                SizedBox(
                  height: isCompact ? 26 : 32,
                  child: _buildWaveform(activeColor, inactiveColor),
                ),
                SizedBox(height: isCompact ? 2 : 4),
                // Time & Speed Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_isPlaying ? _position : _duration),
                      style: TextStyle(
                        fontSize: isCompact ? 10 : 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: fgColor.withValues(alpha: 0.85),
                      ),
                    ),
                    GestureDetector(
                      onTap: _togglePlaybackSpeed,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 6 : 8,
                          vertical: isCompact ? 1 : 2,
                        ),
                        decoration: BoxDecoration(
                          color: activeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_playbackSpeed}x',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: activeColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveform(Color activeColor, Color inactiveColor) {
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Fake Waveform Visualizer
        ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [activeColor, activeColor, inactiveColor, inactiveColor],
              stops: [0.0, progress, progress, 1.0],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(bounds);
          },
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_waveformHeights.length, (index) {
              final h = _waveformHeights[index];
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 3,
                height: _isPlaying ? h : h * 0.4,
                decoration: BoxDecoration(
                  color: Colors.white, // Color applied via ShaderMask
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ),
        // Invisible Slider for seeking (thumb is visible)
        Positioned.fill(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 32,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              thumbColor: activeColor,
              overlayColor: activeColor.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _position.inMilliseconds.toDouble(),
              min: 0,
              max: _duration.inMilliseconds.toDouble() > 0
                  ? _duration.inMilliseconds.toDouble()
                  : 1.0,
              onChanged: (val) {
                _audioPlayer.seek(Duration(milliseconds: val.toInt()));
              },
            ),
          ),
        ),
      ],
    );
  }
}
