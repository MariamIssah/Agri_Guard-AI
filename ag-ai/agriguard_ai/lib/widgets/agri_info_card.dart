import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class AgriInfoCard extends StatelessWidget {
  const AgriInfoCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.accentColor = AgriColors.leafGreen,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Dark: solid accent bg + white icon; Light: tinted bg + colored icon
    final iconBg = isDark
        ? accentColor.withValues(alpha: 0.80)
        : accentColor.withValues(alpha: 0.12);
    final iconColor = isDark ? Colors.white : accentColor;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: onSurface.withValues(alpha: 0.50),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
