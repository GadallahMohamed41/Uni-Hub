import 'package:equatable/equatable.dart';
<<<<<<< HEAD
import 'package:project_test2/features/chat/domain/entities/message_entity.dart';
=======
import '../../../domain/entities/message_entity.dart';
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c

abstract class MessagesState extends Equatable {
  const MessagesState();
  @override
  List<Object?> get props => [];
}

class MessagesInitial extends MessagesState {
  const MessagesInitial();
}

class MessagesLoading extends MessagesState {
  const MessagesLoading();
}

class MessagesLoaded extends MessagesState {
  final List<MessageEntity> messages;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isSending;
  final bool isOtherTyping;
  final MessageEntity? replyingTo;
  final String? error;

  const MessagesLoaded({
    required this.messages,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.isSending = false,
    this.isOtherTyping = false,
    this.replyingTo,
    this.error,
  });

  MessagesLoaded copyWith({
    List<MessageEntity>? messages,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isSending,
    bool? isOtherTyping,
    MessageEntity? replyingTo,
    String? error,
    bool clearReply = false,
  }) {
    return MessagesLoaded(
      messages: messages ?? this.messages,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSending: isSending ?? this.isSending,
      isOtherTyping: isOtherTyping ?? this.isOtherTyping,
      replyingTo: clearReply ? null : (replyingTo ?? this.replyingTo),
      error: error,
    );
  }

  @override
  List<Object?> get props => [
        messages,
        hasMore,
        isLoadingMore,
        isSending,
        isOtherTyping,
        replyingTo,
        error,
      ];
}

class MessagesError extends MessagesState {
  final String message;
  const MessagesError(this.message);
  @override
  List<Object?> get props => [message];
}
