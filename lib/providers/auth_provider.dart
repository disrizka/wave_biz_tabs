import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';
import '../models/business_model.dart';
import '../services/api_service.dart';
import '../services/token_storage_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// State immutable untuk auth. Riverpod nge-rebuild widget yang watch
/// setiap kali object AuthState baru di-emit lewat copyWith.
class AuthState {
  final AuthStatus status;
  final bool isLoading;
  final String? errorMessage;
  final UserModel? user;
  final List<BusinessModel> businessList;
  final AuthTokenModel? token;

  /// idBusiness yang lagi aktif dipakai user (buat langsung buka
  /// ProductListScreen tanpa lewat halaman pilih-bisnis lagi).
  final String? activeBusinessId;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.isLoading = false,
    this.errorMessage,
    this.user,
    this.businessList = const [],
    this.token,
    this.activeBusinessId,
  });

  String? get accessToken => token?.accessToken;

  /// Business yang lagi aktif. Fallback ke business pertama kalau
  /// `activeBusinessId` belum/tidak ke-set (mis. baru login).
  BusinessModel? get activeBusiness {
    if (businessList.isEmpty) return null;
    return businessList.firstWhere(
      (b) => b.idBusiness == activeBusinessId,
      orElse: () => businessList.first,
    );
  }

  AuthState copyWith({
    AuthStatus? status,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    UserModel? user,
    List<BusinessModel>? businessList,
    AuthTokenModel? token,
    String? activeBusinessId,
  }) {
    return AuthState(
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      user: user ?? this.user,
      businessList: businessList ?? this.businessList,
      token: token ?? this.token,
      activeBusinessId: activeBusinessId ?? this.activeBusinessId,
    );
  }
}

/// Pakai API modern Riverpod: `Notifier` + `NotifierProvider`.
class AuthNotifier extends Notifier<AuthState> {
  late final ApiService _api;
  late final TokenStorageService _storage;
  Timer? _refreshTimer;

  @override
  AuthState build() {
    _api = ApiService();
    _storage = TokenStorageService();
    ref.onDispose(() => _refreshTimer?.cancel());
    return const AuthState();
  }

  /// Dipanggil sekali di splash screen untuk cek apakah ada sesi tersimpan.
  Future<void> tryAutoLogin() async {
    final session = await _storage.loadSession();

    if (session == null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }

    final token = session['token'] as AuthTokenModel;
    final user = session['user'] as UserModel;
    final businessList = session['business'] as List<BusinessModel>;
    final savedAt = session['savedAt'] as DateTime;

    state = state.copyWith(
      token: token,
      user: user,
      businessList: businessList,
      activeBusinessId: businessList.isNotEmpty
          ? businessList.first.idBusiness
          : null,
    );

    final elapsed = DateTime.now().difference(savedAt);

    if (elapsed >= AppConstants.tokenRefreshInterval) {
      final refreshed = await _refreshNow();
      if (!refreshed) {
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return;
      }
    } else {
      _scheduleRefresh(remaining: AppConstants.tokenRefreshInterval - elapsed);
    }

    state = state.copyWith(status: AuthStatus.authenticated);
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _api.login(username: username, password: password);
      await _applySuccessfulLogin(result);
      return true;
    } on ApiNetworkException catch (e) {
      // Request gagal di level NETWORK (CORS/timeout/no connection) —
      // BUKAN salah username/password. Sementara pakai data mock biar
      // alur ke Home tetap bisa dites, sambil masalah konektivitasnya
      // dibenerin (lihat AppConstants.enableMockLoginFallback).
      debugPrint('[AuthNotifier] Network error saat login: $e');
      if (AppConstants.enableMockLoginFallback) {
        await _applySuccessfulLogin(_mockLoginResult());
        return true;
      }
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } on ApiException catch (e) {
      // Server berhasil dijawab tapi isinya error beneran
      // (mis. username/password salah) -> jangan di-mock, tampilkan asli.
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Terjadi kesalahan tak terduga: $e',
      );
    }
    return false;
  }

  Future<void> _applySuccessfulLogin(LoginResponseModel result) async {
    await _storage.saveSession(
      token: result.token,
      user: result.user,
      business: result.business,
    );

    _scheduleRefresh(remaining: AppConstants.tokenRefreshInterval);

    state = state.copyWith(
      status: AuthStatus.authenticated,
      isLoading: false,
      user: result.user,
      businessList: result.business,
      token: result.token,
      clearError: true,
      activeBusinessId: result.business.isNotEmpty
          ? result.business.first.idBusiness
          : null,
    );
  }

  /// Dipanggil dari switcher di ProductListScreen saat user ganti bisnis.
  void setActiveBusiness(String idBusiness) {
    state = state.copyWith(activeBusinessId: idBusiness);
  }

  /// Data mock — persis dari contoh response API asli yang kamu kasih
  /// (user "User Test", 2 bisnis: satu di bawah 200 produk/kategori
  /// [Burger Restaurant, allProducts:true], satu di atas 200
  /// [Popular Stationery, allProducts:false]). Dipakai buat testing
  /// switcher bisnis DAN kedua skenario katalog sekaligus.
  /// Cuma dipakai sebagai FALLBACK saat request beneran gagal di level
  /// network — bukan pengganti login asli. Set
  /// `AppConstants.enableMockLoginFallback = false` untuk mematikan ini
  /// setelah masalah CORS/network-nya kelar.
  LoginResponseModel _mockLoginResult() {
    return LoginResponseModel.fromJson({
      'status': 200,
      'data': {
        'idUser': '2ebc039352c84470d82c1c6d0bf42f29bb34da',
        'firstname': 'User',
        'lastname': 'Test',
        'phone': '',
        'email': 'user30@mail.com',
        'photo': '',
        'photoPath': 'https://wave-cdn.eon.id/static/cdn/no-img.jpg',
        'isDeactivated': false,
        'username': 'u1787547142',
        'hasPage': false,
        'userRoleName': 'Owner',
        'roleId': '77850d4cb833de1a41934982a36c5c6c066f6e',
      },
      'business': [
        {
          'idBusiness': '46e96364c42e6f3132525e75813ea514c8cded',
          'name': 'Burger Restaurant',
          'logo': '26/08/Icon-Background-Gradient-1787547236.png',
          'logoPath':
              'https://wave-cdn.eon.id/static/business/logo/26/08/Icon-Background-Gradient-1787547236.png',
          'username': 'burger_restaurant',
          'about': '',
          'canBeSoldOutOfStock': true,
          'userRoleName': 'Owner',
          'roleId': 'ba14afeeddc29018bd2ec8baafb0effb9294bc',
          'isPremium': true,
          'premiumStartAt': '2026-08-21T19:46:51+07:00',
          'premiumExpiresAt': '2026-12-21T19:46:51+07:00',
          'banned': null,
        },
        {
          'idBusiness': 'f9e4ed4f9c121b3186c5690995bce54a91edce',
          'name': 'Popular Stationery',
          'logo': '26/08/eade_logo-1787547316.png',
          'logoPath':
              'https://wave-cdn.eon.id/static/business/logo/26/08/eade_logo-1787547316.png',
          'username': 'popular_st',
          'about': '',
          'canBeSoldOutOfStock': true,
          'userRoleName': 'Owner',
          'roleId': 'b718fdfdc4e37c71a88a67626596d0c3738fe5',
          'isPremium': false,
          'premiumStartAt': null,
          'premiumExpiresAt': null,
          'banned': null,
        },
      ],
      'token': {
        'access_token': 'mock-access-token-untuk-testing-ui',
        'refresh_token': 'mock-refresh-token-untuk-testing-ui',
      },
    });
  }

  void _scheduleRefresh({required Duration remaining}) {
    _refreshTimer?.cancel();
    final safeDuration = remaining.isNegative ? Duration.zero : remaining;

    _refreshTimer = Timer(safeDuration, () async {
      final success = await _refreshNow();
      if (success) {
        _scheduleRefresh(remaining: AppConstants.tokenRefreshInterval);
      } else {
        await logout();
      }
    });
  }

  Future<bool> _refreshNow() async {
    final currentToken = state.token;
    if (currentToken == null) return false;
    try {
      final newAccessToken = await _api.refreshToken(currentToken.refreshToken);
      final newToken = AuthTokenModel(
        accessToken: newAccessToken,
        refreshToken: currentToken.refreshToken,
      );
      await _storage.updateTokens(newToken);
      state = state.copyWith(token: newToken);
      return true;
    } catch (e) {
      debugPrint('[AuthNotifier] Gagal refresh token: $e');
      return false;
    }
  }

  Future<void> logout() async {
    _refreshTimer?.cancel();
    await _storage.clearSession();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
