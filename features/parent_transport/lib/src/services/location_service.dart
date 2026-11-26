import 'package:api_client/api_client.dart';
import 'package:injectable/injectable.dart';
import 'package:parent_transport/src/models/live_track.dart';

/// Base URL of the serverless location API.
const locationApiUrl = String.fromEnvironment(
  'LOCATION_API_URL',
  defaultValue: 'https://func-locservices-icue-dev01-apim.azure-api.net/func-locservices-icue-dev01/v1',
);

/// Subscription key of the location API. Never hardcode it:
/// `--dart-define=LOCATION_API_KEY=...`.
const locationApiKey = String.fromEnvironment('LOCATION_API_KEY');

/// Registers the HTTP client of the serverless location API.
@module
abstract class LocationClientModule {
  @Named('location')
  @lazySingleton
  ApiClient locationClient() => ApiClient(
    dio: Dio(
      BaseOptions(
        baseUrl: locationApiUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        headers: <String, dynamic>{
          'Content-Type': 'application/json',
          'Ocp-Apim-Subscription-Key': locationApiKey,
        },
      ),
    ),
  );
}

/// Serverless tracking (`/getactiveroute`, `/getlivetrack`) for students on it.
@lazySingleton
class LocationService {
  const LocationService(@Named('location') this._client);

  final ApiClient _client;

  /// The location API wants neither the parent token nor `Source`/`BranchId`.
  static final _plain = Options(
    extra: <String, dynamic>{'no_auth': true, 'no_context': true},
  );

  Future<ActiveRoute> getActiveRoute(int routeId) async {
    final response = await _client.post<dynamic>(
      '/getactiveroute',
      data: <String, dynamic>{'route_id': '$routeId'},
      options: _plain,
    );
    return _client.parse(
      response,
      (payload) => ActiveRoute.fromJson(payload as Map<String, dynamic>),
    );
  }

  Future<LiveTrack> getLiveTrack(ActiveRoute route) async {
    final response = await _client.post<dynamic>(
      '/getlivetrack',
      data: <String, dynamic>{
        'route_id': route.routeId,
        'route_track_id': route.routeTrackId,
      },
      options: _plain,
    );
    return _client.parse(
      response,
      (payload) => LiveTrack.fromJson(payload as Map<String, dynamic>),
    );
  }
}
