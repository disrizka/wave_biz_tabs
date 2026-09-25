import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:wave_biz_tabs/core/constants.dart';
import 'package:wave_biz_tabs/models/transaction_model.dart';
import 'package:wave_biz_tabs/services/api_service.dart'; 

enum PaymentMethod {
  cash(1, 'Tunai'),
  midtransDebit(2, 'Midtrans Debit'), 
  midtransRegular(3, 'Midtrans Biasa (QRIS / Snap)'),
  edc(4, 'EDC'), 
  tt(5, 'TT'),
  shopee(6, 'Shopee');

  final int code;
  final String label;
  const PaymentMethod(this.code, this.label);
}

class SaleItemInput {
  final String productId;
  final String productSkuId;
  final int qty;
  final int discount;
  final int price;

  SaleItemInput({
    required this.productId,
    required this.productSkuId,
    required this.qty,
    this.discount = 0,
    required this.price,
  });

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'product_sku_id': productSkuId,
    'qty': qty,
    'discount': discount,
    'price': price,
  };
}

/// Result of creating a sale (used for QRIS / Midtrans flow to get payment_link).
class TransactionSaleResult {
  final String idTransaction;
  final String status;
  final int amount;
  final String? paymentToken;
  final String? paymentLink;

  TransactionSaleResult({
    required this.idTransaction,
    required this.status,
    required this.amount,
    this.paymentToken,
    this.paymentLink,
  });

  factory TransactionSaleResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return TransactionSaleResult(
      idTransaction: data['idTransaction'] as String,
      status: data['status'] as String,
      amount: data['amount'] as int,
      paymentToken: json['payment_token'] as String?,
      paymentLink: json['payment_link'] as String?,
    );
  }
}

class PaymentCheckResult {
  final String status; 

  PaymentCheckResult({required this.status});

  factory PaymentCheckResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return PaymentCheckResult(status: data['status'] as String);
  }
}

class TransactionService {
  final http.Client _client;

  TransactionService({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _headers(String accessToken) {
    final formattedToken = accessToken.startsWith('Bearer ')
        ? accessToken
        : 'Bearer $accessToken';
    return {
      'Content-Type': 'application/json',
      'Authorization': ApiConstants.basicAuthCredential,
      'Access-Token': formattedToken,
    };
  }

  Map<String, dynamic> _decodeOrThrow(http.Response response) {
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw ApiException(
        decoded['message']?.toString() ??
            'Request failed (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  Future<TransactionListResponse> getTransactions({
    required String accessToken,
    required String businessId,
    int page = 1,
  }) async {
    final uri = Uri.parse(
      ApiConstants.transactionSales(businessId),
    ).replace(queryParameters: {'page': '$page'});
    final response = await _client.get(uri, headers: _headers(accessToken));
    final decoded = _decodeOrThrow(response);
    return TransactionListResponse.fromJson(decoded);
  }

  Future<TransactionDetailResponse> getTransactionDetail({
    required String accessToken,
    required String businessId,
    required String idTransaction,
  }) async {
    final uri = Uri.parse(
      ApiConstants.transactionPaymentCheck(businessId, idTransaction),
    );
    final response = await _client.get(uri, headers: _headers(accessToken));
    final decoded = _decodeOrThrow(response);
    return TransactionDetailResponse.fromJson(decoded);
  }

  Future<TransactionSaleResult> createSale({
    required String accessToken,
    required String businessId,
    required String storeLocationId,
    required List<SaleItemInput> items,
    required PaymentMethod paymentMethod,
    String? customerId,
    int storeId = 0,
    int discount = 0,
    int shippingFee = 0,
    String note = '',
    String reference = '',
  }) async {
    final body = {
      'store_location_id': storeLocationId,
      'customer_id': customerId ?? '',
      'store_id': storeId,
      'discount': discount,
      'shipping_fee': shippingFee,
      'note': note,
      'reference': reference,
      'payment_method': paymentMethod.code,
      'items': items.map((e) => e.toJson()).toList(),
    };

    final response = await _client.post(
      Uri.parse(ApiConstants.transactionSales(businessId)),
      headers: _headers(accessToken),
      body: jsonEncode(body),
    );

    final decoded = _decodeOrThrow(response);
    return TransactionSaleResult.fromJson(decoded);
  }

  Future<TransactionSaleResult> createQrisSale({
    required String accessToken,
    required String businessId,
    required String storeLocationId,
    required List<SaleItemInput> items,
    String note = '',
    String reference = '',
    int discount = 0,
    int shippingFee = 0,
  }) {
    return createSale(
      accessToken: accessToken,
      businessId: businessId,
      storeLocationId: storeLocationId,
      items: items,
      paymentMethod: PaymentMethod.midtransRegular,
      customerId: '',
      note: note,
      reference: reference,
      discount: discount,
      shippingFee: shippingFee,
    );
  }

  Future<PaymentCheckResult> checkPaymentStatus({
    required String accessToken,
    required String businessId,
    required String idTransaction,
  }) async {
    final detail = await getTransactionDetail(
      accessToken: accessToken,
      businessId: businessId,
      idTransaction: idTransaction,
    );
    return PaymentCheckResult(status: detail.transaction.status);
  }
}
