import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:project_test2/core/theme.dart';
import 'package:project_test2/core/page_transitions.dart';
import '../../providers/auth_provider.dart';
import '../../layout/main_layout.dart';
import '../../widgets/auth_wrapper.dart';
import '../../widgets/biometric_gate.dart';
import '../auth/login_screen.dart';
import '../../services/deep_link_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _progressController;
  
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotationAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _textSlideAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    
    // Logo Animation Controller
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Text Animation Controller
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Progress Animation Controller
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Logo Scale Animation
    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.elasticOut,
      ),
    );

    // Logo Rotation Animation
    _logoRotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Text Fade Animation
    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOut,
      ),
    );

    // Text Slide Animation
    _textSlideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Progress Animation
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeInOut,
      ),
    );

    // Start animations
    // Read AuthProvider synchronously BEFORE any async work
    // to avoid use_build_context_synchronously warnings
    final authProvider = context.read<AuthProvider>();
    _startAnimations(authProvider);
  }

  void _startAnimations(AuthProvider authProvider) async {
    // ① Start auth check immediately in parallel with animations
    final authFuture = authProvider.checkAuthState();

    // ② Run logo animation
    _logoController.forward();

    // ③ After 300ms, start text + progress animations
    await Future.delayed(const Duration(milliseconds: 300));
    _textController.forward();
    final progressFuture = _progressController.forward().orCancel;

    // ④ Wait for auth to finish (with a timeout of 1500ms to prevent hanging/lagging)
    try {
      await authFuture.timeout(const Duration(milliseconds: 1500));
    } catch (e, stack) {
      debugPrint('[Splash] Auth check error or timeout: $e\n$stack');
    }

    // ⑤ Wait for progress bar to visually complete
    try {
      await progressFuture;
    } catch (_) {}

    // ⑥ Wait for progress bar to visually complete
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    if (authProvider.isAuthenticated) {
      // ignore: use_build_context_synchronously
      Navigator.pushReplacement(
        context,
        PageTransitions.scaleTransition(
          BiometricGate(child: AuthWrapper(child: const MainLayout())),
        ),
      );
    } else {
      // ignore: use_build_context_synchronously
      Navigator.pushReplacement(
        context,
        PageTransitions.scaleTransition(const LoginScreen()),
      );
    }

    // Mark app as ready AFTER navigation completes and the new route's
    // first frame is rendered. This unblocks the Completer in DeepLinkService,
    // allowing any cold-start deep link to proceed with navigation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkService.instance.markAppReady();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                
                // Animated Logo — isolated repaint boundary
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _logoScaleAnimation.value,
                        child: Transform.rotate(
                          angle: _logoRotationAnimation.value * 0.1,
                          child: Container(
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.school_rounded,
                              size: 100,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Animated Text
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _textController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _textFadeAnimation.value,
                        child: Transform.translate(
                          offset: Offset(0, _textSlideAnimation.value),
                          child: Column(
                            children: [
                              const Text(
                                "NATU-Students",
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "Connecting Students Together",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color.fromRGBO(255, 255, 255, 0.9),
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                const Spacer(flex: 3),
                
                // Progress Indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60),
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, child) {
                        return Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: _progressAnimation.value,
                                backgroundColor: Colors.white.withValues(alpha: 0.3),
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                minHeight: 4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "${(_progressAnimation.value * 100).toInt()}%",
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color.fromRGBO(255, 255, 255, 0.8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
