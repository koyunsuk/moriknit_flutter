import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../../core/utils/firestore_json.dart';
import '../domain/market_item.dart';
import '../domain/market_review.dart';

class MarketRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _items => _db.collection('market_items');

  bool _isVisible(MarketItem item) {
    // status 필드가 없는 기존 문서는 fromFirestore에서 'approved' 기본값으로 처리됨
    // 'pending' / 'rejected' 만 숨김
    return item.status != 'pending' && item.status != 'rejected';
  }

  Stream<List<MarketItem>> watchItems() {
    return _items.snapshots().map((snapshot) {
      final items = snapshot.docs.map(MarketItem.fromFirestore).where(_isVisible).toList();
      items.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return items;
    });
  }

  /// 도안 카테고리 인기순 (viewCount 내림차순, 최대 10개)
  /// category 필터를 클라이언트 사이드에서 제거 — 기존 문서에 category 필드가 없어도 표시
  Stream<List<MarketItem>> watchPopularPatterns() {
    return _items.snapshots().map((s) {
      final items = s.docs.map(MarketItem.fromFirestore).where(_isVisible).where((item) => item.category == 'pattern' || item.category.isEmpty).toList();
      items.sort((a, b) => b.viewCount.compareTo(a.viewCount));
      return items.take(10).toList();
    });
  }

  /// 도안 카테고리 최신순 (createdAt 내림차순, 최대 10개)
  /// category 필터 클라이언트 사이드 적용 — 기존 문서(category 필드 없음)도 포함
  Stream<List<MarketItem>> watchLatestPatterns() {
    return _items.snapshots().map((s) {
      final items = s.docs.map(MarketItem.fromFirestore).where(_isVisible).where((item) => item.category == 'pattern' || item.category.isEmpty).toList();
      items.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return items.take(10).toList();
    });
  }

  /// 이슈 #629 — 무료 도안만 (price == 0). 최신순, 최대 20개.
  /// category 필터를 클라이언트 사이드에서 적용 (기존 문서에 category 필드가 없어도 표시)
  Stream<List<MarketItem>> watchFreePatterns() {
    return _items.snapshots().map((s) {
      final items = s.docs
          .map(MarketItem.fromFirestore)
          .where(_isVisible)
          .where((item) =>
              item.price == 0 &&
              (item.category == 'pattern' || item.category.isEmpty))
          .toList();
      items.sort((a, b) => (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0)));
      return items.take(20).toList();
    });
  }

  /// 도안 조회수 1 증가
  Future<void> incrementViewCount(String id) async {
    await _items.doc(id).update({'viewCount': FieldValue.increment(1)});
  }

  Stream<List<MarketItem>> watchPendingItems() {
    return _items.where('status', isEqualTo: 'pending').orderBy('createdAt', descending: true).snapshots().map((s) => s.docs.map(MarketItem.fromFirestore).toList());
  }

  Future<void> approveItem(String id) async {
    await _items.doc(id).update({'status': 'approved'});
  }

  Future<void> rejectItem(String id) async {
    await _items.doc(id).update({'status': 'rejected'});
  }

  Future<void> submitUserListing({required MarketItem item, String? imageFile, String? pdfFile}) async {
    await createItem(item, imageFile: imageFile, pdfFile: pdfFile);
  }

  Stream<List<MarketItem>> watchMyItems(String uid) {
    return _items.where('sellerUid', isEqualTo: uid).snapshots().map((snapshot) => snapshot.docs.map(MarketItem.fromFirestore).toList());
  }

  Stream<List<MarketItem>> watchItemsByIds(List<String> ids) {
    final uniqueIds = ids.toSet().where((id) => id.isNotEmpty).toList();
    if (uniqueIds.isEmpty) return Stream.value(const <MarketItem>[]);

    final queries = <Stream<List<MarketItem>>>[];
    for (var i = 0; i < uniqueIds.length; i += 10) {
      final end = i + 10 > uniqueIds.length ? uniqueIds.length : i + 10;
      final chunk = uniqueIds.sublist(i, end);
      queries.add(_items.where(FieldPath.documentId, whereIn: chunk).snapshots().map((snapshot) => snapshot.docs.map(MarketItem.fromFirestore).toList()));
    }

    if (queries.length == 1) return queries.first;

    return Stream.multi((controller) {
      final latest = List<List<MarketItem>>.generate(queries.length, (_) => const <MarketItem>[]);
      final subscriptions = <StreamSubscription<List<MarketItem>>>[];

      void emit() {
        final merged = latest.expand((items) => items).toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
        controller.add(merged);
      }

      for (var i = 0; i < queries.length; i++) {
        final index = i;
        subscriptions.add(queries[i].listen((items) {
          latest[index] = items;
          emit();
        }, onError: controller.addError));
      }

      controller.onCancel = () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      };
    });
  }

  Future<MarketItem?> getItemById(String id) async {
    if (id.isEmpty) return null;
    final doc = await _items.doc(id).get();
    if (!doc.exists) return null;
    return MarketItem.fromFirestore(doc);
  }

  Stream<List<MarketPurchase>> watchMyPurchases(String uid) {
    return _db.collection('users').doc(uid).collection('market_purchases').orderBy('purchasedAt', descending: true).snapshots().map((snapshot) => snapshot.docs.map(MarketPurchase.fromFirestore).toList());
  }

  Stream<List<MarketPurchase>> watchMySales(String uid) {
    return _db.collection('users').doc(uid).collection('market_sales').orderBy('purchasedAt', descending: true).snapshots().map((snapshot) => snapshot.docs.map(MarketPurchase.fromFirestore).toList());
  }

  Future<void> createItem(
    MarketItem item, {
    String? imageFile,
    String? pdfFile,
    Uint8List? imageBytes,
    Uint8List? pdfBytes,
    Map<String, dynamic>? extraData,
  }) async {
    var imageUrl = '';
    var pdfUrl = '';

    try {
      final fileName = 'market/${item.sellerUid}/${DateTime.now().millisecondsSinceEpoch}_image.jpg';
      final ref = _storage.ref(fileName);
      if (imageBytes != null) {
        await ref.putData(imageBytes, SettableMetadata(contentType: 'image/jpeg'));
        imageUrl = await ref.getDownloadURL();
      } else if (imageFile != null && imageFile.isNotEmpty) {
        await ref.putFile(File(imageFile));
        imageUrl = await ref.getDownloadURL();
      }
    } catch (e) {
      debugPrint('Image upload error: $e');
    }

    try {
      final fileName = 'market/${item.sellerUid}/${DateTime.now().millisecondsSinceEpoch}_content.pdf';
      final ref = _storage.ref(fileName);
      if (pdfBytes != null) {
        await ref.putData(pdfBytes, SettableMetadata(contentType: 'application/pdf'));
        pdfUrl = await ref.getDownloadURL();
      } else if (pdfFile != null && pdfFile.isNotEmpty) {
        await ref.putFile(File(pdfFile));
        pdfUrl = await ref.getDownloadURL();
      }
    } catch (e) {
      debugPrint('PDF upload error: $e');
    }

    final itemData = {
      ...item.toJson(),
      'imageUrl': imageUrl,
      'pdfUrl': pdfUrl,
      'createdAt': FieldValue.serverTimestamp(),
      ...?extraData,
    };
    await _items.add(itemData);
  }

  /// 해당 도안을 구매한 기록이 있는지 확인합니다.
  Future<bool> hasSales(String itemId) async {
    final snap = await _db
        .collectionGroup('market_purchases')
        .where('itemId', isEqualTo: itemId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// 도안을 삭제합니다.
  /// 판매 기록이 있으면 [Exception]을 throw합니다.
  Future<void> deleteItem(String id) async {
    try {
      final sold = await hasSales(id);
      if (sold) throw Exception('sold');
    } catch (e) {
      // collectionGroup 쿼리 권한/인덱스 문제 시 판매 여부 확인 없이 삭제 진행
      if (e.toString().contains('sold')) rethrow;
    }
    await _items.doc(id).delete();
  }

  Future<void> updateItem(MarketItem item) async {
    await _items.doc(item.id).update({
      'title': item.title,
      'description': item.description,
      'price': item.price,
      'category': item.category,
      'isSoldOut': item.isSoldOut,
      'isOfficial': item.isOfficial,
    });
  }

  Future<void> toggleSoldOut(String id, bool isSoldOut) async {
    await _items.doc(id).update({'isSoldOut': isSoldOut});
  }

  Future<void> toggleOfficial(String id, bool isOfficial) async {
    await _items.doc(id).update({'isOfficial': isOfficial});
  }

  // ── 찜(즐겨찾기) ──────────────────────────────────────────
  Stream<Set<String>> watchFavorites(String uid) {
    return _db.collection('users').doc(uid).collection('market_favorites')
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toSet());
  }

  Future<void> toggleFavorite(String uid, String itemId, bool currentlyFavorited) async {
    final ref = _db.collection('users').doc(uid).collection('market_favorites').doc(itemId);
    if (currentlyFavorited) {
      await ref.delete();
    } else {
      await ref.set({'addedAt': FieldValue.serverTimestamp()});
    }
  }

  Stream<List<MarketItem>> watchFavoriteItems(String uid) {
    return _db.collection('users').doc(uid).collection('market_favorites')
        .snapshots()
        .asyncMap((s) async {
      final ids = s.docs.map((d) => d.id).toList();
      if (ids.isEmpty) return <MarketItem>[];
      final results = await Future.wait(ids.map((id) => _items.doc(id).get()));
      return results
          .where((doc) => doc.exists)
          .map((doc) => MarketItem.fromFirestore(doc))
          .where(_isVisible)
          .toList();
    });
  }

  // ── 판매자별 상품 ─────────────────────────────────────────
  Stream<List<MarketItem>> watchItemsBySeller(String sellerUid) {
    return _items.where('sellerUid', isEqualTo: sellerUid).snapshots().map((s) {
      final items = s.docs.map(MarketItem.fromFirestore).where(_isVisible).toList();
      items.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return items;
    });
  }

  // ── 태그 기반 검색 ────────────────────────────────────────
  Stream<List<MarketItem>> watchItemsByTag(String tag) {
    return _items.where('tags', arrayContains: tag).snapshots().map((s) {
      final items = s.docs.map(MarketItem.fromFirestore).where(_isVisible).toList();
      items.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return items;
    });
  }

  // ── 리뷰 ─────────────────────────────────────────────────
  Stream<List<MarketReview>> watchReviews(String itemId) {
    return _items.doc(itemId).collection('reviews')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) {
          final data = normalizeFirestoreMap(d.data());
          return MarketReview(
            id: d.id,
            itemId: itemId,
            reviewerUid: data['reviewerUid'] as String? ?? '',
            reviewerName: data['reviewerName'] as String? ?? '',
            rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
            comment: data['comment'] as String? ?? '',
            createdAt: DateTime.tryParse(data['createdAt'] as String? ?? ''),
          );
        }).toList());
  }

  Future<bool> hasUserReviewed(String itemId, String uid) async {
    final snap = await _items.doc(itemId).collection('reviews')
        .where('reviewerUid', isEqualTo: uid)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> submitReview({required String itemId, required MarketReview review}) async {
    final batch = _db.batch();
    final reviewRef = _items.doc(itemId).collection('reviews').doc();
    batch.set(reviewRef, {
      ...review.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_items.doc(itemId), {
      'reviewCount': FieldValue.increment(1),
    });
    await batch.commit();
    await _recalcAverageRating(itemId);
  }

  Future<void> _recalcAverageRating(String itemId) async {
    try {
      final snap = await _items.doc(itemId).collection('reviews').get();
      if (snap.docs.isEmpty) return;
      final ratings = snap.docs.map((d) => (d.data()['rating'] as num?)?.toDouble() ?? 0.0).toList();
      final avg = ratings.reduce((a, b) => a + b) / ratings.length;
      await _items.doc(itemId).update({'averageRating': avg});
    } catch (_) {}
  }

  Stream<List<MarketItem>> watchAllItemsAdmin() {
    return _items.orderBy('createdAt', descending: true).snapshots().map((s) => s.docs.map(MarketItem.fromFirestore).toList());
  }

  Future<void> purchaseItem({required String buyerUid, required MarketItem item}) async {
    final purchase = {
      'itemId': item.id,
      'buyerUid': buyerUid,
      'title': item.title,
      'price': item.price,
      'category': item.category,
      'purchasedAt': FieldValue.serverTimestamp(),
    };

    await _db.collection('users').doc(buyerUid).collection('market_purchases').add(purchase);
    if (item.sellerUid.isNotEmpty) {
      await _db.collection('users').doc(item.sellerUid).collection('market_sales').add(purchase);
    }
  }
}
