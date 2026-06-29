part of 'connections_bloc.dart';

class ConnectionsState extends Equatable {
  final List<UserModel> connections;
  final List<UserModel> incomingRequests;
  final List<UserModel> suggestedUsers;
  final bool isLoading;
  final bool isLoadingSuggestions;
  final String? actionInProgressUserId;
  final Set<String> sentRequests;

  const ConnectionsState({
    required this.connections,
    required this.incomingRequests,
    required this.suggestedUsers,
    required this.isLoading,
    required this.isLoadingSuggestions,
    required this.actionInProgressUserId,
    required this.sentRequests,
  });

  factory ConnectionsState.initial() {
    return const ConnectionsState(
      connections: [],
      incomingRequests: [],
      suggestedUsers: [],
      isLoading: false,
      isLoadingSuggestions: false,
      actionInProgressUserId: null,
      sentRequests: {},
    );
  }

  ConnectionsState copyWith({
    List<UserModel>? connections,
    List<UserModel>? incomingRequests,
    List<UserModel>? suggestedUsers,
    bool? isLoading,
    bool? isLoadingSuggestions,
    String? actionInProgressUserId,
    bool clearActionInProgress = false,
    Set<String>? sentRequests,
  }) {
    return ConnectionsState(
      connections: connections ?? this.connections,
      incomingRequests: incomingRequests ?? this.incomingRequests,
      suggestedUsers: suggestedUsers ?? this.suggestedUsers,
      isLoading: isLoading ?? this.isLoading,
      isLoadingSuggestions: isLoadingSuggestions ?? this.isLoadingSuggestions,
      actionInProgressUserId: clearActionInProgress 
          ? null 
          : (actionInProgressUserId ?? this.actionInProgressUserId),
      sentRequests: sentRequests ?? this.sentRequests,
    );
  }

  @override
  List<Object?> get props => [
        connections,
        incomingRequests,
        suggestedUsers,
        isLoading,
        isLoadingSuggestions,
        actionInProgressUserId,
        sentRequests,
      ];
}

