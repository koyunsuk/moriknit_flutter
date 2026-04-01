import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/admin_config.dart';

class AdminConfigRepository {
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('adminConfig').doc('appContent');

  Stream<AdminConfig> watchConfig() => _doc.snapshots().map(
    (snap) => snap.exists ? AdminConfig.fromMap(snap.data()!) : const AdminConfig(),
  );

  Future<void> saveConfig(AdminConfig config) async {
    await _doc.set(config.toMap(), SetOptions(merge: true));
  }
}
