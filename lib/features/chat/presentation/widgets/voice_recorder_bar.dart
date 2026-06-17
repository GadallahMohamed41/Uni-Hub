import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../../services/voice_recording_service.dart';

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
    with SingleTickerProviderStateMixin {
  late final VoiceRecordingService _recordingService;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  bool _isRecording = false;
  bool _isLocked = false;
  int _duration = 0;

  // Slide to cancel / Swipe to lock
  double _dragOffset = 0.0;
  double _verticalDragOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _recordingService = VoiceRecordingService();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _recordingService.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    // Recording is started externally via startRecording() when the user long-presses the mic button.
    // Do NOT auto-start here.
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _recordingService.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Called externally by the parent (via GlobalKey) right after the bar is shown.
  Future<void> startRecording() => _startRecording();

  Future<void> stopAndSend() => _stopAndSend();

  Future<void> cancelRecording() => _cancelRecording();

  bool get isLocked => _isLocked;

  void handleDragUpdate({required double dx, required double dy}) {
    if (_isLocked || !_isRecording) return;
    setState(() {
      if (dx < 0) {
        _dragOffset = dx;
      }
      if (dy < 0) {
        _verticalDragOffset = dy;
      }
    });

    if (_dragOffset < -100) {
      _cancelRecording();
    } else if (_verticalDragOffset < -80) {
      setState(() {
        _isLocked = true;
        _dragOffset = 0;
        _verticalDragOffset = 0;
      });
    }
  }

  Future<void> _startRecording() async {
    try {
      final hasPerm = await _recordingService.hasPermission();
      if (!hasPerm) return;

      await _recordingService.startRecording();
      setState(() {
        _isRecording = true;
        _isLocked = false;
        _dragOffset = 0;
        _verticalDragOffset = 0;
      });
      widget.onStateChanged?.call(true);
      _pulseController.repeat(reverse: true);
    } catch (e) {
      debugPrint('Failed to start recording: $e');
    }
  }

  Future<void> _stopAndSend() async {
    if (!_isRecording) return;
    _pulseController.stop();
    final path = await _recordingService.stopRecording();
    final dur = _duration;

    setState(() {
      _isRecording = false;
      _isLocked = false;
      _dragOffset = 0;
      _verticalDragOffset = 0;
    });
    widget.onStateChanged?.call(false);

    if (path != null && dur > 0) {
      await widget.onSend(path, dur);
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;
    _pulseController.stop();
    await _recordingService.cancelRecording();

    setState(() {
      _isRecording = false;
      _isLocked = false;
      _dragOffset = 0;
      _verticalDragOffset = 0;
      _duration = 0;
    });
    widget.onStateChanged?.call(false);

    widget.onCancel();
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_isLocked || !_isRecording) return;

    final dx = details.offsetFromOrigin.dx;
    final dy = details.offsetFromOrigin.dy;

    setState(() {
      if (dx < 0) {
        _dragOffset = dx;
      }
      if (dy < 0) {
        _verticalDragOffset = dy;
      }
    });

    // Cancel if slid left significantly
    if (_dragOffset < -100) {
      _cancelRecording();
    }
    // Lock if swiped up significantly
    else if (_verticalDragOffset < -80) {
      setState(() {
        _isLocked = true;
        _dragOffset = 0;
        _verticalDragOffset = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main Input Bar Replacement
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: const Icon(Icons.mic_rounded,
                        color: AppTheme.error, size: 20),
                  );
                },
              ),
              const SizedBox(width: 8),
              Text(
                _formatDuration(_duration),
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(width: 16),
              if (!_isLocked)
                Expanded(
                  child: Transform.translate(
                    offset: Offset(_dragOffset, 0),
                    child: Opacity(
                      opacity: (1 - (_dragOffset.abs() / 100)).clamp(0.0, 1.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Icon(Icons.chevron_left_rounded,
                              color: Colors.grey),
                          Text(
                            'Slide to cancel',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _cancelRecording,
                        child: const Text('Cancel',
                            style: TextStyle(color: AppTheme.error)),
                      ),
                      IconButton(
                        onPressed: _stopAndSend,
                        icon: const Icon(Icons.send_rounded,
                            color: AppTheme.primary),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Lock indicator UI (Swipe up)
        if (!_isLocked)
          Positioned(
            right: 0,
            bottom: 60 + _verticalDragOffset.abs(),
            child: Opacity(
              opacity: (1 - (_verticalDragOffset.abs() / 80)).clamp(0.0, 1.0),
              child: Column(
                children: [
                  const Icon(Icons.lock_open_rounded, color: Colors.grey),
                  const SizedBox(height: 4),
                  const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.grey),
                ],
              ),
            ),
          ),

        // The touch area for the mic when not locked
        if (!_isLocked && widget.showMicButton)
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onLongPressEnd: (_) {
                if (_isLocked) return;
                _stopAndSend();
              },
              onLongPressMoveUpdate: _onLongPressMoveUpdate,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic_rounded,
                    color: Colors.white, size: 24),
              ),
            ),
          ),
      ],
    );
  }
}
