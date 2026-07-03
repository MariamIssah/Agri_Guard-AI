import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import '../utils/app_theme.dart';

// ── Data model from API ────────────────────────────────────────────────────────
class _ForecastItem {
  const _ForecastItem({
    required this.crop,
    required this.region,
    required this.year,
    required this.yieldKgHa,
    required this.areaHa,
    required this.productionTonnes,
    required this.trendPct,
    required this.isPositive,
    required this.isModelPrediction,
  });

  final String crop;
  final String region;
  final int year;
  final double yieldKgHa;
  final double areaHa;
  final double productionTonnes;
  final double trendPct;
  final bool isPositive;
  final bool isModelPrediction;

  factory _ForecastItem.fromJson(Map<String, dynamic> j) => _ForecastItem(
        crop:              j['crop']?.toString() ?? '',
        region:            j['region']?.toString() ?? '',
        year:              (j['year'] as num?)?.toInt() ?? 0,
        yieldKgHa:         (j['predicted_yield_kg_per_ha'] as num?)?.toDouble() ?? 0,
        areaHa:            (j['area_ha'] as num?)?.toDouble() ?? 0,
        productionTonnes:  (j['production_tonnes'] as num?)?.toDouble() ?? 0,
        trendPct:          (j['trend_pct'] as num?)?.toDouble() ?? 0,
        isPositive:        j['is_positive'] as bool? ?? true,
        isModelPrediction: j['is_model_prediction'] as bool? ?? false,
      );

  String get trendStr =>
      '${isPositive ? '+' : ''}${trendPct.toStringAsFixed(1)}%';

  String get yieldStr =>
      '${_fmt(yieldKgHa)} kg/ha';

  String get areaStr =>
      '${_fmt(areaHa)} ha';

  String get productionStr =>
      '${_fmt(productionTonnes)} t';

  static String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// ── Screen ─────────────────────────────────────────────────────────────────────
class RegionalForecastScreen extends StatefulWidget {
  const RegionalForecastScreen({super.key});

  @override
  State<RegionalForecastScreen> createState() => _RegionalForecastScreenState();
}

class _RegionalForecastScreenState extends State<RegionalForecastScreen> {
  bool _loading = true;
  String? _error;
  List<_ForecastItem> _items = [];
  List<int> _dataYears = [];
  List<int> _forecastYears = [];
  int? _selectedYear;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BackendService>().logBuyerActivity(
        buyerId: context.read<AuthService>().currentUser?.id ?? 'guest',
        action: 'browse',
        screen: 'regional_forecast',
      );
      _loadForecast();
    });
  }

  Future<void> _loadForecast({int? year}) async {
    setState(() {
      _loading = true;
      _error   = null;
    });
    try {
      final data = await context.read<BackendService>()
          .getRegionalForecast(year: year);
      final results = (data['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final dy = (data['data_years'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [];
      final fy = (data['forecast_years'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [];
      final yr = (data['year'] as num?)?.toInt();
      setState(() {
        _items         = results.map(_ForecastItem.fromJson).toList();
        _dataYears     = dy;
        _forecastYears = fy;
        _selectedYear  = yr;
        _loading       = false;
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
      appBar: AppBar(title: Text(context.t('regional_forecast_title'))),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorView(error: _error!, onRetry: () => _loadForecast(year: _selectedYear))
                : _Body(
                    items: _items,
                    dataYears: _dataYears,
                    forecastYears: _forecastYears,
                    selectedYear: _selectedYear,
                    onYearSelected: (y) => _loadForecast(year: y),
                  ),
      ),
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
            Text('Could not load forecasts',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Make sure the server is running and try again.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13),
              textAlign: TextAlign.center,
            ),
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
  const _Body({
    required this.items,
    required this.dataYears,
    required this.forecastYears,
    required this.selectedYear,
    required this.onYearSelected,
  });

  final List<_ForecastItem> items;
  final List<int> dataYears;
  final List<int> forecastYears;
  final int? selectedYear;
  final void Function(int year) onYearSelected;

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListView(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.viewPaddingOf(context).bottom + 120),
      children: [
        Text(
          context.t('regional_forecast_description'),
          style: TextStyle(color: onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 12),

        // ── Year selector ────────────────────────────────────────────────────
        if (dataYears.isNotEmpty || forecastYears.isNotEmpty) ...[
          _YearSelector(
            dataYears: dataYears,
            forecastYears: forecastYears,
            selectedYear: selectedYear,
            onSelected: onYearSelected,
          ),
          const SizedBox(height: 12),
        ],

        // ── Source badge ────────────────────────────────────────────────────
        if (selectedYear != null) ...[
          Row(
            children: [
              Icon(
                items.any((i) => i.isModelPrediction)
                    ? Icons.auto_awesome_rounded
                    : Icons.history_rounded,
                size: 14,
                color: onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                items.any((i) => i.isModelPrediction)
                    ? 'ML model forecast for $selectedYear'
                    : 'FAOSTAT historical data for $selectedYear',
                style: TextStyle(fontSize: 11, color: onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],

        // ── Cards ────────────────────────────────────────────────────────────
        if (items.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'No forecast data available for the selected year.',
                style: TextStyle(color: onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ForecastCard(item: item),
            ),
          ),
      ],
    );
  }
}

// ── Year selector ──────────────────────────────────────────────────────────────
class _YearSelector extends StatelessWidget {
  const _YearSelector({
    required this.dataYears,
    required this.forecastYears,
    required this.selectedYear,
    required this.onSelected,
  });

  final List<int> dataYears;
  final List<int> forecastYears;
  final int? selectedYear;
  final void Function(int) onSelected;

  @override
  Widget build(BuildContext context) {
    final allYears = [...dataYears, ...forecastYears];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: allYears.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (ctx, i) {
          final y = allYears[i];
          final isForecast = forecastYears.contains(y);
          final isSelected = y == selectedYear;
          return GestureDetector(
            onTap: () => onSelected(y),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AgriColors.forestGreen
                    : isForecast
                        ? AgriColors.forestGreen.withValues(alpha: 0.12)
                        : Theme.of(ctx).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AgriColors.forestGreen
                      : isForecast
                          ? AgriColors.forestGreen.withValues(alpha: 0.4)
                          : Theme.of(ctx).colorScheme.outline,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isForecast) ...[
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 11,
                      color: isSelected
                          ? Colors.white
                          : AgriColors.forestGreen,
                    ),
                    const SizedBox(width: 3),
                  ],
                  Text(
                    '$y',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : Theme.of(ctx).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Forecast card ──────────────────────────────────────────────────────────────
class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.item});
  final _ForecastItem item;

  Color get _color =>
      item.isPositive ? AgriColors.leafGreen : AgriColors.gold;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final color = _color;
    final badgeBg   = isDark ? color.withValues(alpha: 0.80) : color.withValues(alpha: 0.12);
    final badgeText = isDark ? Colors.white : color;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.read<BackendService>().logBuyerActivity(
            buyerId: context.read<AuthService>().currentUser?.id ?? 'guest',
            action: 'select',
            screen: 'regional_forecast',
            crop: item.crop,
            region: item.region,
          );
          _showDetail(context);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item.crop} — ${item.region}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: onSurface,
                            ),
                          ),
                        ),
                        if (item.isModelPrediction)
                          Tooltip(
                            message: 'ML model forecast',
                            child: Icon(Icons.auto_awesome_rounded,
                                size: 14, color: AgriColors.meadowGreen),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.yieldStr,
                      style: TextStyle(fontSize: 13, color: onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.areaStr} planted · ${item.productionStr} production',
                      style: TextStyle(fontSize: 11, color: onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item.trendStr,
                      style: TextStyle(fontWeight: FontWeight.bold, color: badgeText),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Tap for details',
                      style: TextStyle(fontSize: 10, color: onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color  = _color;

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
          height: MediaQuery.sizeOf(ctx).height * 0.88,
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

                // Header gradient
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.crop,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 22,
                              fontWeight: FontWeight.w800)),
                      Text('${item.region} Region — ${item.year}',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 14)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _HeaderChip(
                              label: item.trendStr,
                              icon: item.isPositive
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded),
                          const SizedBox(width: 10),
                          _HeaderChip(
                              label: item.isModelPrediction
                                  ? 'ML Forecast'
                                  : 'Historical',
                              icon: item.isModelPrediction
                                  ? Icons.auto_awesome_rounded
                                  : Icons.history_rounded),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Key stats
                Text('Season Stats', style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 12),
                _StatRow(Icons.grass_rounded, 'Expected Yield',
                    item.yieldStr, AgriColors.forestGreen),
                _StatRow(Icons.square_foot_rounded, 'Cultivated Area',
                    item.areaStr, AgriColors.wheatGold),
                _StatRow(Icons.inventory_2_outlined, 'Production',
                    item.productionStr, AgriColors.leafGreen),
                _StatRow(
                    item.isPositive
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    'Year-on-Year Trend',
                    item.trendStr,
                    item.isPositive ? AgriColors.leafGreen : AgriColors.gold),
                const SizedBox(height: 24),

                // Data source note
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AgriColors.forestGreen.withValues(
                        alpha: isDark ? 0.15 : 0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        item.isModelPrediction
                            ? Icons.auto_awesome_rounded
                            : Icons.storage_rounded,
                        color: AgriColors.forestGreen, size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.isModelPrediction
                                  ? 'ML Model Prediction'
                                  : 'FAOSTAT Historical Data',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.isModelPrediction
                                  ? 'Yield predicted by the trained RandomForest model '
                                    '(R² = 0.97). Continuously improves as farmers '
                                    'submit daily diary entries and harvest actuals.'
                                  : 'Data sourced from FAOSTAT Ghana national statistics '
                                    '(2012–2024). Adjusted by regional area share coefficient.',
                              style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: Theme.of(ctx).colorScheme.onSurface),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Reusable widgets ───────────────────────────────────────────────────────────

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.icon, this.label, this.value, this.color);
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13)),
          ),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }
}
