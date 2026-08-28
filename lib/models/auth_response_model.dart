import 'user_model.dart';
import 'business_model.dart';

class AuthTokenModel {
  final String accessToken;
  final String refreshToken;

  AuthTokenModel({
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthTokenModel.fromJson(Map<String, dynamic> json) {
    return AuthTokenModel(
      accessToken: json['access_token'] ?? '',
      refreshToken: json['refresh_token'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
    };
  }
}

class LoginResponseModel {
  final UserModel user;
  final List<BusinessModel> business;
  final AuthTokenModel token;

  LoginResponseModel({
    required this.user,
    required this.business,
    required this.token,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    final businessList = (json['business'] as List<dynamic>? ?? [])
        .map((e) => BusinessModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return LoginResponseModel(
      user: UserModel.fromJson(json['data'] as Map<String, dynamic>),
      business: businessList,
      token: AuthTokenModel.fromJson(json['token'] as Map<String, dynamic>),
    );
  }
}
