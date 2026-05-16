// 이슈 #723 — 스와치 그룹 Repository.
//
// Firestore: users/{uid}/swatch_groups/{gid}
// 기존 swatch_repository.dart 는 절대 건드리지 않음 — 신설만.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/firestore_timeout_extension.dart';
import '../../../providers/auth_provider.dart';
import '../domain/swatch_group.dart';

class SwatchGroupRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference get _groupsRef =>
      _db.collection('users').doc(_uid).collection('swatch_groups');

  // ── CREATE ───────────────────────────────────────────────
  Future<SwatchGroup> createGroup(SwatchGroup group) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');

    final docRef =
        group.id.isEmpty ? _groupsRef.doc() : _groupsRef.doc(group.id);

    await docRef.set({
      ...group.toJson(),
      'id': docRef.id,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }).withServerTimeout(op: 'create_swatch_group');

    return group.copyWith(id: docRef.id);
  }

  // ── UPDATE ───────────────────────────────────────────────
  Future<SwatchGroup> updateGroup(SwatchGroup group) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    if (group.id.isEmpty) throw Exception('그룹 ID가 비어있어요.');

    final json = Map<String, dynamic>.from(group.toJson())
      ..remove('id')
      ..remove('createdAt');
    json['updatedAt'] = FieldValue.serverTimestamp();

    await _groupsRef
        .doc(group.id)
        .update(json)
        .withServerTimeout(op: 'update_swatch_group');

    return group.copyWith(updatedAt: DateTime.now());
  }

  // ── DELETE ───────────────────────────────────────────────
  Future<void> deleteGroup(String groupId) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    await _groupsRef
        .doc(groupId)
        .delete()
        .withServerTimeout(op: 'delete_swatch_group');
  }

  // ── ADD/REMOVE swatch ────────────────────────────────────
  Future<void> addSwatch(String groupId, String swatchId) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    await _groupsRef.doc(groupId).update({
      'swatchIds': FieldValue.arrayUnion([swatchId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }).withServerTimeout(op: 'add_swatch_to_group');
  }

  Future<void> removeSwatch(String groupId, String swatchId) async {
    if (_uid.isEmpty) throw Exception('로그인이 필요해요.');
    await _groupsRef.doc(groupId).update({
      'swatchIds': FieldValue.arrayRemove([swatchId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }).withServerTimeout(op: 'remove_swatch_from_group');
  }

  // ── READ ─────────────────────────────────────────────────
  Stream<List<SwatchGroup>> watchAll() {
    if (_uid.isEmpty) return Stream.value([]);
    return _groupsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => SwatchGroup.fromFirestore(doc)).toList());
  }

  Stream<SwatchGroup?> watchOne(String groupId) {
    if (_uid.isEmpty) return Stream.value(null);
    return _groupsRef.doc(groupId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return SwatchGroup.fromFirestore(doc);
    });
  }

  Future<SwatchGroup?> getOne(String groupId) async {
    final doc = await _groupsRef
        .doc(groupId)
        .get()
        .withServerTimeout(op: 'get_swatch_group');
    if (!doc.exists) return null;
    return SwatchGroup.fromFirestore(doc);
  }
}

// ── Providers ────────────────────────────────────────────
final swatchGroupRepositoryProvider = Provider<SwatchGroupRepository>((ref) {
  return SwatchGroupRepository();
});

final swatchGroupListProvider = StreamProvider<List<SwatchGroup>>((ref) {
  ref.keepAlive();
  final isLoggedIn = ref.watch(isLoggedInProvider);
  if (!isLoggedIn) return Stream.value([]);
  return ref.watch(swatchGroupRepositoryProvider).watchAll();
});

final swatchGroupByIdProvider =
    StreamProvider.family<SwatchGroup?, String>((ref, id) {
  final isLoggedIn = ref.watch(isLoggedInProvider);
  if (!isLoggedIn) return Stream.value(null);
  return ref.watch(swatchGroupRepositoryProvider).watchOne(id);
});
