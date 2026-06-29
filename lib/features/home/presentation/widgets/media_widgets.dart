import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:project_test2/core/theme/theme.dart';

class FullscreenImagesPage extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const FullscreenImagesPage({super.key, required this.urls, this.initialIndex = 0});

  @override
  State<FullscreenImagesPage> createState() => _FullscreenImagesPageState();
}

class _FullscreenImagesPageState extends State<FullscreenImagesPage> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.urls.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final url = widget.urls[i];
                return InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.contain,
                      placeholder: (c, _) => const Center(
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                      errorWidget: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_rounded, color: Colors.white),
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 10,
              left: 10,
              child: _ControlCircle(
                icon: Icons.close_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            if (widget.urls.length > 1)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_index + 1}/${widget.urls.length}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AdaptiveMediaCarousel extends StatefulWidget {
  final List<String> urls;
  final double minHeight;
  final double maxHeight;
  final BorderRadius borderRadius;
  const AdaptiveMediaCarousel({
    super.key,
    required this.urls,
    required this.minHeight,
    required this.maxHeight,
    required this.borderRadius,
  });

  @override
  State<AdaptiveMediaCarousel> createState() => _AdaptiveMediaCarouselState();
}

class _AdaptiveMediaCarouselState extends State<AdaptiveMediaCarousel> {
  int _index = 0;
  final Map<String, double> _ratios = {};
  final Map<String, ImageStream> _streams = {};
  final Map<String, ImageStreamListener> _listeners = {};

  void _resolveRatio(String url) {
    if (_ratios.containsKey(url) || _streams.containsKey(url)) return;
    final provider = CachedNetworkImageProvider(url);
    final stream = provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (w > 0 && h > 0) {
        final ratio = math.max(0.75, math.min(1.65, w / h));
        if (mounted) setState(() => _ratios[url] = ratio);
      }
      stream.removeListener(listener);
      _streams.remove(url);
      _listeners.remove(url);
    }, onError: (_, __) {
      stream.removeListener(listener);
      _streams.remove(url);
      _listeners.remove(url);
    });
    _streams[url] = stream;
    _listeners[url] = listener;
    stream.addListener(listener);
  }

  @override
  void dispose() {
    for (final entry in _streams.entries) {
      final l = _listeners[entry.key];
      if (l != null) entry.value.removeListener(l);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    if (urls.isEmpty) return const SizedBox.shrink();

    final safeIndex = _index.clamp(0, urls.length - 1);
    final currentUrl = urls[safeIndex];
    _resolveRatio(currentUrl);
    final ratio = _ratios[currentUrl] ?? 4 / 3;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = (width / ratio).clamp(widget.minHeight, widget.maxHeight);
        return ClipRRect(
          borderRadius: widget.borderRadius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: height,
            width: double.infinity,
            color: AppTheme.surfaceVariant,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  itemCount: urls.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final url = urls[i];
                    _resolveRatio(url);
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        // Blurred background
                        CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          memCacheWidth: 80,
                        ),
                        BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.22),
                          ),
                        ),
                        // Sharp foreground image
                        CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          fadeInDuration: const Duration(milliseconds: 140),
                          fadeOutDuration: const Duration(milliseconds: 80),
                          memCacheWidth: 1000,
                          placeholder: (c, _) => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          errorWidget: (context, url, error) =>
                              const Center(child: Icon(Icons.broken_image_rounded, color: Colors.white)),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => FullscreenImagesPage(urls: urls, initialIndex: i),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
                if (urls.length > 1)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${safeIndex + 1}/${urls.length}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                  ),
                if (urls.length > 1)
                  Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(urls.length, (i) {
                        final active = i == safeIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 12 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: active ? 0.95 : 0.55),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class InlineVideo extends StatefulWidget {
  final String url;
  final BoxFit fit;
  const InlineVideo({super.key, required this.url, this.fit = BoxFit.contain});
  @override
  State<InlineVideo> createState() => _InlineVideoState();
}

class _InlineVideoState extends State<InlineVideo> {
  static final ValueNotifier<String?> _activeUrl = ValueNotifier<String?>(null);

  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _muted = true;
  bool _playing = false;

  void _pause() {
    if (!_ready) return;
    if (!_controller.value.isPlaying && !_playing) return;
    _controller.pause();
    if (mounted) setState(() => _playing = false);
  }

  void _play() {
    if (!_ready) return;
    if (_controller.value.isPlaying && _playing) return;
    _controller.play();
    if (mounted) setState(() => _playing = true);
  }

  @override
  void initState() {
    super.initState();
    _activeUrl.addListener(_onActiveChanged);
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(true)
      ..initialize().then((_) {
        _controller.setVolume(_muted ? 0.0 : 1.0);
        if (mounted) setState(() => _ready = true);
      });
  }

  void _onActiveChanged() {
    final active = _activeUrl.value;
    if (active == null) return;
    if (active != widget.url) {
      _pause();
    }
  }

  @override
  void dispose() {
    if (_activeUrl.value == widget.url) {
      _activeUrl.value = null;
    }
    _activeUrl.removeListener(_onActiveChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aspect = _ready && _controller.value.size.width > 0
        ? _controller.value.aspectRatio
        : 16 / 9;
    return VisibilityDetector(
      key: ValueKey('inline_video_${widget.url}'),
      onVisibilityChanged: (info) {
        if (!_ready) return;
        final fraction = info.visibleFraction;
        if (fraction >= 0.65) {
          if (!_playing) {
            _activeUrl.value = widget.url;
            _play();
          }
        } else {
          if (_playing) _pause();
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: aspect,
          child: Stack(
            children: [
              Positioned.fill(
                child: _ready
                    ? FittedBox(
                        fit: widget.fit,
                        child: SizedBox(
                          width: _controller.value.size.width,
                          height: _controller.value.size.height,
                          child: VideoPlayer(_controller),
                        ),
                      )
                    : Container(
                        color: Colors.black,
                        child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                      ),
              ),
              if (!_ready)
                const SizedBox.shrink()
              else
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        _pause();
                        if (_activeUrl.value == widget.url) {
                          _activeUrl.value = null;
                        }
                        final pos = _controller.value.position;
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FullscreenVideoPage(url: widget.url, startPosition: pos, muted: _muted),
                          ),
                        );
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                ),
              Positioned(
                top: 10,
                right: 10,
                child: _ControlCircle(
                  icon: _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  onTap: () {
                    setState(() {
                      _muted = !_muted;
                      _controller.setVolume(_muted ? 0.0 : 1.0);
                    });
                  },
                ),
              ),
              Positioned(
                bottom: 10,
                left: 10,
                child: _ControlCircle(
                  size: 44,
                  icon: _controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  onTap: () {
                    if (!_ready) return;
                    if (_controller.value.isPlaying) {
                      _pause();
                    } else {
                      _activeUrl.value = widget.url;
                      _play();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlCircle extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  const _ControlCircle({required this.icon, required this.onTap, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: Colors.white, size: size * 0.58),
        ),
      ),
    );
  }
}

class FullscreenVideoPage extends StatefulWidget {
  final String url;
  final Duration startPosition;
  final bool muted;
  const FullscreenVideoPage({super.key, required this.url, this.startPosition = Duration.zero, this.muted = true});

  @override
  State<FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<FullscreenVideoPage> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  late bool _muted;

  @override
  void initState() {
    super.initState();
    _muted = widget.muted;
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(true)
      ..initialize().then((_) async {
        await _controller.seekTo(widget.startPosition);
        await _controller.setVolume(_muted ? 0.0 : 1.0);
        await _controller.play();
        if (mounted) setState(() => _ready = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aspect = _ready && _controller.value.size.width > 0 ? _controller.value.aspectRatio : 16 / 9;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: aspect,
                child: _ready
                    ? FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: _controller.value.size.width,
                          height: _controller.value.size.height,
                          child: VideoPlayer(_controller),
                        ),
                      )
                    : const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: _ControlCircle(
                icon: Icons.close_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: _ControlCircle(
                icon: _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                onTap: () {
                  setState(() {
                    _muted = !_muted;
                    _controller.setVolume(_muted ? 0.0 : 1.0);
                  });
                },
              ),
            ),
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: _ControlCircle(
                  size: 56,
                  icon: _controller.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  onTap: () {
                    if (_controller.value.isPlaying) {
                      _controller.pause();
                    } else {
                      _controller.play();
                    }
                    setState(() {});
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
