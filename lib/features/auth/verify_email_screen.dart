import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:project_test2/core/theme.dart';
import 'package:project_test2/core/app_snackbar.dart';
import 'package:project_test2/core/page_transitions.dart';
import 'package:project_test2/core/i18n.dart';
import '../../providers/auth_provider.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _checking = false;
  bool _resending = false;

  // بيرسل تاني civic pipeline-mail تأكيد للإيميل
  Future<void> _resend() async {
    setState(() => _resending = true);
    await context.read<AuthProvider>().resendEmailVerification();
    if (!mounted) return;
    setState(() => _resending = false);
    AppSnackBar.showSuccess(
      context,
      context.tr(en: 'Verification email sent', ar: 'تم إرسال رسالة التأكيد'),
    );
  }

  // بيشيّك إذا الإيميل اتأكد ويرجّعك للّوجين لو تمام
  Future<void> _checkVerified() async {
    setState(() => _checking = true);
    final ok = await context.read<AuthProvider>().refreshEmailVerified();
    if (!mounted) return;
    setState(() => _checking = false);
    if (ok) {
      AppSnackBar.showSuccess(
        context,
        context.tr(
          en: 'Email verified successfully. Please login.',
          ar: 'تم تأكيد البريد بنجاح. من فضلك سجّل الدخول.',
        ),
      );
      Navigator.pushAndRemoveUntil(
        context,
        PageTransitions.slideTransition(const LoginScreen(), fromRight: false),
        (_) => false,
      );
    } else {
      AppSnackBar.showInfo(
        context,
        context.tr(
          en: 'Not verified yet. Please check your email.',
          ar: 'لم يتم التأكيد بعد. من فضلك افحص بريدك.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // بتبنّي شاشة تأكيد الإيميل وتعامل الأزرار
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textMain),
          onPressed: () async {
            final auth = context.read<AuthProvider>();
            await auth.signOut(context);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).clearSnackBars();
            AppSnackBar.showInfo(
              context,
              context.tr(
                en: 'You have signed out. Please sign in again.',
                ar: 'تم تسجيل الخروج. من فضلك سجّل الدخول مرة أخرى.',
              ),
            );
            Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const SignUpScreen()),
              (route) => false,
            );
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.mark_email_unread_rounded, color: Colors.white, size: 56),
              ),
              const SizedBox(height: 20),
              Text(
                context.tr(en: 'Confirm your email', ar: 'تأكيد البريد الإلكتروني'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMain),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  en: 'We sent a confirmation message to:',
                  ar: 'لقد أرسلنا رسالة تأكيد إلى:',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                widget.email,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textMain),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _checking ? null : _checkVerified,
                child: _checking
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(context.tr(en: 'I verified', ar: 'تم التأكيد')),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _resending ? null : _resend,
                child: _resending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(context.tr(en: 'Resend email', ar: 'إعادة الإرسال')),
              ),
              const Spacer(),
              Text(
                context.tr(
                  en: 'Tip: check Spam/Junk if you can’t find it.',
                  ar: 'ملحوظة: افحص الرسائل غير المرغوب فيها إذا لم تجدها.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
