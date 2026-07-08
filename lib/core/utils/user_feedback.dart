import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../constants/app_copy.dart';
import '../../utils/error_utils.dart';

void showUserErrorSnackBar(
  BuildContext context,
  dynamic error, {
  String? fallback,
}) {
  final message = error != null
      ? ErrorUtils.userMessage(error, fallback: fallback)
      : (fallback ?? AppCopy.errorGeneric);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: AppColors.error,
    ),
  );
}

void showUserSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: AppColors.success,
    ),
  );
}
