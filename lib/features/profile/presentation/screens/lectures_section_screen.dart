import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/core/utils/app_snackbar.dart';
import 'package:project_test2/features/auth/presentation/providers/auth_provider.dart';
import 'package:project_test2/features/profile/data/models/user_model.dart';
import 'package:project_test2/core/services/storage_service.dart';
import 'package:project_test2/core/services/firestore_service.dart';
import 'package:project_test2/core/utils/animations.dart';
import 'package:project_test2/features/profile/presentation/screens/schedule_image_viewer_screen.dart';

class LecturesSectionScreen extends StatefulWidget {
  const LecturesSectionScreen({super.key});

  @override
  State<LecturesSectionScreen> createState() => _LecturesSectionScreenState();
}

class _LecturesSectionScreenState extends State<LecturesSectionScreen> {
  final StorageService _storage = StorageService();
  final FirestoreService _firestoreService = FirestoreService();
  String? _selectedUniversity;
  String? _selectedDepartment;
  String? _selectedLevel;
  bool _initialized = false;
  int? _lastSeenScheduleVersion;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final user = context.read<AuthProvider>().currentUser;
      if (user != null) {
        _selectedUniversity = user.universityKey ?? _selectedUniversity;
        _selectedDepartment = user.departmentKey ?? _selectedDepartment;
        _selectedLevel = user.levelKey ?? _selectedLevel;
      }
      _initialized = true;
    }
  }

  String _withCacheBuster(String url, int v) {
    if (url.contains('?')) return '$url&v=$v';
    return '$url?v=$v';
  }

  String _universityLabel(String key) {
    for (final e in _universities.entries) {
      if (e.value == key) return e.key;
    }
    return key;
  }

  String _departmentLabel(String universityKey, String departmentKey) {
    final list = _departmentsByUniversity[universityKey] ?? const [];
    for (final item in list) {
      if (item['key'] == departmentKey) return item['label'] ?? departmentKey;
    }
    return departmentKey;
  }

  String _levelLabel(String levelKey) {
    for (final e in _levels.entries) {
      if (e.value == levelKey) return e.key;
    }
    return levelKey;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = context.select<AuthProvider, UserModel?>((auth) => auth.currentUser);
    final userUniversity = user?.universityKey;
    final userDepartment = user?.departmentKey;
    final userLevel = user?.levelKey;
    final lockedToProfile = userUniversity != null && userDepartment != null && userLevel != null;

    if (lockedToProfile &&
        (_selectedUniversity != userUniversity || _selectedDepartment != userDepartment || _selectedLevel != userLevel)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedUniversity = userUniversity;
          _selectedDepartment = userDepartment;
          _selectedLevel = userLevel;
        });
      });
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        elevation: 0,
        title: const Text(
          'جدول المحاضرات',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FadeInAnimation(
          delay: 100,
          child: Column(
            children: [
              if (lockedToProfile && _selectedUniversity != null && _selectedDepartment != null && _selectedLevel != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color ?? theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _universityLabel(_selectedUniversity!),
                        style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _departmentLabel(_selectedUniversity!, _selectedDepartment!),
                        style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _levelLabel(_selectedLevel!),
                        style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'اختر الجامعة',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: theme.cardTheme.color ?? theme.colorScheme.surface,
                        ),
                        dropdownColor: theme.cardTheme.color ?? theme.colorScheme.surface,
                        initialValue: _selectedUniversity,
                        items: _universities.entries
                            .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key)))
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            _selectedUniversity = v;
                            _selectedDepartment = null;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'اختر القسم',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: theme.cardTheme.color ?? theme.colorScheme.surface,
                        ),
                        dropdownColor: theme.cardTheme.color ?? theme.colorScheme.surface,
                        initialValue: _selectedDepartment,
                        items: (_selectedUniversity == null
                                ? <DropdownMenuItem<String>>[]
                                : _departmentsByUniversity[_selectedUniversity!]!
                                    .map((m) => DropdownMenuItem(value: m['key'], child: Text(m['label']!)))
                                    .toList()),
                        onChanged: (v) {
                          setState(() {
                            _selectedDepartment = v;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'اختر الفرقة',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: theme.cardTheme.color ?? theme.colorScheme.surface,
                        ),
                        dropdownColor: theme.cardTheme.color ?? theme.colorScheme.surface,
                        initialValue: _selectedLevel,
                        items: _levels.entries
                            .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key)))
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            _selectedLevel = v;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: Container(
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
                  clipBehavior: Clip.antiAlias,
                  child: (_selectedUniversity == null || _selectedDepartment == null || _selectedLevel == null)
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_not_supported_rounded, size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                              const SizedBox(height: 12),
                              Text(
                                lockedToProfile
                                    ? 'لا توجد بيانات كافية لعرض الجدول'
                                    : 'اختر الجامعة والقسم والفرقة لعرض الجدول',
                                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                              ),
                            ],
                          ),
                        )
                      : StreamBuilder<Map<String, dynamic>?>(
                          stream: _firestoreService.getScheduleMetaStream(
                            universityKey: _selectedUniversity!,
                            departmentKey: _selectedDepartment!,
                            levelKey: _selectedLevel!,
                          ),
                          builder: (context, snap) {
                            final data = snap.data;
                            return FutureBuilder<String?>(
                              future: (data?['imageUrl'] as String?)?.trim().isNotEmpty == true
                                  ? Future.value(data!['imageUrl'] as String)
                                  : _storage.getScheduleUrl(_selectedUniversity!, _selectedDepartment!, _selectedLevel!),
                              builder: (context, urlSnap) {
                                if (urlSnap.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }
                                
                                final baseUrl = urlSnap.data ?? '';
                                if (baseUrl.isEmpty) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.image_not_supported_rounded,
                                            size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                                        const SizedBox(height: 12),
                                        Text(
                                          'لا توجد صورة جدول لهذا الاختيار حالياً',
                                          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                final updatedAt = data?['updatedAt'];
                                final v = updatedAt is Timestamp
                                    ? updatedAt.toDate().millisecondsSinceEpoch
                                    : DateTime.now().millisecondsSinceEpoch;

                                final imageUrl = _withCacheBuster(baseUrl, v);

                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!mounted) return;
                                  final prev = _lastSeenScheduleVersion;
                                  if (prev == null) {
                                    _lastSeenScheduleVersion = v;
                                    return;
                                  }
                                  if (v > prev) {
                                    _lastSeenScheduleVersion = v;
                                    AppSnackBar.showInfo(context, 'تم رفع جدول جديد');
                                  }
                                });

                                final heroTag = 'schedule:$imageUrl';

                                return InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ScheduleImageViewerScreen(
                                          imageUrl: imageUrl,
                                          heroTag: heroTag,
                                          title: 'جدول المحاضرات',
                                        ),
                                      ),
                                    );
                                  },
                                  child: Hero(
                                    tag: heroTag,
                                    child: CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.contain,
                                      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                      errorWidget: (context, url, error) => Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.image_not_supported_rounded,
                                                size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                                            const SizedBox(height: 12),
                                            Text(
                                              'لا توجد صورة جدول لهذا الاختيار حالياً',
                                              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
