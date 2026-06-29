import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:project_test2/core/utils/app_snackbar.dart';
import 'package:project_test2/core/utils/page_transitions.dart';
import 'package:project_test2/features/auth/presentation/screens/login_screen.dart';
import 'package:project_test2/features/auth/presentation/providers/auth_provider.dart';

class AuthWrapper extends StatefulWidget {
  final Widget child;
  
  const AuthWrapper({super.key, required this.child});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}
class _AuthWrapperState extends State<AuthWrapper> {
  bool _hasShownDeletionMessage = false;
  AuthProvider? _authProvider;
  @override
  void initState() {
    super.initState();
    // Listen to auth provider changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _setupAuthListener();
      }
    });
  }

  void _setupAuthListener() {
    _authProvider = context.read<AuthProvider>();
    _authProvider?.addListener(_onAuthStateChanged);
  }

  void _onAuthStateChanged() {
    final authProvider = _authProvider;
    if (authProvider == null) return;
    
    // Check if user was logged out due to account deletion
    if (authProvider.currentUser == null && 
        authProvider.error == 'Account deleted or no longer exists' &&
        !_hasShownDeletionMessage) {
      
      _hasShownDeletionMessage = true;
      
      // Show message to user
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppSnackBar.showError(context, 'تم حذف حسابك م');
          
          // Navigate to login screen after showing the message
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.pushAndRemoveUntil(
                context,
                PageTransitions.slideTransition(const LoginScreen(), fromRight: false),
                (_) => false,
              );
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}