/// Response payload from `/api/v2.0/getloginotp`.
class OtpResponse {
  const OtpResponse({required this.username, required this.pin});

  factory OtpResponse.fromJson(Map<String, dynamic> json) {
    return OtpResponse(
      username: json['username'] as String? ?? '',
      pin: json['pin'] as String? ?? '',
    );
  }

  final String username;
  final String pin;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'username': username,
    'pin': pin,
  };
}
