abstract final class AppDateUtils {
  /// Safely parses a date string supporting ISO 8601, dd-MM-yyyy, and MM/dd/yyyy.
  static DateTime? tryParseDate(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    final trimmed = input.trim();
    final direct = DateTime.tryParse(trimmed);
    if (direct != null) return direct;

    final parts = trimmed.split(RegExp(r'[-/]'));
    if (parts.length == 3) {
      final p1 = int.tryParse(parts[0]);
      final p2 = int.tryParse(parts[1]);
      final p3 = int.tryParse(parts[2]);
      if (p1 != null && p2 != null && p3 != null) {
        if (p3 > 1000) {
          if (p2 <= 12 && p1 <= 31) {
            return DateTime(p3, p2, p1);
          }
        } else if (p1 > 1000) {
          return DateTime(p1, p2, p3);
        }
      }
    }
    return null;
  }

  /// Calculates expiry status message (e.g. "License expired 5 days ago", "License will expire in 12 days").
  static String? checkExpiryStatus(String title, DateTime? expiryDate) {
    if (expiryDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final diff = target.difference(today).inDays;

    if (diff > 30) {
      return null;
    } else if (diff > 0 && diff <= 30) {
      return '$title will expire in $diff days';
    } else if (diff == 0) {
      return '$title expires today';
    } else {
      return '$title expired ${diff.abs()} days ago';
    }
  }

  /// Formats date to dd/MM/yyyy.
  static String formatDate(DateTime? date) {
    if (date == null) return '-';
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }
}
