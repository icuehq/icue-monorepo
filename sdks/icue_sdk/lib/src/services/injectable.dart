import 'package:get_it/get_it.dart';
import 'package:icue_sdk/src/services/injectable.config.dart';
import 'package:injectable/injectable.dart';

/// Dedicated, isolated service locator instance for the iCue SDK.
/// Using [GetIt.asNewInstance] prevents collisions with host application DI containers.
final getIt = GetIt.asNewInstance();

@InjectableInit()
Future<void> configureDependencies() async {
  getIt.init();
}

@module
abstract class RegisterModule {}
