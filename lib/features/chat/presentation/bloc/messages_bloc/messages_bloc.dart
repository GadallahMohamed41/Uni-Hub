import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:project_test2/features/chat/domain/entities/message_entity.dart';
import 'package:project_test2/features/chat/domain/repositories/chat_repository.dart';
import 'package:project_test2/features/chat/presentation/bloc/messages_bloc/messages_event.dart';
import 'package:project_test2/features/chat/presentation/bloc/messages_bloc/messages_state.dart';

// ── Internal events (defined here to avoid cross-file private-class issues) ───

class _MessagesStreamUpdated extends MessagesEvent {
  final List<MessageEntity> messages;
  const _MessagesStreamUpdated(this.messages);
  @override
  List<Object?> get props => [messages];
}

class _TypingStreamUpdated extends MessagesEvent {
  final bool isOtherTyping;
  const _TypingStreamUpdated(this.isOtherTyping);
  @override
  List<Object?> get props => [isOtherTyping];
}

class _MessagesStreamError extends MessagesEvent {
  final Object error;
  const _MessagesStreamError(this.error);
  @override
  List<Object?> get props => [error];
}

class MessagesBloc extends Bloc<MessagesEvent, MessagesState> {
  MessagesBloc({required ChatRepository repository})
      : _repository = repository,
        super(const MessagesInitial()) {
    on<MessagesStarted>(_onStarted);
    on<MessagesLoadMore>(_onLoadMore);
    on<MessageSent>(_onSendMessage);
    on<LocalMessageUpserted>(_onLocalMessageUpserted);
    on<LocalMessageRemoved>(_onLocalMessageRemoved);
    on<MessagesSeen>(_onMarkSeen);
    on<TypingStatusChanged>(_onTypingChanged);
    on<MessageDeleted>(_onDeleteMessage);
    on<MessageDeletedForMe>(_onDeleteMessageForMe);
    on<MessageDeletedForEveryone>(_onDeleteMessageForEveryone);
    on<MessageEdited>(_onEditMessage);
    on<MessageReacted>(_onReactToMessage);
    on<MessageRemovedReaction>(_onRemoveReaction);
    on<MessageReplySet>(_onReplySet);
    on<_MessagesStreamUpdated>(_onStreamUpdated);
    on<_MessagesStreamError>(_onStreamError);
    on<_TypingStreamUpdated>(_onTypingStreamUpdated);
  }

  final ChatRepository _repository;
  StreamSubscription? _messagesSub;
  StreamSubscription? _typingSub;
  final Map<String, MessageEntity> _pendingLocalMessages = {};
  List<MessageEntity> _lastStreamMessages = const [];

  String? _conversationId;
  String? _myUserId;
  String? _otherUserId;
  /// Pagination cursor: the id of the oldest message currently loaded.
  String? _oldestMessageId;
  static const int _pageSize = 30;

  // ── Handlers ──────────────────────────────────────────────────────────────

  Future<void> _onStarted(
    MessagesStarted event,
    Emitter<MessagesState> emit,
  ) async {
    _conversationId = event.conversationId;
    _myUserId = event.myUserId;
    _pendingLocalMessages.clear();
    _lastStreamMessages = const [];

    emit(const MessagesLoading());

    await _messagesSub?.cancel();
    await _typingSub?.cancel();

    try {
      await _repository.markDelivered(event.conversationId, event.myUserId);
    } catch (_) {}

    _messagesSub = _repository
        .watchMessages(event.conversationId, pageSize: _pageSize)
        .listen(
          (messages) => add(_MessagesStreamUpdated(messages)),
          onError: (e) => add(_MessagesStreamError(e)),
        );
  }

  void _subscribeTyping(String otherUserId) {
    final convId = _conversationId;
    if (convId == null) return;
    _typingSub?.cancel();
    _typingSub = _repository
        .watchTyping(convId, otherUserId)
        .listen((isTyping) => add(_TypingStreamUpdated(isTyping)));
  }

  Future<void> _onLoadMore(
    MessagesLoadMore event,
    Emitter<MessagesState> emit,
  ) async {
    final current = state;
    if (current is! MessagesLoaded) return;
    if (current.isLoadingMore || !current.hasMore) return;
    final oldestId = _oldestMessageId;
    if (oldestId == null) return;

    emit(current.copyWith(isLoadingMore: true));

    try {
      final older = await _repository.loadMoreMessages(
        _conversationId!,
        beforeMessageId: oldestId,
        pageSize: _pageSize,
      );

      final currentStateAfter = state;
      if (currentStateAfter is MessagesLoaded) {
        final combined = [...older, ...currentStateAfter.messages];
        if (older.isNotEmpty) {
          _oldestMessageId = older.first.id;
        }

        emit(currentStateAfter.copyWith(
          messages: combined,
          isLoadingMore: false,
          hasMore: older.length == _pageSize,
        ));
      }
    } catch (e) {
      final currentStateAfter = state;
      if (currentStateAfter is MessagesLoaded) {
        emit(currentStateAfter.copyWith(
          isLoadingMore: false,
          error: e.toString(),
        ));
      }
    }
  }

  Future<void> _onSendMessage(
    MessageSent event,
    Emitter<MessagesState> emit,
  ) async {
    final convId = _conversationId;
    if (convId == null) return;

    if (state is MessagesLoaded) {
      emit((state as MessagesLoaded).copyWith(isSending: true));
    }

    try {
      await _repository.sendMessage(
        messageId: event.messageId,
        conversationId: convId,
        senderId: event.senderId,
        senderName: event.senderName,
        senderAvatar: event.senderAvatar,
        text: event.text,
        participantIds: event.participantIds,
        mediaUrls: event.mediaUrls,
        audioUrl: event.audioUrl,
        audioDuration: event.audioDuration,
        messageType: event.messageType,
        replyToMessageId: event.replyingTo?.id,
        replyToText: event.replyingTo?.text,
        replyToSenderId: event.replyingTo?.senderId,
        replyToSenderName: event.replyingTo?.senderName,
      );
      // Clear typing indicator after send
      _repository.setTyping(convId, event.senderId, false);

      final sentMessageId = event.messageId;
      if (sentMessageId != null) {
        final pending = _pendingLocalMessages[sentMessageId];
        if (pending != null) {
          _pendingLocalMessages[sentMessageId] =
              pending.copyWith(status: MessageStatus.sent);
          _emitCombinedIfLoaded(emit);
        }
      }
    } catch (e, st) {
      print('❌ Error in _onSendMessage: $e\n$st');
      if (state is MessagesLoaded) {
        emit((state as MessagesLoaded).copyWith(isSending: false, error: 'Failed to send: $e'));
      }
      return;
    }

    if (state is MessagesLoaded) {
      emit((state as MessagesLoaded).copyWith(
        isSending: false,
        error: null,
        clearReply: true,
      ));
    }
  }

  Future<void> _onMarkSeen(
    MessagesSeen event,
    Emitter<MessagesState> emit,
  ) async {
    final convId = _conversationId;
    final myId = _myUserId;
    if (convId == null || myId == null) return;
    try {
      await _repository.markSeen(convId, myId);
    } catch (_) {}
  }

  Future<void> _onTypingChanged(
    TypingStatusChanged event,
    Emitter<MessagesState> emit,
  ) async {
    final convId = _conversationId;
    final myId = _myUserId;
    if (convId == null || myId == null) return;
    try {
      await _repository.setTyping(convId, myId, event.isTyping);
    } catch (_) {}
  }

  Future<void> _onDeleteMessage(
    MessageDeleted event,
    Emitter<MessagesState> emit,
  ) async {
    final convId = _conversationId;
    if (convId == null) return;
    await _repository.deleteMessage(
      conversationId: convId,
      messageId: event.messageId,
    );
  }

  Future<void> _onDeleteMessageForMe(
    MessageDeletedForMe event,
    Emitter<MessagesState> emit,
  ) async {
    final convId = _conversationId;
    final myId = _myUserId;
    if (convId == null || myId == null) return;
    final current = state;
    if (current is MessagesLoaded) {
      final updated = current.messages.map((m) {
        if (m.id != event.messageId) return m;
        final list = [...m.deletedForMe];
        if (!list.contains(myId)) list.add(myId);
        return m.copyWith(deletedForMe: list);
      }).toList();
      emit(current.copyWith(messages: updated));
    }
    await _repository.deleteMessageForMe(
      conversationId: convId,
      messageId: event.messageId,
      userId: myId,
    );
  }

  Future<void> _onDeleteMessageForEveryone(
    MessageDeletedForEveryone event,
    Emitter<MessagesState> emit,
  ) async {
    final convId = _conversationId;
    if (convId == null) return;
    final current = state;
    if (current is MessagesLoaded) {
      final updated = current.messages.map((m) {
        if (m.id != event.messageId) return m;
        return m.copyWith(
          deletedForAll: true,
          text: 'This message was deleted.',
          mediaUrls: const [],
          audioUrl: null,
          reactions: const {},
        );
      }).toList();
      emit(current.copyWith(messages: updated));
    }

    try {
      await _repository.deleteMessageForEveryone(
        conversationId: convId,
        messageId: event.messageId,
      );
    } catch (e) {
      final s = state;
      if (s is MessagesLoaded) {
        emit(s.copyWith(error: 'Failed to delete: $e'));
      }
    }
  }

  Future<void> _onEditMessage(
    MessageEdited event,
    Emitter<MessagesState> emit,
  ) async {
    final convId = _conversationId;
    if (convId == null) return;
    await _repository.editMessage(
      conversationId: convId,
      messageId: event.messageId,
      newText: event.newText,
    );
  }

  Future<void> _onReactToMessage(
    MessageReacted event,
    Emitter<MessagesState> emit,
  ) async {
    final convId = _conversationId;
    final myId = _myUserId;
    if (convId == null || myId == null) return;
    await _repository.reactToMessage(
      conversationId: convId,
      messageId: event.messageId,
      userId: myId,
      emoji: event.emoji,
    );
  }

  Future<void> _onRemoveReaction(
    MessageRemovedReaction event,
    Emitter<MessagesState> emit,
  ) async {
    final convId = _conversationId;
    final myId = _myUserId;
    if (convId == null || myId == null) return;
    await _repository.removeReaction(
      conversationId: convId,
      messageId: event.messageId,
      userId: myId,
    );
  }

  void _onReplySet(
    MessageReplySet event,
    Emitter<MessagesState> emit,
  ) {
    if (state is MessagesLoaded) {
      emit((state as MessagesLoaded).copyWith(
        replyingTo: event.replyingTo,
        clearReply: event.replyingTo == null,
      ));
    }
  }

  void _onStreamUpdated(
    _MessagesStreamUpdated event,
    Emitter<MessagesState> emit,
  ) {
    final streamMessages = List<MessageEntity>.from(event.messages);
    _lastStreamMessages = streamMessages;
    final streamIds = streamMessages.map((m) => m.id).toSet();
    for (final id in streamIds) {
      _pendingLocalMessages.remove(id);
    }

    // Resolve other user for typing subscription (first time only)
    if (_otherUserId == null && streamMessages.isNotEmpty && _myUserId != null) {
      final other = streamMessages.firstWhere(
        (m) => m.senderId != _myUserId,
        orElse: () => streamMessages.first,
      );
      if (other.senderId != _myUserId) {
        _otherUserId = other.senderId;
        _subscribeTyping(_otherUserId!);
      }
    }

    // Update pagination cursor to oldest message ID
    if (streamMessages.isNotEmpty) {
      _oldestMessageId = streamMessages.first.id;
    }

    final current = state;
    final isOtherTyping =
        current is MessagesLoaded ? current.isOtherTyping : false;

    final combined = _combineStreamAndPending(streamMessages);

    emit(MessagesLoaded(
      messages: combined,
      hasMore: streamMessages.length >= _pageSize,
      isOtherTyping: isOtherTyping,
    ));
  }

  void _onLocalMessageUpserted(
    LocalMessageUpserted event,
    Emitter<MessagesState> emit,
  ) {
    final msg = event.message;
    _pendingLocalMessages[msg.id] = msg;

    final current = state;
    if (current is MessagesLoaded) {
      final combined = _combineStreamAndPending(_lastStreamMessages);
      emit(current.copyWith(messages: combined));
      return;
    }

    emit(MessagesLoaded(messages: [msg]));
  }

  void _onLocalMessageRemoved(
    LocalMessageRemoved event,
    Emitter<MessagesState> emit,
  ) {
    _pendingLocalMessages.remove(event.messageId);
    _emitCombinedIfLoaded(emit);
  }

  List<MessageEntity> _combineStreamAndPending(List<MessageEntity> streamMessages) {
    final byId = <String, MessageEntity>{};
    final streamIds = <String>{};
    for (final m in streamMessages) {
      byId[m.id] = m;
      streamIds.add(m.id);
    }
    for (final e in _pendingLocalMessages.entries) {
      if (!streamIds.contains(e.key)) {
        byId[e.key] = e.value;
      }
    }
    final combined = byId.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return combined;
  }

  void _emitCombinedIfLoaded(Emitter<MessagesState> emit) {
    final current = state;
    if (current is! MessagesLoaded) return;
    final combined = _combineStreamAndPending(_lastStreamMessages);
    emit(current.copyWith(messages: combined));
  }

  void _onStreamError(
    _MessagesStreamError event,
    Emitter<MessagesState> emit,
  ) {
    emit(MessagesError(event.error.toString()));
  }

  void _onTypingStreamUpdated(
    _TypingStreamUpdated event,
    Emitter<MessagesState> emit,
  ) {
    final current = state;
    if (current is MessagesLoaded) {
      emit(current.copyWith(isOtherTyping: event.isOtherTyping));
    }
  }

  @override
  Future<void> close() {
    _messagesSub?.cancel();
    _typingSub?.cancel();
    return super.close();
  }
}
