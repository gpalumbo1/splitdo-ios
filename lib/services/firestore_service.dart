import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/group.dart';
import '../models/task.dart';
import '../models/user.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> groupDoc(String groupId) =>
      _db.collection('groups').doc(groupId);

  Future<void> joinGroup(String groupId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await groupDoc(groupId).update({
      'members': FieldValue.arrayUnion([uid]),
    });
  }

  Future<DocumentReference> createGroup(String name, List<String> members) =>
      _db.collection('groups').add({
        'name': name,
        'members': members,
        'createdBy': FirebaseAuth.instance.currentUser!.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Stream<List<Group>> groupsStreamForUser(String uid) =>
      _db
          .collection('groups')
          .where('members', arrayContains: uid)
          .orderBy('createdAt')
          .snapshots()
          .map((snap) =>
              snap.docs.map((d) => Group.fromMap(d.id, d.data())).toList());

  Stream<List<Task>> tasksStream(String groupId) =>
      _db
          .collection('groups/$groupId/tasks')
          .orderBy('createdAt')
          .snapshots()
          .map((snap) =>
              snap.docs.map((d) => Task.fromMap(d.id, d.data())).toList());

  /// Ora NON incrementiamo più il contatore globale in Firestore
  Future<void> addTask(String groupId, Task task) async {
    await _db.collection('groups/$groupId/tasks').add(task.toMap());
  }

  Future<void> updateTask(
          String groupId, String taskId, Map<String, dynamic> data) =>
      _db.doc('groups/$groupId/tasks/$taskId').update(data);

  Future<void> deleteTask(String groupId, String taskId) =>
      _db.doc('groups/$groupId/tasks/$taskId').delete();

  Future<void> deleteGroup(String groupId) async {
    final batch = _db.batch();
    final tasksSnap = await _db.collection('groups/$groupId/tasks').get();
    for (var doc in tasksSnap.docs) batch.delete(doc.reference);
    batch.delete(groupDoc(groupId));
    await batch.commit();
  }

  Stream<Group> groupStream(String groupId) =>
      groupDoc(groupId).snapshots().map((d) => Group.fromMap(d.id, d.data()!));

  Future<bool> addUserToGroup({
    required String groupId,
    required String nickname,
  }) async {
    final nickSnap = await _db.doc('nicknames/$nickname').get();
    if (!nickSnap.exists) return false;
    final newUid = nickSnap.data()!['uid'] as String;
    await groupDoc(groupId).update({
      'members': FieldValue.arrayUnion([newUid]),
    });
    return true;
  }

  Future<void> addMemberByUid(String groupId, String uid) =>
      groupDoc(groupId).update({
        'members': FieldValue.arrayUnion([uid]),
      });

  Future<void> removeUserFromGroup({
    required String groupId,
    required String memberUid,
  }) =>
      groupDoc(groupId).update({
        'members': FieldValue.arrayRemove([memberUid]),
      });

  Future<String> getUserNickname(String uid) async {
    final snap = await _db.doc('users/$uid').get();
    if (!snap.exists) return uid;
    return snap.data()!['nickname'] as String? ?? uid;
  }

  Future<List<UserModel>> getFriends() async {
    final me = FirebaseAuth.instance.currentUser!.uid;
    final udoc = await _db.doc('users/$me').get();
    final List<String> friendUids =
        List<String>.from(udoc.data()?['friends'] ?? []);
    if (friendUids.isEmpty) return [];
    final snaps = await _db
        .collection('users')
        .where(FieldPath.documentId, whereIn: friendUids)
        .get();
    return snaps.docs
        .map((d) => UserModel.fromMap(d.id, d.data()!))
        .toList();
  }

  Future<bool> addFriendByNickname({required String nickname}) async {
    final query = await _db
        .collection('users')
        .where('nickname', isEqualTo: nickname)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return false;
    final friendUid = query.docs.first.id;
    final me = FirebaseAuth.instance.currentUser!.uid;
    await _db.doc('users/$me').update({
      'friends': FieldValue.arrayUnion([friendUid]),
    });
    return true;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> groupDocStream(
          String groupId) =>
      groupDoc(groupId).snapshots();

  Future<void> updateSettledBalance(
          String groupId, String uid, bool settled) =>
      groupDoc(groupId).update({
        'settledBalances.$uid': settled,
      });

  Future<void> removeFriendByUid(String friendUid) async {
    final me = FirebaseAuth.instance.currentUser!.uid;
    await _db.doc('users/$me').update({
      'friends': FieldValue.arrayRemove([friendUid]),
    });
  }
}

