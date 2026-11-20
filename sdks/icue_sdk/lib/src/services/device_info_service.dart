import 'dart:developer';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:package_info_plus/package_info_plus.dart';

@singleton
class DeviceInfoService {
  Map<String, dynamic>? _deviceInfoCache;

  Future<Map<String, dynamic>> getDeviceInfo() async {
    if (_deviceInfoCache != null && _deviceInfoCache!.isNotEmpty) {
      return _deviceInfoCache!;
    }
    try {
      final deviceInfoPlugin = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();
      final Map<String, dynamic> info;
      if (kIsWeb) {
        final webInfo = await deviceInfoPlugin.webBrowserInfo;
        info = {
          'appversion': packageInfo.version,
          'sdkversion': packageInfo.version,
          'brand': webInfo.browserName.name,
          'platform': 'Web',
        };
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            final androidInfo = await deviceInfoPlugin.androidInfo;
            info = {
              'appversion': packageInfo.version,
              'sdkversion': packageInfo.version,
              'osname': 'Android',
              'osversionno': androidInfo.version.release,
              'osversion': androidInfo.version.sdkInt.toString(),
              'brand': androidInfo.brand,
              'model': androidInfo.model,
              'device': androidInfo.device,
              'manufacturer': androidInfo.manufacturer,
            };
            break;
          case TargetPlatform.iOS:
            final iosInfo = await deviceInfoPlugin.iosInfo;
            info = {
              'appversion': packageInfo.version,
              'sdkversion': packageInfo.version,
              'osname': 'iOS',
              'osversion': iosInfo.systemVersion,
              'osversionno': iosInfo.systemVersion,
              'brand': iosInfo.name,
              'model': iosInfo.model,
              'device': iosInfo.utsname.machine,
              'manufacturer': iosInfo.name,
            };
            break;
          default:
            info = {
              'appversion': packageInfo.version,
              'sdkversion': packageInfo.version,
              'platform': defaultTargetPlatform.name,
            };
        }
      }
      _deviceInfoCache = info;
      return info;
    } catch (e, stack) {
      log('Failed to get device info', error: e, stackTrace: stack);
      return _deviceInfoCache ?? {};
    }
  }
}
