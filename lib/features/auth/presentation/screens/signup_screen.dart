import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/core/utils/page_transitions.dart';
import 'package:project_test2/core/utils/app_snackbar.dart';
import 'package:project_test2/core/config/i18n.dart';
import 'package:project_test2/core/utils/animations.dart';
import 'package:project_test2/features/auth/presentation/providers/auth_provider.dart';
import 'package:project_test2/features/auth/presentation/screens/login_screen.dart';
import 'package:project_test2/features/auth/presentation/screens/verify_email_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _selectedUniversity;
  String? _selectedDepartment;
  String? _selectedLevel;
  final Map<String, String> _universities = {
    'Industrial and Energy Technology': 'industrial_energy_technology',
    'College of Applied Health Sciences': 'applied_health_sciences',
  };
  final Map<String, List<Map<String, String>>> _departmentsByUniversity = {
    'industrial_energy_technology': [
      {'label': 'تكنولوجيه المعلومات', 'key': 'it'},
      {'label': 'أجهزه', 'key': 'devices'},
      {'label': 'شبكات', 'key': 'networks'},
      {'label': 'تصنيع غذائي', 'key': 'food_industry'},
    ],
    'applied_health_sciences': [],
  };
  final Map<String, String> _levels = {
    'الفرقه الاولى': 'level1',
    'الفرقه الثانيه': 'level2',
    'الفرقه الثالثه': 'level3',
    'الفرقه الرابعه': 'level4',
  };

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final deptLabel = (_selectedUniversity != null && _selectedDepartment != null)
        ? (_departmentsByUniversity[_selectedUniversity!]!
            .firstWhere((m) => m['key'] == _selectedDepartment, orElse: () => {'label': ''})['label'])
        : '';
    final success = await authProvider.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      name: _nameController.text.trim(),
      studentId: _idController.text.trim(),
      department: deptLabel?.toString().trim().isEmpty == true ? null : deptLabel,
      universityKey: _selectedUniversity,
      departmentKey: _selectedDepartment,
      levelKey: _selectedLevel,
    );

    if (!mounted) return;

    if (success) {
      setState(() => _isLoading = false);
      AppSnackBar.showInfo(
        context,
        context.tr(
          en: 'Please confirm your email then continue',
          ar: 'من فضلك أكد بريدك الإلكتروني ثم تابع',
        ),
      );
      Navigator.pushReplacement(
        context,
        PageTransitions.slideTransition(
          VerifyEmailScreen(email: _emailController.text.trim()),
          fromRight: true,
        ),
      );
    } else {
      setState(() => _isLoading = false);
      AppSnackBar.showError(
        context,
        authProvider.error ??
            context.tr(en: 'Sign up failed', ar: 'فشل إنشاء الحساب'),
      );
      authProvider.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Professional Gradient Header
          Container(
            height: size.height * 0.4,
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeInAnimation(
                      delay: 100,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 70,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FadeInAnimation(
                      delay: 200,
                      child: Text(
                        context.tr(en: "Join Us Now", ar: "انضم إلينا الآن"),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeInAnimation(
                      delay: 250,
                      child: Text(
                        context.tr(
                          en: "Create your university account",
                          ar: "أنشئ حسابك الجامعي",
                        ),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Floating Sign Up Card
          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  SizedBox(height: size.height * 0.33),
                  ScaleAnimation(
                    delay: 300,
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color ?? theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              context.tr(
                                en: "Create Account",
                                ar: "إنشاء حساب",
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Fill in your details to get started",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 28),
                            
                            _buildModernInput(
                              context,
                              "Full Name",
                              Icons.person_outline,
                              _nameController,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            _buildModernInput(
                              context,
                              "Student ID",
                              Icons.badge_outlined,
                              _idController,
                              isNumber: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your student ID';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            _buildModernInput(
                              context,
                              "University Email",
                              Icons.email_outlined,
                              _emailController,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!value.contains('@')) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Select College',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.surfaceVariant,
                              ),
                              dropdownColor: theme.cardTheme.color ?? theme.colorScheme.surface,
                              initialValue: _selectedUniversity,
                              items: _universities.entries
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e.value,
                                      child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                setState(() {
                                  _selectedUniversity = v;
                                  _selectedDepartment = null;
                                });
                              },
                              selectedItemBuilder: (context) {
                                return _universities.entries
                                    .map(
                                      (e) => Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ),
                                    )
                                    .toList();
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select your college';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Select Department',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.surfaceVariant,
                              ),
                              dropdownColor: theme.cardTheme.color ?? theme.colorScheme.surface,
                              initialValue: _selectedDepartment,
                              items: (_selectedUniversity == null
                                      ? <DropdownMenuItem<String>>[]
                                      : _departmentsByUniversity[_selectedUniversity!]!
                                          .map(
                                            (m) => DropdownMenuItem(
                                              value: m['key'],
                                              child: Text(m['label']!, maxLines: 1, overflow: TextOverflow.ellipsis),
                                            ),
                                          )
                                          .toList()),
                              onChanged: (v) => setState(() => _selectedDepartment = v),
                              validator: (value) {
                                if (_selectedUniversity == 'industrial_energy_technology') {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select your department';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Select Level',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.surfaceVariant,
                              ),
                              dropdownColor: theme.cardTheme.color ?? theme.colorScheme.surface,
                              initialValue: _selectedLevel,
                              items: _levels.entries
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e.value,
                                      child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() => _selectedLevel = v),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select your level';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            
                            _buildModernInput(
                              context,
                              "Password",
                              Icons.lock_outline,
                              _passwordController,
                              isPassword: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 30),
                            
                            ElevatedButton(
                              onPressed: _isLoading ? null : _handleSignUp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      "CREATE ACCOUNT",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height:5),
                  
                  FadeInAnimation(
                    delay: 400,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Already have an account? ",
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushReplacement(
                            context,
                            PageTransitions.slideTransition(const LoginScreen(), fromRight: false),
                          ),
                          child: const Text(
                            "Login Here",
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernInput(
    BuildContext context,
    String hint,
    IconData icon,
    TextEditingController controller, {
    bool isPassword = false,
    bool isNumber = false,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      validator: validator,
      style: TextStyle(color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 14),
        prefixIcon: Icon(icon, color: AppTheme.primary, size: 22),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                onPressed: () => setState(() {
                  _obscurePassword = !_obscurePassword;
                }),
              )
            : null,
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.error, width: 2),
        ),
      ),
    );
  }
}
