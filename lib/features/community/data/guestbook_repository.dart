import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/guestbook_entry.dart';

class GuestbookRepository {
  final _col = FirebaseFirestore.instance.collection('guestbook');

  /// 최신 [limit]개 항목을 createdAt 내림차순으로 구독합니다.
  Stream<List<GuestbookEntry>> watchLatest({int limit = 20}) {
    return _col
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => GuestbookEntry.fromMap(
                    doc.data(),
                    doc.id,
                  ))
              .toList(),
        );
  }

  /// 방명록 항목을 추가합니다.
  Future<void> addEntry(GuestbookEntry entry) {
    return _col.add(entry.toMap());
  }

  /// 본인 항목만 삭제합니다. 권한 확인은 Firestore Rules에서도 처리합니다.
  Future<void> deleteEntry(String id) {
    return _col.doc(id).delete();
  }
}
