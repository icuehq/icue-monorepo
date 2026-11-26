import 'package:flutter/widgets.dart';

/// Key of the root navigator; lets code without a `BuildContext` (such as the
/// API error toast) reach the app's overlay.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
