import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

<<<<<<< HEAD
import 'package:project_test2/features/chat/domain/entities/conversation_entity.dart';
import 'package:project_test2/features/chat/domain/repositories/chat_repository.dart';
import 'package:project_test2/features/chat/presentation/bloc/conversations_bloc/conversations_event.dart';
import 'package:project_test2/features/chat/presentation/bloc/conversations_bloc/conversations_state.dart';
=======
import '../../../domain/entities/conversation_entity.dart';
import '../../../domain/repositories/chat_repository.dart';
import 'conversations_event.dart';
import 'conversations_state.dart';
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c

// ── Internal event (defined here to avoid cross-file private-class issues) ────
class _ConversationsUpdated extends ConversationsEvent {
  final List<ConversationEntity> conversations;
  const _ConversationsUpdated(this.conversations);
  @override
  List<Object?> get props => [conversations];
}

class ConversationsBloc
    extends Bloc<ConversationsEvent, ConversationsState> {
  ConversationsBloc({required ChatRepository repository})
      : _repository = repository,
        super(const ConversationsInitial()) {
    on<ConversationsStarted>(_onStarted);
    on<ConversationsStopped>(_onStopped);
    on<ConversationsDeleteConversation>(_onDeleteConversation);
    on<ConversationsMuteConversation>(_onMuteConversation);
    on<_ConversationsUpdated>(_onUpdated);
    on<ConversationsToggleSelect>(_onToggleSelect);
    on<ConversationsClearSelection>(_onClearSelection);
    on<ConversationsDeleteSelected>(_onDeleteSelected);
    on<ConversationsArchiveSelected>(_onArchiveSelected);
    on<ConversationsPinSelected>(_onPinSelected);
  }

  final ChatRepository _repository;
  StreamSubscription? _sub;

  Future<void> _onStarted(
    ConversationsStarted event,
    Emitter<ConversationsState> emit,
  ) async {
    emit(const ConversationsLoading());
    await _sub?.cancel();

    _sub = _repository.watchConversations(event.userId).listen(
      (conversations) => add(_ConversationsUpdated(conversations)),
      onError: (e) => emit(ConversationsError(e.toString())),
    );
  }

  void _onStopped(
    ConversationsStopped event,
    Emitter<ConversationsState> emit,
  ) {
    _sub?.cancel();
    _sub = null;
    emit(const ConversationsInitial());
  }

  void _onUpdated(
    _ConversationsUpdated event,
    Emitter<ConversationsState> emit,
  ) {
    final current = state;
    if (current is ConversationsLoaded) {
      emit(current.copyWith(conversations: event.conversations));
    } else {
      emit(ConversationsLoaded(event.conversations));
    }
  }

  void _onToggleSelect(
    ConversationsToggleSelect event,
    Emitter<ConversationsState> emit,
  ) {
    final current = state;
    if (current is ConversationsLoaded) {
      final updated = Set<String>.from(current.selectedChatIds);
      if (updated.contains(event.conversationId)) {
        updated.remove(event.conversationId);
      } else {
        updated.add(event.conversationId);
      }
      emit(current.copyWith(selectedChatIds: updated));
    }
  }

  void _onClearSelection(
    ConversationsClearSelection event,
    Emitter<ConversationsState> emit,
  ) {
    final current = state;
    if (current is ConversationsLoaded) {
      emit(current.copyWith(selectedChatIds: {}));
    }
  }

  Future<void> _onDeleteSelected(
    ConversationsDeleteSelected event,
    Emitter<ConversationsState> emit,
  ) async {
    final current = state;
    if (current is ConversationsLoaded && current.selectedChatIds.isNotEmpty) {
      final selectedIds = current.selectedChatIds.toList();
      emit(current.copyWith(selectedChatIds: {}));
      try {
        await _repository.deleteConversationsBatch(selectedIds, event.userId);
      } catch (_) {}
    }
  }

  Future<void> _onArchiveSelected(
    ConversationsArchiveSelected event,
    Emitter<ConversationsState> emit,
  ) async {
    final current = state;
    if (current is ConversationsLoaded && current.selectedChatIds.isNotEmpty) {
      final selectedIds = current.selectedChatIds.toList();
      emit(current.copyWith(selectedChatIds: {}));
      try {
        await _repository.archiveConversationsBatch(selectedIds, event.userId, event.archive);
      } catch (_) {}
    }
  }

  Future<void> _onPinSelected(
    ConversationsPinSelected event,
    Emitter<ConversationsState> emit,
  ) async {
    final current = state;
    if (current is ConversationsLoaded && current.selectedChatIds.isNotEmpty) {
      final selectedIds = current.selectedChatIds.toList();
      emit(current.copyWith(selectedChatIds: {}));
      try {
        await _repository.pinConversationsBatch(selectedIds, event.userId, event.pin);
      } catch (_) {}
    }
  }

  Future<void> _onDeleteConversation(
    ConversationsDeleteConversation event,
    Emitter<ConversationsState> emit,
  ) async {
    try {
      await _repository.deleteConversation(event.conversationId);
    } catch (e) {
      // Could emit an error state here if needed, but the list 
      // is real-time, so it might interrupt the stream view.
      // Usually logging is enough for a deletion failure in this context.
    }
  }

  Future<void> _onMuteConversation(
    ConversationsMuteConversation event,
    Emitter<ConversationsState> emit,
  ) async {
    try {
      await _repository.muteConversation(
        event.conversationId,
        event.userId,
        event.muteUntil,
      );
    } catch (e) {
      // Stream will automatically revert state if failed, or log.
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
