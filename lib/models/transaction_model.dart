library;

import 'package:wave_biz_tabs/models/product_model.dart' show ProductPageMeta;

class TransactionItemModel {
  final String idTransactionItem;
  final String transactionReference;
  final int productId;
  final String productUuid;
  final String skuId;

  final int qtyIn;
  final int qtyOut;
  final int price;
  final int discount;

  const TransactionItemModel({
    required this.idTransactionItem,
    this.transactionReference = '',
    this.productId = 0,
    this.productUuid = '',
    this.skuId = '',
    this.qtyIn = 0,
    this.qtyOut = 0,
    this.price = 0,
    this.discount = 0,
  });

  int get quantity => qtyOut - qtyIn;

  bool get hasSku => skuId.isNotEmpty;

  int get lineTotal => price * (quantity == 0 ? 1 : quantity) - discount;

  factory TransactionItemModel.fromJson(Map<String, dynamic> json) {
    return TransactionItemModel(
      idTransactionItem: json['idTransactionItem']?.toString() ?? '',
      transactionReference: json['transaction_reference']?.toString() ?? '',
      productId: (json['ProductID'] as num?)?.toInt() ?? 0,
      productUuid: json['product_id']?.toString() ?? '',
      skuId: json['product_sku_id']?.toString() ?? '',
      qtyIn: (json['qty_in'] as num?)?.toInt() ?? 0,
      qtyOut: (json['qty_out'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toInt() ?? 0,
      discount: (json['discount'] as num?)?.toInt() ?? 0,
    );
  }
}

class TransactionCustomerModel {
  final String idCustomer;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String cityName;

  const TransactionCustomerModel({
    this.idCustomer = '',
    this.name = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.cityName = '',
  });

  factory TransactionCustomerModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TransactionCustomerModel();
    final city = json['city'] as Map<String, dynamic>?;
    return TransactionCustomerModel(
      idCustomer: json['idCustomer']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      cityName: city?['name']?.toString() ?? '',
    );
  }
}

enum TransactionOrderType { dineIn, takeaway }

class TransactionModel {
  final String idTransaction;
  final String storeLocationId;
  final String storeLocationName;
  final String businessName;
  final int type;
  final String number;
  final TransactionCustomerModel customer;
  final String note;
  final String reference;
  final String status;
  final int amount;
  final int discount;
  final int orderAt;
  final int paymentMethod;

  /// Raw "dd-MM-yyyy HH:mm" string from the API.
  final String createdAt;
  final List<TransactionItemModel> items;

  const TransactionModel({
    required this.idTransaction,
    this.storeLocationId = '',
    this.storeLocationName = '',
    this.businessName = '',
    this.type = 1,
    this.number = '',
    this.customer = const TransactionCustomerModel(),
    this.note = '',
    this.reference = '',
    this.status = '',
    this.amount = 0,
    this.discount = 0,
    this.orderAt = 0,
    this.paymentMethod = 0,
    this.createdAt = '',
    this.items = const [],
  });

  TransactionOrderType get orderType =>
      type == 1 ? TransactionOrderType.dineIn : TransactionOrderType.takeaway;

  String get orderTypeLabel =>
      orderType == TransactionOrderType.dineIn ? 'Dine In' : 'Take Away';

  bool get isPaid => status.toLowerCase() == 'paid';

  /// Parses [createdAt] ("dd-MM-yyyy HH:mm"); falls back to [orderAt]
  /// (unix seconds) when that fails, and finally to null.
  DateTime? get orderDateTime {
    final parts = createdAt.split(' ');
    if (parts.length == 2) {
      final dateParts = parts[0].split('-');
      final timeParts = parts[1].split(':');
      if (dateParts.length == 3 && timeParts.length == 2) {
        final day = int.tryParse(dateParts[0]);
        final month = int.tryParse(dateParts[1]);
        final year = int.tryParse(dateParts[2]);
        final hour = int.tryParse(timeParts[0]);
        final minute = int.tryParse(timeParts[1]);
        if (day != null &&
            month != null &&
            year != null &&
            hour != null &&
            minute != null) {
          return DateTime(year, month, day, hour, minute);
        }
      }
    }
    if (orderAt > 0) {
      return DateTime.fromMillisecondsSinceEpoch(orderAt * 1000);
    }
    return null;
  }

  static const _months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  String get formattedDate {
    final dt = orderDateTime;
    if (dt == null) return createdAt;
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${_months[dt.month - 1]} ${dt.year}, $hh:$mm';
  }

  static String formatRupiah(int value) {
    final s = value.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buffer.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write('.');
    }
    return '${value < 0 ? '-' : ''}Rp $buffer';
  }

  String get formattedAmount => formatRupiah(amount);

  int get totalItemQty => items.fold(0, (sum, e) => sum + e.quantity);

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    final storeLocation = json['store_location'] as Map<String, dynamic>?;
    final business = storeLocation?['business'] as Map<String, dynamic>?;

    return TransactionModel(
      idTransaction: json['idTransaction']?.toString() ?? '',
      storeLocationId: json['store_location_id']?.toString() ?? '',
      storeLocationName: storeLocation?['name']?.toString() ?? '',
      businessName: business?['name']?.toString() ?? '',
      type: (json['type'] as num?)?.toInt() ?? 1,
      number: json['number']?.toString() ?? '',
      customer: TransactionCustomerModel.fromJson(
        json['customer'] as Map<String, dynamic>?,
      ),
      note: json['note']?.toString() ?? '',
      reference: json['reference']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      discount: (json['discount'] as num?)?.toInt() ?? 0,
      orderAt: (json['order_at'] as num?)?.toInt() ?? 0,
      paymentMethod: (json['payment_method'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt']?.toString() ?? '',
      items: (json['items'] as List? ?? [])
          .whereType<Map>()
          .map((e) => TransactionItemModel.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

class TransactionListResponse {
  final List<TransactionModel> transactions;
  final ProductPageMeta page;

  const TransactionListResponse({
    required this.transactions,
    required this.page,
  });

  factory TransactionListResponse.fromJson(Map<String, dynamic> json) {
    final items = (json['data'] as List? ?? [])
        .whereType<Map>()
        .map((e) => TransactionModel.fromJson(e.cast<String, dynamic>()))
        .toList();

    return TransactionListResponse(
      transactions: items,
      page: ProductPageMeta.fromJson(
        json['page'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

/// Status pengecekan pembayaran, muncul di response
/// `.../transaction/sales/{idTransaction}/payment-check` pada key
/// "payment_status". Bisa null kalau backend tidak mengirimkannya.
class PaymentStatusModel {
  final String id;
  final String statusCode;
  final String statusMessage;

  const PaymentStatusModel({
    this.id = '',
    this.statusCode = '',
    this.statusMessage = '',
  });

  factory PaymentStatusModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PaymentStatusModel();
    return PaymentStatusModel(
      id: json['id']?.toString() ?? '',
      statusCode: json['status_code']?.toString() ?? '',
      statusMessage: json['status_message']?.toString() ?? '',
    );
  }
}

/// Wrapper response untuk endpoint detail/payment-check:
/// {
///   "status": 200,
///   "data": { ...transaksi tunggal, sama shape-nya dengan item TransactionListResponse... },
///   "payment_status": { "id": "...", "status_code": "...", "status_message": "..." },
///   "message": "..."
/// }
class TransactionDetailResponse {
  final TransactionModel transaction;
  final PaymentStatusModel? paymentStatus;
  final String message;

  const TransactionDetailResponse({
    required this.transaction,
    this.paymentStatus,
    this.message = '',
  });

  factory TransactionDetailResponse.fromJson(Map<String, dynamic> json) {
    return TransactionDetailResponse(
      transaction: TransactionModel.fromJson(
        json['data'] as Map<String, dynamic>? ?? {},
      ),
      paymentStatus: json['payment_status'] != null
          ? PaymentStatusModel.fromJson(
              json['payment_status'] as Map<String, dynamic>?,
            )
          : null,
      message: json['message']?.toString() ?? '',
    );
  }
}
