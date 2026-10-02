class ApiConstants {
  static const String baseUrl = 'https://wave-api.eon.id';
  // static const String baseUrl = 'https://api.wave.id';
  static const String login = '$baseUrl/user/login';
  static const String refreshToken = '$baseUrl/user/refresh-token';
  static const String basicAuthCredential =
      'Basic bWFudWFsX2FwcDpkZGY0YjY1OTE2NTc2N2E2Mjc4NGY5NGM0ZWU1NmQwNzVkYjEwYzk0NTBkYTVjZjgxYjZhZjdiOWY1NmYxZWY3';

  static String transactionSales(String businessId) =>
      '$baseUrl/waveup/$businessId/transaction/sales';

  static String transactionSaleDetail(
    String businessId,
    String idTransaction,
  ) => '$baseUrl/waveup/$businessId/transaction/sales/$idTransaction';

  static String transactionPaymentCheck(
    String businessId,
    String idTransaction,
  ) =>
      '$baseUrl/waveup/$businessId/transaction/sales/$idTransaction/payment-check';
}

class MidtransConstants {
  /// Diisi lewat --dart-define supaya HP, emulator, dan build release
  /// selalu memakai key yang sama dan tidak ikut ter-commit ke repo.
  ///
  ///   flutter run --dart-define=MIDTRANS_CLIENT_KEY=SB-Mid-client-xxxx
  ///   flutter build apk --release --dart-define=MIDTRANS_CLIENT_KEY=Mid-client-xxxx
  ///
  /// Sandbox  -> diawali "SB-Mid-client-"
  /// Production -> diawali "Mid-client-"
  /// Harus SAMA environment-nya dengan Server Key yang dipakai backend
  /// saat membuat snap token (kalau beda -> "Transaksi tidak ditemukan").
  static const String clientKey = String.fromEnvironment(
    'MIDTRANS_CLIENT_KEY',
    defaultValue: '',
  );

  static const String merchantBaseUrl = 'https://wave-api.eon.id/';

  static bool get isConfigured => clientKey.isNotEmpty;
  static bool get isSandbox => clientKey.startsWith('SB-');
  static String get environmentLabel => isSandbox ? 'SANDBOX' : 'PRODUCTION';
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
  static const String activeBusinessId = 'active_business_id';
}

class AssetPaths {
  static const String logo = 'assets/images/logo.png';
  static const String illustration = 'assets/images/login/ilustrasi.png';
}

class TransactionConstants {
  static const String defaultStoreLocationId =
      'eb6791f248bc8b80348cdb7ec7dd858c71';
  static const String defaultCustomerId = 'c09136813e7f206e2a13f76a7d5047e680';
}
