import 'base_config.dart';

class DevConfig extends BaseConfig {
  @override
  String get baseUrl => 'https://itraxpro.com';

  @override
  String get hrmsBaseUrl => 'https://hrmscore.itraxpro.com';

  @override
  String get env => 'DEV';
}
