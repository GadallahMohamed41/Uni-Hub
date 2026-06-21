import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_test2/core/theme.dart';
import 'package:project_test2/services/biometric_service.dart';

/// Wraps the main app content and blocks access with a biometric prompt
/// on startup and whenever the app is resumed from the background.
class BiometricGate extends StatefulWidget {
  final Widget child;

  const BiometricGate({super.key, required this.child});

  @override
  State<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<BiometricGate>
    with WidgetsBindingObserver {
  bool _locked = false;
  bool _isAuthenticating = false;
  bool _initialized = false;
  // Track if lock was triggered by coming back from background (resume)
  bool _lockedOnResume = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkOnStartup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Called when the app lifecycle changes (e.g. comes back from background)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App went to background — lock immediately
      _lockImmediately();
    } else if (state == AppLifecycleState.resumed && _initialized) {
      if (_isAuthenticating) return; // Ignore resume events caused by the biometric dialog itself
      _authenticateOnResume();
    }
  }

  Future<void> _lockImmediately() async {
    final enabled = await BiometricService.instance.isBiometricEnabled();
    if (enabled && mounted) {
      setState(() {
        _locked = true;
        _lockedOnResume = true;
      });
    }
  }

  Future<void> _authenticateOnResume() async {
    final enabled = await BiometricService.instance.isBiometricEnabled();
    if (enabled && _locked && !_isAuthenticating) {
      await _authenticate(fromResume: true);
    }
  }

  Future<void> _checkOnStartup() async {
    final enabled = await BiometricService.instance.isBiometricEnabled();
    if (mounted) {
      if (enabled) {
        setState(() {
          _locked = true;
          _lockedOnResume = false;
        });
        await _authenticate(fromResume: false);
      }
      setState(() => _initialized = true);
    }
  }

  Future<void> _authenticate({bool fromResume = false}) async {
    if (_isAuthenticating) return;
    setState(() => _isAuthenticating = true);

    final success = await BiometricService.instance.authenticate(
      reason: 'Authenticate to access the app',
    );

    if (mounted) {
      if (success) {
        setState(() {
          _locked = false;
          _lockedOnResume = false;
        });
        // Delay resetting _isAuthenticating to avoid infinite loop of biometric prompts.
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) setState(() => _isAuthenticating = false);
        });
      } else {
        setState(() => _isAuthenticating = false);
        // If came back from background and user cancelled/dismissed → close app
        if (fromResume || _lockedOnResume) {
          SystemNavigator.pop();
        }
        // On startup failure → stay on lock screen so user can retry
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_locked) return widget.child;

    // ── Lock Screen Overlay ──────────────────────────────────────────────
    return PopScope(
      // Prevent back button from bypassing the lock
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _lockedOnResume) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Lock icon with pulsing glow
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.95, end: 1.05),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeInOut,
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.2),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.fingerprint_rounded,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  const Text(
                    'App Locked',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'Verify your fingerprint to continue',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Retry button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isAuthenticating
                            ? null
                            : () => _authenticate(fromResume: _lockedOnResume),
                        icon: _isAuthenticating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme.primary),
                                ),
                              )
                            : const Icon(Icons.fingerprint_rounded,
                                color: AppTheme.primary),
                        label: Text(
                          _isAuthenticating ? 'Authenticating…' : 'Try Again',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),

                  // Exit button — only shown when locked from background
                  if (_lockedOnResume) ...[
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: () => SystemNavigator.pop(),
                      child: Text(
                        'Exit App',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
