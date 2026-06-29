import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:project_test2/features/auth/presentation/providers/auth_provider.dart';
import 'package:project_test2/core/services/firestore_service.dart';
import 'package:project_test2/features/profile/presentation/screens/cv_viewer_screen.dart';

class CertificatesViewerScreen extends StatefulWidget {
  final String? userId;

  const CertificatesViewerScreen({super.key, this.userId});

  @override
  State<CertificatesViewerScreen> createState() =>
      _CertificatesViewerScreenState();
}

class _CertificatesViewerScreenState extends State<CertificatesViewerScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  List<Map<String, dynamic>> _certificates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCertificates();
  }

  Future<void> _loadCertificates() async {
    final uid = widget.userId ?? context.read<AuthProvider>().userId;

    if (uid == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final data = await _firestoreService.listUserCertificates(
        userId: uid,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _certificates = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Certificates'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _certificates.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_outlined,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No certificates found',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Upload your certificates to showcase your achievements',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _certificates.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _certificates[index];
                    final name = (item['name'] ?? 'Certificate').toString();
                    final url = (item['url'] ?? '').toString();
                    final description = (item['description'] ?? '').toString();
                    final createdAt = item['createdAt'] as Timestamp?;
                    final certificateId = item['id'] as String?;

                    return Dismissible(
                      key: Key(certificateId ?? index.toString()),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade400,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Certificate'),
                            content: Text(
                                'Are you sure you want to delete "$name"?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                      },
                      onDismissed: (direction) async {
                        final uid = widget.userId ??
                            context.read<AuthProvider>().userId;

                        if (certificateId != null && uid != null) {
                          try {
                            await _firestoreService.deleteUserCertificate(
                              userId: uid,
                              certificateId: certificateId,
                            );
                            if (!context.mounted) return;
                            setState(() {
                              _certificates.removeAt(index);
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Certificate deleted successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Error deleting certificate: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            _loadCertificates();
                          }
                        }
                      },
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          if (url.isEmpty) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CvViewerScreen(url: url, title: name),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.dividerColor.withValues(alpha: 0.2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                               Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.picture_as_pdf_rounded,
                                      color: Colors.red.shade700,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: theme.colorScheme.onSurface,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                        if (createdAt != null) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.access_time_rounded,
                                                size: 12,
                                                color: theme
                                                    .colorScheme.onSurface
                                                    .withValues(alpha: 0.5),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _formatDate(createdAt.toDate()),
                                                style: TextStyle(
                                                  color: theme
                                                      .colorScheme.onSurface
                                                      .withValues(alpha: 0.5),
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          theme.primaryColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'View',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(Icons.arrow_forward_ios_rounded,
                                            size: 12),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                               if (description.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _DescriptionWidget(
                                  key: ValueKey(
                                      'desc_${certificateId ?? index}'),
                                  description: description,
                                  theme: theme,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}

 class _DescriptionWidget extends StatefulWidget {
  final String description;
  final ThemeData theme;

  const _DescriptionWidget({
    super.key,
    required this.description,
    required this.theme,
  });

  @override
  State<_DescriptionWidget> createState() => _DescriptionWidgetState();
}

class _DescriptionWidgetState extends State<_DescriptionWidget> {
  bool _isExpanded = false;
  static const int _maxLines = 2;

   bool get _isLongText {
    final desc = widget.description;
     if (desc.length > 100) return true;
     if (desc.split('\n').length > 2) return true;
     if (desc.contains('. ') && desc.length > 80) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
            widget.theme.colorScheme.primaryContainer.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.theme.colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عنوان الوصف
          Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 14,
                color: widget.theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Description',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: widget.theme.colorScheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // نص الوصف مع AnimatedCrossFade
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Text(
              widget.description,
              maxLines: _maxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: widget.theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            secondChild: Text(
              widget.description,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: widget.theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),

          // زر Read More / Show Less
          if (_isLongText) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 14,
                      color: widget.theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isExpanded ? 'Show less' : 'Read more',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: widget.theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
