import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../models/sale_request.dart';
import 'api_service.dart';

class SaleService {
  Future<Map<String, dynamic>> createSale({
    required String businessId,
    required String accessToken,
    required SaleRequest request,
  }) async {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}/waveup/$businessId/transaction/sales',
    );

    final formattedToken = accessToken.startsWith('Bearer ')
        ? accessToken
        : 'Bearer $accessToken';

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': ApiConstants.basicAuthCredential,
      'Access-Token': formattedToken,
    };

    debugPrint('[SaleService] POST URL: $uri');
    debugPrint('[SaleService] BODY: ${jsonEncode(request.toJson())}');

    http.Response response;
    try {
      response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(request.toJson()),
      );
      debugPrint('[SaleService] STATUS: ${response.statusCode}');
      debugPrint('[SaleService] RESPONSE: ${response.body}');
    } catch (e) {
      throw ApiNetworkException(
        'Gagal terhubung ke server saat membuat transaksi: $e',
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

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        decoded['message']?.toString() ?? 'Gagal membuat transaksi.',
        statusCode: response.statusCode,
      );
    }

    return decoded;
  }
}
