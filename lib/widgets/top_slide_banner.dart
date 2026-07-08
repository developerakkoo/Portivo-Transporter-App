import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/notifications/app_banner_controller.dart';
import '../core/theme/app_colors.dart';

class TopSlideBanner extends StatelessWidget {
  const TopSlideBanner({super.key});

  Color _accentColor(AppBannerType type) {
    switch (type) {
      case AppBannerType.success:
        return AppColors.success;
      case AppBannerType.warning:
        return AppColors.warning;
      case AppBannerType.info:
        return AppColors.primary;
    }
  }

  IconData _icon(AppBannerType type) {
    switch (type) {
      case AppBannerType.success:
        return Icons.check_circle_outline;
      case AppBannerType.warning:
        return Icons.info_outline;
      case AppBannerType.info:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppBannerController>(
      builder: (context, controller, _) {
        final message = controller.current;
        final visible = message != null;

        return IgnorePointer(
          ignoring: !visible,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            offset: visible ? Offset.zero : const Offset(0, -1.2),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: visible ? 1 : 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.background,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: message != null
                              ? _accentColor(message.type).withValues(alpha: 0.35)
                              : AppColors.dividerGrey,
                        ),
                      ),
                      child: message == null
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    _icon(message.type),
                                    size: 20,
                                    color: _accentColor(message.type),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          message.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          message.body,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: controller.dismiss,
                                    icon: const Icon(Icons.close, size: 18),
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
