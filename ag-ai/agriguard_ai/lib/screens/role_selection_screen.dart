import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_localizations.dart';
import '../models/user_role.dart';
import '../services/user_session.dart';
import '../utils/app_theme.dart';
import 'main_shell.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: Text(context.t('select_user_type_title'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.t('select_user_type_continue_as'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.t('select_user_type_subtitle'),
              style: TextStyle(color: onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            _roleCard(
              context,
              role: UserRole.farmer,
              icon: Icons.agriculture_rounded,
              title: context.t('role_farmer_title'),
              subtitle: context.t('role_farmer_subtitle'),
              color: AgriColors.forestGreen,
            ),
            const SizedBox(height: 16),
            _roleCard(
              context,
              role: UserRole.buyer,
              icon: Icons.storefront_rounded,
              title: context.t('role_buyer_title'),
              subtitle: context.t('role_buyer_subtitle'),
              color: AgriColors.wheatGold,
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleCard(
    BuildContext context, {
    required UserRole role,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    // Dark mode: solid color bg + white icon; Light mode: tinted bg + colored icon
    final iconBg = isDark
        ? color.withValues(alpha: 0.80)
        : color.withValues(alpha: 0.15);
    final iconColor = isDark ? Colors.white : color;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.read<UserSession>().setRole(role);
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainShell()),
            (_) => false,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
