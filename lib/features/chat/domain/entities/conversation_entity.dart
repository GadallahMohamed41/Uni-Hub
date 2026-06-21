import 'package:equatable/equatable.dart';

/// Core domain entity for a 1-to-1 conversation.
/// Pure Dart — no Firebase imports here.
class ConversationEntity extends Equatable {
  final String id;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final Map<String, String?> participantAvatars;
  final String lastMessage;
  final String lastMessageSenderId;
  final DateTime lastMessageAt;
  final Map<String, int> unreadCount;
  final Map<String, DateTime> muteUntil;
  final Map<String, bool> archivedBy;
  final Map<String, DateTime> pinnedBy;

  const ConversationEntity({
    required this.id,
    required this.participantIds,
    required this.participantNames,
    required this.participantAvatars,
    required this.lastMessage,
    required this.lastMessageSenderId,
    required this.lastMessageAt,
    required this.unreadCount,
    this.muteUntil = const {},
    this.archivedBy = const {},
    this.pinnedBy = const {},
  });

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Returns the ID of the other participant in a 1-to-1 chat.
  String otherUserId(String myId) =>
      participantIds.firstWhere((id) => id != myId, orElse: () => '');

  String otherUserName(String myId) =>
      participantNames[otherUserId(myId)] ?? '';

  String? otherUserAvatar(String myId) =>
      participantAvatars[otherUserId(myId)];

  int myUnread(String myId) => unreadCount[myId] ?? 0;

  bool isMuted(String myId) {
    final date = muteUntil[myId];
    if (date == null) return false;
    return date.isAfter(DateTime.now());
  }

  bool isArchived(String myId) => archivedBy[myId] == true;

  bool isPinned(String myId) => pinnedBy[myId] != null;

  DateTime? pinnedAt(String myId) => pinnedBy[myId];

  ConversationEntity copyWith({
    String? id,
    List<String>? participantIds,
    Map<String, String>? participantNames,
    Map<String, String?>? participantAvatars,
    String? lastMessage,
    String? lastMessageSenderId,
    DateTime? lastMessageAt,
    Map<String, int>? unreadCount,
    Map<String, DateTime>? muteUntil,
    Map<String, bool>? archivedBy,
    Map<String, DateTime>? pinnedBy,
  }) {
    return ConversationEntity(
      id: id ?? this.id,
      participantIds: participantIds ?? this.participantIds,
      participantNames: participantNames ?? this.participantNames,
      participantAvatars: participantAvatars ?? this.participantAvatars,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      muteUntil: muteUntil ?? this.muteUntil,
      archivedBy: archivedBy ?? this.archivedBy,
      pinnedBy: pinnedBy ?? this.pinnedBy,
    );
  }

  @override
  List<Object?> get props => [
        id,
        participantIds,
        lastMessage,
        lastMessageSenderId,
        lastMessageAt,
        unreadCount,
        muteUntil,
        archivedBy,
        pinnedBy,
      ];
}
