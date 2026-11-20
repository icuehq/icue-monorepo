import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:injectable/injectable.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Device and app facts the parent endpoints expect on login and student refresh.
@lazySingleton
class ParentDeviceInfo {
  Map<String, dynamic>? _cached;

  /// App version, e.g. `6.1.1`; empty before [load].
  String appVersion = '';

  Map<String, dynamic> get json => _cached ?? <String, dynamic>{};

  Future<void> load() async {
    final package = await PackageInfo.fromPlatform();
    appVersion = package.version;
    final plugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      _cached = <String, dynamic>{
        'appversion': package.version,
        'osname': 'Android',
        'osversion': info.version.sdkInt.toString(),
        'osversionno': info.version.release,
        'brand': info.brand,
        'model': info.model,
        'device': info.device,
        'manufacturer': info.manufacturer,
      };
    } else if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      _cached = <String, dynamic>{
        'appversion': package.version,
        'osname': 'iOS',
        'osversion': info.systemVersion,
        'osversionno': info.systemVersion,
        'brand': info.name,
        'model': info.model,
        'device': info.utsname.machine,
        'manufacturer': info.name,
      };
    }
  }
}
