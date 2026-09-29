library;

import 'package:wave_biz_tabs/models/product_model.dart';

String formatIDR(int amount) {
  final s = amount.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final posFromEnd = s.length - i;
    buffer.write(s[i]);
    if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write('.');
  }
  return 'IDR $buffer';
}

/// Normalizes a product/uuid/code identifier before it's stored or compared.
///
/// Backend responses for the SAME product across DIFFERENT endpoints (or
/// different requests to the same endpoint) have been observed to format an
/// otherwise-identical ID slightly differently — e.g. a numeric ID that
/// comes back as `123` (int) in one response and `123.0` (double) in
/// another, which `.toString()`-based parsing turns into "123" vs "123.0",
/// or with incidental leading/trailing whitespace, leading zeros, or
/// different letter casing. Left as-is, these cosmetic differences make an
/// exact string match fail even though it's the same product — which is
/// exactly what causes the "quantity resets to 0" bug after the catalog
/// gets re-fetched (app restart, pull-to-refresh, or loading a draft saved
/// in an earlier session). Normalizing both sides before comparing fixes
/// that without needing the backend IDs to be perfectly stable.
String normalizeCartId(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return v;
  final asNum = num.tryParse(v);
  if (asNum != null) {
    // Angka utuh (mis. "123", "123.0", "00123") disamain ke bentuk integer
    // paling sederhana biar variasi format apa pun tetap ke-anggep sama.
    if (asNum == asNum.roundToDouble() && asNum.isFinite) {
      return asNum.toInt().toString();
    }
    return asNum.toString();
  }
  return v.toLowerCase();
}

class CartItem {
  final String productId;
  final String name;
  final int unitPrice;
  final String photoPath;
  final int quantity;
  final String note;
  final String skuUuid;
  final String skuId;
  final String variantLabel;

  const CartItem({
    required this.productId,
    required this.name,
    required this.unitPrice,
    this.photoPath = '',
    this.quantity = 1,
    this.note = '',
    this.skuUuid = '',
    this.skuId = '',
    this.variantLabel = '',
  });

  String get cartLineId => skuUuid.isEmpty ? productId : '$productId::$skuUuid';

  int get lineTotal => unitPrice * quantity;
  String get formattedLineTotal => formatIDR(lineTotal);

  factory CartItem.fromProduct(
    ProductModel product, {
    ProductSku? sku,
    int quantity = 1,
    String note = '',
  }) {
    return CartItem(
      productId: normalizeCartId(
        product.idProduct.isNotEmpty ? product.idProduct : product.uuid,
      ),
      name: product.name,
      unitPrice: sku?.price ?? product.basePrice,
      photoPath: product.photoPath,
      quantity: quantity,
      note: note,
      skuUuid: sku?.uuid ?? '',
      skuId: sku?.idProductSku ?? '',
      variantLabel: sku?.label ?? '',
    );
  }

  CartItem copyWith({int? quantity, String? note}) {
    return CartItem(
      productId: productId,
      name: name,
      unitPrice: unitPrice,
      photoPath: photoPath,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
      skuUuid: skuUuid,
      skuId: skuId,
      variantLabel: variantLabel,
    );
  }

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'name': name,
    'unitPrice': unitPrice,
    'photoPath': photoPath,
    'quantity': quantity,
    'note': note,
    'skuUuid': skuUuid,
    'skuId': skuId,
    'variantLabel': variantLabel,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: json['productId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      unitPrice: (json['unitPrice'] as num?)?.toInt() ?? 0,
      photoPath: json['photoPath']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      note: json['note']?.toString() ?? '',
      skuUuid: json['skuUuid']?.toString() ?? '',
      skuId: json['skuId']?.toString() ?? '',
      variantLabel: json['variantLabel']?.toString() ?? '',
    );
  }
}

enum OrderType { dineIn, takeaway }
