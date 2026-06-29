import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/core/utils/app_snackbar.dart';
import 'package:project_test2/features/auth/presentation/providers/auth_provider.dart';
import 'package:project_test2/features/profile/data/models/user_model.dart';

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
  late final TextEditingController _linkgethub;
  late final TextEditingController _linklinledin;

  bool _initialized = false;

  bool? _isGitHubValid;
  bool? _isLinkedinValid;

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
    _linkgethub = TextEditingController();
    _linklinledin = TextEditingController();
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
    _collegeCtrl.text = user.universityKey == null
        ? ''
        : (_universities[user.universityKey!] ?? user.universityKey!);
    _levelCtrl.text = user.levelKey == null
        ? ''
        : (_levels[user.levelKey!] ?? user.levelKey!);

    _linkgethub.text = user.githubLink ?? '';
    _linklinledin.text = user.linkedinLink ?? '';

    _isGitHubValid = _linkgethub.text.isEmpty
        ? null
        : _linkgethub.text.toLowerCase().contains('github.com');
    _isLinkedinValid = _linklinledin.text.isEmpty
        ? null
        : _linklinledin.text.toLowerCase().contains('linkedin.com');

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
    _linkgethub.dispose();
    _linklinledin.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_linkgethub.text.isNotEmpty && _isGitHubValid == false) return;
    if (_linklinledin.text.isNotEmpty && _isLinkedinValid == false) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.updateProfile(
      name: _nameCtrl.text.trim(),
      bio: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
      studentId: _studentIdCtrl.text.trim().isEmpty
          ? null
          : _studentIdCtrl.text.trim(),
      githubLink:
          _linkgethub.text.trim().isEmpty ? null : _linkgethub.text.trim(),
      linkedinLink:
          _linklinledin.text.trim().isEmpty ? null : _linklinledin.text.trim(),
    );

    if (!mounted) return;
    if (success) {
      AppSnackBar.showSuccess(context, 'Profile updated');
      Navigator.pop(context);
    } else {
      AppSnackBar.showError(context, auth.error ?? 'Failed to update profile');
    }
  }

  InputDecoration _fieldDecoration(
      BuildContext context, String hint, IconData icon) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 14),
      prefixIcon: Icon(icon, color: AppTheme.primary, size: 22),
      filled: true,
      fillColor:
          isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.surfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
    );
  }

  InputDecoration _linkDecoration(
      BuildContext context, String hint, IconData icon, bool? isValid) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 14),
      prefixIcon: Icon(icon, color: AppTheme.primary, size: 22),
      suffixIcon: isValid == null
          ? null
          : Icon(isValid ? Icons.check_circle : Icons.cancel,
              color: isValid ? Colors.green : Colors.red),
      filled: true,
      fillColor:
          isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.surfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isValid == null
              ? AppTheme.primary
              : isValid
                  ? Colors.green
                  : Colors.red,
          width: 2,
        ),
      ),
    );
  }

  String? _validateGitHub(String? value) {
    if (value == null || value.isEmpty) return null;
    if (!value.toLowerCase().contains('github.com')) {
      return 'This is not a valid GitHub link';
    }
    return null;
  }

  String? _validateLinkedIn(String? value) {
    if (value == null || value.isEmpty) return null;
    if (!value.toLowerCase().contains('linkedin.com')) {
      return 'This is not a valid LinkedIn link';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthProvider, UserModel?>((auth) => auth.currentUser);
    final isLoading = context.select<AuthProvider, bool>((auth) => auth.isLoading);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.cardTheme.color ?? theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
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
                // Name
                TextFormField(
                  controller: _nameCtrl,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: _fieldDecoration(
                      context, 'Name', Icons.person_outline_rounded),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // College (disabled)
                TextFormField(
                  controller: _collegeCtrl,
                  style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  decoration: _fieldDecoration(
                      context, 'College', Icons.apartment_rounded),
                  enabled: false,
                ),
                const SizedBox(height: 14),

                // Department (disabled)
                TextFormField(
                  controller: _departmentCtrl,
                  style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  decoration: _fieldDecoration(
                      context, 'Department', Icons.school_outlined),
                  enabled: false,
                ),
                const SizedBox(height: 14),

                // Level (disabled)
                TextFormField(
                  controller: _levelCtrl,
                  style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  decoration:
                      _fieldDecoration(context, 'Level', Icons.class_rounded),
                  enabled: false,
                ),
                const SizedBox(height: 14),

                // Student ID
                TextFormField(
                  controller: _studentIdCtrl,
                  style: TextStyle(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: user?.isAdmin == true ? 1.0 : 0.6)),
                  decoration: _fieldDecoration(
                      context, 'Student ID', Icons.badge_outlined),
                  enabled: user?.isAdmin == true,
                ),
                const SizedBox(height: 14),

                // GitHub
                TextFormField(
                  controller: _linkgethub,
                  maxLines: 1,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: _linkDecoration(context, 'Add a link to GitHub',
                      Icons.add_link_outlined, _isGitHubValid),
                  onChanged: (value) {
                    setState(() {
                      _isGitHubValid = value.isEmpty
                          ? null
                          : value.toLowerCase().contains('github.com');
                    });
                  },
                  validator: _validateGitHub,
                ),
                const SizedBox(height: 14),

                // LinkedIn
                TextFormField(
                  controller: _linklinledin,
                  maxLines: 1,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: _linkDecoration(context, 'Add a link to LinkedIn',
                      Icons.add_link_outlined, _isLinkedinValid),
                  onChanged: (value) {
                    setState(() {
                      _isLinkedinValid = value.isEmpty
                          ? null
                          : value.toLowerCase().contains('linkedin.com');
                    });
                  },
                  validator: _validateLinkedIn,
                ),
                const SizedBox(height: 14),

                // Bio
                TextFormField(
                  controller: _bioCtrl,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: _fieldDecoration(
                      context, 'Bio', Icons.info_outline_rounded),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),

                // Save Button
                ElevatedButton(
                  onPressed: isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : const Text('SAVE',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
