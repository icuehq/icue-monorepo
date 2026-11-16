import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:firebase_core/firebase_core.dart';

/// Firebase JS SDK that ships Crashlytics for web.
const _sdk = 'https://www.gstatic.com/firebasejs/13.3.0';

JSObject? _crashlytics;
JSObject? _module;
final _attributes = <String, String>{};

Future<JSObject> _import(String url) {
  final import = (globalContext['Function']! as JSFunction)
      .callAsConstructor<JSFunction>('u'.toJS, 'return import(u)'.toJS);
  return (import.callAsFunction(null, url.toJS)! as JSPromise<JSObject>).toDart;
}

/// Starts the JS Crashlytics SDK on its own app instance (same project as
/// the default Firebase app). It registers `error`/`unhandledrejection`
/// listeners itself.
Future<void> initWebCrashlytics() async {
  final options = Firebase.app().options;
  final config = {
    'apiKey': options.apiKey,
    'authDomain': options.authDomain,
    'projectId': options.projectId,
    'storageBucket': options.storageBucket,
    'messagingSenderId': options.messagingSenderId,
    'appId': options.appId,
  }.jsify();
  final app = (await _import('$_sdk/firebase-app.js')).callMethod<JSObject>(
    'initializeApp'.toJS,
    config,
    'icue-crashlytics'.toJS,
  );
  _module = await _import('$_sdk/firebase-crashlytics.js');
  _crashlytics = _module!.callMethod<JSObject>('getCrashlytics'.toJS, app);
}

/// Dart errors never reach `window.onerror`, so they are forwarded here.
void recordWebError(
  Object error,
  StackTrace? stack, {
  String? reason,
  List<Object> information = const [],
}) {
  final module = _module;
  final crashlytics = _crashlytics;
  if (module == null || crashlytics == null) return;
  final jsError = (globalContext['Error']! as JSFunction)
      .callAsConstructor<JSObject>('$error'.toJS);
  if (stack != null) jsError['stack'] = '$error\n$stack'.toJS;

  final attributes = {
    ..._attributes,
    if (reason != null && reason.isNotEmpty) 'reason': reason,
    if (information.isNotEmpty) 'information': information.join(', '),
  }.jsify();

  module.callMethod<JSAny?>(
    'recordError'.toJS,
    crashlytics,
    jsError,
    attributes,
  );
}

void setWebUser({
  String? id,
  String? organizationId,
  String? zoneId,
  String? branchId,
  String? schoolName,
}) {
  if (id == null) {
    _attributes.remove('userId');
    _attributes.remove('organizationId');
    _attributes.remove('zoneId');
    _attributes.remove('branchId');
    _attributes.remove('schoolName');
    return;
  }
  _attributes['userId'] = id;
  if (organizationId != null && organizationId.isNotEmpty) {
    _attributes['organizationId'] = organizationId;
  }
  if (zoneId != null && zoneId.isNotEmpty) {
    _attributes['zoneId'] = zoneId;
  }
  if (branchId != null && branchId.isNotEmpty) {
    _attributes['branchId'] = branchId;
  }
  if (schoolName != null && schoolName.isNotEmpty) {
    _attributes['schoolName'] = schoolName;
  }
}

void setWebCustomKey(String key, String value) {
  _attributes[key] = value;
}

void logWeb(String message) {
  final module = _module;
  final crashlytics = _crashlytics;
  if (module == null || crashlytics == null) return;
  module.callMethod<JSAny?>(
    'log'.toJS,
    crashlytics,
    message.toJS,
    _attributes.jsify(),
  );
}
