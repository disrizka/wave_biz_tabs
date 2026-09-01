import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wave_biz_tabs/core/constants.dart';
import 'package:wave_biz_tabs/models/auth_response_model.dart';
import 'package:wave_biz_tabs/models/business_model.dart';
import 'package:wave_biz_tabs/models/user_model.dart';
import 'package:wave_biz_tabs/services/api_service.dart';
import 'package:wave_biz_tabs/services/token_storage_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final bool isLoading;
  final String? errorMessage;
  final UserModel? user;
  final List<BusinessModel> businessList;
  final AuthTokenModel? token;
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
      debugPrint('[AuthNotifier] Network error saat login: $e');
      if (AppConstants.enableMockLoginFallback) {
        await _applySuccessfulLogin(_mockLoginResult());
        return true;
      }
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } on ApiException catch (e) {
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

  void setActiveBusiness(String idBusiness) {
    state = state.copyWith(activeBusinessId: idBusiness);
  }

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
