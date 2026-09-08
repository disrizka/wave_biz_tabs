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
