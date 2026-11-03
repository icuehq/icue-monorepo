/// API environments for icue apps.
enum ApiEnvironment {
  dev('https://itraxpro.com'),
  prod('https://icuepro.com');

  const ApiEnvironment(this.baseUrl);

  /// Resolves the environment using compile-time flags:
  /// e.g. `--dart-define=ENV=prod` or `--dart-define=FLAVOR=prod`.
  /// Defaults to [ApiEnvironment.dev].
  factory ApiEnvironment.fromEnvironment() {
    const env = String.fromEnvironment('ENV');
    const flavor = String.fromEnvironment('FLAVOR');

    final target = env.isNotEmpty ? env : flavor;

    return switch (target.toLowerCase()) {
      'prod' || 'production' => ApiEnvironment.prod,
      _ => ApiEnvironment.dev,
    };
  }

  final String baseUrl;

  bool get isDev => this == ApiEnvironment.dev;
  bool get isProd => this == ApiEnvironment.prod;
}
