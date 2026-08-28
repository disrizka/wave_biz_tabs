class ApiConstants {
  // Base URL API sesuai screenshot Postman kamu
  static const String baseUrl = 'https://wave-api.eon.id';

  static const String login = '$baseUrl/user/login';

  // Endpoint refresh token: GET /user/refresh-token (dikonfirmasi dari Postman).
  // Tidak ada body. Butuh 2 header:
  //   - Authorization: Basic <credential tetap milik app, BUKAN per-user>
  //   - Refresh-Token: <refresh_token milik user, tanpa prefix "Bearer">
  static const String refreshToken = '$baseUrl/user/refresh-token';

  // Kredensial tetap milik app (bukan token per-user), dipakai khusus
  // untuk request GET /user/refresh-token.
  static const String basicAuthCredential =
      'Basic bWFudWFsX2FwcDpkZGY0YjY1OTE2NTc2N2E2Mjc4NGY5NGM0ZWU1NmQwNzVkYjEwYzk0NTBkYTVjZjgxYjZhZjdiOWY1NmYxZWY3';
}

class AppConstants {
  static const String appName = 'WAVEUP';
  static const String clientType = 'app';
  static const String appType = 'WAVEUP';

  // Access token di-refresh otomatis tiap 8 jam
  static const Duration tokenRefreshInterval = Duration(hours: 8);

  /// SEMENTARA UNTUK TESTING: kalau true, dan login gagal karena masalah
  /// NETWORK (bukan salah password), otomatis lanjut ke Home pakai data
  /// mock supaya alur UI bisa dites duluan sambil masalah konektivitas
  /// ke API (biasanya CORS kalau run di web/Chrome) diselesaikan.
  ///
  /// Set ke `false` sebelum rilis / setelah API-nya beneran bisa diakses.
  static const bool enableMockLoginFallback = true;
}

class StorageKeys {
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String tokenSavedAt = 'token_saved_at';
  static const String userData = 'user_data';
  static const String businessData = 'business_data';
}

class AssetPaths {
  static const String logo = 'assets/images/logo.png';
  static const String illustration = 'assets/images/login/ilustrasi.png';
}
