import 'package:api_client/api_client.dart';

/// User-facing text for a failed call.
String describeError(Object error) =>
    error is ApiException ? error.message : error.toString();
