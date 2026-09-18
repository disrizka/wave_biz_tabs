library;

import 'package:wave_biz_tabs/models/product_model.dart';

/// Formats an integer amount as "IDR 20.000" (dot thousand separators).
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

/// A single line in the current order / cart.
class CartItem {
  final String productId;
  final String name;
  final int unitPrice;
  final String photoPath;
  final int quantity;
  final String note;

  /// The selected SKU's uuid, or '' when the product has no variants.
  final String skuUuid;

  /// The selected SKU's idProductSku (what the sales API expects as
  /// product_sku_id), or '' when the product has no variants.
  final String skuId;

  /// Human-readable variant summary, e.g. "Chicken, Small".
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

  /// Unique key for this cart line. Two lines can share the same
  /// [productId] when they're different variants of the same product, so
  /// every cart-mutating call (increment/decrement/removeItem/setNote)
  /// should key off this instead of [productId].
  String get cartLineId => skuUuid.isEmpty ? productId : '$productId::$skuUuid';

  int get lineTotal => unitPrice * quantity;
  String get formattedLineTotal => formatIDR(lineTotal);

  factory CartItem.fromProduct(
    ProductModel product, {
    ProductSku? sku,
    int quantity = 1,
  }) {
    return CartItem(
      productId: product.idProduct.isNotEmpty
          ? product.idProduct
          : product.uuid,
      name: product.name,
      unitPrice: sku?.price ?? product.basePrice,
      photoPath: product.photoPath,
      quantity: quantity,
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
