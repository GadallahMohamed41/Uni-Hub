import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:project_test2/core/theme.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/firebase_storage_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/custom_confirm_dialog.dart';
import 'cv_viewer_screen.dart';

class TestimonialsUser extends StatefulWidget {
  const TestimonialsUser({super.key});

  @override
  State<TestimonialsUser> createState() => _TestimonialsUserState();
}

class _TestimonialsUserState extends State<TestimonialsUser> {
  static const int _maxCertificates = 20;

  final StorageService _storageService = StorageService();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseStorageService _firebaseStorageService =
      FirebaseStorageService();

  final List<_CertificateItem> _certificates = <_CertificateItem>[];
  bool _isUploading = false;
  bool _isLoading = true;
  String? _userId;

  // ✅ متغيرات لحقل الوصف والملف المختار
  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  bool _showDescriptionField = false;

  Color get _bg => Theme.of(context).scaffoldBackgroundColor;
  Color get _surface =>
      Theme.of(context).cardTheme.color ??
      Theme.of(context).colorScheme.surface;
  Color get _primary => Theme.of(context).colorScheme.primary;
  Color get _success => AppTheme.success;
  Color get _textPrim => Theme.of(context).colorScheme.onSurface;
  Color get _textSec => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF94A3B8)
      : AppTheme.textSecondary;
  Color get _textMut => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF64748B)
      : AppTheme.textTertiary;
  Color get _border => Theme.of(context).brightness == Brightness.dark
      ? Colors.white12
      : const Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _userId = context.read<AuthProvider>().userId;
      await _loadCertificates();
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCertificates() async {
    final uid = _userId ?? context.read<AuthProvider>().userId;
    if (uid == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _certificates.clear();
      });
      return;
    }

    if (mounted) {
      setState(() => _isLoading = true);
    }

    List<Map<String, dynamic>> stored = <Map<String, dynamic>>[];
    try {
      stored = await _firestoreService.listUserCertificates(
        userId: uid,
        limit: _maxCertificates,
      );
    } catch (e) {
      if (mounted) {
        _snack('Firestore permission error. Check Firebase rules.',
            color: Colors.red);
      }
    }

    final items = stored
        .map(
          (e) => _CertificateItem(
            id: (e['id'] as String?) ?? '',
            fileName: (e['fileName'] as String?) ?? '',
            displayName: ((e['name'] as String?) ?? '').trim().isNotEmpty
                ? (e['name'] as String).trim()
                : ((e['fileName'] as String?) ?? '').trim(),
            storagePath: (e['storagePath'] as String?) ?? '',
            url: ((e['url'] as String?) ?? '').trim(),
            description: ((e['description'] as String?) ?? '').trim(),
          ),
        )
        .where((e) => e.url.isNotEmpty)
        .toList();

    final legacyExists = await _storageService.userCertificateExists(uid);
    if (legacyExists) {
      const legacyName = 'certificate_user_file.pdf';
      final hasLegacyAlready =
          items.any((e) => e.fileName.toLowerCase() == legacyName);
      if (!hasLegacyAlready) {
        final legacyUrl = await _storageService.getUserCertificateUrl(uid);
        if (legacyUrl != null) {
          items.insert(
            0,
            _CertificateItem(
              id: '',
              fileName: legacyName,
              displayName: 'Legacy Certificate',
              storagePath: '',
              url: legacyUrl,
              description: 'Legacy certificate uploaded previously',
            ),
          );
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _certificates
        ..clear()
        ..addAll(items.take(_maxCertificates));
      _isLoading = false;
    });
  }

  Future<void> _pickFile() async {
    if (_certificates.length >= _maxCertificates) {
      _snack('You reached the max limit ($_maxCertificates)',
          color: Colors.orange);
      return;
    }

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null) return;

      final file = result.files.single;
      final isTooLarge = file.size > (10 * 1024 * 1024);
      if (isTooLarge) {
        _snack('File size must be 10MB or less', color: Colors.red);
        return;
      }

      final bytes = kIsWeb
          ? await file.readAsBytes()
          : await io.File(file.path!).readAsBytes();

      if (bytes.lengthInBytes > (10 * 1024 * 1024)) {
        _snack('File size must be 10MB or less', color: Colors.red);
        return;
      }

      // ✅ تخزين البيانات مباشرة
      setState(() {
        _selectedFileName = file.name;
        _selectedFileBytes = bytes;
        _showDescriptionField = true;
        _descriptionController.clear();
      });
    } catch (e) {
      _snack('Error picking file: $e', color: Colors.red);
    }
  }

  // ✅ دالة رفع الشهادة مع الوصف
  Future<void> _uploadCertificateWithDescription() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      _snack('Please enter a description', color: Colors.orange);
      return;
    }

    if (description.length < 10) {
      _snack('Description must be at least 10 characters',
          color: Colors.orange);
      return;
    }

    if (_selectedFileBytes == null || _selectedFileName == null) {
      _snack('No file selected', color: Colors.red);
      return;
    }

    setState(() => _isUploading = true);

    try {
      final uid = _userId ?? context.read<AuthProvider>().userId;
      if (uid == null) {
        _snack('Please sign in first', color: Colors.red);
        setState(() => _isUploading = false);
        return;
      }

      final incomingName = _selectedFileName!.trim();
      final normalizedBase = incomingName.isEmpty
          ? 'certificate_${DateTime.now().millisecondsSinceEpoch}'
          : incomingName;
      var fileName = _normalizePdfName(normalizedBase);
      if (!fileName.toLowerCase().startsWith('certificate_')) {
        fileName = 'certificate_$fileName';
      }
      fileName = _resolveDuplicateName(fileName);

      final displayName = incomingName.isNotEmpty ? incomingName : fileName;
      final storagePath = 'users/$uid/certificates/$fileName';

      // ✅ استخدام الـ bytes المخزنة مباشرة
      final firebaseUrl = await _firebaseStorageService
          .uploadPdf(
            bytes: _selectedFileBytes!,
            storagePath: storagePath,
          )
          .timeout(const Duration(seconds: 35));

      await _firestoreService.addUserCertificate(
        userId: uid,
        name: displayName,
        description: description,
        fileName: fileName,
        storagePath: storagePath,
        url: firebaseUrl,
      );

      await _firestoreService.updateUserCertificateUrl(uid, firebaseUrl);
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final user = auth.currentUser;
      if (user != null) {
        auth.updateCurrentUser(user.copyWith(certificateUrl: firebaseUrl));
      }

      await _loadCertificates();

      setState(() {
        _isUploading = false;
        _selectedFileName = null;
        _selectedFileBytes = null;
        _showDescriptionField = false;
        _descriptionController.clear();
      });

      _snack('Certificate uploaded successfully', color: _success);
    } catch (e) {
      setState(() => _isUploading = false);
      _snack('Upload failed: $e', color: Colors.red);
    }
  }

  // ✅ إلغاء الرفع
  void _cancelUpload() {
    setState(() {
      _selectedFileName = null;
      _selectedFileBytes = null;
      _showDescriptionField = false;
      _descriptionController.clear();
    });
  }

  String _normalizePdfName(String rawName) {
    var name = rawName.trim().replaceAll(RegExp(r'\s+'), '_');
    name = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '');
    if (name.isEmpty) {
      name = 'certificate_${DateTime.now().millisecondsSinceEpoch}.pdf';
    }
    if (!name.toLowerCase().endsWith('.pdf')) {
      name = '$name.pdf';
    }
    return name;
  }

  String _resolveDuplicateName(String fileName) {
    final lowerSet = _certificates.map((e) => e.fileName.toLowerCase()).toSet();
    if (!lowerSet.contains(fileName.toLowerCase())) {
      return fileName;
    }

    final dot = fileName.lastIndexOf('.');
    final base = dot > 0 ? fileName.substring(0, dot) : fileName;
    final ext = dot > 0 ? fileName.substring(dot) : '.pdf';
    return '${base}_${DateTime.now().millisecondsSinceEpoch}$ext';
  }

  void _openCertificate(_CertificateItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CvViewerScreen(
          url: item.url,
          title: 'View Certificate',
        ),
      ),
    );
  }

  Future<void> _downloadCertificate(_CertificateItem item) async {
    final uri = Uri.tryParse(item.url);
    if (uri == null) {
      _snack('Invalid file URL', color: Colors.red);
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      _snack('Could not open download link', color: Colors.red);
    }
  }

  Future<void> _deleteCertificate(_CertificateItem item) async {
    await CustomConfirmDialog.show(
      context,
      title: 'Delete Certificate',
      content: 'Are you sure you want to delete "${item.displayName}"?',
      confirmLabel: 'Delete',
      confirmColor: AppTheme.error,
      icon: Icons.delete_outline_rounded,
      onConfirm: () async {
        final auth = context.read<AuthProvider>();
        final uid = _userId ?? auth.userId;
        setState(() => _isLoading = true);
        if (item.storagePath.trim().isNotEmpty) {
          try {
            await _firebaseStorageService.deleteByPath(item.storagePath.trim());
          } catch (_) {}
        } else {
          await _storageService.deleteImage(item.url);
        }
        if (uid != null && item.id.isNotEmpty) {
          try {
            await _firestoreService.deleteUserCertificate(
              userId: uid,
              certificateId: item.id,
            );
          } catch (_) {}
        }
        await _loadCertificates();
        if (!mounted) return;
        _snack('Certificate deleted', color: _success);
      },
    );
  }

  void _snack(String msg, {Color? color}) {
    color ??= _primary;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _loadCertificates,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 14),
              _buildListCard(),
              // ✅ عرض حقل الوصف بعد اختيار الملف
              if (_showDescriptionField) _buildDescriptionSheet(),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() => AppBar(
        backgroundColor: _bg,
        foregroundColor: _textPrim,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Certificates',
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _textPrim,
          ),
        ),
      );

  Widget _buildHeader() {
    final count = _certificates.length;
    final canAdd = count < _maxCertificates;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded,
              color: Colors.white, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Certificates',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count / $_maxCertificates',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              canAdd ? 'Active' : 'Full',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border, width: 0.7),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.insert_drive_file_rounded, size: 18, color: _textSec),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your Certificates',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textPrim,
                  ),
                ),
              ),
              if (_isUploading || _isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_certificates.isEmpty && !_isLoading) _buildEmptyState(),
          if (_certificates.isNotEmpty)
            ListView.separated(
              itemCount: _certificates.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) =>
                  _buildCertificateRow(_certificates[index], index + 1),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_isUploading ||
                      _isLoading ||
                      _certificates.length >= _maxCertificates ||
                      _showDescriptionField)
                  ? null
                  : _pickFile,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                _certificates.length >= _maxCertificates
                    ? 'Max reached (20)'
                    : 'Add Certificate',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'PDF only - Max 10MB per certificate',
            style: TextStyle(fontSize: 11, color: _textMut.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }

  // ✅ ويدجت حقل الوصف (الشيت اللي بيظهر تحت)
  Widget _buildDescriptionSheet() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _primary.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس الشيت
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.check_circle, color: _success, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'File Selected',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textPrim,
                      ),
                    ),
                    Text(
                      _selectedFileName ?? 'Unknown file',
                      style: TextStyle(
                        fontSize: 11,
                        color: _textSec,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _cancelUpload,
                icon: Icon(Icons.close_rounded, color: _textMut, size: 20),
                tooltip: 'Cancel',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // حقل الوصف
          Text(
            'Certificate Description',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _textPrim,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              hintText: 'e.g., Flutter Developer Certification from Google\n'
                  'Issued by: Google\n'
                  'Date: 2024',
              hintMaxLines: 3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primary, width: 2),
              ),
              prefixIcon: Icon(Icons.description_outlined, color: _primary),
              filled: true,
              fillColor: _bg,
            ),
            maxLines: 4,
            maxLength: 200,
            buildCounter: (context,
                {required currentLength, required isFocused, maxLength}) {
              return Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: Text(
                  '$currentLength/$maxLength',
                  style: TextStyle(fontSize: 10, color: _textMut),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // أزرار الإجراءات
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _cancelUpload,
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    side: BorderSide(color: _border),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      _isUploading ? null : _uploadCertificateWithDescription,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_rounded, size: 18),
                  label: Text(
                      _isUploading ? 'Uploading...' : 'Upload Certificate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border, width: 0.5),
      ),
      child: Text(
        'No certificates uploaded yet. Tap "Add Certificate" to start.',
        style: TextStyle(fontSize: 12, color: _textSec),
      ),
    );
  }

  Widget _buildCertificateRow(_CertificateItem item, int index) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openCertificate(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border, width: 0.6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded,
                      color: Colors.red, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$index. ${item.displayName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: _textPrim,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _downloadCertificate(item),
                  icon: Icon(Icons.download_rounded, size: 18, color: _primary),
                  tooltip: 'Download',
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  onPressed: () => _deleteCertificate(item),
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 18, color: Colors.red),
                  tooltip: 'Delete',
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: _textMut),
              ],
            ),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.description_outlined,
                          size: 12, color: _primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.description,
                          style: TextStyle(
                            fontSize: 11,
                            color: _textSec,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CertificateItem {
  final String id;
  final String fileName;
  final String displayName;
  final String storagePath;
  final String url;
  final String description;

  const _CertificateItem({
    required this.id,
    required this.fileName,
    required this.displayName,
    required this.storagePath,
    required this.url,
    required this.description,
  });
}
