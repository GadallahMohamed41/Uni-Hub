import 'package:equatable/equatable.dart';
<<<<<<< HEAD
import 'package:project_test2/features/community/domain/entities/group_invite_entity.dart';
=======
import '../../../domain/entities/group_invite_entity.dart';
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c

abstract class GroupInviteState extends Equatable {
  const GroupInviteState();

  @override
  List<Object?> get props => [];
}

class GroupInviteInitial extends GroupInviteState {}

class GroupInviteLoading extends GroupInviteState {}

class GroupInviteLoaded extends GroupInviteState {
  final GroupInviteEntity? invite;
  final String? qrData; // e.g. "myapp://group/invite?token=ABC"

  const GroupInviteLoaded({this.invite, this.qrData});

  @override
  List<Object?> get props => [invite, qrData];
}

class GroupInviteError extends GroupInviteState {
  final String message;

  const GroupInviteError(this.message);

  @override
  List<Object?> get props => [message];
}

class GroupInviteActionLoading extends GroupInviteState {
  final GroupInviteEntity? invite;
  final String? qrData;

  const GroupInviteActionLoading({this.invite, this.qrData});

  @override
  List<Object?> get props => [invite, qrData];
}

class GroupInviteActionSuccess extends GroupInviteState {
  final GroupInviteEntity? invite;
  final String? qrData;
  final String successMessage;

  const GroupInviteActionSuccess({this.invite, this.qrData, required this.successMessage});

  @override
  List<Object?> get props => [invite, qrData, successMessage];
}

class GroupInviteActionError extends GroupInviteState {
  final GroupInviteEntity? invite;
  final String? qrData;
  final String errorMessage;

  const GroupInviteActionError({this.invite, this.qrData, required this.errorMessage});

  @override
  List<Object?> get props => [invite, qrData, errorMessage];
}

