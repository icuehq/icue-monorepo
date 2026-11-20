// To parse this JSON data, do
//
//     final routeNotifications = routeNotificationsFromJson(jsonString);

import 'dart:convert';

RouteNotifications routeNotificationsFromJson(String str) =>
    RouteNotifications.fromJson(json.decode(str) as Map<String, dynamic>);

String routeNotificationsToJson(RouteNotifications data) =>
    json.encode(data.toJson());

class RouteNotifications {
  RouteNotifications({
    required this.err,
    required this.message,
    required this.msgs,
  });

  factory RouteNotifications.fromJson(Map<String, dynamic> json) =>
      RouteNotifications(
        err: (json['err'] as bool?) ?? false,
        message: json['message']?.toString() ?? '',
        msgs: json['msgs'] is List
            ? List<Msg>.from(
                (json['msgs'] as List)
                    .whereType<Map<String, dynamic>>()
                    .map((x) => Msg.fromJson(x)),
              )
            : [],
      );

  final bool err;
  final String message;
  final List<Msg> msgs;

  Map<String, dynamic> toJson() => {
        'err': err,
        'message': message,
        'msgs': List<dynamic>.from(msgs.map((x) => x.toJson())),
      };
}

class Msg {
  Msg({required this.msg, required this.at});

  factory Msg.fromJson(Map<String, dynamic> json) => Msg(
        msg: json['msg']?.toString() ?? '',
        at: json['at']?.toString() ?? '',
      );

  final String at;
  final String msg;

  Map<String, dynamic> toJson() => {'msg': msg, 'at': at};
}
