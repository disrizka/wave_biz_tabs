import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../models/product_model.dart';
import 'api_service.dart';

/// Service buat endpoint "[POS] Product List" yang sudah dikonfirmasi:
///
/// `GET {baseUrl}/waveup/{idBusiness}/product/pos?category=&brand=`
///
/// Perilaku (dari contoh response asli):
/// - `category` kosong  -> backend balikin SEMUA kategori (buat chip),
///   dan:
///     - kalau `allProducts: true`  -> `products` juga udah lengkap semua
///       kategori (business ini <= 200 produk, sekali fetch selesai).
///     - kalau `allProducts: false` -> `products` cuma preview 1 kategori
///       default (business > 200 produk, harus pilih kategori manual).
/// - `category=<idProductCategory>` -> `products` isi kategori itu aja.
///
/// ASUMSI yang BELUM dikonfirmasi (tolong cek kalau ada isu):
/// - Param `page` buat lanjut ke halaman berikutnya kalau satu kategori
///   sendiri isinya > `row_per_page` (200). Jarang kejadian karena
///   kategori di data kamu granular banget, tapi tetap di-handle di sini.
/// - Header Authorization pakai `Bearer <access_token>` (pola umum JWT,
///   samain kayak endpoint lain kalau ternyata beda).
class ProductService {
  Future<ProductPosResponse> getProducts({
    required String accessToken,
    required String businessId,
    String? categoryId,
    String? brand,
    int page = 1,
  }) async {
    final uri =
        Uri.parse(
          '${ApiConstants.baseUrl}/waveup/$businessId/product/pos',
        ).replace(
          queryParameters: {
            'category': categoryId ?? '',
            'brand': brand ?? '',
            if (page > 1) 'page': '$page',
          },
        );

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': ApiConstants.basicAuthCredential,
      'Access-Token': accessToken,
    };

    http.Response response;
    try {
      debugPrint('[ProductService] GET URL: $uri');
      debugPrint('[ProductService] HEADERS: $headers');
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
