import 'package:flutter/material.dart';

import 'main_shell_scope.dart';

/// Hamburger button that opens the main shell drawer when available.
class OpenAppDrawerButton extends StatelessWidget {
  const OpenAppDrawerButton({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = MainShellScope.maybeOf(context);
    if (scope == null) return const SizedBox.shrink();

    return IconButton(
      icon: const Icon(Icons.menu),
      tooltip: 'Menu',
      onPressed: scope.openDrawer,
    );
  }
}
