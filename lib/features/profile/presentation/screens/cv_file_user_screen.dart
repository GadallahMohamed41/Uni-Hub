import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:project_test2/core/services/storage_service.dart';
import 'package:provider/provider.dart';
import 'package:project_test2/features/auth/presentation/providers/auth_provider.dart';
import 'package:project_test2/features/profile/presentation/screens/cv_viewer_screen.dart';
import 'package:project_test2/core/services/firestore_service.dart';

class CvFileUser extends StatefulWidget {
  const CvFileUser({super.key});
  @override
  State<CvFileUser> createState() => _CvFileUserState();
}
class _CvFileUserState extends State<CvFileUser>
    with SingleTickerProviderStateMixin {
  final StorageService _storageService = StorageService();
  final FirestoreService _firestoreService = FirestoreService();

  String? _uploadedUrl;
  bool _isUploading = false;
  String? _userId;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  // ── Colors ──────────────────────────────────────────────
  Color get _bg => Theme.of(context).scaffoldBackgroundColor;
  Color get _surface =>
      Theme.of(context).cardTheme.color ??
      Theme.of(context).colorScheme.surface;
  Color get _surface2 => Theme.of(context).brightness == Brightness.dark
      ? Theme.of(context).colorScheme.surfaceContainerHighest
      : const Color(0xFFE8EEFF);
  Color get _blue => Theme.of(context).colorScheme.primary;
  Color get _blueDark => Theme.of(context).colorScheme.primary;
  Color get _green => const Color(0xFF1DAE75);
  Color get _textPrim => Theme.of(context).colorScheme.onSurface;
  Color get _textMut => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF94A3B8)
      : const Color(0xFF8A93B2);
  Color get _border => Theme.of(context).brightness == Brightness.dark
      ? Colors.white12
      : const Color(0xFFD0D8F5);

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uid = context.read<AuthProvider>().userId;
      _userId = uid;
      if (!mounted) return;
      final user = context.read<AuthProvider>().currentUser;
      final savedUrl = (user?.cvUrl ?? '').trim();
      if (savedUrl.isNotEmpty) {
        setState(() => _uploadedUrl = savedUrl);
        return;
      }
      if (uid != null) {
        final url = await _storageService.getUserCvUrl(uid);
        if (!mounted) return;
        setState(() {
          _uploadedUrl = url;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ── Logic ────────────────────────────────────────────────
  Future<void> _pickAndUploadPdf() async {
    final auth = context.read<AuthProvider>();
    final uid = _userId ?? auth.userId;
    if (uid == null) {
      _snack('Please sign in first');
      return;
    }

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null) return;

      final file = result.files.first;
      final bytes = kIsWeb
          ? await file.readAsBytes()
          : await io.File(file.path!).readAsBytes();

      if (!mounted) return;
      setState(() => _isUploading = true);

      final url = await _storageService
          .uploadUserCv(bytes, uid)
          .timeout(const Duration(seconds: 35));

      if (!mounted) return;
      if (url != null) {
        setState(() {
          _uploadedUrl = url;
          _isUploading = false;
        });
        try {
          await _firestoreService.updateUserCvUrl(uid, url);
          final user = auth.currentUser;
          if (user != null) {
            auth.updateCurrentUser(user.copyWith(cvUrl: url));
          }
        } catch (_) {}
        _snack('CV uploaded successfully ✓', color: _green);
      } else {
        setState(() => _isUploading = false);
        _snack('Upload failed. Please try again', color: Colors.red);
      }
    } on TimeoutException catch (_) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      _snack('Network timeout. Please try again', color: Colors.red);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      _snack('Error: $e', color: Colors.red);
    }
  }

  Future<void> _openLatestCv() async {
    final uid = _userId ?? context.read<AuthProvider>().userId;
    if (uid == null) {
      _snack('Please sign in first');
      return;
    }

    if (_uploadedUrl != null) {
      _navToViewer(_uploadedUrl!);
      return;
    }
    setState(() => _isUploading = true);
    String? url;
    try {
      url = await _storageService.getUserCvUrl(uid).timeout(const Duration(seconds: 12));
    } on TimeoutException catch (_) {
      setState(() => _isUploading = false);
      _snack('Network timeout. Please try again');
      return;
    }
    setState(() => _isUploading = false);
    if (url != null) {
      setState(() => _uploadedUrl = url);
      if (!mounted) return;
      _navToViewer(_uploadedUrl!);
    } else {
      _snack('No CV saved yet');
    }
  }

  void _navToViewer(String url) => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CvViewerScreen(url: url, title: 'View CV')));

  Future<void> _deleteCV() async {
    final uid = _userId ?? context.read<AuthProvider>().userId;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.red.shade400, size: 22),
            const SizedBox(width: 8),
            Text('Delete CV', style: TextStyle(color: _textPrim, fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete your CV? This action cannot be undone.',
          style: TextStyle(color: _textMut, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: _textMut)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;
    setState(() => _isUploading = true);
    try {
      await _storageService.deleteUserCv(uid);
      await _firestoreService.updateUserCvUrl(uid, '');
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final user = auth.currentUser;
      if (user != null) auth.updateCurrentUser(user.copyWith(cvUrl: ''));
      setState(() {
        _uploadedUrl = null;
        _isUploading = false;
      });
      _snack('CV deleted successfully', color: const Color(0xFF1DAE75));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      _snack('Error deleting CV: $e', color: Colors.red);
    }
  }

  void _snack(String msg, {Color color = const Color(0xFF333344)}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'DMSans')),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }



  // ── UI ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
        child: Column(
          children: [
            _buildHeroCard(),
            const SizedBox(height: 16),
            _buildInfoRow(),
            const SizedBox(height: 16),
            _buildTipCard(),
          ],
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: Color(0xFF666676)),
          onPressed: () => Navigator.pop(context),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF5B8AF5), Color(0xFF2B5CE6), Color(0xFF1A3DB8)],
          ).createShader(bounds),
          child: const Text(
            'My CV',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: _border.withValues(alpha: 0.5)),
        ),
      );

  Widget _buildHeroCard() {
    final isUploaded = _uploadedUrl != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_surface, _surface2],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isUploaded
              ? _green.withValues(alpha: 0.3)
              : _blue.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          // PDF Icon
          _buildPdfIcon(isUploaded),
          const SizedBox(height: 20),

          // Title + subtitle
          Text(
            isUploaded ? 'CV Uploaded' : 'Upload Your CV',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: _textPrim,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isUploaded
                ? 'Your resume is saved and ready to share'
                : 'Upload your resume in PDF format\nto share with potential employers',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: _textMut,
              height: 1.6,
              fontWeight: FontWeight.w300,
            ),
          ),

          if (isUploaded) ...[
            const SizedBox(height: 14),
            _buildSuccessBadge(),
          ],

          const SizedBox(height: 24),

          // Buttons — fixed overflow with Expanded inside Row
          if (_isUploading)
            SizedBox(
              height: 50,
              child: Center(
                  child:
                      CircularProgressIndicator(color: _blue, strokeWidth: 2)),
            )
          else
            Row(
              children: [
                Expanded(child: _buildUploadBtn()),
                const SizedBox(width: 10),
                Expanded(child: _buildViewBtn()),
                if (_uploadedUrl != null) ...
                  [
                    const SizedBox(width: 8),
                    _buildDeleteBtn(),
                  ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPdfIcon(bool isUploaded) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) => Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: _surface2,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isUploaded
                ? _green.withValues(alpha: _pulseAnim.value * 0.5)
                : _blue.withValues(alpha: _pulseAnim.value * 0.35),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isUploaded ? _green : _blue).withValues(alpha: 0.08),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              isUploaded ? Icons.task_rounded : Icons.picture_as_pdf_rounded,
              size: 40,
              color: isUploaded ? _green : _blue,
            ),
            Positioned(
              bottom: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isUploaded ? _green : _blueDark,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isUploaded ? '✓' : 'PDF',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: isUploaded ? Colors.white : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: _green.withValues(alpha: 0.1),
          border: Border.all(color: _green.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: _green, shape: BoxShape.circle)),
            const SizedBox(width: 7),
            Text('Uploaded successfully',
                style: TextStyle(fontSize: 12, color: _green)),
          ],
        ),
      );

  Widget _buildUploadBtn() => ElevatedButton.icon(
        onPressed: _pickAndUploadPdf,
        icon: const Icon(Icons.upload_file_rounded, size: 18),
        label: const Text('Upload File'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          elevation: 0,
        ),
      );

  Widget _buildViewBtn() => OutlinedButton.icon(
        onPressed: _isUploading ? null : _openLatestCv,
        icon: const Icon(Icons.visibility_rounded, size: 18),
        label: const Text('View CV'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _blue,
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: _blue.withValues(alpha: 0.3), width: 0.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        ),
      );

  Widget _buildDeleteBtn() => Tooltip(
        message: 'Delete CV',
        child: InkWell(
          onTap: _isUploading ? null : _deleteCV,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.25),
                width: 0.8,
              ),
            ),
            child: Icon(
              Icons.delete_outline_rounded,
              color: Colors.red.shade400,
              size: 20,
            ),
          ),
        ),
      );

  Widget _buildInfoRow() => Row(
        children: [
          _infoChip('Format', 'PDF only'),
          const SizedBox(width: 10),
          _infoChip('Max size', '10 MB'),
          const SizedBox(width: 10),
          _infoChip('Status', _uploadedUrl != null ? 'Active' : 'No file',
              valueColor: _uploadedUrl != null ? _green : _textMut),
        ],
      );

  Widget _infoChip(String label, String value, {Color? valueColor}) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: _border.withValues(alpha: 0.5), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: TextStyle(
                      fontSize: 9,
                      color: _textMut,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w400)),
              const SizedBox(height: 6),
              Text(value,
                  style: TextStyle(
                      fontSize: 12,
                      color: valueColor ?? _textPrim,
                      fontWeight: FontWeight.w400)),
            ],
          ),
        ),
      );

  Widget _buildTipCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _blue.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _blue.withValues(alpha: 0.1), width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 5),
              width: 5,
              height: 5,
              decoration:
                  BoxDecoration(color: _blueDark, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Uploading a new file will automatically replace your previous CV. Make sure to select the latest version.',
                style: TextStyle(
                    fontSize: 12,
                    color: _textMut,
                    height: 1.6,
                    fontWeight: FontWeight.w300),
              ),
            ),
          ],
        ),
      );
}
