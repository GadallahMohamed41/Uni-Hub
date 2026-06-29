import 'package:equatable/equatable.dart';
import 'package:project_test2/features/community/domain/entities/group_entity.dart';
import 'package:project_test2/features/community/domain/entities/group_member_entity.dart';
import 'package:project_test2/features/community/domain/entities/group_message_entity.dart';

abstract class GroupChatState extends Equatable {
  const GroupChatState();
  @override
  List<Object?> get props => [];
}

class GroupChatInitial extends GroupChatState {
  const GroupChatInitial();
}

class GroupChatLoading extends GroupChatState {
  const GroupChatLoading();
}

class GroupChatLoaded extends GroupChatState {
  final GroupEntity group;
  final List<GroupMessageEntity> messages;
  final List<GroupMemberEntity> members;
  final List<String> typingUserIds;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isSending;
  final GroupMessageEntity? replyingTo;
  final String? error;

  const GroupChatLoaded({
    required this.group,
    required this.messages,
    required this.members,
    this.typingUserIds = const [],
    this.hasMore = true,
    this.isLoadingMore = false,
    this.isSending = false,
    this.replyingTo,
    this.error,
  });

  GroupChatLoaded copyWith({
    GroupEntity? group,
    List<GroupMessageEntity>? messages,
    List<GroupMemberEntity>? members,
    List<String>? typingUserIds,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isSending,
    GroupMessageEntity? replyingTo,
    Object? error = _sentinel,
    bool clearReply = false,
  }) {
    return GroupChatLoaded(
      group: group ?? this.group,
      messages: messages ?? this.messages,
      members: members ?? this.members,
      typingUserIds: typingUserIds ?? this.typingUserIds,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSending: isSending ?? this.isSending,
      replyingTo: clearReply ? null : (replyingTo ?? this.replyingTo),
      error: error == _sentinel ? this.error : error as String?,
    );
  }

  /// Returns member info for a given userId (for avatar display etc.)
  GroupMemberEntity? memberById(String uid) =>
      members.where((m) => m.userId == uid).cast<GroupMemberEntity?>().firstOrNull;

  /// Returns the names of currently typing users (excluding self).
  List<String> typingNames(String myUid) {
    return typingUserIds
        .where((id) => id != myUid)
        .map((id) => memberById(id)?.name ?? 'Someone')
        .toList();
  }

  @override
  List<Object?> get props => [
        group,
        messages,
        members,
        typingUserIds,
        hasMore,
        isLoadingMore,
        isSending,
        replyingTo,
        error,
      ];
}

class GroupChatKicked extends GroupChatState {
  /// The user was removed from this group.
  const GroupChatKicked();
}

/// User opened the chat but is not in [GroupEntity.memberIds] (e.g. deep link).
class GroupChatAccessDenied extends GroupChatState {
  const GroupChatAccessDenied();
}

class GroupChatDeleted extends GroupChatState {
  /// The group was deleted by the owner.
  const GroupChatDeleted();
}

class GroupChatError extends GroupChatState {
  final String message;
  const GroupChatError(this.message);
  @override
  List<Object?> get props => [message];
}

const Object _sentinel = Object();

