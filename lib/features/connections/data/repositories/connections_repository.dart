import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:project_test2/features/profile/data/models/user_model.dart';

Map<String, dynamic> _extractSenderData(UserModel? user) {
  if (user == null) return {};
  final name = (user.name ).trim();
  final avatar = (user.avatarUrl ?? '').trim();
  return {
    if (name.isNotEmpty) 'senderName': name,
    if (avatar.isNotEmpty) 'senderAvatarUrl': avatar,
  };
}

enum ConnectionStatus {
  none,
  connectable,
  pending,
  incomingRequest,
  connected,
}

class ConnectionsRepository {
  final FirebaseFirestore _firestore;

  ConnectionsRepository(FirebaseFirestore firestore) : _firestore = firestore;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  Future<void> sendConnectionRequest({
    required String fromUserId,
    required String toUserId,
  }) async {
    if (fromUserId == toUserId) {
      return;
    }

    final fromConnectionsRef = _usersRef
        .doc(fromUserId)
        .collection('connections')
        .doc(toUserId);
    final toConnectionsRef =
        _usersRef.doc(toUserId).collection('connections').doc(fromUserId);

    final outgoingRef = _usersRef
        .doc(fromUserId)
        .collection('outgoingConnectionRequests')
        .doc(toUserId);
    final incomingRef = _usersRef
        .doc(toUserId)
        .collection('incomingConnectionRequests')
        .doc(fromUserId);

    final existing = await Future.wait([
      fromConnectionsRef.get(),
      toConnectionsRef.get(),
      outgoingRef.get(),
      incomingRef.get(),
    ]);

    final fromConnectionDoc = existing[0];
    final toConnectionDoc = existing[1];
    final outgoingDoc = existing[2];
    final incomingDoc = existing[3];

    if (fromConnectionDoc.exists || toConnectionDoc.exists) {
      return;
    }

    if (outgoingDoc.exists || incomingDoc.exists) {
      return;
    }

    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();
    final notificationId = _firestore.collection('notifications').doc().id;

    batch.set(outgoingRef, {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'createdAt': now,
      'notificationId': notificationId,
    });

    batch.set(incomingRef, {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'createdAt': now,
      'notificationId': notificationId,
    });

    // Fetch sender info for notification
    UserModel? fromUser;
    try {
      final senderDoc = await _usersRef.doc(fromUserId).get();
      if (senderDoc.exists) {
        fromUser = UserModel.fromFirestore(senderDoc);
      }
    } catch (_) {}

    final senderData = _extractSenderData(fromUser);

    batch.set(_firestore.collection('notifications').doc(notificationId), {
      'toUserId': toUserId,
      'fromUserId': fromUserId,
      'type': 'connection_request',
      'createdAt': Timestamp.now(),
      'read': false,
      ...senderData,
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> acceptConnectionRequest({
    required String currentUserId,
    required String fromUserId,
  }) async {
    final incomingRef = _usersRef
        .doc(currentUserId)
        .collection('incomingConnectionRequests')
        .doc(fromUserId);
    final outgoingRef = _usersRef
        .doc(fromUserId)
        .collection('outgoingConnectionRequests')
        .doc(currentUserId);

    final currentConnectionRef = _usersRef
        .doc(currentUserId)
        .collection('connections')
        .doc(fromUserId);
    final otherConnectionRef =
        _usersRef.doc(fromUserId).collection('connections').doc(currentUserId);

    final currentUserRef = _usersRef.doc(currentUserId);
    final otherUserRef = _usersRef.doc(fromUserId);

    final batch = _firestore.batch();

    batch.delete(incomingRef);
    batch.delete(outgoingRef);

    final now = FieldValue.serverTimestamp();

    batch.set(currentConnectionRef, {
      'userId': fromUserId,
      'createdAt': now,
    });

    batch.set(otherConnectionRef, {
      'userId': currentUserId,
      'createdAt': now,
    });

    batch.update(currentUserRef, {
      'connectionsCount': FieldValue.increment(1),
    });

    batch.update(otherUserRef, {
      'connectionsCount': FieldValue.increment(1),
    });

    // Fetch acceptor info for notification
    UserModel? acceptorUser;
    try {
      final acceptorDoc = await _usersRef.doc(currentUserId).get();
      if (acceptorDoc.exists) {
        acceptorUser = UserModel.fromFirestore(acceptorDoc);
      }
    } catch (_) {}

    final acceptorData = _extractSenderData(acceptorUser);

    // Send 'request_accepted' notification to the original sender
    final acceptNotifId = 'conn_accept_${fromUserId}_$currentUserId';
    batch.set(_firestore.collection('notifications').doc(acceptNotifId), {
      'toUserId': fromUserId,
      'fromUserId': currentUserId,
      'type': 'request_accepted',
      'createdAt': Timestamp.now(),
      'read': false,
      ...acceptorData,
    }, SetOptions(merge: true));

    // NOTE: We intentionally do NOT delete the connection_request notification here.
    // The notifications screen keeps it visible as "Connected ✓" until the user
    // navigates away, then deletes it on dispose.

    await batch.commit();
  }

  Future<void> ignoreConnectionRequest({
    required String currentUserId,
    required String fromUserId,
  }) async {
    final incomingRef = _usersRef
        .doc(currentUserId)
        .collection('incomingConnectionRequests')
        .doc(fromUserId);
    final outgoingRef = _usersRef
        .doc(fromUserId)
        .collection('outgoingConnectionRequests')
        .doc(currentUserId);

    // Fetch the notificationId before deleting the request document
    String? notificationId;
    try {
      final doc = await incomingRef.get();
      if (doc.exists) {
        notificationId = doc.data()?['notificationId'] as String?;
      }
    } catch (_) {}

    final batch = _firestore.batch();
    batch.delete(incomingRef);
    batch.delete(outgoingRef);

    // Delete the 'connection_request' notification
    final notifId = notificationId ?? 'conn_req_${currentUserId}_$fromUserId';
    batch.delete(_firestore.collection('notifications').doc(notifId));

    await batch.commit();
  }

  Future<void> removeConnection({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final currentConnectionRef = _usersRef
        .doc(currentUserId)
        .collection('connections')
        .doc(otherUserId);
    final otherConnectionRef = _usersRef
        .doc(otherUserId)
        .collection('connections')
        .doc(currentUserId);

    final currentUserRef = _usersRef.doc(currentUserId);
    final otherUserRef = _usersRef.doc(otherUserId);

    final batch = _firestore.batch();

    batch.delete(currentConnectionRef);
    batch.delete(otherConnectionRef);

    batch.update(currentUserRef, {
      'connectionsCount': FieldValue.increment(-1),
    });

    batch.update(otherUserRef, {
      'connectionsCount': FieldValue.increment(-1),
    });

    await batch.commit();
  }


  Stream<List<UserModel>> watchConnections(String userId) {
    // No orderBy to avoid requiring Firestore composite index
    final connectionsRef =
        _usersRef.doc(userId).collection('connections');

    return connectionsRef.snapshots().asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) return <UserModel>[];
      final ids = snapshot.docs.map((d) => d.id).toList();
      final users = await _loadUsersByIds(ids);
      return users;
    });
  }

  Stream<List<UserModel>> watchIncomingRequests(String userId) {
    // No orderBy to avoid requiring Firestore composite index
    final incomingRef = _usersRef
        .doc(userId)
        .collection('incomingConnectionRequests');

    return incomingRef.snapshots().asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) return <UserModel>[];
      final ids = snapshot.docs.map((d) => d.id).toList();
      final users = await _loadUsersByIds(ids);
      return users;
    });
  }

  Future<List<UserModel>> fetchSuggestedUsers(
    String userId, {
    int limit = 50,
  }) async {
    try {
      // Get all existing connections (no orderBy = no index needed)
      final connectionsSnap =
          await _usersRef.doc(userId).collection('connections').get();
      final connectedIds = <String>{for (final d in connectionsSnap.docs) d.id};

      // Get all outgoing requests
      final outgoingSnap = await _usersRef
          .doc(userId)
          .collection('outgoingConnectionRequests')
          .get();
      final pendingIds = <String>{for (final d in outgoingSnap.docs) d.id};

      // Fetch ALL users with simple limit - no orderBy to avoid index errors
      final usersSnap = await _usersRef.limit(limit * 3).get();

      final result = <UserModel>[];
      for (final doc in usersSnap.docs) {
        if (doc.id == userId) continue;
        if (connectedIds.contains(doc.id)) continue;
        if (pendingIds.contains(doc.id)) continue;
        result.add(UserModel.fromFirestore(doc));
        if (result.length >= limit) break;
      }

      // Sort newest first in Dart (no Firestore index needed)
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return result;
    } catch (e) {
      return [];
    }
  }

  Future<ConnectionStatus> getConnectionStatus({
    required String currentUserId,
    required String otherUserId,
  }) async {
    if (currentUserId == otherUserId) {
      return ConnectionStatus.connected;
    }

    final connectionsRef = _usersRef
        .doc(currentUserId)
        .collection('connections')
        .doc(otherUserId);
    final outgoingRef = _usersRef
        .doc(currentUserId)
        .collection('outgoingConnectionRequests')
        .doc(otherUserId);
    final incomingRef = _usersRef
        .doc(currentUserId)
        .collection('incomingConnectionRequests')
        .doc(otherUserId);

    final results = await Future.wait([
      connectionsRef.get(),
      outgoingRef.get(),
      incomingRef.get(),
    ]);

    final connectionDoc = results[0];
    final outgoingDoc = results[1];
    final incomingDoc = results[2];

    if (connectionDoc.exists) {
      return ConnectionStatus.connected;
    }

    if (outgoingDoc.exists) {
      return ConnectionStatus.pending;
    }

    if (incomingDoc.exists) {
      return ConnectionStatus.incomingRequest;
    }

    return ConnectionStatus.connectable;
  }

  Future<List<UserModel>> _loadUsersByIds(List<String> ids) async {
    if (ids.isEmpty) {
      return <UserModel>[];
    }

    final users = <UserModel>[];
    const chunkSize = 10;

    for (var i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.sublist(
        i,
        i + chunkSize > ids.length ? ids.length : i + chunkSize,
      );
      final snapshot = await _usersRef
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      users.addAll(snapshot.docs.map(UserModel.fromFirestore));
    }

    return users;
  }
}
