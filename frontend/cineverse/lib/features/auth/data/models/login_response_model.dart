/// Espelha literalmente `POST /auth/login` → `200 {accessToken, refreshToken}`.
class LoginResponseModel {
  const LoginResponseModel({
    required this.accessToken,
    required this.refreshToken,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    return LoginResponseModel(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
    );
  }

  final String accessToken;
  final String refreshToken;
}
