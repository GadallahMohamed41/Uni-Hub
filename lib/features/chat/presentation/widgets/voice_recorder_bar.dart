import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/core/services/voice_recording_service.dart';
import 'package:project_test2/core/config/i18n.dart';
import 'package:record/record.dart';

class VoiceRecorderBar extends StatefulWidget {
  final Future<void> Function(String path, int durationSeconds) onSend;
  final VoidCallback onCancel;
  final ValueChanged<bool>? onStateChanged;
  final bool showMicButton;

  const VoiceRecorderBar({
    super.key,
    required this.onSend,
    required this.onCancel,
    this.onStateChanged,
    this.showMicButton = true,
  });

  @override
  State<VoiceRecorderBar> createState() => VoiceRecorderBarState();
}

class VoiceRecorderBarState extends State<VoiceRecorderBar>
    with TickerProviderStateMixin {
  late final VoiceRecordingService _recordingService;
  
  // Pulsing animation for the recording icon
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // Deletion animation controllers and animations
  late final AnimationController _deleteController;
  late Animation<double> _lidAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<double> _binFadeAnimation;

  bool _isRecording = false;
  bool _isLocked = false;
  bool _isPaused = false;
  bool _isDeleting = false;
  int _duration = 0;

  // Gesture tracking
  double _dragOffset = 0.0;
  double _verticalDragOffset = 0.0;

  // Amplitude data for real-time waveform
  final List<double> _recordedAmplitudes = [];
  StreamSubscription<Amplitude>? _amplitudeSub;
  StreamSubscription<int>? _durationSub;

  // Pre-send playback player and state
  AudioPlayer? _previewPlayer;
  bool _isPreviewPlaying = false;
  Duration _previewPosition = Duration.zero;
  Duration _previewDuration = Duration.zero;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _playerPositionSub;
  StreamSubscription? _playerDurationSub;

  @override
  void initState() {
    super.initState();
    _recordingService = VoiceRecordingService();

    // Pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Setup multi-stage trash deletion animation
    _deleteController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _lidAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.6).chain(CurveTween(curve: Curves.easeOut)), weight: 20),
      TweenSequenceItem(tween: ConstantTween(-0.6), weight: 30),
      TweenSequenceItem(tween: Tween(begin: -0.6, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 15),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 35),
    ]).animate(_deleteController);

    _slideAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 30),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
    ]).animate(_deleteController);

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.elasticIn)), weight: 25),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 15),
    ]).animate(_deleteController);

    _binFadeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 85),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 15),
    ]).animate(_deleteController);

    // Duration stream subscription
    _durationSub = _recordingService.durationStream.listen((d) {
      if (mounted) {
        setState(() => _duration = d);
      }
    });
  }

  @override
  void dispose() {
    _amplitudeSub?.cancel();
    _durationSub?.cancel();
    _pulseController.dispose();
    _deleteController.dispose();
    _recordingService.dispose();
    _disposePreviewPlayer();
    super.dispose();
  }

  void _disposePreviewPlayer() {
    _playerStateSub?.cancel();
    _playerPositionSub?.cancel();
    _playerDurationSub?.cancel();
    _previewPlayer?.dispose();
    _previewPlayer = null;
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatDurationMs(Duration d) {
    final s = d.inSeconds;
    return _formatDuration(s);
  }

  // --- External Control Methods (via GlobalKey) ---
  
  Future<void> startRecording() => _startRecording();
  Future<void> stopAndSend() => _stopAndSend();
  Future<void> cancelRecording() => _cancelRecording();
  bool get isLocked => _isLocked;

  Future<void> handleInterruption() async {
    if (_isRecording && !_isPaused) {
      setState(() {
        _isLocked = true;
      });
      await _pauseRecording();
    }
  }

  void handleDragUpdate({required double dx, required double dy}) {
    if (_isLocked || !_isRecording || _isDeleting) return;

    final isRtl = Directionality.of(context) == TextDirection.rtl;

    setState(() {
      // In RTL, cancel is swiping right (dx > 0). In LTR, cancel is swiping left (dx < 0).
      if (isRtl) {
        if (dx > 0) _dragOffset = dx;
      } else {
        if (dx < 0) _dragOffset = dx;
      }
      
      // Vertical lock is always swiping up (dy < 0)
      if (dy < 0) {
        _verticalDragOffset = dy;
      }
    });

    // Cancel threshold: 100 pixels
    if (isRtl && _dragOffset > 100) {
      _cancelRecording();
    } else if (!isRtl && _dragOffset < -100) {
      _cancelRecording();
    } 
    // Lock threshold: 80 pixels
    else if (_verticalDragOffset < -80) {
      HapticFeedback.mediumImpact();
      setState(() {
        _isLocked = true;
        _dragOffset = 0;
        _verticalDragOffset = 0;
      });
    }
  }

  // --- Recording Actions ---

  Future<void> _startRecording() async {
    try {
      final hasPerm = await _recordingService.hasPermission();
      if (!hasPerm) {
        // If permission denied, the service gracefully returns.
        // We can notify the parent screen state.
        widget.onCancel();
        return;
      }

      _disposePreviewPlayer();
      _recordedAmplitudes.clear();

      await _recordingService.startRecording();
      
      // Start listening to real-time amplitude for waveform
      _amplitudeSub = _recordingService.onAmplitudeChanged().listen((amp) {
        if (mounted && _isRecording && !_isPaused) {
          setState(() {
            // Normalizing dB values typically between -160 and 0 to 0.0 - 1.0 range
            double normalized = (amp.current + 160.0) / 160.0;
            normalized = normalized.clamp(0.05, 1.0);
            _recordedAmplitudes.add(normalized);
          });
        }
      });

      setState(() {
        _isRecording = true;
        _isLocked = false;
        _isPaused = false;
        _isDeleting = false;
        _duration = 0;
        _dragOffset = 0;
        _verticalDragOffset = 0;
      });
      
      widget.onStateChanged?.call(true);
      _pulseController.repeat(reverse: true);
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Failed to start voice recording: $e');
      widget.onCancel();
    }
  }

  Future<void> _stopAndSend() async {
    if (!_isRecording && _previewPlayer == null) return;
    
    _pulseController.stop();
    _amplitudeSub?.cancel();

    String? path;
    int dur = _duration;

    if (_isPaused || _previewPlayer != null) {
      // Audio is already stopped/paused, and loaded in player
      path = await _recordingService.stopRecording();
      _disposePreviewPlayer();
    } else {
      path = await _recordingService.stopRecording();
    }

    setState(() {
      _isRecording = false;
      _isLocked = false;
      _isPaused = false;
      _dragOffset = 0;
      _verticalDragOffset = 0;
    });

    widget.onStateChanged?.call(false);
    HapticFeedback.vibrate();

    if (path != null && dur > 0) {
      await widget.onSend(path, dur);
    } else {
      widget.onCancel();
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording && _previewPlayer == null) return;
    
    _pulseController.stop();
    _amplitudeSub?.cancel();
    _disposePreviewPlayer();

    // Trigger high-fidelity trash deletion animation
    setState(() {
      _isDeleting = true;
    });
    
    HapticFeedback.heavyImpact();
    await _recordingService.cancelRecording();

    // Play deletion animation
    await _deleteController.forward(from: 0.0);

    setState(() {
      _isRecording = false;
      _isLocked = false;
      _isPaused = false;
      _isDeleting = false;
      _dragOffset = 0;
      _verticalDragOffset = 0;
      _duration = 0;
    });

    _deleteController.reset();
    widget.onStateChanged?.call(false);
    widget.onCancel();
  }

  // --- Pre-send Playback Preview Controls ---

  Future<void> _pauseRecording() async {
    if (!_isRecording || _isPaused) return;
    HapticFeedback.mediumImpact();

    await _recordingService.pauseRecording();
    _amplitudeSub?.cancel();
    _pulseController.stop();

    setState(() {
      _isPaused = true;
    });

    // Prepare preview playback
    final path = await _recordingService.stopRecording(); // Writes file headers and stops segments
    if (path != null) {
      _initPreviewPlayer(path);
    }
  }

  Future<void> _resumeRecording() async {
    if (!_isRecording || !_isPaused) return;
    HapticFeedback.mediumImpact();

    _disposePreviewPlayer();

    await _recordingService.resumeRecording();

    // Re-start amplitude subscription
    _amplitudeSub = _recordingService.onAmplitudeChanged().listen((amp) {
      if (mounted && _isRecording && !_isPaused) {
        setState(() {
          double normalized = (amp.current + 160.0) / 160.0;
          normalized = normalized.clamp(0.05, 1.0);
          _recordedAmplitudes.add(normalized);
        });
      }
    });

    setState(() {
      _isPaused = false;
      _isPreviewPlaying = false;
    });
    
    _pulseController.repeat(reverse: true);
  }

  Future<void> _initPreviewPlayer(String path) async {
    _previewPlayer = AudioPlayer();
    
    _playerPositionSub = _previewPlayer!.positionStream.listen((pos) {
      if (mounted) setState(() => _previewPosition = pos);
    });

    _playerDurationSub = _previewPlayer!.durationStream.listen((dur) {
      if (dur != null && mounted) setState(() => _previewDuration = dur);
    });

    _playerStateSub = _previewPlayer!.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPreviewPlaying = state.playing &&
              state.processingState != ProcessingState.completed;
        });

        if (state.processingState == ProcessingState.completed) {
          _previewPlayer?.seek(Duration.zero);
          _previewPlayer?.pause();
          setState(() => _previewPosition = Duration.zero);
        }
      }
    });

    try {
      await _previewPlayer!.setFilePath(path);
    } catch (e) {
      debugPrint('Error loading voice preview file: $e');
    }
  }

  Future<void> _togglePreviewPlayPause() async {
    if (_previewPlayer == null) return;
    HapticFeedback.lightImpact();

    if (_isPreviewPlaying) {
      await _previewPlayer!.pause();
    } else {
      await _previewPlayer!.play();
    }
  }

  // --- Downsampling for playback waveform representation ---
  
  List<double> _downsampleAmplitudes(int targetSize) {
    if (_recordedAmplitudes.isEmpty) {
      return List.filled(targetSize, 0.08);
    }
    if (_recordedAmplitudes.length <= targetSize) {
      final res = List<double>.from(_recordedAmplitudes);
      while (res.length < targetSize) {
        res.add(0.08);
      }
      return res;
    }
    
    final List<double> res = [];
    final double bucketSize = _recordedAmplitudes.length / targetSize;
    
    for (int i = 0; i < targetSize; i++) {
      final start = (i * bucketSize).floor();
      final end = ((i + 1) * bucketSize).floor().clamp(0, _recordedAmplitudes.length);
      
      double sum = 0;
      int count = 0;
      for (int j = start; j < end; j++) {
        sum += _recordedAmplitudes[j];
        count++;
      }
      
      res.add(count > 0 ? (sum / count).clamp(0.08, 1.0) : 0.08);
    }
    return res;
  }

  // --- Widgets Builders ---

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    if (_isDeleting) {
      return _buildDeletionBar(isDark, isRtl);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Background Drawer Container
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark 
                  ? Colors.white.withValues(alpha: 0.08) 
                  : AppTheme.primary.withValues(alpha: 0.15),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 8),
              if (_isLocked) 
                _buildLockedDrawerControls(isDark, isRtl)
              else 
                _buildStandardRecordingControls(isDark, isRtl),
            ],
          ),
        ),

        // Lock indicator UI (Swipe up locking guide)
        if (!_isLocked && _isRecording && !_isDeleting)
          Positioned(
            right: isRtl ? null : 0,
            left: isRtl ? 0 : null,
            bottom: 60 + _verticalDragOffset.abs(),
            child: Opacity(
              opacity: (1 - (_verticalDragOffset.abs() / 80)).clamp(0.0, 1.0),
              child: SizedBox(
                width: 48,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_open_rounded, color: Colors.grey, size: 20),
                    const SizedBox(height: 2),
                    const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.grey, size: 18),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // 1. Standard holding layout (Slide to Cancel)
  Widget _buildStandardRecordingControls(bool isDark, bool isRtl) {
    return Expanded(
      child: Row(
        children: [
          // Pulse Mic Recording Dot & Timer
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(_duration),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(width: 12),

          // Real-time scrolling Waveform
          Expanded(
            child: _buildRealTimeWaveform(isDark),
          ),

          // Slide to Cancel gesture indicator
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: Opacity(
              opacity: (1 - (_dragOffset.abs() / 100)).clamp(0.0, 1.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isRtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                    color: Colors.grey,
                    size: 18,
                  ),
                  Text(
                    context.tr(en: 'Slide to cancel', ar: 'اسحب للإلغاء'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 48), // Padding to avoid overlap with mic button
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. Locked hands-free Drawer layout
  Widget _buildLockedDrawerControls(bool isDark, bool isRtl) {
    return Expanded(
      child: Row(
        children: [
          // Trash Icon Button
          IconButton(
            onPressed: _cancelRecording,
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 38, height: 38),
          ),
          
          // Waveform and timer panel
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _isPaused 
                  ? _buildPreviewPlayerWaveform(isDark) 
                  : Row(
                      children: [
                        // Red recording dot & Timer
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatDuration(_duration),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(width: 10),
                        // Active Waveform
                        Expanded(child: _buildRealTimeWaveform(isDark)),
                      ],
                    ),
            ),
          ),

          // Central controls (Pause/Play/Resume)
          if (!_isPaused)
            IconButton(
              onPressed: _pauseRecording,
              icon: const Icon(Icons.pause_circle_filled_rounded, color: AppTheme.primary, size: 30),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 38, height: 38),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Resume Recording Button
                IconButton(
                  onPressed: _resumeRecording,
                  icon: const Icon(Icons.mic_none_rounded, color: Colors.blueGrey, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                ),
                const SizedBox(width: 2),
                // Play/Pause Preview Button
                IconButton(
                  onPressed: _togglePreviewPlayPause,
                  icon: Icon(
                    _isPreviewPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, 
                    color: AppTheme.primary, 
                    size: 26,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                ),
              ],
            ),
          
          const SizedBox(width: 4),
          
          // Send Button
          GestureDetector(
            onTap: _stopAndSend,
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  // 3. Deletion animation drawer bar
  Widget _buildDeletionBar(bool isDark, bool isRtl) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : AppTheme.primary.withValues(alpha: 0.1),
        ),
      ),
      child: AnimatedBuilder(
        animation: _deleteController,
        builder: (context, child) {
          final double slide = _slideAnimation.value;
          final double scale = (1 - slide * 1.5).clamp(0.0, 1.0);
          
          // Compute horizontal slide offset based on RTL/LTR
          final double dxTranslation = isRtl 
              ? slide * 220.0 
              : -slide * 220.0;

          return Row(
            children: [
              const SizedBox(width: 8),
              // Vector Trash Bin
              _TrashBinWidget(
                lidRotation: _lidAnimation.value,
                shakeOffset: math.sin(_shakeAnimation.value * 3 * math.pi) * 6,
                opacity: _binFadeAnimation.value,
              ),
              
              // Recording info sliding into trash bin
              Expanded(
                child: Transform.translate(
                  offset: Offset(dxTranslation, 0),
                  child: Opacity(
                    opacity: scale,
                    child: Transform.scale(
                      scale: scale,
                      alignment: isRtl ? Alignment.centerLeft : Alignment.centerRight,
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDuration(_duration),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: _buildRealTimeWaveform(isDark)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Real-time scrolling audio waveform builder
  Widget _buildRealTimeWaveform(bool isDark) {
    final barsColor = isDark ? Colors.white60 : Colors.black38;
    
    // Display the last 30 amplitudes for scrolling effect
    final displayAmplitudes = _recordedAmplitudes.length > 30
        ? _recordedAmplitudes.sublist(_recordedAmplitudes.length - 30)
        : _recordedAmplitudes;

    return Center(
      child: SizedBox(
        height: 24,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (displayAmplitudes.isEmpty) ...[
              // Placeholder when no voice input is recorded yet
              ...List.generate(15, (index) => Container(
                width: 2,
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: barsColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(1),
                ),
              )),
            ] else ...[
              ...displayAmplitudes.map((amp) {
                final height = (amp * 24).clamp(3.0, 24.0);
                return Container(
                  width: 2.5,
                  height: height,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: barsColor,
                    borderRadius: BorderRadius.circular(1),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  // Preview Mode: Playback progress waveform + timer
  Widget _buildPreviewPlayerWaveform(bool isDark) {
    final activeColor = AppTheme.primary;
    final inactiveColor = isDark ? Colors.white24 : Colors.black12;
    final textStyle = TextStyle(
      fontSize: 11, 
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.white70 : Colors.black54,
    );

    final durationMs = _previewDuration.inMilliseconds;
    final positionMs = _previewPosition.inMilliseconds;
    final double progress = durationMs > 0 
        ? (positionMs / durationMs).clamp(0.0, 1.0) 
        : 0.0;

    // Downsample recorded voice notes to exactly 24 bars to fit perfectly in the drawer
    final downsampled = _downsampleAmplitudes(22);

    return Row(
      children: [
        // Play position timer
        Text(_formatDurationMs(_previewPosition), style: textStyle),
        const SizedBox(width: 8),
        
        // Progress Waveform
        Expanded(
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              if (_previewPlayer == null || durationMs <= 0) return;
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              
              final localPos = box.globalToLocal(details.globalPosition);
              // Roughly estimate slider position within the middle waveform area
              // Total width is about 150px
              final double relativeX = (localPos.dx - 80) / 120;
              final double targetPercent = relativeX.clamp(0.0, 1.0);
              _previewPlayer!.seek(Duration(milliseconds: (targetPercent * durationMs).toInt()));
            },
            child: SizedBox(
              height: 24,
              child: ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    colors: [activeColor, activeColor, inactiveColor, inactiveColor],
                    stops: [0.0, progress, progress, 1.0],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ).createShader(bounds);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: downsampled.map((amp) {
                    final h = (amp * 24).clamp(3.0, 24.0);
                    return Container(
                      width: 3,
                      height: h,
                      decoration: BoxDecoration(
                        color: Colors.white, // Overwritten by ShaderMask
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 8),
        // Total duration timer
        Text(_formatDurationMs(_previewDuration), style: textStyle),
      ],
    );
  }
}

// Custom vector Trash Bin animation drawer element
class _TrashBinWidget extends StatelessWidget {
  final double lidRotation;
  final double shakeOffset;
  final double opacity;

  const _TrashBinWidget({
    required this.lidRotation,
    required this.shakeOffset,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(shakeOffset, 0),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Trash Bin Body
              Positioned(
                bottom: 6,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.redAccent, width: 1.8),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Container(width: 1.5, height: 10, color: Colors.redAccent),
                      Container(width: 1.5, height: 10, color: Colors.redAccent),
                    ],
                  ),
                ),
              ),
              // Trash Bin Lid
              Positioned(
                bottom: 24,
                child: Transform.rotate(
                  angle: lidRotation,
                  origin: const Offset(-6, 3), // Pivot from left
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle
                      Container(
                        width: 5,
                        height: 2,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(1)),
                        ),
                      ),
                      // Lid base
                      Container(
                        width: 22,
                        height: 1.8,
                        color: Colors.redAccent,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
