Future<void> initWebCrashlytics() async {}

void recordWebError(
  Object error,
  StackTrace? stack, {
  String? reason,
  List<Object> information = const [],
}) {}

void setWebUser({
  String? id,
  String? organizationId,
  String? zoneId,
  String? branchId,
  String? schoolName,
}) {}

void setWebCustomKey(String key, String value) {}

void logWeb(String message) {}
