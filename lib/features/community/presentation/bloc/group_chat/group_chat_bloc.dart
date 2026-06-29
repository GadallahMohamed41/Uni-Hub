import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_test2/features/community/domain/entities/group_entity.dart';
import 'package:project_test2/features/community/domain/repositories/group_repository.dart';
import 'package:project_test2/features/community/presentation/bloc/group_chat/group_chat_event.dart';
import 'package:project_test2/features/community/presentation/bloc/group_chat/group_chat_state.dart';

class GroupChatBloc extends Bloc<GroupChatEvent, GroupChatState> {
  GroupChatBloc({
    required GroupRepository repository,
    required String groupId,
    required String currentUserId,
  })  : _repo = repository,
        _groupId = groupId,
        _myId = currentUserId,
        super(const GroupChatLoading()) {
    on<GroupChatStarted>(_onStarted);
    on<GroupChatMessagesUpdated>(_onMessagesUpdated);
    on<GroupChatGroupUpdated>(_onGroupUpdated);
    on<GroupChatMembersUpdated>(_onMembersUpdated);
    on<GroupChatTypingUpdated>(_onTypingUpdated);
    on<GroupChatSendMessage>(_onSendMessage);
    on<GroupChatEditMessage>(_onEditMessage);
    on<GroupChatDeleteMessageForMe>(_onDeleteForMe);
    on<GroupChatDeleteMessageForEveryone>(_onDeleteForEveryone);
    on<GroupChatReactToMessage>(_onReact);
    on<GroupChatRemoveReaction>(_onRemoveReaction);
    on<GroupChatLoadMore>(_onLoadMore);
    on<GroupChatTypingChanged>(_onTypingChanged);
    on<GroupChatSetReply>(_onSetReply);
    on<GroupChatPinMessage>(_onPinMessage);
    on<GroupChatUnpinMessage>(_onUnpinMessage);
    on<GroupChatMarkSeen>(_onMarkSeen);
    on<GroupChatMarkListened>(_onMarkListened);
    on<GroupChatErrorCleared>(_onErrorCleared);
  }

  final GroupRepository _repo;
  final String _groupId;
  final String _myId;

  StreamSubscription? _messagesSub;
  StreamSubscription? _groupSub;
  StreamSubscription? _membersSub;
  StreamSubscription? _typingSub;
  Timer? _typingDebounce;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> _onStarted(
      GroupChatStarted event, Emitter<GroupChatState> emit) async {
    final group = await _repo.getGroup(_groupId);
    if (group == null) {
      emit(const GroupChatDeleted());
      return;
    }
    if (!group.isMember(event.currentUserId)) {
      emit(const GroupChatAccessDenied());
      return;
    }

    // Emit initial loaded state with empty lists; streams will populate them.
    emit(GroupChatLoaded(group: group, messages: const [], members: const []));

    _messagesSub ??= _repo
        .watchMessages(_groupId)
        .listen((msgs) => add(GroupChatMessagesUpdated(msgs)));

    _groupSub ??= _repo.watchGroup(_groupId).listen((group) {
      add(GroupChatGroupUpdated(group ?? _emptyGroup()));
    });

    // Single subscription for members — no double-subscribe
    _membersSub ??= _repo
        .watchMembers(_groupId)
        .listen((m) => add(GroupChatMembersUpdated(m)));

    _typingSub ??= _repo
        .watchTyping(_groupId)
        .listen((ids) => add(GroupChatTypingUpdated(ids)));
  }

  void _onGroupUpdated(
      GroupChatGroupUpdated event, Emitter<GroupChatState> emit) {
    if (event.group.id.isEmpty) {
      emit(const GroupChatDeleted());
      return;
    }
    final current = state;
    if (current is GroupChatLoaded) {
      if (!event.group.isMember(_myId)) {
        emit(const GroupChatKicked());
        return;
      }
      emit(current.copyWith(group: event.group));
    }
  }

  void _onMessagesUpdated(
      GroupChatMessagesUpdated event, Emitter<GroupChatState> emit) {
    final current = state;
    if (current is GroupChatLoaded) {
      emit(current.copyWith(messages: event.messages));
    }
  }

  void _onMembersUpdated(
      GroupChatMembersUpdated event, Emitter<GroupChatState> emit) {
    final current = state;
    if (current is GroupChatLoaded) {
      emit(current.copyWith(members: event.members));
    }
  }

  void _onTypingUpdated(
      GroupChatTypingUpdated event, Emitter<GroupChatState> emit) {
    final current = state;
    if (current is GroupChatLoaded) {
      emit(current.copyWith(typingUserIds: event.typingUserIds));
    }
  }

  // ── Messaging ──────────────────────────────────────────────────────────────

  Future<void> _onSendMessage(
      GroupChatSendMessage event, Emitter<GroupChatState> emit) async {
    final current = state;
    if (current is! GroupChatLoaded) return;
    emit(current.copyWith(isSending: true));
    try {
      await _repo.sendMessage(
        groupId: _groupId,
        senderId: event.senderId,
        senderName: event.senderName,
        senderAvatarUrl: event.senderAvatarUrl,
        text: event.text,
        memberIds: current.group.memberIds,
        mediaUrls: event.mediaUrls,
        messageType: event.messageType,
        audioDuration: event.audioDuration,
        replyToMessageId: event.replyToMessageId,
        replyToText: event.replyToText,
        replyToSenderId: event.replyToSenderId,
        replyToSenderName: event.replyToSenderName,
        mentionedUserIds: event.mentionedUserIds,
      );
      await _repo.setTyping(_groupId, event.senderId, false);
      final s = state;
      if (s is GroupChatLoaded) {
        emit(s.copyWith(isSending: false, clearReply: true));
      }
    } catch (e) {
      final s = state;
      if (s is GroupChatLoaded) {
        emit(s.copyWith(isSending: false, error: e.toString()));
      }
    }
  }

  Future<void> _onEditMessage(
      GroupChatEditMessage event, Emitter<GroupChatState> emit) async {
    try {
      await _repo.editMessage(
        groupId: _groupId,
        messageId: event.messageId,
        newText: event.newText,
        editorId: event.editorId,
      );
    } catch (e) {
      _emitError(emit, e.toString());
    }
  }

  Future<void> _onDeleteForMe(
      GroupChatDeleteMessageForMe event, Emitter<GroupChatState> emit) async {
    try {
      await _repo.deleteMessageForMe(
          groupId: _groupId,
          messageId: event.messageId,
          userId: event.userId);
    } catch (e) {
      _emitError(emit, e.toString());
    }
  }

  Future<void> _onDeleteForEveryone(GroupChatDeleteMessageForEveryone event,
      Emitter<GroupChatState> emit) async {
    try {
      await _repo.deleteMessageForEveryone(
          groupId: _groupId,
          messageId: event.messageId,
          senderId: event.senderId);
    } catch (e) {
      _emitError(emit, e.toString());
    }
  }

  Future<void> _onReact(
      GroupChatReactToMessage event, Emitter<GroupChatState> emit) async {
    try {
      await _repo.reactToMessage(
        groupId: _groupId,
        messageId: event.messageId,
        userId: event.userId,
        emoji: event.emoji,
      );
    } catch (e) {
      _emitError(emit, e.toString());
    }
  }

  Future<void> _onRemoveReaction(
      GroupChatRemoveReaction event, Emitter<GroupChatState> emit) async {
    try {
      await _repo.removeReaction(
          groupId: _groupId, messageId: event.messageId, userId: event.userId);
    } catch (e) {
      _emitError(emit, e.toString());
    }
  }

  // ── Pagination ─────────────────────────────────────────────────────────────

  Future<void> _onLoadMore(
      GroupChatLoadMore event, Emitter<GroupChatState> emit) async {
    final current = state;
    if (current is! GroupChatLoaded) return;
    if (current.isLoadingMore || !current.hasMore || current.messages.isEmpty) {
      return;
    }
    emit(current.copyWith(isLoadingMore: true));
    try {
      final older = await _repo.loadMoreMessages(_groupId,
          beforeMessageId: current.messages.first.id);
      final s = state;
      if (s is GroupChatLoaded) {
        emit(s.copyWith(
          messages: [...older, ...s.messages],
          isLoadingMore: false,
          hasMore: older.length >= 30,
        ));
      }
    } catch (e) {
      final s = state;
      if (s is GroupChatLoaded) {
        emit(s.copyWith(isLoadingMore: false, error: e.toString()));
      }
    }
  }

  // ── Typing ─────────────────────────────────────────────────────────────────

  Future<void> _onTypingChanged(
      GroupChatTypingChanged event, Emitter<GroupChatState> emit) async {
    _typingDebounce?.cancel();
    if (event.isTyping) {
      await _repo.setTyping(_groupId, event.userId, true);
      _typingDebounce = Timer(const Duration(seconds: 5), () {
        _repo.setTyping(_groupId, event.userId, false);
      });
    } else {
      await _repo.setTyping(_groupId, event.userId, false);
    }
  }

  // ── Reply ──────────────────────────────────────────────────────────────────

  void _onSetReply(GroupChatSetReply event, Emitter<GroupChatState> emit) {
    final current = state;
    if (current is GroupChatLoaded) {
      emit(current.copyWith(
          replyingTo: event.message, clearReply: event.message == null));
    }
  }

  // ── Admin ──────────────────────────────────────────────────────────────────

  Future<void> _onPinMessage(
      GroupChatPinMessage event, Emitter<GroupChatState> emit) async {
    try {
      await _repo.pinMessage(
          groupId: _groupId,
          messageId: event.messageId,
          actorId: event.actorId);
    } catch (e) {
      _emitError(emit, e.toString());
    }
  }

  Future<void> _onUnpinMessage(
      GroupChatUnpinMessage event, Emitter<GroupChatState> emit) async {
    try {
      await _repo.unpinMessage(groupId: _groupId, actorId: event.actorId);
    } catch (e) {
      _emitError(emit, e.toString());
    }
  }

  // ── Mark seen ──────────────────────────────────────────────────────────────

  Future<void> _onMarkSeen(
      GroupChatMarkSeen event, Emitter<GroupChatState> emit) async {
    try {
      await _repo.markSeen(
          groupId: _groupId,
          userId: event.userId,
          messageIds: event.messageIds);
    } catch (_) {}
  }

  Future<void> _onMarkListened(
      GroupChatMarkListened event, Emitter<GroupChatState> emit) async {
    try {
      await _repo.markListened(
          groupId: _groupId,
          userId: event.userId,
          messageId: event.messageId);
    } catch (_) {}
  }

  void _onErrorCleared(
      GroupChatErrorCleared event, Emitter<GroupChatState> emit) {
    final current = state;
    if (current is GroupChatLoaded) {
      emit(current.copyWith(error: null));
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _emitError(Emitter<GroupChatState> emit, String msg) {
    final current = state;
    if (current is GroupChatLoaded) {
      emit(current.copyWith(error: msg));
    }
  }

  GroupEntity _emptyGroup() => GroupEntity(
        id: '',
        name: '',
        description: '',
        ownerId: '',
        adminIds: const [],
        memberIds: const [],
        activeMembers: const [],
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  @override
  Future<void> close() {
    _messagesSub?.cancel();
    _groupSub?.cancel();
    _membersSub?.cancel();
    _typingSub?.cancel();
    _typingDebounce?.cancel();
    return super.close();
  }
}

