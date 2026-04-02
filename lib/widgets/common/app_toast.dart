import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showAppToast(
  BuildContext context,
  String message, {
  Color backgroundColor = AppColors.surfaceAlt,
  Color? foregroundColor,
  IconData? icon,
  Duration duration = const Duration(seconds: 2),
}) {
  final textColor = foregroundColor ?? AppColors.textPrimary;

  return ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: duration,
      backgroundColor: backgroundColor,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withOpacity(0.06)),
      ),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: textColor, size: 18),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(message, style: TextStyle(color: textColor)),
          ),
        ],
      ),
    ),
  );
}
