import 'dart:async';

import 'package:flutter/foundation.dart';

enum AppBannerType { info, success, warning }

class AppBannerMessage {
  const AppBannerMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
  });

  final String id;
  final String title;
  final String body;
  final AppBannerType type;
}

class AppBannerController extends ChangeNotifier {
  AppBannerController();

  AppBannerMessage? _current;
  Timer? _dismissTimer;
  final Set<String> _shownIds = {};

  AppBannerMessage? get current => _current;

  void show({
    required String id,
    required String title,
    required String body,
    AppBannerType type = AppBannerType.info,
    Duration autoDismiss = const Duration(seconds: 4),
    bool allowRepeat = false,
  }) {
    if (!allowRepeat && _shownIds.contains(id)) return;

    _dismissTimer?.cancel();
    _shownIds.add(id);
    _current = AppBannerMessage(
      id: id,
      title: title,
      body: body,
      type: type,
    );
    notifyListeners();

    _dismissTimer = Timer(autoDismiss, dismiss);
  }

  void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    if (_current == null) return;
    _current = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }
}
