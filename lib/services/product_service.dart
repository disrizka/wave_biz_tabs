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
      'id_category=${Uri.encodeComponent(categoryId ?? '')}',
      'id_brand=${Uri.encodeComponent(brand ?? '')}',
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
      const chunkSize = 800;
      final body = response.body;
      for (var i = 0; i < body.length; i += chunkSize) {
        final end = (i + chunkSize < body.length) ? i + chunkSize : body.length;
        debugPrint(
          '[ProductService] RESPONSE[$i-$end]: ${body.substring(i, end)}',
        );
      }
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

    final result = ProductPosResponse.fromJson(decoded);
    debugPrint(
      '[ProductService] Parsed: allProducts=${result.allProducts}, '
      'categories=${result.categories.length}, '
      'groups=${result.productsByCategoryName.keys.toList()}',
    );
    result.productsByCategoryName.forEach((name, items) {
      debugPrint('[ProductService]   -> "$name": ${items.length} produk');
    });

    return result;
  }

  /// GET /waveup/{businessId}/product — flat list endpoint.
  /// Unlike /product/pos, this one reliably filters by id_category.
  Future<ProductFlatResponse> getProductsFlat({
    required String accessToken,
    required String businessId,
    String? categoryId,
    String? brand,
    String? search,
    String? storeLocationId,
    int page = 1,
    int limit = 50,
  }) async {
    final queryParts = <String>[
      'page=$page',
      'limit=$limit',
      'search=${Uri.encodeComponent(search ?? '')}',
      'id_category=${Uri.encodeComponent(categoryId ?? '')}',
      'id_brand=${Uri.encodeComponent(brand ?? '')}',
      'store_location_id=${Uri.encodeComponent(storeLocationId ?? '')}',
      'stock_opname_month=',
      'stock_opname_status=',
    ];

    final fullUrl =
        '${ApiConstants.baseUrl}/waveup/$businessId/product?${queryParts.join('&')}';
    final uri = Uri.parse(fullUrl);

    final formattedToken = accessToken.startsWith('Bearer ')
        ? accessToken
        : 'Bearer $accessToken';

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': ApiConstants.basicAuthCredential,
      'Access-Token': formattedToken,
    };

    debugPrint('[ProductService] FLAT GET URL: $uri');

    http.Response response;
    try {
      response = await http.get(uri, headers: headers);
      debugPrint('[ProductService] FLAT STATUS: ${response.statusCode}');
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

    final result = ProductFlatResponse.fromJson(decoded);
    debugPrint(
      '[ProductService] FLAT Parsed: ${result.products.length} produk, '
      'page=${result.page.currentPage}/${result.page.totalPages}',
    );

    return result;
  }
}
