/// Mewakili metode pembayaran di modal "Select payment method".
/// Sesuaikan value int ini kalau enum di backend Wave berbeda.
enum PaymentMethod {
  cash(1),
  debit(2),
  qris(3);

  final int value;
  const PaymentMethod(this.value);
}

class SaleItem {
  final String productId;
  final String productSkuId;
  final int qty;
  final int discount;
  final int price;

  SaleItem({
    required this.productId,
    required this.productSkuId,
    required this.qty,
    this.discount = 0,
    required this.price,
  });

  Map<String, dynamic> toJson() => {
    "product_id": productId,
    "product_sku_id": productSkuId,
    "qty": qty,
    "discount": discount,
    "price": price,
  };
}

/// Body untuk POST /waveup/{businessId}/transaction/sales
class SaleRequest {
  final String storeLocationId;
  final String customerId;
  final int storeId;
  final int discount;
  final int shippingFee;
  final String note;
  final String reference;
  final PaymentMethod paymentMethod;
  final List<SaleItem> items;

  SaleRequest({
    required this.storeLocationId,
    required this.customerId,
    this.storeId = 0,
    this.discount = 0,
    this.shippingFee = 0,
    this.note = "",
    required this.reference,
    required this.paymentMethod,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
    "store_location_id": storeLocationId,
    "customer_id": customerId,
    "store_id": storeId,
    "discount": discount,
    "shipping_fee": shippingFee,
    "note": note,
    "reference": reference,
    "payment_method": paymentMethod.value,
    "items": items.map((e) => e.toJson()).toList(),
  };
}
