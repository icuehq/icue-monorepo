import 'package:icue_sdk/src/config/base_config.dart';
import 'package:icue_sdk/src/config/dev_config.dart';
import 'package:icue_sdk/src/config/prod_config.dart';

enum IcueEnvironment { prod, dev }

class IcueEnv {
  factory IcueEnv() => _instance;

  IcueEnv._internal();

  static final IcueEnv _instance = IcueEnv._internal();

  BaseConfig? _baseConfig;

  BaseConfig? get baseConfig => _baseConfig;

  void init(IcueEnvironment environment) {
    _baseConfig = switch (environment) {
      IcueEnvironment.dev => DevConfig(),
      IcueEnvironment.prod => ProdConfig(),
    };
  }
}
