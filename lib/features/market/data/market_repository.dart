import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/market_item.dart';

class MarketRepository {
  static const officialSellerUid = 'moriknit_official';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _items => _db.collection('market_items');

  Stream<List<MarketItem>> watchItems() {
    return _items.orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      final remote = snapshot.docs.map(MarketItem.fromFirestore).toList();
      final items = <MarketItem>[..._defaultItems, ...remote];
      final seen = <String>{};
      return items.where((item) => seen.add(item.id.isEmpty ? item.title : item.id)).toList();
    });
  }

  Stream<List<MarketItem>> watchMyItems(String uid) {
    return _items.where('sellerUid', isEqualTo: uid).snapshots().map((snapshot) => snapshot.docs.map(MarketItem.fromFirestore).toList());
  }

  Stream<List<MarketPurchase>> watchMyPurchases(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('market_purchases')
        .orderBy('purchasedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(MarketPurchase.fromFirestore).toList());
  }

  Stream<List<MarketPurchase>> watchMySales(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('market_sales')
        .orderBy('purchasedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(MarketPurchase.fromFirestore).toList());
  }

  Future<void> createItem(MarketItem item) async {
    await _items.add({...item.toJson(), 'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> purchaseItem({required String buyerUid, required MarketItem item}) async {
    final purchase = {
      'itemId': item.id,
      'buyerUid': buyerUid,
      'title': item.title,
      'price': item.price,
      'purchasedAt': FieldValue.serverTimestamp(),
    };

    await _db.collection('users').doc(buyerUid).collection('market_purchases').add(purchase);

    if (item.sellerUid.isNotEmpty) {
      await _db.collection('users').doc(item.sellerUid).collection('market_sales').add(purchase);
    }
  }

  static final List<MarketItem> _defaultItems = [
    MarketItem(
      id: 'official-pattern-starter',
      sellerUid: officialSellerUid,
      sellerName: 'MoriKnit',
      title: '모리니트 스타터 도안팩',
      description: '처음 기록을 시작하는 메이커를 위한 입문 도안 묶음',
      price: 5900,
      category: 'pattern',
      accentHex: '#F472B6',
      imageType: 'pattern',
      isSoldOut: false,
      isOfficial: true,
      createdAt: DateTime(2026, 3, 1),
    ),
    MarketItem(
      id: 'official-soft-merino',
      sellerUid: officialSellerUid,
      sellerName: 'MoriKnit',
      title: '소프트 메리노 추천 세트',
      description: '스와치와 프로젝트 기록에 바로 연결하기 좋은 기본 실 세트',
      price: 12900,
      category: 'yarn',
      accentHex: '#A3E635',
      imageType: 'yarn',
      isSoldOut: false,
      isOfficial: true,
      createdAt: DateTime(2026, 3, 2),
    ),
    MarketItem(
      id: 'official-tool-bundle',
      sellerUid: officialSellerUid,
      sellerName: 'MoriKnit',
      title: '기록형 도구 번들',
      description: '카운터와 게이지 체크에 맞춘 모리니트 추천 도구 묶음',
      price: 18900,
      category: 'tool',
      accentHex: '#C084FC',
      imageType: 'tool',
      isSoldOut: false,
      isOfficial: true,
      createdAt: DateTime(2026, 3, 3),
    ),
  ];
}
