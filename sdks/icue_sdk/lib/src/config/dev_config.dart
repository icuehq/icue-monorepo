import 'package:icue_sdk/src/config/base_config.dart';

class DevConfig extends BaseConfig {
  @override
  String get baseUrl => 'https://itraxpro.com/api';

  @override
  String get env => 'DEV';
}
