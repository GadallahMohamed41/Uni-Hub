import 'package:equatable/equatable.dart';
import 'package:project_test2/features/community/domain/entities/group_entity.dart';

abstract class GroupsListState extends Equatable {
  const GroupsListState();
  @override
  List<Object?> get props => [];
}

class GroupsListInitial extends GroupsListState {
  const GroupsListInitial();
}

class GroupsListLoading extends GroupsListState {
  const GroupsListLoading();
}

class GroupsListLoaded extends GroupsListState {
  final List<GroupEntity> groups;
  final bool isCreating;
  final String? error;
  final GroupEntity? newlyCreatedGroup;

  const GroupsListLoaded({
    required this.groups,
    this.isCreating = false,
    this.error,
    this.newlyCreatedGroup,
  });

  GroupsListLoaded copyWith({
    List<GroupEntity>? groups,
    bool? isCreating,
    Object? error = _sentinel,
    Object? newlyCreatedGroup = _sentinel,
  }) {
    return GroupsListLoaded(
      groups: groups ?? this.groups,
      isCreating: isCreating ?? this.isCreating,
      error: error == _sentinel ? this.error : error as String?,
      newlyCreatedGroup: newlyCreatedGroup == _sentinel
          ? this.newlyCreatedGroup
          : newlyCreatedGroup as GroupEntity?,
    );
  }

  @override
  List<Object?> get props => [groups, isCreating, error, newlyCreatedGroup];
}

class GroupsListError extends GroupsListState {
  final String message;
  const GroupsListError(this.message);
  @override
  List<Object?> get props => [message];
}

const Object _sentinel = Object();

