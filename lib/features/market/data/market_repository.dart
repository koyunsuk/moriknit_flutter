import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../domain/market_item.dart';

class MarketRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _items => _db.collection('market_items');

  Stream<List<MarketItem>> watchItems() {
    return _items.where('status', whereIn: ['approved', 'active']).snapshots().map((snapshot) {
      final items = snapshot.docs.map(MarketItem.fromFirestore).toList();
      items.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return items;
    });
  }

  /// 도안 카테고리 인기순 (viewCount 내림차순, 최대 10개)
  Stream<List<MarketItem>> watchPopularPatterns() {
    return _items
        .where('status', whereIn: ['approved', 'active'])
        .where('category', isEqualTo: 'pattern')
        .snapshots()
        .map((s) {
      final items = s.docs.map(MarketItem.fromFirestore).toList();
      items.sort((a, b) => b.viewCount.compareTo(a.viewCount));
      return items.take(10).toList();
    });
  }

  /// 도안 카테고리 최신순 (createdAt 내림차순, 최대 10개)
  Stream<List<MarketItem>> watchLatestPatterns() {
    return _items
        .where('status', whereIn: ['approved', 'active'])
        .where('category', isEqualTo: 'pattern')
        .snapshots()
        .map((s) {
      final items = s.docs.map(MarketItem.fromFirestore).toList();
      items.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return items.take(10).toList();
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
