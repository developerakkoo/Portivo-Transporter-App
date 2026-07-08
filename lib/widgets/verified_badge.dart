import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({
    super.key,
    this.size = 16,
    this.iconSize = 10,
  });

  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.success,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.check,
        size: iconSize,
        color: AppColors.background,
      ),
    );
  }
}
