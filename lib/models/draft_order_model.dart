library;

import 'package:wave_biz_tabs/models/cart_model.dart';

class DraftOrder {
  final String id;
  final List<CartItem> items;
  final OrderType orderType;
  final DateTime savedAt;

  const DraftOrder({
    required this.id,
    required this.items,
    required this.orderType,
    required this.savedAt,
  });

  int get totalQuantity => items.fold(0, (sum, i) => sum + i.quantity);
  int get totalAmount => items.fold(0, (sum, i) => sum + i.lineTotal);
  String get formattedTotal => formatIDR(totalAmount);

  Map<String, dynamic> toJson() => {
    'id': id,
    'items': items.map((e) => e.toJson()).toList(),
    'orderType': orderType == OrderType.takeaway ? 'takeaway' : 'dineIn',
    'savedAt': savedAt.toIso8601String(),
  };

  factory DraftOrder.fromJson(Map<String, dynamic> json) {
    return DraftOrder(
      id:
          json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      items: ((json['items'] as List?) ?? const [])
          .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      orderType: json['orderType'] == 'takeaway'
          ? OrderType.takeaway
          : OrderType.dineIn,
      savedAt:
          DateTime.tryParse(json['savedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
