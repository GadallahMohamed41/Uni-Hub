import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/features/community/data/repositories/group_repository_impl.dart';
import 'package:project_test2/features/community/domain/entities/group_message_entity.dart';

class GroupMediaScreen extends StatefulWidget {
  final String groupId;

  const GroupMediaScreen({super.key, required this.groupId});

  @override
  State<GroupMediaScreen> createState() => _GroupMediaScreenState();
}

class _GroupMediaScreenState extends State<GroupMediaScreen> {
  final _repo = GroupRepositoryImpl();
  List<GroupMessageEntity> _mediaMessages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    try {
      final res = await _repo.getMediaMessages(widget.groupId);
      if (mounted) {
        setState(() {
          _mediaMessages = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Media'),
        backgroundColor: AppTheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mediaMessages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library_rounded,
                          size: 64,
                          color: AppTheme.primary.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(
                        'No media found',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(4),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: _mediaMessages.length,
                  itemBuilder: (_, i) {
                    final msg = _mediaMessages[i];
                    final url = msg.mediaUrls.firstOrNull;
                    if (url == null) return const SizedBox.shrink();

                    return GestureDetector(
                      onTap: () {
                        // In a real app, open a full screen image viewer
                        showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            backgroundColor: Colors.transparent,
                            insetPadding: EdgeInsets.zero,
                            child: InteractiveViewer(
                              child: CachedNetworkImage(imageUrl: url),
                            ),
                          ),
                        );
                      },
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey.shade300,
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.broken_image_rounded),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

