import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:project_test2/core/theme.dart';
import 'package:project_test2/core/page_transitions.dart';
import 'package:project_test2/core/app_snackbar.dart';
import '../../core/animations.dart';
import '../../providers/auth_provider.dart';
import '../splash/loading_screen.dart';
import 'login_screen.dart';
import 'verify_email_screen.dart';

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
    // بننظّف الكنترولرز لما الشاشة تتقفل
    _nameController.dispose();
    _idController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // بيجهّز الداتا وينادي التسجيل وبعدين يفتح شاشة تأكيد الإيميل
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
      AppSnackBar.showInfo(context, 'Please confirm your email then continue');
      Navigator.pushReplacement(
        context,
        PageTransitions.slideTransition(
          VerifyEmailScreen(email: _emailController.text.trim()),
          fromRight: true,
        ),
      );
    } else {
      setState(() => _isLoading = false);
      AppSnackBar.showError(context, authProvider.error ?? 'Sign up failed');
      authProvider.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    // بتبنّي شاشة التسجيل بكل الحقول والأزرار
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.background,
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
                          color: Colors.white.withOpacity(0.2),
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
                    const FadeInAnimation(
                      delay: 200,
                      child: Text(
                        "Join Us Now",
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
                        "Create your university account",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
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
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
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
                            const Text(
                              "Create Account",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textMain,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Fill in your details to get started",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 28),
                            
                            _buildModernInput(
                              "Full Name",
                              Icons.person_outline,
                              _nameController,
                              validator: (value) {
                                // بيشيّك إن الاسم مش فاضي
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            _buildModernInput(
                              "Student ID",
                              Icons.badge_outlined,
                              _idController,
                              isNumber: true,
                              validator: (value) {
                                // بيشيّك إن الرقم الجامعي مش فاضي
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your student ID';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            _buildModernInput(
                              "University Email",
                              Icons.email_outlined,
                              _emailController,
                              validator: (value) {
                                // بيشيّك إن الإيميل مش فاضي وفيه @
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
                                fillColor: AppTheme.surfaceVariant,
                              ),
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
                                // بيشيّك إن الكلية اختيرت
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
                                fillColor: AppTheme.surfaceVariant,
                              ),
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
                                // بيشيّك إن القسم اختير لو الكلية صناعية
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
                                fillColor: AppTheme.surfaceVariant,
                              ),
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
                                // بيشيّك إن الفرقة اختيرت
                                if (value == null || value.isEmpty) {
                                  return 'Please select your level';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            
                            _buildModernInput(
                              "Password",
                              Icons.lock_outline,
                              _passwordController,
                              isPassword: true,
                              validator: (value) {
                                // بيشيّك إن الباسورد مش فاضي وطوله 6 حروف على الأقل
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
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushReplacement(
                            context,
                            PageTransitions.slideTransition(const LoginScreen(), fromRight: false),
                          ),
                          child: Text(
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

  // بيبني حقل إدخال حديث مع أيقونة وتصميم متجاوب
  Widget _buildModernInput(
    String hint,
    IconData icon,
    TextEditingController controller, {
    bool isPassword = false,
    bool isNumber = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      validator: validator,
      style: const TextStyle(color: AppTheme.textMain),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppTheme.textTertiary, fontSize: 14),
        prefixIcon: Icon(icon, color: AppTheme.primary, size: 22),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppTheme.textTertiary,
                ),
                // بيغيّر وضع إظهار/إخفاء الباسورد
                onPressed: () => setState(() {
                  _obscurePassword = !_obscurePassword;
                }),
              )
            : null,
        filled: true,
        fillColor: AppTheme.surfaceVariant,
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
