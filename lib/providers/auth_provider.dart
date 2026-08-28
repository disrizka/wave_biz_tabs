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

  const AuthState({
    this.status = AuthStatus.unknown,
    this.isLoading = false,
    this.errorMessage,
    this.user,
    this.businessList = const [],
    this.token,
  });

  String? get accessToken => token?.accessToken;

  AuthState copyWith({
    AuthStatus? status,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    UserModel? user,
    List<BusinessModel>? businessList,
    AuthTokenModel? token,
  }) {
    return AuthState(
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      user: user ?? this.user,
      businessList: businessList ?? this.businessList,
      token: token ?? this.token,
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
    );
  }

  /// Data mock, disalin dari contoh response API kamu (user "Ciha XD").
  /// Cuma dipakai sebagai FALLBACK saat request beneran gagal di level
  /// network — bukan pengganti login asli. Set
  /// `AppConstants.enableMockLoginFallback = false` untuk mematikan ini
  /// setelah masalah CORS/network-nya kelar.
  LoginResponseModel _mockLoginResult() {
    return LoginResponseModel.fromJson({
      'status': 200,
      'data': {
        'idUser': '44f82b4eafce25bdff2ef7497859d5bdbf64',
        'firstname': 'Ciha XD',
        'lastname': 'VOC',
        'phone': '',
        'email': 'ciha@gmail.com',
        'photo': '25/11/_-(58)-1762088031.jpeg',
        'photoPath':
            'https://wave-cdn.eon.id/static/user/photo/25/11/_-(58)-1762088031.jpeg',
        'isDeactivated': false,
        'username': 'cihaaa',
        'hasPage': false,
        'userRoleName': 'Owner',
        'roleId': '8d3c825fe32cf8afc659f2fbd99ca67d65ad',
      },
      'business': [
        {
          'idBusiness': 'c8a8462022cb258475fce759e928adaeba78',
          'name': 'Ciha Orc',
          'logo': '25/10/chiv-1761803431.png',
          'logoPath':
              'https://wave-cdn.eon.id/static/business/logo/25/10/chiv-1761803431.png',
          'username': 'Ciwha',
          'about': 'About',
          'canBeSoldOutOfStock': true,
          'userRoleName': 'Owner',
          'roleId': '46f0c2f25b5430a6aa40a9c7b2a205458e7e',
          'isPremium': false,
          'premiumStartAt': null,
          'premiumExpiresAt': null,
          'banned': 'ban',
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
