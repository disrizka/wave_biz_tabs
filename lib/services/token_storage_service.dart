import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wave_biz_tabs/core/constants.dart';
import 'package:wave_biz_tabs/models/auth_response_model.dart';
import 'package:wave_biz_tabs/models/business_model.dart';
import 'package:wave_biz_tabs/models/user_model.dart';

class TokenStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> saveSession({
    required AuthTokenModel token,
    required UserModel user,
    required List<BusinessModel> business,
  }) async {
    await _storage.write(
      key: StorageKeys.accessToken,
      value: token.accessToken,
    );
    await _storage.write(
      key: StorageKeys.refreshToken,
      value: token.refreshToken,
    );
    await _storage.write(
      key: StorageKeys.tokenSavedAt,
      value: DateTime.now().toIso8601String(),
    );
    await _storage.write(
      key: StorageKeys.userData,
      value: jsonEncode(user.toJson()),
    );
    await _storage.write(
      key: StorageKeys.businessData,
      value: jsonEncode(business.map((b) => b.toJson()).toList()),
    );
  }

  Future<void> updateTokens(AuthTokenModel token) async {
    await _storage.write(
      key: StorageKeys.accessToken,
      value: token.accessToken,
    );
    await _storage.write(
      key: StorageKeys.refreshToken,
      value: token.refreshToken,
    );
    await _storage.write(
      key: StorageKeys.tokenSavedAt,
      value: DateTime.now().toIso8601String(),
    );
  }

  Future<Map<String, dynamic>?> loadSession() async {
    final accessToken = await _storage.read(key: StorageKeys.accessToken);
    final refreshToken = await _storage.read(key: StorageKeys.refreshToken);
    final savedAtStr = await _storage.read(key: StorageKeys.tokenSavedAt);
    final userStr = await _storage.read(key: StorageKeys.userData);
    final businessStr = await _storage.read(key: StorageKeys.businessData);

    if (accessToken == null || refreshToken == null || userStr == null) {
      return null;
    }

    return {
      'token': AuthTokenModel(
        accessToken: accessToken,
        refreshToken: refreshToken,
      ),
      'savedAt': savedAtStr != null
          ? DateTime.parse(savedAtStr)
          : DateTime.now(),
      'user': UserModel.fromJson(jsonDecode(userStr)),
      'business': businessStr != null
          ? (jsonDecode(businessStr) as List)
                .map((e) => BusinessModel.fromJson(e))
                .toList()
          : <BusinessModel>[],
    };
  }

  Future<void> clearSession() async {
    await _storage.delete(key: StorageKeys.accessToken);
    await _storage.delete(key: StorageKeys.refreshToken);
    await _storage.delete(key: StorageKeys.tokenSavedAt);
    await _storage.delete(key: StorageKeys.userData);
    await _storage.delete(key: StorageKeys.businessData);
  }
}
