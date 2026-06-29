import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/features/community/data/repositories/group_repository_impl.dart';
import 'package:project_test2/features/community/domain/entities/group_entity.dart';
import 'package:project_test2/features/community/domain/entities/group_message_entity.dart';
import 'package:project_test2/features/community/presentation/widgets/group_message_bubble.dart';

class GroupSearchScreen extends StatefulWidget {
  final GroupEntity group;
  final String currentUserId;

  const GroupSearchScreen({
    super.key,
    required this.group,
    required this.currentUserId,
  });

  @override
  State<GroupSearchScreen> createState() => _GroupSearchScreenState();
}

class _GroupSearchScreenState extends State<GroupSearchScreen> {
  final _repo = GroupRepositoryImpl();
  final _searchCtrl = TextEditingController();
  List<GroupMessageEntity> _results = [];
  bool _isLoading = false;
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _query = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _query = q;
    });

    try {
      final res = await _repo.searchMessages(groupId: widget.group.id, query: q);
      if (mounted) {
        setState(() {
          _results = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search in ${widget.group.name}...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            border: InputBorder.none,
          ),
          onSubmitted: _performSearch,
          textInputAction: TextInputAction.search,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_rounded),
            onPressed: () {
              _searchCtrl.clear();
              _performSearch('');
            },
          ),
        ],
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded,
                size: 64, color: AppTheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'Search for messages, links, or media',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Text(
          'No results found for "$_query"',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 32),
      itemBuilder: (_, i) {
        final msg = _results[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  DateFormat.yMMMd().add_jm().format(msg.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Reusing GroupMessageBubble as read-only preview
            IgnorePointer(
              child: GroupMessageBubble(
                message: msg,
                isMe: msg.senderId == widget.currentUserId,
                showSenderInfo: true,
                currentUserId: widget.currentUserId,
                isAdmin: false,
                onReply: (_) {},
                onEdit: (_) {},
                onDelete: (_, __) {},
                onInfo: (_) {},
                onReact: (_, __) {},
                onPin: null,
              ),
            ),
          ],
        );
      },
    );
  }
}

