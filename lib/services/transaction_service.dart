import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/transaction_model.dart';
import 'api_service.dart';

class TransactionService {
  Future<TransactionListResponse> getTransactions({
    required String accessToken,
    required String businessId,
    String? storeLocationId,
    String? customerId,
    int page = 1,
  }) async {
    final queryParts = <String>[
      'id_store_location=${Uri.encodeComponent(storeLocationId ?? '')}',
      'id_customer=${Uri.encodeComponent(customerId ?? '')}',
    ];
    if (page > 1) {
      queryParts.add('page=$page');
    }

    final fullUrl =
        '${ApiConstants.transactionSales(businessId)}?${queryParts.join('&')}';
    final uri = Uri.parse(fullUrl);

    final formattedToken = accessToken.startsWith('Bearer ')
        ? accessToken
        : 'Bearer $accessToken';

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': ApiConstants.basicAuthCredential,
      'Access-Token': formattedToken,
    };

    debugPrint('[TransactionService] GET URL: $uri');

    http.Response response;
    try {
      response = await http.get(uri, headers: headers);
      debugPrint('[TransactionService] STATUS: ${response.statusCode}');
    } catch (e) {
      throw ApiNetworkException(
        'Gagal terhubung ke server saat ambil daftar transaksi: $e',
      );
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw ApiException(
        'Response server tidak valid (bukan JSON). Status: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode != 200 || decoded['status'] != 200) {
      throw ApiException(
        decoded['message']?.toString() ?? 'Gagal mengambil daftar transaksi.',
        statusCode: response.statusCode,
      );
    }

    final result = TransactionListResponse.fromJson(decoded);
    debugPrint(
      '[TransactionService] Parsed: ${result.transactions.length} transaksi, '
      'page=${result.page.currentPage}/${result.page.totalPages}',
    );

    return result;
  }

  /// GET /waveup/{idBusiness}/transaction/sales/{idTransaction}/payment-check
  /// Dipakai untuk halaman detail transaksi (klik salah satu item di list).
  Future<TransactionDetailResponse> getTransactionDetail({
    required String accessToken,
    required String businessId,
    required String idTransaction,
  }) async {
    final uri = Uri.parse(
      ApiConstants.transactionPaymentCheck(businessId, idTransaction),
    );

    final formattedToken = accessToken.startsWith('Bearer ')
        ? accessToken
        : 'Bearer $accessToken';

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': ApiConstants.basicAuthCredential,
      'Access-Token': formattedToken,
    };

    debugPrint('[TransactionService] DETAIL GET URL: $uri');

    http.Response response;
    try {
      response = await http.get(uri, headers: headers);
      debugPrint('[TransactionService] DETAIL STATUS: ${response.statusCode}');
    } catch (e) {
      throw ApiNetworkException(
        'Gagal terhubung ke server saat ambil detail transaksi: $e',
      );
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw ApiException(
        'Response server tidak valid (bukan JSON). Status: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode != 200 || decoded['status'] != 200) {
      throw ApiException(
        decoded['message']?.toString() ?? 'Gagal mengambil detail transaksi.',
        statusCode: response.statusCode,
      );
    }

    final result = TransactionDetailResponse.fromJson(decoded);
    debugPrint(
      '[TransactionService] DETAIL Parsed: idTransaction=${result.transaction.idTransaction}, '
      'items=${result.transaction.items.length}, '
      'paymentStatus=${result.paymentStatus?.statusMessage}',
    );

    return result;
  }
}
