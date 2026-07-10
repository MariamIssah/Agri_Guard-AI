import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_key_service.dart';
import '../services/auth_service.dart';
import '../services/theme_notifier.dart';
import '../services/user_session.dart';
import '../utils/app_theme.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'my_activity_screen.dart';
import '../models/user_role.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session      = context.watch<UserSession>();
    final auth         = context.watch<AuthService>();
    final themeNotifier = context.watch<ThemeNotifier>();
    final apiKeys      = context.watch<ApiKeyService>();
    final user         = auth.currentUser;
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final gradient     = isDark ? darkHeaderGradient : lightHeaderGradient;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.viewPaddingOf(context).bottom + 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── User card ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(22)),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 2),
                    ),
                    child: Icon(
                      session.isFarmer
                          ? Icons.agriculture_rounded
                          : Icons.storefront_rounded,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user?.name ?? 'Agri-Guard User',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      session.isFarmer ? 'Farmer' : 'Buyer / Stakeholder',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Edit profile button ───────────────────────────────────────────
            if (auth.currentUser?.role != UserRole.admin)
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const EditProfileScreen()),
                ),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Edit Profile'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10)),
              ),

            const SizedBox(height: 24),

            // ── Farm info (farmers only) ──────────────────────────────────────
            if (session.isFarmer && user != null) ...[
              _SectionTitle('Farm Details'),
              const SizedBox(height: 12),
              _InfoRow(Icons.map_outlined, 'Region', user.region ?? 'Not set'),
              _InfoRow(Icons.location_city_outlined, 'District',
                  user.district ?? 'Not set'),
              _InfoRow(Icons.square_foot_rounded, 'Farm size',
                  user.farmSizeHa != null ? '${user.farmSizeHa} ha' : 'Not set'),
              _InfoRow(Icons.phone_outlined, 'Phone',
                  user.phone.isEmpty ? 'Not set' : user.phone),
              _InfoRow(Icons.badge_outlined, 'Farmer ID', user.id),
              const SizedBox(height: 24),
            ],

            // ── Buyer info + activity ─────────────────────────────────────────
            if (!session.isFarmer &&
                auth.currentUser?.role != UserRole.admin &&
                user != null) ...[
              _SectionTitle('Account Details'),
              const SizedBox(height: 12),
              if (user.region != null)
                _InfoRow(Icons.map_outlined, 'Region', user.region!),
              if (user.district != null)
                _InfoRow(Icons.location_city_outlined, 'District', user.district!),
              if (user.phone.isNotEmpty)
                _InfoRow(Icons.phone_outlined, 'Phone', user.phone),
              _InfoRow(Icons.badge_outlined, 'Buyer ID', user.id),
              const SizedBox(height: 8),
              _SettingTile(
                icon: Icons.history_rounded,
                title: 'My Activity History',
                subtitle: 'View and manage your browsing, searches & selections',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const MyActivityScreen()),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── App settings ─────────────────────────────────────────────────
            _SectionTitle('Settings'),
            const SizedBox(height: 12),
            _SettingTile(
              icon: isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              title: isDark ? 'Light theme' : 'Dark theme',
              subtitle: isDark
                  ? 'Switch to white + deep green'
                  : 'Switch to black + deep green',
              trailing: Switch(
                value: isDark,
                onChanged: (_) => themeNotifier.toggle(),
                activeThumbColor: AgriColors.leafGreen,
              ),
            ),
            const SizedBox(height: 24),

            // ── Connection settings ───────────────────────────────────────────
            _SectionTitle('Connection'),
            const SizedBox(height: 12),
            _SettingTile(
              icon: Icons.cloud_outlined,
              title: 'Weather API Key',
              subtitle: apiKeys.hasWeatherKey
                  ? 'Key saved — weather is active'
                  : 'Not set — tap to add your OpenWeather key',
              trailing: Icon(
                apiKeys.hasWeatherKey
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                color: apiKeys.hasWeatherKey
                    ? AgriColors.forestGreen
                    : AgriColors.gold,
              ),
              onTap: () => _showWeatherKeyDialog(context, apiKeys),
            ),
            const SizedBox(height: 8),
            _SettingTile(
              icon: Icons.dns_rounded,
              title: 'Backend Server URL',
              subtitle: apiKeys.effectiveBackendUrl,
              trailing: const Icon(Icons.edit_outlined, size: 18),
              onTap: () => _showBackendUrlDialog(context, apiKeys),
            ),
            const SizedBox(height: 24),

            // ── About ─────────────────────────────────────────────────────────
            _SectionTitle('About'),
            const SizedBox(height: 12),
            _SettingTile(
              icon: Icons.info_outline_rounded,
              title: 'Agri-Guard AI',
              subtitle: 'v2.0 — Agricultural Intelligence Platform',
            ),
            const SizedBox(height: 32),

            // ── Sign out ──────────────────────────────────────────────────────
            OutlinedButton.icon(
              onPressed: () async {
                await auth.logout();
                if (!context.mounted) return;
                context.read<UserSession>().clear();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AgriColors.danger,
                side: const BorderSide(color: AgriColors.danger),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 12),

            // ── Delete account ────────────────────────────────────────────────
            if (auth.currentUser?.role.name != 'admin')
              TextButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Account?'),
                      content: const Text(
                        'Your account and personal information will be permanently '
                        'removed from AgriGuard. Anonymised farm data may be kept '
                        'to improve crop predictions for all farmers.',
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete',
                              style: TextStyle(color: AgriColors.danger)),
                        ),
                      ],
                    ),
                  );
                  if (confirm != true || !context.mounted) return;
                  try {
                    await auth.deleteAccount();
                    if (!context.mounted) return;
                    context.read<UserSession>().clear();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$e'),
                            backgroundColor: AgriColors.danger),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.delete_forever_rounded,
                    color: AgriColors.danger, size: 18),
                label: const Text('Delete My Account',
                    style: TextStyle(color: AgriColors.danger)),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showWeatherKeyDialog(BuildContext context, ApiKeyService apiKeys) {
    final ctrl = TextEditingController(text: apiKeys.openWeatherKey ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('OpenWeather API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Get a free key at openweathermap.org/api',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'API Key',
                prefixIcon: Icon(Icons.key_outlined),
                hintText: 'Paste your key here',
              ),
            ),
          ],
        ),
        actions: [
          if (apiKeys.hasWeatherKey)
            TextButton(
              onPressed: () async {
                await apiKeys.clearOpenWeatherKey();
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
              child: const Text('Clear', style: TextStyle(color: AgriColors.danger)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final key = ctrl.text.trim();
              if (key.isEmpty) return;
              await apiKeys.saveOpenWeatherKey(key);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text('Weather API key saved'),
                  backgroundColor: AgriColors.forestGreen,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showBackendUrlDialog(BuildContext context, ApiKeyService apiKeys) {
    final ctrl =
        TextEditingController(text: apiKeys.effectiveBackendUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backend Server URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the URL of your hosted Agri-Guard API server.\n'
              'Example: https://your-server.com',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                prefixIcon: Icon(Icons.dns_rounded),
                hintText: 'https://your-api-server.com',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await apiKeys.clearBackendUrl();
              ctrl.text = apiKeys.effectiveBackendUrl;
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Reset to default URL')),
              );
            },
            child: const Text('Reset to default'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final url = ctrl.text.trim();
              if (url.isEmpty) return;
              final error = await apiKeys.saveBackendUrl(url);
              if (!ctx.mounted) return;
              if (error != null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(error),
                    backgroundColor: AgriColors.danger,
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text('Backend URL saved: $url'),
                  backgroundColor: AgriColors.forestGreen,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Text('$label: ',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          Expanded(
              child: Text(value,
                  style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(title, style: Theme.of(context).textTheme.titleSmall),
          subtitle: subtitle != null
              ? Text(subtitle!,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis)
              : null,
          trailing: trailing,
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
