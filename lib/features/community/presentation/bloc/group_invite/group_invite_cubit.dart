import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gal/gal.dart';
<<<<<<< HEAD
import 'package:project_test2/core/config/app_config.dart';
=======
import 'package:project_test2/core/app_config.dart';
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

<<<<<<< HEAD
import 'package:project_test2/features/community/domain/entities/group_invite_entity.dart';
import 'package:project_test2/features/community/domain/repositories/group_invite_repository.dart';
import 'package:project_test2/features/community/presentation/bloc/group_invite/group_invite_state.dart';
=======
import '../../../domain/entities/group_invite_entity.dart';
import '../../../domain/repositories/group_invite_repository.dart';
import 'group_invite_state.dart';
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c

class GroupInviteCubit extends Cubit<GroupInviteState> {
  final GroupInviteRepository _repository;

  GroupInviteCubit({required GroupInviteRepository repository})
      : _repository = repository,
        super(GroupInviteInitial());

  Future<void> generateOrGetInvite(String groupId, String createdBy) async {
    emit(GroupInviteLoading());
    try {
      final invite = await _repository.createInvite(
        groupId: groupId,
        creatorId: createdBy,
        requiresApproval: true,
      );
      
      // Use the production-grade HTTPS deep link URL for external scanning clickability
      final qrData = '${AppConfig.deepLinkDomain}/group/invite?token=${invite.inviteToken}';
      debugPrint('[GroupInviteCubit] Generated QR HTTPS Link: $qrData');
      
      emit(GroupInviteLoaded(invite: invite, qrData: qrData));
    } catch (e) {
      debugPrint('[GroupInviteCubit] Error generating invite: $e');
      emit(GroupInviteError('Failed to load invite: ${e.toString()}'));
    }
  }

  Future<void> downloadQrCode(Uint8List imageBytes, {required String name}) async {
    final GroupInviteEntity? currentInvite = state is GroupInviteLoaded ? (state as GroupInviteLoaded).invite : null;
    final String? currentQrData = state is GroupInviteLoaded ? (state as GroupInviteLoaded).qrData : null;
    
    emit(GroupInviteActionLoading(invite: currentInvite, qrData: currentQrData));
    try {
      debugPrint('[GroupInviteCubit] Requesting gallery access...');
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          throw Exception("Permission to save images was denied. Please enable storage permission in settings.");
        }
      }
      
      // Sanitize the group name to create a valid file name
      final safeName = name.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_');
      final fileName = "Group_Invite_${safeName}_${DateTime.now().millisecondsSinceEpoch}";
      
      debugPrint('[GroupInviteCubit] Saving QR bytes using Gal to gallery...');
      await Gal.putImageBytes(
        imageBytes,
        name: fileName,
      );

      debugPrint('[GroupInviteCubit] QR saved successfully.');
      emit(GroupInviteActionSuccess(
        invite: currentInvite,
        qrData: currentQrData,
        successMessage: "]QR Saved to gallery successfully.",
      ));
    } catch (e) {
      debugPrint('[GroupInviteCubit] Error downloading QR: $e');
      emit(GroupInviteActionError(
        invite: currentInvite,
        qrData: currentQrData,
        errorMessage: "Failed to save QR: ${e.toString()}",
      ));
    }
  }

  Future<void> shareQrCode(Uint8List imageBytes, String text) async {
    final GroupInviteEntity? currentInvite = state is GroupInviteLoaded ? (state as GroupInviteLoaded).invite : null;
    final String? currentQrData = state is GroupInviteLoaded ? (state as GroupInviteLoaded).qrData : null;
    
    emit(GroupInviteActionLoading(invite: currentInvite, qrData: currentQrData));
    try {
      debugPrint('[GroupInviteCubit] Sharing QR code...');
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/invite_qr.png').create();
      await file.writeAsBytes(imageBytes);

      await SharePlus.instance.share(
        ShareParams(
          text: text,
          files: [XFile(file.path, mimeType: 'image/png')],
        ),
      );
      emit(GroupInviteLoaded(invite: currentInvite, qrData: currentQrData)); // Reset to loaded
    } catch (e) {
      debugPrint('[GroupInviteCubit] Error sharing QR: $e');
      emit(GroupInviteActionError(
        invite: currentInvite,
        qrData: currentQrData,
        errorMessage: "فشل مشاركة رمز QR: ${e.toString()}",
      ));
    }
  }
}
