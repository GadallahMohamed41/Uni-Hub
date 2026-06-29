/// Mention System (@) for the Create Post screen.
library;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:project_test2/features/profile/data/models/user_model.dart';

class MentionController {
  final String currentUserId;
  final TextEditingController textController;
  final Function(String text) onTextChanged;

  List<UserModel> _allConnections = [];
  List<UserModel> _filteredSuggestions = [];
  bool _showingSuggestions = false;
  int _mentionStartIndex = -1;
  String _mentionQuery = '';
  bool _isLoadingConnections = false;
  bool _connectionsLoaded = false;

  final Set<String> _mentionedUserIds = {};

  MentionController({
    required this.currentUserId,
    required this.textController,
    required this.onTextChanged,
  });

  List<UserModel> get filteredSuggestions => _filteredSuggestions;
  bool get showingSuggestions => _showingSuggestions;
  bool get isLoadingConnections => _isLoadingConnections;
  Set<String> get mentionedUserIds => _mentionedUserIds;

  List<UserModel> getAllConnections() {
    return _allConnections;
  }

  Future<void> refreshConnections() async {
    _connectionsLoaded = false;
    _allConnections = [];
    _filteredSuggestions = [];
    await loadConnections();
  }

  Future<void> loadConnections() async {
    if (_connectionsLoaded || _isLoadingConnections) return;
    _isLoadingConnections = true;

    try {
 
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('connections')
          .get();

 
      if (snapshot.docs.isEmpty) {
         _allConnections = [];
        _filteredSuggestions = [];
        _isLoadingConnections = false;
        _connectionsLoaded = true;
        return;
      }

      final ids = snapshot.docs.map((d) => d.id).toList();
 
      final users = <UserModel>[];

      for (var i = 0; i < ids.length; i += 10) {
        final chunk = ids.sublist(
          i,
          i + 10 > ids.length ? ids.length : i + 10,
        );
 
        final usersSnap = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

 
        for (final doc in usersSnap.docs) {
          final data = doc.data();
 
          try {
            final user = UserModel.fromFirestore(doc);
            users.add(user);
           } catch (e) {
           }
        }
      }

      _allConnections = users;
      _filteredSuggestions = List.from(_allConnections);
     
      for (final user in _allConnections) {
       }

      _connectionsLoaded = true;
    } catch (e) {
       _allConnections = [];
      _filteredSuggestions = [];
    }
    _isLoadingConnections = false;
  }

  void onTextUpdated(String text) {
    onTextChanged(text);

    final cursorPos = textController.selection.baseOffset;
    if (cursorPos < 0 || cursorPos > text.length) {
      _closeSuggestions();
      return;
    }

    int atIndex = -1;
    for (int i = cursorPos - 1; i >= 0; i--) {
      if (text[i] == '@') {
        if (i == 0 || text[i - 1] == ' ' || text[i - 1] == '\n') {
          atIndex = i;
        }
        break;
      }
      if (text[i] == ' ' || text[i] == '\n') break;
    }

    if (atIndex == -1) {
      _closeSuggestions();
      return;
    }

    _mentionStartIndex = atIndex;
    _mentionQuery = text.substring(atIndex + 1, cursorPos).toLowerCase();

    if (_mentionQuery.isEmpty) {
      _filteredSuggestions = List.from(_allConnections);
    } else {
      _filteredSuggestions = _allConnections
          .where((u) => u.name.toLowerCase().contains(_mentionQuery))
          .toList();
    }

    _showingSuggestions = _filteredSuggestions.isNotEmpty;
  }

  // ========== دالة selectMention المعدلة ==========
  void selectMention(UserModel user) {
    // التحقق إذا كان المستخدم مذكور بالفعل
    if (_mentionedUserIds.contains(user.uid)) {
       _showingSuggestions = false;
      return;
    }

    final text = textController.text;
    final cursorPos = textController.selection.baseOffset;

     int atIndex = -1;
    for (int i = cursorPos - 1; i >= 0; i--) {
      if (text[i] == '@') {
        if (i == 0 || text[i - 1] == ' ' || text[i - 1] == '\n') {
          atIndex = i;
          break;
        }
      }
    }

    String newText;
    int newCursorPos;

    if (atIndex == -1) {
      // مفيش @، نضيف منشن جديد في النهاية
      final mentionText = '@${user.name} ';
      final prefix = text.isNotEmpty && !text.endsWith(' ') ? ' ' : '';
      newText = '$text$prefix$mentionText';
      newCursorPos = newText.length;
    } else {
       final beforeAt = text.substring(0, atIndex);
      final afterAt = text.substring(atIndex);

      final mentionText = '@${user.name} ';
      final prefix = beforeAt.isNotEmpty && !beforeAt.endsWith(' ') ? ' ' : '';

      // نحتفظ بالمنشن القديم ونضيف الجديد بعده
      newText = '$beforeAt$prefix$mentionText$afterAt';
      newCursorPos = beforeAt.length + prefix.length + mentionText.length;
    }

    textController.text = newText;
    textController.selection = TextSelection.collapsed(offset: newCursorPos);

    _mentionedUserIds.add(user.uid);
    onTextChanged(newText);

    _showingSuggestions = false;
  }

  void handleMentionDeletion(String oldText, String newText) {
    if (newText.length >= oldText.length) return;

    final connections = getAllConnections();
    String updatedText = newText;
    bool changed = false;
    int deleteIndex = -1;

    for (final userId in List<String>.from(_mentionedUserIds)) {
      UserModel? matchedUser;
      for (final u in connections) {
        if (u.uid == userId) {
          matchedUser = u;
          break;
        }
      }
      if (matchedUser == null) continue;

      final mentionStringWithSpace = '@${matchedUser.name} ';
      final mentionStringWithoutSpace = '@${matchedUser.name}';

      if (oldText.contains(mentionStringWithSpace) && !newText.contains(mentionStringWithSpace)) {
        final index = oldText.indexOf(mentionStringWithSpace);
        if (index != -1) {
          updatedText = newText.replaceRange(
            index,
            index + (mentionStringWithSpace.length - 1) <= newText.length
                ? index + (mentionStringWithSpace.length - 1)
                : newText.length,
            '',
          );
          _mentionedUserIds.remove(userId);
          changed = true;
          deleteIndex = index;
          break;
        }
      } else if (oldText.contains(mentionStringWithoutSpace) && !newText.contains(mentionStringWithoutSpace)) {
        final index = oldText.indexOf(mentionStringWithoutSpace);
        if (index != -1) {
          updatedText = newText.replaceRange(
            index,
            index + (mentionStringWithoutSpace.length - 1) <= newText.length
                ? index + (mentionStringWithoutSpace.length - 1)
                : newText.length,
            '',
          );
          _mentionedUserIds.remove(userId);
          changed = true;
          deleteIndex = index;
          break;
        }
      }
    }

    if (changed && deleteIndex != -1) {
      textController.text = updatedText;
      textController.selection = TextSelection.collapsed(offset: deleteIndex);
      onTextChanged(updatedText);
    }
  }

  void _closeSuggestions() {
    _showingSuggestions = false;
  }

  void dispose() {}
}

/// Overlay widget that shows mention suggestions.
class MentionSuggestionsOverlay extends StatelessWidget {
  final List<UserModel> suggestions;
  final ValueChanged<UserModel> onSelect;

  const MentionSuggestionsOverlay({
    super.key,
    required this.suggestions,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final user = suggestions[index];
          final avatarUrl = (user.avatarUrl ?? '').trim();
          final hasAvatar = avatarUrl.isNotEmpty;
          final initials = user.name.trim().isNotEmpty
              ? user.name.trim()[0].toUpperCase()
              : 'U';

          return ListTile(
            leading: CircleAvatar(
              radius: 16,
              backgroundImage:
                  hasAvatar ? CachedNetworkImageProvider(avatarUrl) : null,
              child: hasAvatar
                  ? null
                  : Text(
                      initials,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
            ),
            title: Text(
              user.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            subtitle: user.bio != null && user.bio!.isNotEmpty
                ? Text(
                    user.bio!,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  )
                : null,
            onTap: () => onSelect(user),
          );
        },
      ),
    );
  }
}
