import 'package:intl/intl.dart';

/// Seconds between the bus's last fix and the server clock (`HH:mm:ss`);
/// 999 when either cannot be read, so unreadable times count as offline.
int fixAgeSeconds(String coordinatesTime, String serverTime) {
  try {
    final format = DateFormat('HH:mm:ss');
    return format
        .parse(serverTime)
        .difference(format.parse(coordinatesTime))
        .inSeconds;
  } on FormatException {
    return 999;
  }
}
