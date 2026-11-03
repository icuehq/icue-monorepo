import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_update_flutter/in_app_update_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Store-driven update prompts. Android uses Play in-app updates; iOS looks up
/// the App Store listing and shows the native store sheet when it is newer.
/// No-op in debug builds (and for builds not installed from the store).
class AppUpdateService {
  const AppUpdateService._();

  /// Android priority (set in Play Console) at/above which the update blocks.
  static const immediatePriority = 4;

  /// Call once at startup. Never throws: a failed check must not affect the app.
  static Future<void> checkForUpdate() async {
    if (kDebugMode) return;
    try {
      if (Platform.isAndroid) {
        await _android();
      } else if (Platform.isIOS) {
        await _ios();
      }
    } catch (e) {
      debugPrint('In-app update check failed: $e');
    }
  }

  // Flexible updates download in the background; they are applied as soon as
  // the download finishes (this runs at launch, so the restart is early).
  static Future<void> _android() async {
    final plugin = InAppUpdateFlutter();
    final info = await plugin.checkUpdateAndroid();
    if (info.updateAvailability != UpdateAvailabilityAndroid.updateAvailable) {
      return;
    }
    if (info.updatePriority >= immediatePriority &&
        info.isImmediateUpdateAllowed) {
      await plugin.startImmediateUpdateAndroid();
    } else if (info.isFlexibleUpdateAllowed) {
      late final StreamSubscription<dynamic> sub;
      sub = plugin.installStateStreamAndroid.listen((state) {
        if (state.status == InstallStatusAndroid.downloaded) {
          unawaited(sub.cancel());
          unawaited(plugin.completeUpdateAndroid());
        }
      });
      await plugin.startFlexibleUpdateAndroid();
    }
  }

  static Future<void> _ios() async {
    final package = await PackageInfo.fromPlatform();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(
        Uri.https('itunes.apple.com', '/lookup', {
          'bundleId': package.packageName,
        }),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      final body = await response.transform(utf8.decoder).join();
      final results = (jsonDecode(body) as Map)['results'] as List;
      if (results.isEmpty) return; // Not (yet) on the App Store.
      final store = results.first as Map;
      if (isNewerVersion(store['version'] as String, package.version)) {
        await InAppUpdateFlutter().showUpdateForIos(
          appStoreId: '${store['trackId']}',
        );
      }
    } finally {
      client.close();
    }
  }

  /// True when dotted version [store] is greater than [installed].
  @visibleForTesting
  static bool isNewerVersion(String store, String installed) {
    List<int> parse(String v) =>
        v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final a = parse(store);
    final b = parse(installed);
    for (var i = 0; i < a.length || i < b.length; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }
}
