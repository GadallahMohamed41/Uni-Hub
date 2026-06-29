import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:project_test2/core/theme.dart';
import 'package:project_test2/providers/auth_provider.dart';
import 'package:project_test2/models/user_model.dart';

class UniversityCardScreen extends StatelessWidget {
  const UniversityCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthProvider, UserModel?>((auth) => auth.currentUser);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('University Card'),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        foregroundColor: AppTheme.textMain,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'NATU-Students',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _InfoRow(label: 'Name', value: user?.name ?? '-'),
                _InfoRow(label: 'Department', value: user?.department ?? user?.bio ?? '-'),
                _InfoRow(label: 'Student ID', value: user?.studentId ?? '-'),
                _InfoRow(label: 'Email', value: user?.email ?? '-'),
                const Spacer(),
                Container(
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                  ),
                  child: const Center(
                    child: Icon(Icons.qr_code_rounded, color: Colors.white, size: 56),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Show this card at university services',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

