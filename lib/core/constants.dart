class ApiConstants {
  static const String baseUrl = 'https://wave-api.eon.id';
  static const String login = '$baseUrl/user/login';
  static const String refreshToken = '$baseUrl/user/refresh-token';
  static const String basicAuthCredential =
      'Basic bWFudWFsX2FwcDpkZGY0YjY1OTE2NTc2N2E2Mjc4NGY5NGM0ZWU1NmQwNzVkYjEwYzk0NTBkYTVjZjgxYjZhZjdiOWY1NmYxZWY3';

  /// GET /waveup/{idBusiness}/transaction/sales — list transaksi.
  static String transactionSales(String businessId) =>
      '$baseUrl/waveup/$businessId/transaction/sales';

  /// GET /waveup/{idBusiness}/transaction/sales/{idTransaction}/payment-check
  /// — detail transaksi + status pembayaran.
  static String transactionPaymentCheck(
    String businessId,
    String idTransaction,
  ) =>
      '$baseUrl/waveup/$businessId/transaction/sales/$idTransaction/payment-check';
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

/// TODO: Belum ada layar pemilihan store location & customer di app ini.
/// Nilai di bawah ini contoh dari Postman kamu, dipakai sementara supaya
/// alur payment bisa langsung dicoba. Ganti dengan ID yang sebenarnya
/// (idealnya diambil dari provider store/customer begitu fitur itu dibuat).
class TransactionConstants {
  static const String defaultStoreLocationId =
      'eb6791f248bc8b80348cdb7ec7dd858c71';
  static const String defaultCustomerId = 'c09136813e7f206e2a13f76a7d5047e680';
}
