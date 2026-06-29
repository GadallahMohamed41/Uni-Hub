import 'package:equatable/equatable.dart';
<<<<<<< HEAD
import 'package:project_test2/features/chat/domain/entities/conversation_entity.dart';
=======
import '../../../domain/entities/conversation_entity.dart';
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c

abstract class ConversationsState extends Equatable {
  const ConversationsState();
  @override
  List<Object?> get props => [];
}

class ConversationsInitial extends ConversationsState {
  const ConversationsInitial();
}

class ConversationsLoading extends ConversationsState {
  const ConversationsLoading();
}

class ConversationsLoaded extends ConversationsState {
  final List<ConversationEntity> conversations;
  final Set<String> selectedChatIds;

  const ConversationsLoaded(
    this.conversations, {
    this.selectedChatIds = const {},
  });

  bool get isSelectionMode => selectedChatIds.isNotEmpty;

  ConversationsLoaded copyWith({
    List<ConversationEntity>? conversations,
    Set<String>? selectedChatIds,
  }) {
    return ConversationsLoaded(
      conversations ?? this.conversations,
      selectedChatIds: selectedChatIds ?? this.selectedChatIds,
    );
  }

  @override
  List<Object?> get props => [conversations, selectedChatIds];
}

class ConversationsError extends ConversationsState {
  final String message;
  const ConversationsError(this.message);
  @override
  List<Object?> get props => [message];
}
