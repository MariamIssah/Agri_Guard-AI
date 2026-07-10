import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import '../services/theme_notifier.dart';
import '../services/user_session.dart';
import '../utils/app_theme.dart';
import 'disease_screen.dart';
import 'farm_activity_screen.dart';
import 'farm_registration_screen.dart';
import 'login_screen.dart';
import 'map_screen.dart';
import 'prediction_screen.dart';
import 'produce_availability_screen.dart';
import 'regional_forecast_screen.dart';
import 'weather_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onSearchTap});
  final VoidCallback? onSearchTap;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _health;
  int? _myCropCount;
  String? _estYieldDisplay;
  int? _uniqueFarmers;
  int? _uniqueCrops;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkHealth();
      _fetchStats();
    });
  }

  Future<void> _checkHealth() async {
    try {
      final h = await context.read<BackendService>().health();
      if (mounted) setState(() => _health = h);
    } catch (_) {}
  }

  Future<void> _fetchStats() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;
    final isFarmer = context.read<UserSession>().isFarmer;
    final backend = context.read<BackendService>();
    try {
      if (isFarmer) {
        final res = await backend.getMySubmissions(user.id);
        final subs = (res['submissions'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        final crops = subs
            .map((s) => s['crop']?.toString() ?? '')
            .where((c) => c.isNotEmpty)
            .toSet();
        final totalKg = subs.fold<double>(
            0, (sum, s) => sum + ((s['actual_yield_kg'] as num?)?.toDouble() ?? 0));
        final yieldStr = totalKg == 0
            ? '—'
            : totalKg >= 1000
                ? '${(totalKg / 1000).toStringAsFixed(1)}t'
                : '${totalKg.round()}kg';
        if (mounted) setState(() { _myCropCount = crops.length; _estYieldDisplay = yieldStr; });
      } else {
        final data = await backend.getHarvestActuals();
        final entries = (data['entries'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final crops = entries
            .map((e) => e['crop']?.toString() ?? '')
            .where((c) => c.isNotEmpty)
            .toSet();
        final farmers = entries
            .map((e) => e['farmer_id']?.toString() ?? '')
            .where((f) => f.isNotEmpty)
            .toSet();
        if (mounted) setState(() { _uniqueCrops = crops.length; _uniqueFarmers = farmers.length; });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<UserSession>();
    final themeNotifier = context.watch<ThemeNotifier>();
    final isFarmer = session.isFarmer;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = isDark ? darkHeaderGradient : lightHeaderGradient;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agri-Guard AI'),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            tooltip: isDark ? 'Light theme' : 'Dark theme',
            onPressed: themeNotifier.toggle,
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: widget.onSearchTap,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async { await Future.wait([_checkHealth(), _fetchStats()]); },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewPaddingOf(context).bottom + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hero header ────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.eco_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome, ${session.displayName}',
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              Text(
                                isFarmer ? 'Farmer Dashboard' : 'Buyer Dashboard',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                        _ApiStatusDot(health: _health),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isFarmer
                          ? 'Track your crops, predict yield, and get disease advisory.'
                          : 'Explore regional supply, harvest data, and market forecasts.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Quick stats ────────────────────────────────────────────
              _StatsRow(
                isFarmer: isFarmer,
                myCropCount: _myCropCount,
                estYieldDisplay: _estYieldDisplay,
                uniqueCrops: _uniqueCrops,
                uniqueFarmers: _uniqueFarmers,
              ),
              const SizedBox(height: 24),

              // ── Menu grid ──────────────────────────────────────────────
              Text(
                isFarmer ? 'Farm Tools' : 'Market Intelligence',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: isFarmer ? _farmerMenuItems(context) : _buyerMenuItems(context),
              ),

              const SizedBox(height: 24),

              // ── Quick actions ──────────────────────────────────────────
              Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              _QuickActionRow(isFarmer: isFarmer),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _farmerMenuItems(BuildContext context) => [
        _MenuCard(
          title: 'Predict Yield',
          subtitle: 'Pre & post harvest',
          icon: Icons.analytics_rounded,
          gradient: const LinearGradient(colors: [AgriColors.forestGreen, AgriColors.leafGreen]),
          onTap: () => _push(context, const PredictionScreen()),
        ),
        _MenuCard(
          title: 'Crop Health',
          subtitle: 'Disease detection',
          icon: Icons.healing_rounded,
          gradient: LinearGradient(colors: [AgriColors.danger, AgriColors.danger.withValues(alpha: 0.7)]),
          onTap: () => _push(context, const DiseaseScreen()),
        ),
        _MenuCard(
          title: 'Weather',
          subtitle: 'Forecast & advisory',
          icon: Icons.wb_sunny_rounded,
          gradient: LinearGradient(colors: [AgriColors.sky, AgriColors.sky.withValues(alpha: 0.7)]),
          onTap: () => _push(context, const WeatherScreen()),
        ),
        _MenuCard(
          title: 'Farm Register',
          subtitle: 'Log your farm',
          icon: Icons.landscape_rounded,
          gradient: LinearGradient(colors: [AgriColors.deepGreen, AgriColors.forestGreen]),
          onTap: () => _push(context, const FarmRegistrationScreen()),
        ),
      ];

  List<Widget> _buyerMenuItems(BuildContext context) => [
        _MenuCard(
          title: 'Harvest Data',
          subtitle: 'Actual produce',
          icon: Icons.inventory_2_rounded,
          gradient: const LinearGradient(colors: [AgriColors.forestGreen, AgriColors.leafGreen]),
          onTap: () => _push(context, const ProduceAvailabilityScreen()),
        ),
        _MenuCard(
          title: 'Forecasts',
          subtitle: 'Regional trends',
          icon: Icons.trending_up_rounded,
          gradient: LinearGradient(colors: [AgriColors.gold, AgriColors.gold.withValues(alpha: 0.7)]),
          onTap: () => _push(context, const RegionalForecastScreen()),
        ),
        _MenuCard(
          title: 'Crop Map',
          subtitle: 'Farm locations',
          icon: Icons.map_rounded,
          gradient: LinearGradient(colors: [AgriColors.sky, AgriColors.sky.withValues(alpha: 0.7)]),
          onTap: () => _push(context, const MapScreen()),
        ),
        _MenuCard(
          title: 'Predict Supply',
          subtitle: 'Future availability',
          icon: Icons.insights_rounded,
          gradient: LinearGradient(colors: [AgriColors.deepGreen, AgriColors.forestGreen]),
          onTap: () => _push(context, const PredictionScreen()),
        ),
      ];

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

// ── Supporting widgets ─────────────────────────────────────────────────────────

class _ApiStatusDot extends StatelessWidget {
  const _ApiStatusDot({this.health});
  final Map<String, dynamic>? health;

  @override
  Widget build(BuildContext context) {
    final ok = health != null && health!['status'] == 'ok';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: health == null ? Colors.grey : (ok ? Colors.greenAccent : Colors.redAccent),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          health == null ? 'Connecting…' : (ok ? 'API Online' : 'API Offline'),
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.isFarmer,
    this.myCropCount,
    this.estYieldDisplay,
    this.uniqueCrops,
    this.uniqueFarmers,
  });
  final bool isFarmer;
  final int? myCropCount;
  final String? estYieldDisplay;
  final int? uniqueCrops;
  final int? uniqueFarmers;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: isFarmer
          ? [
              Expanded(child: _stat(context, 'My Crops', myCropCount?.toString() ?? '—')),
              const SizedBox(width: 8),
              Expanded(child: _stat(context, 'Est. Yield', estYieldDisplay ?? '—')),
              const SizedBox(width: 8),
              Expanded(child: _stat(context, 'Health', '—')),
            ]
          : [
              Expanded(child: _stat(context, 'Crops Listed', uniqueCrops?.toString() ?? '…')),
              const SizedBox(width: 8),
              Expanded(child: _stat(context, 'Regions', '16')),
              const SizedBox(width: 8),
              Expanded(child: _stat(context, 'Farmers', uniqueFarmers?.toString() ?? '—')),
            ],
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: AgriColors.forestGreen)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const Spacer(),
            Text(title,
                style: const TextStyle(
                    color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(subtitle,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({required this.isFarmer});
  final bool isFarmer;

  @override
  Widget build(BuildContext context) {
    final items = isFarmer
        ? [
            ('Log Activity', Icons.event_note_rounded,
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FarmActivityScreen()))),
            ('Weather Now', Icons.cloud_rounded,
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeatherScreen()))),
          ]
        : [
            ('Regional Forecast', Icons.bar_chart_rounded,
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegionalForecastScreen()))),
            ('Sign Out', Icons.logout_rounded, () async {
              await context.read<AuthService>().logout();
              if (!context.mounted) return;
              context.read<UserSession>().clear();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            }),
          ];

    return Row(
      children: items.map((item) {
        final (label, icon, onTap) = item;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: item == items.last ? 0 : 10),
            child: OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 18),
              label: Text(label, overflow: TextOverflow.ellipsis),
            ),
          ),
        );
      }).toList(),
    );
  }
}
