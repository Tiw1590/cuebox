import 'package:flutter/material.dart';

import '../theme.dart';

/// 统一的空状态：图标 + 标题 + 说明 + 可选操作。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final softIconColor = iconColor ?? CueBoxColors.textSecondary;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    CueBoxColors.surfaceHigh,
                    CueBoxColors.surface,
                  ],
                ),
                border: Border.all(
                  color: CueBoxColors.borderStrong,
                  width: 1.2,
                ),
                boxShadow: [
                  CueBoxColors.ambientShadow,
                  if (CueBoxColors.isGlass)
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.45),
                      blurRadius: 2,
                      spreadRadius: -1,
                    ),
                ],
              ),
              child: Icon(icon, size: 46, color: softIconColor),
            ),
            SizedBox(height: 22),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(
                  color: CueBoxColors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
