import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class SlateBottomSheet extends StatelessWidget {
  final String? title;
  final Widget child;
  final double? height;

  const SlateBottomSheet({
    super.key,
    this.title,
    required this.child,
    this.height,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    double? height,
    String? title,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      builder: (context) => SlateBottomSheet(
        title: title,
        height: height,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (title != null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                title!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Flexible(child: child),
        ],
      ),
    );
  }
}