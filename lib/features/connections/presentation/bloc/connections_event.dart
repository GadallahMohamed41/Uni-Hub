part of 'connections_bloc.dart';

abstract class ConnectionsEvent extends Equatable {
  const ConnectionsEvent();

  @override
  List<Object?> get props => [];
}

class ConnectionsStarted extends ConnectionsEvent {
  const ConnectionsStarted();
}

class ConnectionsConnectionsUpdated extends ConnectionsEvent {
  final List<UserModel> users;

  const ConnectionsConnectionsUpdated(this.users);

  @override
  List<Object?> get props => [users];
}

class ConnectionsIncomingUpdated extends ConnectionsEvent {
  final List<UserModel> users;

  const ConnectionsIncomingUpdated(this.users);

  @override
  List<Object?> get props => [users];
}

class ConnectionsSuggestedUsersRequested extends ConnectionsEvent {
  const ConnectionsSuggestedUsersRequested();
}

class ConnectionsSendRequestPressed extends ConnectionsEvent {
  final String userId;

  const ConnectionsSendRequestPressed(this.userId);

  @override
  List<Object?> get props => [userId];
}

class ConnectionsAcceptRequestPressed extends ConnectionsEvent {
  final String userId;

  const ConnectionsAcceptRequestPressed(this.userId);

  @override
  List<Object?> get props => [userId];
}

class ConnectionsIgnoreRequestPressed extends ConnectionsEvent {
  final String userId;

  const ConnectionsIgnoreRequestPressed(this.userId);

  @override
  List<Object?> get props => [userId];
}

class ConnectionsLoadingTimedOut extends ConnectionsEvent {
  const ConnectionsLoadingTimedOut();
}

class ConnectionsRemovePressed extends ConnectionsEvent {
  final String userId;

  const ConnectionsRemovePressed(this.userId);

  @override
  List<Object?> get props => [userId];
}
