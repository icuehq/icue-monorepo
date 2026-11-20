import 'package:icue_sdk/src/config/base_config.dart';

class ProdConfig extends BaseConfig {
  @override
  String get baseUrl => 'https://icuepro.com/api';

  @override
  String get env => 'PROD';
}
