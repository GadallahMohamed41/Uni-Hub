import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../models/user_model.dart';
import '../../connections/data/connections_repository.dart';

part 'connections_event.dart';
part 'connections_state.dart';

class ConnectionsBloc extends Bloc<ConnectionsEvent, ConnectionsState> {
  final ConnectionsRepository _repository;
  final String _currentUserId;

  StreamSubscription<List<UserModel>>? _connectionsSub;
  StreamSubscription<List<UserModel>>? _incomingSub;
  Timer? _loadingTimeoutTimer;

  ConnectionsBloc({
    required ConnectionsRepository repository,
    required String currentUserId,
  })  : _repository = repository,
        _currentUserId = currentUserId,
        super(ConnectionsState.initial()) {
    on<ConnectionsStarted>(_onStarted);
    on<ConnectionsConnectionsUpdated>(_onConnectionsUpdated);
    on<ConnectionsIncomingUpdated>(_onIncomingUpdated);
    on<ConnectionsSuggestedUsersRequested>(_onSuggestedRequested);
    on<ConnectionsSendRequestPressed>(_onSendRequest);
    on<ConnectionsAcceptRequestPressed>(_onAcceptRequest);
    on<ConnectionsIgnoreRequestPressed>(_onIgnoreRequest);
    on<ConnectionsLoadingTimedOut>(_onLoadingTimedOut);
    on<ConnectionsRemovePressed>(_onRemoveConnection);
  }

  void _onStarted(
    ConnectionsStarted event,
    Emitter<ConnectionsState> emit,
  ) {
    emit(state.copyWith(isLoading: true));

    _connectionsSub?.cancel();
    _incomingSub?.cancel();
    _loadingTimeoutTimer?.cancel();

    // Safety timeout - if streams don't respond in 5s, stop loading
    _loadingTimeoutTimer = Timer(const Duration(seconds: 5), () {
      add(const ConnectionsLoadingTimedOut());
    });

    _connectionsSub =
        _repository.watchConnections(_currentUserId).listen((users) {
      add(ConnectionsConnectionsUpdated(users));
    }, onError: (_) {
      add(const ConnectionsConnectionsUpdated([]));
    });

    _incomingSub =
        _repository.watchIncomingRequests(_currentUserId).listen((users) {
      add(ConnectionsIncomingUpdated(users));
    }, onError: (_) {
      add(const ConnectionsIncomingUpdated([]));
    });

    add(const ConnectionsSuggestedUsersRequested());
  }

  void _onLoadingTimedOut(
    ConnectionsLoadingTimedOut event,
    Emitter<ConnectionsState> emit,
  ) {
    if (state.isLoading) {
      emit(state.copyWith(isLoading: false));
    }
  }

  void _onConnectionsUpdated(
    ConnectionsConnectionsUpdated event,
    Emitter<ConnectionsState> emit,
  ) {
    _loadingTimeoutTimer?.cancel();
    emit(state.copyWith(connections: event.users, isLoading: false));
  }

  void _onIncomingUpdated(
    ConnectionsIncomingUpdated event,
    Emitter<ConnectionsState> emit,
  ) {
    emit(state.copyWith(incomingRequests: event.users, isLoading: false));
  }

  Future<void> _onSuggestedRequested(
    ConnectionsSuggestedUsersRequested event,
    Emitter<ConnectionsState> emit,
  ) async {
    emit(state.copyWith(isLoadingSuggestions: true));
    try {
      final users =
          await _repository.fetchSuggestedUsers(_currentUserId, limit: 50);
      emit(state.copyWith(
        suggestedUsers: users,
        isLoadingSuggestions: false,
      ));
    } catch (_) {
      emit(state.copyWith(isLoadingSuggestions: false));
    }
  }

  Future<void> _onSendRequest(
    ConnectionsSendRequestPressed event,
    Emitter<ConnectionsState> emit,
  ) async {
    emit(state.copyWith(actionInProgressUserId: event.userId));
    
    // Optimistically update the UI to show the request was sent
    final newSentRequests = Set<String>.from(state.sentRequests)..add(event.userId);
    emit(state.copyWith(sentRequests: newSentRequests));
    
    try {
      await _repository.sendConnectionRequest(
        fromUserId: _currentUserId,
        toUserId: event.userId,
      );
    } catch (_) {
      // On failure, we probably want to remove it. Not necessary if we just fetch again.
    }
    emit(state.copyWith(clearActionInProgress: true));
    // Refresh suggestions after sending request
    add(const ConnectionsSuggestedUsersRequested());
  }

  Future<void> _onAcceptRequest(
    ConnectionsAcceptRequestPressed event,
    Emitter<ConnectionsState> emit,
  ) async {
    emit(state.copyWith(actionInProgressUserId: event.userId));
    try {
      await _repository.acceptConnectionRequest(
        currentUserId: _currentUserId,
        fromUserId: event.userId,
      );
    } catch (_) {}
    emit(state.copyWith(clearActionInProgress: true));
  }

  Future<void> _onIgnoreRequest(
    ConnectionsIgnoreRequestPressed event,
    Emitter<ConnectionsState> emit,
  ) async {
    emit(state.copyWith(actionInProgressUserId: event.userId));
    try {
      await _repository.ignoreConnectionRequest(
        currentUserId: _currentUserId,
        fromUserId: event.userId,
      );
    } catch (_) {}
    emit(state.copyWith(clearActionInProgress: true));
  }

  Future<void> _onRemoveConnection(
    ConnectionsRemovePressed event,
    Emitter<ConnectionsState> emit,
  ) async {
    emit(state.copyWith(actionInProgressUserId: event.userId));
    try {
      await _repository.removeConnection(
        currentUserId: _currentUserId,
        otherUserId: event.userId,
      );
    } catch (_) {}
    emit(state.copyWith(clearActionInProgress: true));
  }

  @override
  Future<void> close() {
    _connectionsSub?.cancel();
    _incomingSub?.cancel();
    _loadingTimeoutTimer?.cancel();
    return super.close();
  }
}
