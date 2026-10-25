import 'package:api_client/src/auth/token_provider.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

const String defaultSourceKey = 'Source';
const String defaultBranchKey = 'BranchId';
const String defaultSourceValue = 'adminapp';

/// Interceptor that attaches the authentication token ('token' header),
/// injects required contextual metadata (Source, BranchId) into non-GET request bodies,
/// and handles automatic 401 retry and session revocation.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    this.tokenProvider,
    required this.dio,
    this.source,
    this.sourceProvider,
    this.branchIdProvider,
    this.onSessionExpired,
  });

  TokenProvider? tokenProvider;
  final Dio dio;
  final String? source;
  final String? Function()? sourceProvider;
  final dynamic Function()? branchIdProvider;
  final void Function()? onSessionExpired;

  TokenProvider? _resolveTokenProvider() {
    if (tokenProvider != null) return tokenProvider;
    if (GetIt.I.isRegistered<TokenProvider>()) {
      return GetIt.I<TokenProvider>();
    }
    return null;
  }

  String? _resolveSource() {
    if (source != null) return source;
    final providedSource = sourceProvider?.call();
    if (providedSource != null) return providedSource;
    return _resolveTokenProvider()?.getSource() ?? defaultSourceValue;
  }

  dynamic _resolveBranchId() {
    final providedBranchId = branchIdProvider?.call();
    if (providedBranchId != null) return providedBranchId;
    return _resolveTokenProvider()?.getBranchId();
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 1. Attach authentication token if not opting out
    if (options.extra['no_auth'] != true) {
      try {
        final provider = _resolveTokenProvider();
        final token = await provider?.getAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['token'] = token;
        }
      } catch (_) {
        // Fallthrough if token resolution fails
      }
    }

    // 2. Inject extra fields for requests that allow data (non-GET requests)
    if (options.method.toUpperCase() != 'GET' &&
        options.extra['no_context'] != true) {
      final extraFields = <String, dynamic>{
        defaultSourceKey: _resolveSource(),
        defaultBranchKey: _resolveBranchId(),
      }..removeWhere((_, v) => v == null);

      if (options.data is Map<dynamic, dynamic>) {
        final mapData = Map<String, dynamic>.from(
          options.data as Map<dynamic, dynamic>,
        )..addAll(extraFields);
        options.data = mapData;
      } else if (options.data is FormData) {
        final formData = options.data as FormData;
        final existingFields = <String, String>{
          for (final f in formData.fields) f.key: f.value,
        };

        for (final entry in extraFields.entries) {
          if (!existingFields.containsKey(entry.key)) {
            formData.fields.add(
              MapEntry<String, String>(entry.key, '${entry.value}'),
            );
          }
        }
        options.data = formData;
      } else {
        options.data ??= extraFields;
      }
    }

    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final is401 = response?.statusCode == 401;
    final isRetried = err.requestOptions.extra['is_retry'] == true;

    if (is401 && !isRetried) {
      final provider = _resolveTokenProvider();
      if (provider != null) {
        try {
          final refreshed = await provider.refreshToken();
          if (refreshed) {
            final options = err.requestOptions;
            options.extra['is_retry'] = true;

            final newToken = await provider.getAccessToken();
            if (newToken != null && newToken.isNotEmpty) {
              options.headers['token'] = newToken;
            }

            final retryResponse = await dio.fetch<dynamic>(options);
            return handler.resolve(retryResponse);
          } else {
            await provider.onAuthFailed();
            onSessionExpired?.call();
          }
        } catch (_) {
          await provider.onAuthFailed();
          onSessionExpired?.call();
        }
      }
    }

    return handler.next(err);
  }
}
