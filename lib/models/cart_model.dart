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

  const CartItem({
    required this.productId,
    required this.name,
    required this.unitPrice,
    this.photoPath = '',
    this.quantity = 1,
    this.note = '',
  });

  int get lineTotal => unitPrice * quantity;
  String get formattedLineTotal => formatIDR(lineTotal);

  factory CartItem.fromProduct(ProductModel product, {int quantity = 1}) {
    return CartItem(
      productId: product.idProduct.isNotEmpty
          ? product.idProduct
          : product.uuid,
      name: product.name,
      unitPrice: product.basePrice,
      photoPath: product.photoPath,
      quantity: quantity,
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
    );
  }

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'name': name,
    'unitPrice': unitPrice,
    'photoPath': photoPath,
    'quantity': quantity,
    'note': note,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: json['productId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      unitPrice: (json['unitPrice'] as num?)?.toInt() ?? 0,
      photoPath: json['photoPath']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      note: json['note']?.toString() ?? '',
    );
  }
}

enum OrderType { dineIn, takeaway }