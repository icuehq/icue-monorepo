enum IcueEnvironment { prod, dev }

class IcueEnv {
  factory IcueEnv() => _instance;

  IcueEnv._internal();

  static final IcueEnv _instance = IcueEnv._internal();

  String baseUrl = '';

  void init(IcueEnvironment environment) {
    baseUrl = switch (environment) {
      IcueEnvironment.dev => 'https://itraxpro.com/api',
      IcueEnvironment.prod => 'https://icuepro.com/api',
    };
  }
}
