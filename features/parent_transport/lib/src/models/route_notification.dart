class RouteNotification {
  const RouteNotification({required this.message, required this.at});

  factory RouteNotification.fromJson(Map<String, dynamic> json) =>
      RouteNotification(
        message: json['msg'] as String? ?? '',
        at: json['at'] as String? ?? '',
      );

  final String message;
  final String at;
}
