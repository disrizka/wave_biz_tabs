import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../models/product_model.dart';
import 'api_service.dart';

class ProductService {
  Future<ProductPosResponse> getProducts({
    required String accessToken,
    required String businessId,
    String? categoryId,
    String? brand,
    int page = 1,
  }) async {
    final queryParts = <String>[
      'category=${Uri.encodeComponent(categoryId ?? '')}',
      'brand=${Uri.encodeComponent(brand ?? '')}',
    ];
    if (page > 1) {
      queryParts.add('page=$page');
    }

    final fullUrl =
        '${ApiConstants.baseUrl}/waveup/$businessId/product/pos?${queryParts.join('&')}';
    final uri = Uri.parse(fullUrl);

    final formattedToken = accessToken.startsWith('Bearer ')
        ? accessToken
        : 'Bearer $accessToken';

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': ApiConstants.basicAuthCredential,
      'Access-Token': formattedToken,
    };

    debugPrint('[ProductService] GET URL: $uri');
    debugPrint('[ProductService] HEADERS: $headers');

    http.Response response;
    try {
      response = await http.get(uri, headers: headers);
      debugPrint('[ProductService] STATUS: ${response.statusCode}');
      debugPrint('[ProductService] RESPONSE: ${response.body}');
    } catch (e) {
      throw ApiNetworkException(
        'Gagal terhubung ke server saat ambil produk: $e',
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
        decoded['message'] ?? 'Gagal mengambil daftar produk.',
        statusCode: response.statusCode,
      );
    }

    return ProductPosResponse.fromJson(decoded);
  }
}
