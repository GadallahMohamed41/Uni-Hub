import 'package:equatable/equatable.dart';
import 'package:project_test2/features/community/domain/entities/community_entity.dart';

abstract class CommunityListState extends Equatable {
  const CommunityListState();
  @override
  List<Object?> get props => [];
}

class CommunityListInitial extends CommunityListState {
  const CommunityListInitial();
}

class CommunityListLoading extends CommunityListState {
  const CommunityListLoading();
}

class CommunityListLoaded extends CommunityListState {
  final List<CommunityEntity> communities;
  final bool isCreating;
  final CommunityEntity? newlyCreated;
  final String? error;

  const CommunityListLoaded({
    required this.communities,
    this.isCreating = false,
    this.newlyCreated,
    this.error,
  });

  CommunityListLoaded copyWith({
    List<CommunityEntity>? communities,
    bool? isCreating,
    Object? newlyCreated = _sentinel,
    Object? error = _sentinel,
  }) {
    return CommunityListLoaded(
      communities: communities ?? this.communities,
      isCreating: isCreating ?? this.isCreating,
      newlyCreated: newlyCreated == _sentinel
          ? this.newlyCreated
          : newlyCreated as CommunityEntity?,
      error: error == _sentinel ? this.error : error as String?,
    );
  }

  @override
  List<Object?> get props => [communities, isCreating, newlyCreated, error];
}

class CommunityListError extends CommunityListState {
  final String message;
  const CommunityListError(this.message);
  @override
  List<Object?> get props => [message];
}

const Object _sentinel = Object();

