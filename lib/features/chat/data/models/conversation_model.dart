import 'package:cloud_firestore/cloud_firestore.dart';
<<<<<<< HEAD
import 'package:project_test2/features/chat/domain/entities/conversation_entity.dart';
=======
import '../../domain/entities/conversation_entity.dart';
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c

/// Firestore-aware data model that maps to/from [ConversationEntity].
class ConversationModel {
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

  const ConversationModel({
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

  // ── Firestore → Model ────────────────────────────────────────────────────

  factory ConversationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final pNames = (data['participantNames'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v?.toString() ?? '')) ??
        {};
    final pAvatars = (data['participantAvatars'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v?.toString())) ??
        {};
    final unread = (data['unreadCount'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, (v as int?) ?? 0)) ??
        {};
    
    final mute = (data['muteUntil'] as Map<String, dynamic>?)?.map((k, v) {
      if (v is Timestamp) {
        return MapEntry(k, v.toDate());
      }
      return MapEntry(k, DateTime.now());
    }) ?? {};

    final archive = (data['archivedBy'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, (v as bool?) ?? false)) ??
        {};

    final pinned = (data['pinnedBy'] as Map<String, dynamic>?)?.map((k, v) {
      if (v is Timestamp) {
        return MapEntry(k, v.toDate());
      }
      return MapEntry(k, DateTime.now());
    }) ?? {};

    return ConversationModel(
      id: doc.id,
      participantIds:
          List<String>.from(data['participantIds'] as List? ?? []),
      participantNames: pNames,
      participantAvatars: pAvatars,
      lastMessage: data['lastMessage'] as String? ?? '',
      lastMessageSenderId: data['lastMessageSenderId'] as String? ?? '',
      lastMessageAt:
          (data['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCount: unread,
      muteUntil: mute,
      archivedBy: archive,
      pinnedBy: pinned,
    );
  }

  // ── Model → Entity ───────────────────────────────────────────────────────

  ConversationEntity toEntity() => ConversationEntity(
        id: id,
        participantIds: participantIds,
        participantNames: participantNames,
        participantAvatars: participantAvatars,
        lastMessage: lastMessage,
        lastMessageSenderId: lastMessageSenderId,
        lastMessageAt: lastMessageAt,
        unreadCount: unreadCount,
        muteUntil: muteUntil,
        archivedBy: archivedBy,
        pinnedBy: pinnedBy,
      );

  // ── Model → Firestore ────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'participantIds': participantIds,
        'participantNames': participantNames,
        'participantAvatars': participantAvatars,
        'lastMessage': lastMessage,
        'lastMessageSenderId': lastMessageSenderId,
        'lastMessageAt': Timestamp.fromDate(lastMessageAt),
        'unreadCount': unreadCount,
        'muteUntil': muteUntil.map((k, v) => MapEntry(k, Timestamp.fromDate(v))),
        'archivedBy': archivedBy,
        'pinnedBy': pinnedBy.map((k, v) => MapEntry(k, Timestamp.fromDate(v))),
      };
}
