import 'package:flutter/material.dart';

/// Global navigator key so background/push handlers can navigate without a
/// BuildContext (used by PushService deep-link routing).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
