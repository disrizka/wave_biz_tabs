import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/constants.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';
import '../models/business_model.dart';

/// Semua urusan simpan/baca/hapus data auth di local storage
/// dikumpulkan di sini biar AuthNotifier gak berantakan.
///
/// Pakai flutter_secure_storage (bukan shared_preferences) karena isinya
/// token — disimpan terenkripsi (Keychain di iOS, EncryptedSharedPreferences
/// di Android), bukan plain text.
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
