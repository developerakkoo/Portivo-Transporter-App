import 'package:flutter/material.dart';

/// Provides access to the main shell drawer from nested tab scaffolds.
class MainShellScope extends InheritedWidget {
  const MainShellScope({
    super.key,
    required this.openDrawer,
    required super.child,
  });

  final VoidCallback openDrawer;

  static MainShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MainShellScope>();
  }

  static MainShellScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'MainShellScope not found in widget tree');
    return scope!;
  }

  @override
  bool updateShouldNotify(MainShellScope oldWidget) {
    return openDrawer != oldWidget.openDrawer;
  }
}
