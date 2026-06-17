import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme.dart';
import '../../domain/entities/group_member_entity.dart';
import '../../domain/entities/group_message_entity.dart';

/// WhatsApp-style Message Info screen.
/// Shows who received (delivered) and who read (seen) the message.
class MessageInfoScreen extends StatelessWidget {
  final GroupMessageEntity message;
  final List<GroupMemberEntity> members;

  const MessageInfoScreen({
    super.key,
    required this.message,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Build seen list (excluding sender)
    final seenList = message.seenBy.entries
        .where((e) => e.key != message.senderId)
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    // Build delivered list (not yet seen)
    final seenIds = message.seenBy.keys.toSet();
    final deliveredList = message.deliveredTo.entries
        .where((e) => e.key != message.senderId && !seenIds.contains(e.key))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    // Members who haven't received yet
    final pendingIds = members
        .where((m) =>
            m.userId != message.senderId &&
            !seenIds.contains(m.userId) &&
            !message.deliveredTo.containsKey(m.userId))
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Message Info'),
        backgroundColor: AppTheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        children: [
          // Message preview
          _MessagePreview(message: message, isDark: isDark),

          const SizedBox(height: 8),

          // Read by
          if (seenList.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.done_all_rounded,
              label: 'Read',
              color: Colors.blue,
              count: seenList.length,
            ),
            ...seenList.map((entry) {
              final member = _memberFor(entry.key);
              return _ReceiptTile(
                name: member?.name ?? 'Unknown',
                avatarUrl: member?.avatarUrl,
                timestamp: entry.value,
                icon: Icons.done_all_rounded,
                iconColor: Colors.blue,
              );
            }),
          ],

          // Delivered to
          if (deliveredList.isNotEmpty) ...[
            const Divider(height: 24),
            _SectionHeader(
              icon: Icons.done_all_rounded,
              label: 'Delivered',
              color: Colors.grey,
              count: deliveredList.length,
            ),
            ...deliveredList.map((entry) {
              final member = _memberFor(entry.key);
              return _ReceiptTile(
                name: member?.name ?? 'Unknown',
                avatarUrl: member?.avatarUrl,
                timestamp: entry.value,
                icon: Icons.done_all_rounded,
                iconColor: Colors.grey,
              );
            }),
          ],

          // Sent to (Pending)
          if (pendingIds.isNotEmpty) ...[
            const Divider(height: 24),
            _SectionHeader(
              icon: Icons.check_rounded,
              label: 'Sent',
              color: Colors.grey,
              count: pendingIds.length,
            ),
            ...pendingIds.map((m) => _ReceiptTile(
                  name: m.name,
                  avatarUrl: m.avatarUrl,
                  timestamp: null,
                  icon: Icons.check_rounded,
                  iconColor: Colors.grey.shade400,
                )),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  GroupMemberEntity? _memberFor(String uid) {
    try {
      return members.firstWhere((m) => m.userId == uid);
    } catch (_) {
      return null;
    }
  }
}


class _MessagePreview extends StatelessWidget {
  final GroupMessageEntity message;
  final bool isDark;
  const _MessagePreview({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.deletedForAll)
            const Text(
              'This message was deleted',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            )
          else if (message.text.isNotEmpty)
            Text(message.text, style: const TextStyle(fontSize: 15))
          else if (message.mediaUrls.isNotEmpty)
            Row(
              children: [
                Icon(
                  message.messageType == GroupMessageType.image
                      ? Icons.image_rounded
                      : Icons.attach_file_rounded,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 8),
                const Text('Media'),
              ],
            ),
          const SizedBox(height: 8),
          Text(
            DateFormat.yMMMd().add_jm().format(message.createdAt),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int count;
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: color,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptTile extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final DateTime? timestamp;
  final IconData icon;
  final Color iconColor;

  const _ReceiptTile({
    required this.name,
    this.avatarUrl,
    this.timestamp,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
        child: avatarUrl != null && avatarUrl!.isNotEmpty
            ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: avatarUrl!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              )
            : Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
      ),
      title: Text(name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (timestamp != null)
            Text(
              DateFormat.jm().format(timestamp!),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          const SizedBox(width: 6),
          Icon(icon, size: 16, color: iconColor),
        ],
      ),
    );
  }
}

