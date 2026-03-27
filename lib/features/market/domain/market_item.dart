import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/firestore_json.dart';

class MarketItem {
  final String id;
  final String sellerUid;
  final String sellerName;
  final String title;
  final String description;
  final int price;
  final String category;
  final String accentHex;
  final String imageType;
  final bool isSoldOut;
  final bool isOfficial;
  final DateTime? createdAt;

  const MarketItem({
    required this.id,
    required this.sellerUid,
    required this.sellerName,
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.accentHex,
    required this.imageType,
    required this.isSoldOut,
    this.isOfficial = false,
    this.createdAt,
  });

  factory MarketItem.fromFirestore(DocumentSnapshot doc) {
    final data = normalizeFirestoreMap((doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{});
    return MarketItem(
      id: doc.id,
      sellerUid: data['sellerUid'] as String? ?? '',
      sellerName: data['sellerName'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      price: (data['price'] as num?)?.toInt() ?? 0,
      category: data['category'] as String? ?? 'pattern',
      accentHex: data['accentHex'] as String? ?? '#F472B6',
      imageType: data['imageType'] as String? ?? 'pattern',
      isSoldOut: data['isSoldOut'] as bool? ?? false,
      isOfficial: data['isOfficial'] as bool? ?? false,
      createdAt: DateTime.tryParse(data['createdAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sellerUid': sellerUid,
      'sellerName': sellerName,
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'accentHex': accentHex,
      'imageType': imageType,
      'isSoldOut': isSoldOut,
      'isOfficial': isOfficial,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

class MarketPurchase {
  final String id;
  final String itemId;
  final String buyerUid;
  final String title;
  final int price;
  final DateTime? purchasedAt;

  const MarketPurchase({required this.id, required this.itemId, required this.buyerUid, required this.title, required this.price, this.purchasedAt});

  factory MarketPurchase.fromFirestore(DocumentSnapshot doc) {
    final data = normalizeFirestoreMap((doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{});
    return MarketPurchase(
      id: doc.id,
      itemId: data['itemId'] as String? ?? '',
      buyerUid: data['buyerUid'] as String? ?? '',
      title: data['title'] as String? ?? '',
      price: (data['price'] as num?)?.toInt() ?? 0,
      purchasedAt: DateTime.tryParse(data['purchasedAt'] as String? ?? ''),
    );
  }
}
