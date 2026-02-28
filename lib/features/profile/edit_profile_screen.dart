import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:project_test2/core/theme.dart';
import 'package:project_test2/core/app_snackbar.dart';
import 'package:project_test2/providers/auth_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _departmentCtrl;
  late final TextEditingController _studentIdCtrl;
  late final TextEditingController _collegeCtrl;
  late final TextEditingController _levelCtrl;
  bool _initialized = false;

  final Map<String, String> _universities = {
    'industrial_energy_technology': 'Industrial and Energy Technology',
    'applied_health_sciences': 'College of Applied Health Sciences',
  };
  final Map<String, String> _levels = {
    'level1': 'الفرقه الاولى',
    'level2': 'الفرقه الثانيه',
    'level3': 'الفرقه الثالثه',
    'level4': 'الفرقه الرابعه',
  };

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _bioCtrl = TextEditingController();
    _departmentCtrl = TextEditingController();
    _studentIdCtrl = TextEditingController();
    _collegeCtrl = TextEditingController();
    _levelCtrl = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    _nameCtrl.text = user.name;
    _bioCtrl.text = user.bio ?? '';
    _departmentCtrl.text = user.department ?? '';
    _studentIdCtrl.text = user.studentId ?? '';
    _collegeCtrl.text = user.universityKey == null ? '' : (_universities[user.universityKey!] ?? user.universityKey!);
    _levelCtrl.text = user.levelKey == null ? '' : (_levels[user.levelKey!] ?? user.levelKey!);
    _initialized = true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _departmentCtrl.dispose();
    _studentIdCtrl.dispose();
    _collegeCtrl.dispose();
    _levelCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.updateProfile(
      name: _nameCtrl.text.trim(),
      bio: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
      studentId: _studentIdCtrl.text.trim().isEmpty ? null : _studentIdCtrl.text.trim(),
    );

    if (!mounted) return;
    if (success) {
      AppSnackBar.showSuccess(context, 'Profile updated');
      Navigator.pop(context);
    } else {
      AppSnackBar.showError(context, auth.error ?? 'Failed to update profile');
    }
  }

  InputDecoration _fieldDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppTheme.textTertiary, fontSize: 14),
      prefixIcon: Icon(icon, color: AppTheme.primary, size: 22),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        foregroundColor: AppTheme.textMain,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: _fieldDecoration('Name', Icons.person_outline_rounded),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Name is required';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _collegeCtrl,
                  decoration: _fieldDecoration('College', Icons.apartment_rounded),
                  enabled: false,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _departmentCtrl,
                  decoration: _fieldDecoration('Department', Icons.school_outlined),
                  enabled: false,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _levelCtrl,
                  decoration: _fieldDecoration('Level', Icons.class_rounded),
                  enabled: false,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _studentIdCtrl,
                  decoration: _fieldDecoration('Student ID', Icons.badge_outlined),
                  enabled: user?.isAdmin == true,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _bioCtrl,
                  decoration: _fieldDecoration('Bio', Icons.info_outline_rounded),
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: auth.isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: auth.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'SAVE',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
