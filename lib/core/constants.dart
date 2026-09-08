class ApiConstants {
  static const String baseUrl = 'https://wave-api.eon.id';
  static const String login = '$baseUrl/user/login';
  static const String refreshToken = '$baseUrl/user/refresh-token';
  static const String basicAuthCredential =
      'Basic bWFudWFsX2FwcDpkZGY0YjY1OTE2NTc2N2E2Mjc4NGY5NGM0ZWU1NmQwNzVkYjEwYzk0NTBkYTVjZjgxYjZhZjdiOWY1NmYxZWY3';
}

class AppConstants {
  static const String appName = 'WAVEUP';
  static const String clientType = 'app';
  static const String appType = 'WAVEUP';
  static const Duration tokenRefreshInterval = Duration(hours: 8);
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
