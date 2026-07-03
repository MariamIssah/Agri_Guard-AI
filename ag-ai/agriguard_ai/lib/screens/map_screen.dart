import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import '../utils/app_theme.dart';

// ── Data model from /api/harvest/actuals ───────────────────────────────────────
class _FarmerEntry {
  const _FarmerEntry({
    required this.crop,
    required this.region,
    required this.district,
    required this.town,
    required this.phone,
    required this.quantityKg,
    required this.areaHa,
    required this.pricePerKg,
    required this.submittedAt,
    required this.farmerId,
    required this.yieldKgHa,
  });

  final String crop;
  final String region;
  final String district;
  final String town;
  final String phone;
  final double quantityKg;
  final double areaHa;
  final double? pricePerKg;
  final String submittedAt;
  final String farmerId;
  final double yieldKgHa;

  String get location {
    final parts = [town, district, region].where((s) => s.isNotEmpty).toList();
    return parts.join(', ');
  }

  String get quantityStr {
    if (quantityKg >= 1000) {
      return '${(quantityKg / 1000).toStringAsFixed(1)} t';
    }
    return '${quantityKg.toStringAsFixed(0)} kg';
  }

  String get farmSizeStr => '${areaHa.toStringAsFixed(1)} ha';

  String get yieldStr => '${yieldKgHa.toStringAsFixed(0)} kg/ha';

  String get priceStr => pricePerKg != null
      ? 'GHS ${pricePerKg!.toStringAsFixed(2)}/kg'
      : 'Price TBD';

  String get dateStr {
    try {
      final dt = DateTime.parse(submittedAt);
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[dt.month]} ${dt.year}';
    } catch (_) {
      return submittedAt.split('T').first;
    }
  }

  factory _FarmerEntry.fromJson(Map<String, dynamic> j) => _FarmerEntry(
        crop:        j['crop']?.toString() ?? '',
        region:      j['region']?.toString() ?? '',
        district:    j['district']?.toString() ?? '',
        town:        j['town']?.toString() ?? '',
        phone:       j['phone']?.toString() ?? '',
        quantityKg:  (j['quantity_available_kg'] as num?)?.toDouble() ?? 0,
        areaHa:      (j['area_hectares'] as num?)?.toDouble() ?? 0,
        pricePerKg:  (j['price_per_kg_ghs'] as num?)?.toDouble(),
        submittedAt: j['submitted_at']?.toString() ?? '',
        farmerId:    j['farmer_id']?.toString() ?? '',
        yieldKgHa:   (j['prediction']?['predicted_yield_kg_per_ha'] as num?)?.toDouble() ?? 0,
      );
}

// ── Screen ─────────────────────────────────────────────────────────────────────
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _loading = true;
  String? _error;
  List<_FarmerEntry> _farmers = [];
  int _totalKg = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFarmers());
  }

  Future<void> _loadFarmers() async {
    setState(() {
      _loading = true;
      _error   = null;
    });
    try {
      final data = await context.read<BackendService>().getHarvestActuals();
      final entries = (data['entries'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final summary = data['summary'] as Map<String, dynamic>? ?? {};
      setState(() {
        _farmers  = entries.map(_FarmerEntry.fromJson).toList();
        _totalKg  = ((summary['total_quantity_kg'] as num?)?.toInt()) ?? 0;
        _loading  = false;
      });
    } catch (e) {
      setState(() {
        _error   = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('map_title'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _loadFarmers)
              : _Body(farmers: _farmers, totalKg: _totalKg),
    );
  }
}

// ── Error view ─────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: AgriColors.meadowGreen),
            const SizedBox(height: 16),
            Text('Could not load producer data',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Make sure the server is running.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Body ───────────────────────────────────────────────────────────────────────
class _Body extends StatelessWidget {
  const _Body({required this.farmers, required this.totalKg});
  final List<_FarmerEntry> farmers;
  final int totalKg;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.viewPaddingOf(context).bottom + 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Map placeholder
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AgriColors.leafGreen.withValues(alpha: 0.3),
                  AgriColors.mintGreen.withValues(alpha: 0.5),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AgriColors.forestGreen.withValues(alpha: 0.2)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.map_rounded,
                    size: 48, color: AgriColors.forestGreen),
                const SizedBox(height: 8),
                Text(context.t('map_coming_soon'),
                    style: TextStyle(fontSize: 14, color: onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Summary strip
          if (farmers.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AgriColors.forestGreen.withValues(
                    alpha: isDark ? 0.15 : 0.07),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryTile(
                      label: 'Producers',
                      value: '${farmers.length}',
                      icon: Icons.people_rounded,
                    ),
                  ),
                  Container(
                      width: 1, height: 36,
                      color: AgriColors.forestGreen.withValues(alpha: 0.2)),
                  Expanded(
                    child: _SummaryTile(
                      label: 'Total Available',
                      value: totalKg >= 1000
                          ? '${(totalKg / 1000).toStringAsFixed(1)} t'
                          : '$totalKg kg',
                      icon: Icons.inventory_2_outlined,
                    ),
                  ),
                  Container(
                      width: 1, height: 36,
                      color: AgriColors.forestGreen.withValues(alpha: 0.2)),
                  Expanded(
                    child: _SummaryTile(
                      label: 'Crops',
                      value: '${farmers.map((f) => f.crop).toSet().length}',
                      icon: Icons.grass_rounded,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Text(
            context.t('map_active_producers'),
            style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600, color: onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            farmers.isEmpty
                ? 'No harvest reports yet — check back soon.'
                : 'Verified data from farmer harvest submissions.',
            style: TextStyle(fontSize: 12, color: onSurfaceVariant),
          ),
          const SizedBox(height: 12),

          if (farmers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.agriculture_rounded,
                        size: 48,
                        color: onSurfaceVariant.withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    Text('No harvest submissions yet',
                        style: TextStyle(color: onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(
                      'Farmers submit actual yields after harvest.\n'
                      'That data appears here for buyers.',
                      style: TextStyle(
                          fontSize: 12,
                          color: onSurfaceVariant.withValues(alpha: 0.7)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ...farmers.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FarmerCard(farmer: f),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile(
      {required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AgriColors.forestGreen),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AgriColors.forestGreen)),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

// ── Farmer card ────────────────────────────────────────────────────────────────
class _FarmerCard extends StatelessWidget {
  const _FarmerCard({required this.farmer});
  final _FarmerEntry farmer;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => _showDetail(context),
        leading: CircleAvatar(
          backgroundColor: AgriColors.leafGreen.withValues(alpha: 0.15),
          child: Text(
            farmer.crop.isNotEmpty ? farmer.crop[0].toUpperCase() : '?',
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AgriColors.forestGreen),
          ),
        ),
        title: Text(
          '${farmer.crop} · ${farmer.region}',
          style: TextStyle(fontWeight: FontWeight.w600, color: onSurface),
        ),
        subtitle: Text(
          farmer.location.isNotEmpty ? farmer.location : farmer.region,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              farmer.quantityStr,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AgriColors.forestGreen,
                  fontSize: 13),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 16, color: AgriColors.forestGreen),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final bottomPad = MediaQuery.viewPaddingOf(ctx).bottom + 24;
        return SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.85,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPad),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Avatar + name
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AgriColors.forestGreen
                          .withValues(alpha: isDark ? 0.6 : 0.12),
                      child: Text(
                        farmer.crop.isNotEmpty
                            ? farmer.crop[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            color: AgriColors.forestGreen),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            farmer.crop,
                            style: Theme.of(ctx).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            farmer.location.isNotEmpty
                                ? farmer.location
                                : farmer.region,
                            style: TextStyle(
                                color: Theme.of(ctx)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Stats grid
                Row(
                  children: [
                    Expanded(
                        child: _StatTile(Icons.inventory_2_outlined,
                            'Available', farmer.quantityStr,
                            AgriColors.forestGreen)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _StatTile(Icons.grass_rounded, 'Yield',
                            farmer.yieldStr, AgriColors.leafGreen)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: _StatTile(Icons.square_foot_rounded,
                            'Farm Size', farmer.farmSizeStr,
                            AgriColors.wheatGold)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _StatTile(Icons.attach_money_rounded,
                            'Price', farmer.priceStr, AgriColors.sky)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: _StatTile(Icons.location_on_rounded,
                            'Region', farmer.region,
                            AgriColors.forestGreen)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _StatTile(Icons.calendar_today_outlined,
                            'Submitted', farmer.dateStr, AgriColors.sky)),
                  ],
                ),
                const SizedBox(height: 16),

                // Phone
                if (farmer.phone.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AgriColors.forestGreen
                          .withValues(alpha: isDark ? 0.15 : 0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_rounded,
                            color: AgriColors.mintGreen, size: 18),
                        const SizedBox(width: 10),
                        Text(farmer.phone,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AgriColors.mintGreen,
                                fontSize: 15)),
                      ],
                    ),
                  ),

                // Source note
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.verified_outlined,
                        size: 13, color: AgriColors.meadowGreen),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Verified farmer submission — actual harvest data',
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(ctx)
                                .colorScheme
                                .onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.icon, this.label, this.value, this.color);
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface)),
        ],
      ),
    );
  }
}
