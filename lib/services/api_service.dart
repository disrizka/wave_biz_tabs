import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../models/auth_response_model.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiNetworkException extends ApiException {
  ApiNetworkException(super.message);
}

class ApiService {
  Future<LoginResponseModel> login({
    required String username,
    required String password,
    String? fcmToken,
  }) async {
    final deviceInfo = await _getDeviceInfo();

    final body = {
      'user': username,
      'password': password,
      'app': AppConstants.appType,
      'client': AppConstants.clientType,
      'os': deviceInfo['os'],
      'device_id': deviceInfo['device_id'],
      'device_name': deviceInfo['device_name'],
      'fcm_token': (fcmToken == null || fcmToken.isEmpty)
          ? 'dummy-fcm-token-belum-setup-firebase'
          : fcmToken,
    };

    debugPrint('[ApiService] LOGIN URL: ${ApiConstants.login}');
    debugPrint('[ApiService] LOGIN BODY: ${jsonEncode(body)}');

    http.Response response;
    try {
      response = await http.post(
        Uri.parse(ApiConstants.login),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': ApiConstants.basicAuthCredential,
        },
        body: jsonEncode(body),
      );
      debugPrint('[ApiService] LOGIN STATUS: ${response.statusCode}');
      debugPrint('[ApiService] LOGIN RESPONSE BODY: ${response.body}');
    } catch (e) {
      // Ini yang biasanya kejadian: CORS diblokir browser (kalau jalan di
      // Flutter web), tidak ada koneksi internet, atau server tidak
      // bisa dijangkau sama sekali. Bukan salah username/password.
      throw ApiNetworkException(
        'Gagal terhubung ke server. Kalau kamu run di web/Chrome, '
        'kemungkinan besar ini diblokir CORS oleh browser — coba run di '
        'emulator/device (bukan web), atau minta backend nambahin CORS '
        'header buat domain dev kamu.\n\nDetail teknis: $e',
      );
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw ApiException(
        'Response server tidak valid (bukan JSON). '
        'Status: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode == 200 && decoded['status'] == 200) {
      return LoginResponseModel.fromJson(decoded);
    }

    String message;
    if (decoded['message'] != null) {
      message = decoded['message'].toString();
    } else if (decoded['err'] is List && (decoded['err'] as List).isNotEmpty) {
      message = (decoded['err'] as List).join(', ');
    } else {
      message = 'Login gagal, silakan coba lagi.';
    }
    throw ApiException(message, statusCode: response.statusCode);
  }

  /// Refresh access token.
  /// Endpoint: GET /user/refresh-token (dikonfirmasi dari Postman kamu).
  /// Header yang dipakai:
  ///   - Content-Type: application/json
  ///   - Authorization: Basic <credential tetap app> (lihat ApiConstants.basicAuthCredential)
  ///   - Refresh-Token: <refresh_token user, TANPA prefix "Bearer">
  ///
  /// Response API cuma balikin access_token baru (bukan refresh_token baru):
  /// { "access_token": "...", "status": 200 }
  /// Jadi refresh_token lama tetap dipakai terus sampai dia sendiri expired.
  Future<String> refreshToken(String refreshToken) async {
    http.Response response;
    try {
      response = await http.get(
        Uri.parse(ApiConstants.refreshToken),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': ApiConstants.basicAuthCredential,
          'Refresh-Token': refreshToken,
        },
      );
    } catch (e) {
      throw ApiNetworkException(
        'Gagal terhubung ke server saat refresh token: $e',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 && decoded['status'] == 200) {
      final newAccessToken = decoded['access_token'] as String?;
      if (newAccessToken == null || newAccessToken.isEmpty) {
        throw ApiException('Response refresh token tidak berisi access_token.');
      }
      return newAccessToken;
    }

    throw ApiException(
      decoded['message'] ?? 'Gagal refresh token.',
      statusCode: response.statusCode,
    );
  }

  Future<Map<String, String>> _getDeviceInfo() async {
    try {
      final deviceInfoPlugin = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await deviceInfoPlugin.androidInfo;
        return {
          'os': 'android',
          'device_id': info.id,
          'device_name': '${info.manufacturer} ${info.model}',
        };
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await deviceInfoPlugin.iosInfo;
        return {
          'os': 'ios',
          'device_id': info.identifierForVendor ?? 'unknown-ios-device',
          'device_name': info.utsname.machine,
        };
      }
    } catch (_) {
      // Fallback kalau device_info gagal diakses (misalnya di web/desktop)
    }
    return {
      'os': defaultTargetPlatform.name,
      'device_id': 'web-or-desktop-device',
      'device_name': 'Web/Desktop',
    };
  }
}
