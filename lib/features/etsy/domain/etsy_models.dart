// Etsy Open API v3 데이터 모델

// ── 리스팅 (상품) ─────────────────────────────────────────────────────────────
class EtsyListing {
  final int listingId;
  final String title;
  final String? description;
  final String? shopName;
  final double price;
  final String currencyCode;
  final String? thumbnailUrl;
  final String listingUrl;
  final String state;         // active, inactive, etc.
  final List<String> tags;
  final int quantity;

  const EtsyListing({
    required this.listingId,
    required this.title,
    this.description,
    this.shopName,
    required this.price,
    required this.currencyCode,
    this.thumbnailUrl,
    required this.listingUrl,
    required this.state,
    this.tags = const [],
    required this.quantity,
  });

  factory EtsyListing.fromJson(Map<String, dynamic> json) {
    final priceMap = json['price'] as Map<String, dynamic>?;
    final images = json['images'] as List<dynamic>?;
    final firstImage = images?.isNotEmpty == true
        ? images!.first as Map<String, dynamic>?
        : null;

    return EtsyListing(
      listingId: json['listing_id'] as int,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      shopName: json['shop_name'] as String?,
      price: double.tryParse(priceMap?['amount']?.toString() ?? '0') ??
          ((priceMap?['amount'] as num?)?.toDouble() ?? 0.0),
      currencyCode: priceMap?['currency_code'] as String? ?? 'USD',
      thumbnailUrl: firstImage?['url_570xN'] as String? ??
          firstImage?['url_fullxfull'] as String?,
      listingUrl: json['url'] as String? ??
          'https://www.etsy.com/listing/${json['listing_id']}',
      state: json['state'] as String? ?? 'active',
      tags: (json['tags'] as List<dynamic>?)
              ?.map((t) => t as String)
              .toList() ??
          [],
      quantity: json['quantity'] as int? ?? 0,
    );
  }

  String get priceDisplay {
    final symbol = currencyCode == 'USD'
        ? '\$'
        : currencyCode == 'KRW'
            ? '₩'
            : '$currencyCode ';
    return '$symbol${price.toStringAsFixed(currencyCode == 'KRW' ? 0 : 2)}';
  }
}

// ── 샵 ───────────────────────────────────────────────────────────────────────
class EtsyShop {
  final int shopId;
  final String shopName;
  final String? title;
  final String? iconUrl;
  final int listingActiveCount;
  final int transactionSoldCount;

  const EtsyShop({
    required this.shopId,
    required this.shopName,
    this.title,
    this.iconUrl,
    required this.listingActiveCount,
    required this.transactionSoldCount,
  });

  factory EtsyShop.fromJson(Map<String, dynamic> json) {
    return EtsyShop(
      shopId: json['shop_id'] as int,
      shopName: json['shop_name'] as String? ?? '',
      title: json['title'] as String?,
      iconUrl: json['icon_url_fullxfull'] as String?,
      listingActiveCount: json['listing_active_count'] as int? ?? 0,
      transactionSoldCount: json['transaction_sold_count'] as int? ?? 0,
    );
  }
}
