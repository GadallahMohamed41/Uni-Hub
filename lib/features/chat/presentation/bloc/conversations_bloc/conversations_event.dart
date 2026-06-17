import 'package:equatable/equatable.dart';

abstract class ConversationsEvent extends Equatable {
  const ConversationsEvent();
  @override
  List<Object?> get props => [];
}

class ConversationsStarted extends ConversationsEvent {
  final String userId;
  const ConversationsStarted(this.userId);
  @override
  List<Object?> get props => [userId];
}

class ConversationsStopped extends ConversationsEvent {
  const ConversationsStopped();
}

class ConversationsDeleteConversation extends ConversationsEvent {
  final String conversationId;
  const ConversationsDeleteConversation(this.conversationId);
  @override
  List<Object?> get props => [conversationId];
}

class ConversationsToggleSelect extends ConversationsEvent {
  final String conversationId;
  const ConversationsToggleSelect(this.conversationId);
  @override
  List<Object?> get props => [conversationId];
}

class ConversationsClearSelection extends ConversationsEvent {
  const ConversationsClearSelection();
}

class ConversationsDeleteSelected extends ConversationsEvent {
  final String userId;
  const ConversationsDeleteSelected(this.userId);
  @override
  List<Object?> get props => [userId];
}

class ConversationsMuteConversation extends ConversationsEvent {
  final String conversationId;
  final String userId;
  final DateTime? muteUntil;

  const ConversationsMuteConversation({
    required this.conversationId,
    required this.userId,
    this.muteUntil,
  });

  @override
  List<Object?> get props => [conversationId, userId, muteUntil];
}

class ConversationsArchiveSelected extends ConversationsEvent {
  final String userId;
  final bool archive;
  const ConversationsArchiveSelected(this.userId, {required this.archive});

  @override
  List<Object?> get props => [userId, archive];
}

class ConversationsPinSelected extends ConversationsEvent {
  final String userId;
  final bool pin;
  const ConversationsPinSelected(this.userId, {required this.pin});

  @override
  List<Object?> get props => [userId, pin];
}

