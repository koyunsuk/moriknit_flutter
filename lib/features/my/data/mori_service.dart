import 'package:cloud_firestore/cloud_firestore.dart';

class MoriService {
  static final _db = FirebaseFirestore.instance;

  /// Earn mori points
  static Future<void> earn(String uid, {required int amount, required String reason}) async {
    final ref = _db.collection('users').doc(uid);
    await _db.runTransaction((tx) async {
      tx.update(ref, {'moriBalance': FieldValue.increment(amount)});
    });
    // Log transaction
    await ref.collection('mori_transactions').add({
      'type': 'earn',
      'amount': amount,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Spend mori points. Returns false if insufficient balance.
  static Future<bool> spend(String uid, {required int amount, required String reason}) async {
    final ref = _db.collection('users').doc(uid);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final current = (snap.data()?['moriBalance'] as int?) ?? 0;
        if (current < amount) throw Exception('insufficient');
        tx.update(ref, {'moriBalance': FieldValue.increment(-amount)});
      });
      await ref.collection('mori_transactions').add({
        'type': 'spend',
        'amount': amount,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      if (e.toString().contains('insufficient')) return false;
      rethrow;
    }
  }
}
