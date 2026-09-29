/// Satu baris item di struk.
class ReceiptItem {
  final String name;
  final String variantLabel;
  final int quantity;
  final int unitPrice;
  final String note;

  const ReceiptItem({
    required this.name,
    this.variantLabel = '',
    required this.quantity,
    required this.unitPrice,
    this.note = '',
  });

  int get lineTotal => unitPrice * quantity;
}

/// Semua data yang dicetak di struk. Dibuat sebagai "snapshot" saat
/// pembayaran berhasil (sebelum keranjang dikosongkan), jadi nama produk
/// selalu tersedia dan tidak perlu fetch ulang.
class ReceiptData {
  final String businessName;
  final String cashierName;
  final String reference;
  final String transactionId;
  final DateTime dateTime;
  final String orderTypeLabel;
  final String paymentMethodLabel;
  final List<ReceiptItem> items;
  final int total;

  const ReceiptData({
    required this.businessName,
    this.cashierName = '',
    this.reference = '',
    this.transactionId = '',
    required this.dateTime,
    this.orderTypeLabel = '',
    this.paymentMethodLabel = '',
    required this.items,
    required this.total,
  });
}
