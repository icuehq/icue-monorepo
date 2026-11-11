import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:firebase_core/firebase_core.dart';

/// Firebase JS SDK that ships Crashlytics for web (preview).
const _sdk = 'https://www.gstatic.com/firebasejs/13.2.0';

JSObject? _crashlytics;
JSObject? _module;

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
void recordWebError(Object error, StackTrace? stack) {
  final module = _module;
  if (module == null) return;
  final jsError = (globalContext['Error']! as JSFunction)
      .callAsConstructor<JSObject>('$error'.toJS);
  if (stack != null) jsError['stack'] = '$error\n$stack'.toJS;
  module.callMethod<JSAny?>('recordError'.toJS, _crashlytics, jsError);
}
