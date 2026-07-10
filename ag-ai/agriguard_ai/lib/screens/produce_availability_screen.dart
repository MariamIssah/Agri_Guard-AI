import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import '../utils/app_theme.dart';
import '../utils/ghana_locations.dart';

// Each crop group gets a unique (background, accent) pair cycling through this list.
const _kGroupBg = [
  Color(0xFF1B4332), // forest green
  Color(0xFF1A3A5C), // navy blue
  Color(0xFF3D1A5C), // deep purple
  Color(0xFF4A2C0A), // dark amber
  Color(0xFF0D4044), // dark teal
  Color(0xFF5C1A1A), // dark red
  Color(0xFF1A1F5C), // dark indigo
  Color(0xFF2E3E1A), // dark olive
];
const _kGroupAccent = [
  Color(0xFF52B788), // mint green
  Color(0xFF64B5F6), // sky blue
  Color(0xFFCE93D8), // lavender
  Color(0xFFFFB74D), // amber
  Color(0xFF4DB6AC), // teal
  Color(0xFFEF9A9A), // rose
  Color(0xFF9FA8DA), // periwinkle
  Color(0xFFC5E1A5), // light olive
];

class ProduceAvailabilityScreen extends StatefulWidget {
  const ProduceAvailabilityScreen({super.key});

  @override
  State<ProduceAvailabilityScreen> createState() =>
      _ProduceAvailabilityScreenState();
}

class _ProduceAvailabilityScreenState
    extends State<ProduceAvailabilityScreen> {
  static const _crops = [
    'Maize', 'Rice', 'Cassava', 'Yam', 'Cocoa', 'Plantain',
    'Tomato', 'Pepper', 'Millet', 'Sorghum', 'Groundnut', 'Cowpea',
  ];

  String? _selectedCrop;
  String? _selectedRegion;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _data;

  String get _buyerId =>
      context.read<AuthService>().currentUser?.id ?? 'guest';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      context.read<BackendService>().logBuyerActivity(
        buyerId: _buyerId,
        action: 'browse',
        screen: 'produce_availability',
      );
    });
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final backend = context.read<BackendService>();
    final buyerId = _buyerId;
    try {
      final res = await backend.getHarvestActuals(
        crop: _selectedCrop,
        region: _selectedRegion,
      );
      if (mounted) setState(() => _data = res);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    backend.logBuyerActivity(
      buyerId: buyerId,
      action: 'search',
      screen: 'produce_availability',
      crop: _selectedCrop,
      region: _selectedRegion,
    );
  }

  @override
  Widget build(BuildContext context) {
    final botPad = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produce Market'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            crops: _crops,
            regions: ghanaRegionNames,
            selectedCrop: _selectedCrop,
            selectedRegion: _selectedRegion,
            onCropChanged: (v) { setState(() => _selectedCrop = v); _load(); },
            onRegionChanged: (v) { setState(() => _selectedRegion = v); _load(); },
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorView(error: _error!, onRetry: _load)
                    : _data == null
                        ? const _EmptyView()
                        : _MarketView(
                            data: _data!,
                            buyerId: _buyerId,
                            bottomPad: botPad,
                          ),
          ),
        ],
      ),
    );
  }
}

// ── Filter bar ─────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.crops,
    required this.regions,
    required this.selectedCrop,
    required this.selectedRegion,
    required this.onCropChanged,
    required this.onRegionChanged,
  });

  final List<String> crops;
  final List<String> regions;
  final String? selectedCrop;
  final String? selectedRegion;
  final ValueChanged<String?> onCropChanged;
  final ValueChanged<String?> onRegionChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: AgriColors.forestGreen,
      child: Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            value: selectedCrop,
            isDense: true,
            dropdownColor: AgriColors.forestGreen,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            iconEnabledColor: Colors.white70,
            decoration: InputDecoration(
              labelText: 'Crop',
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white30),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white70),
              ),
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('All crops', style: TextStyle(color: Colors.white70)),
              ),
              ...crops.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white)),
                  )),
            ],
            onChanged: onCropChanged,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            value: selectedRegion,
            isDense: true,
            dropdownColor: AgriColors.forestGreen,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            iconEnabledColor: Colors.white70,
            decoration: InputDecoration(
              labelText: 'Region',
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white30),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white70),
              ),
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('All regions', style: TextStyle(color: Colors.white70)),
              ),
              ...regions.map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(r, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white)),
                  )),
            ],
            onChanged: onRegionChanged,
          ),
        ),
      ]),
    );
  }
}

// ── Market view ────────────────────────────────────────────────────────────────

class _MarketView extends StatelessWidget {
  const _MarketView({
    required this.data,
    required this.buyerId,
    required this.bottomPad,
  });

  final Map<String, dynamic> data;
  final String buyerId;
  final double bottomPad;

  @override
  Widget build(BuildContext context) {
    final summary = (data['summary'] as Map<String, dynamic>?) ?? {};
    final entries = (data['entries'] ?? data['predictions']) as List<dynamic>? ?? [];
    final query   = (data['query']   as Map<String, dynamic>?) ?? {};

    final total     = (summary['total_entries'] ?? entries.length) as int? ?? entries.length;
    final avgYield  = (summary['average_yield_kg_per_ha'] ?? 0) as num;
    final totalQty  = (summary['total_quantity_kg'] ?? 0) as num;
    final minPrice  = summary['min_price_ghs'] as num?;
    final maxPrice  = summary['max_price_ghs'] as num?;

    final cropLabel   = query['crop']?.toString()   ?? 'All Crops';
    final regionLabel = query['region']?.toString() ?? 'All Regions';

    // Group entries by crop name
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final raw in entries) {
      final e = Map<String, dynamic>.from(raw as Map);
      final crop = (e['crop']?.toString() ?? 'Unknown').trim();
      grouped.putIfAbsent(crop, () => []).add(e);
    }
    // Sort groups by total quantity available (highest first)
    final sortedGroups = grouped.entries.toList()
      ..sort((a, b) {
        final aQty = a.value.fold<double>(0,
            (s, e) => s + ((e['quantity_available_kg'] as num?)?.toDouble() ?? 0));
        final bQty = b.value.fold<double>(0,
            (s, e) => s + ((e['quantity_available_kg'] as num?)?.toDouble() ?? 0));
        return bQty.compareTo(aQty);
      });

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad + 16),
      children: [
        // ── Aggregated overview card ─────────────────────────────────────
        _MarketOverviewCard(
          cropLabel:    cropLabel,
          regionLabel:  regionLabel,
          totalFarms:   total,
          totalQtyKg:   totalQty.toDouble(),
          avgYieldKgHa: avgYield.toDouble(),
          minPrice:     minPrice?.toDouble(),
          maxPrice:     maxPrice?.toDouble(),
        ),

        const SizedBox(height: 20),

        if (entries.isEmpty)
          _noData(context)
        else ...[
          // ── Section heading ────────────────────────────────────────────
          Row(children: [
            const Icon(Icons.storefront_rounded,
                size: 18, color: AgriColors.mintGreen),
            const SizedBox(width: 6),
            Text(
              '${sortedGroups.length} Crop${sortedGroups.length == 1 ? '' : 's'} · $total Farmer${total == 1 ? '' : 's'}',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
          ]),
          const SizedBox(height: 10),

          // ── One grouped card per crop ──────────────────────────────────
          for (var i = 0; i < sortedGroups.length; i++)
            _CropGroupCard(
              crop: sortedGroups[i].key,
              entries: sortedGroups[i].value,
              buyerId: buyerId,
              colorIndex: i,
            ),
        ],
      ],
    );
  }

  Widget _noData(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined,
                size: 60, color: AgriColors.mintGreen),
            const SizedBox(height: 16),
            Text('No produce listed yet.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Farmers haven\'t submitted harvest reports\nfor this selection yet.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

// ── Market overview card ───────────────────────────────────────────────────────

class _MarketOverviewCard extends StatelessWidget {
  const _MarketOverviewCard({
    required this.cropLabel,
    required this.regionLabel,
    required this.totalFarms,
    required this.totalQtyKg,
    required this.avgYieldKgHa,
    this.minPrice,
    this.maxPrice,
  });

  final String cropLabel;
  final String regionLabel;
  final int totalFarms;
  final double totalQtyKg;
  final double avgYieldKgHa;
  final double? minPrice;
  final double? maxPrice;

  String get _qtyLabel {
    if (totalQtyKg <= 0) return 'N/A';
    return totalQtyKg >= 1000
        ? '${(totalQtyKg / 1000).toStringAsFixed(1)} t'
        : '${totalQtyKg.toStringAsFixed(0)} kg';
  }

  String get _priceLabel {
    if (minPrice == null) return 'N/A';
    if (minPrice == maxPrice) return 'GH₵ ${minPrice!.toStringAsFixed(2)}/kg';
    return 'GH₵ ${minPrice!.toStringAsFixed(2)} – ${maxPrice!.toStringAsFixed(2)}/kg';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AgriColors.deepGreen, AgriColors.forestGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // heading
          Row(children: [
            const Icon(Icons.bar_chart_rounded,
                color: AgriColors.mintGreen, size: 18),
            const SizedBox(width: 6),
            const Text('Market Overview',
                style: TextStyle(
                    color: AgriColors.mintGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
          ]),
          const SizedBox(height: 6),
          Text(cropLabel,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          Text(regionLabel,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),

          // 4 stat boxes in 2×2 grid
          Row(children: [
            Expanded(
              child: _StatBox(
                icon: Icons.people_outline_rounded,
                label: 'Farmers',
                value: '$totalFarms',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatBox(
                icon: Icons.inventory_2_outlined,
                label: 'Total Supply',
                value: _qtyLabel,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _StatBox(
                icon: Icons.trending_up_rounded,
                label: 'Avg Yield',
                value: avgYieldKgHa > 0
                    ? '${avgYieldKgHa.toStringAsFixed(0)} kg/ha'
                    : 'N/A',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatBox(
                icon: Icons.attach_money_rounded,
                label: 'Price Range',
                value: _priceLabel,
                small: minPrice != null && minPrice != maxPrice,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
    this.small = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(children: [
        Icon(icon, color: AgriColors.mintGreen, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.white60, fontSize: 10)),
              Text(value,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: small ? 10 : 13,
                      fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Crop group card (one per crop, expands to show individual farmers) ─────────

class _CropGroupCard extends StatefulWidget {
  const _CropGroupCard({
    required this.crop,
    required this.entries,
    required this.buyerId,
    required this.colorIndex,
  });
  final String crop;
  final List<Map<String, dynamic>> entries;
  final String buyerId;
  final int colorIndex;

  @override
  State<_CropGroupCard> createState() => _CropGroupCardState();
}

class _CropGroupCardState extends State<_CropGroupCard> {
  static const _pageSize = 6;

  bool _expanded = false;
  int _showCount = _pageSize;

  // Cached aggregates — computed once, not on every build
  late final Color _bg;
  late final Color _accent;
  late final Color _farmerBg;
  late final String _qtyLabel;
  late final String? _priceLabel;
  late final LinearGradient _gradient;

  @override
  void initState() {
    super.initState();
    final idx = widget.colorIndex;
    _bg = _kGroupBg[idx % _kGroupBg.length];
    _accent = _kGroupAccent[idx % _kGroupAccent.length];
    _farmerBg = Color.lerp(_bg, Colors.black, 0.30)!;
    _gradient = LinearGradient(
      colors: [_bg, Color.lerp(_bg, _accent, 0.14)!],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    double qty = 0;
    double? minP, maxP;
    for (final e in widget.entries) {
      qty += (e['quantity_available_kg'] as num?)?.toDouble() ?? 0;
      final p = (e['price_per_kg_ghs'] as num?)?.toDouble();
      if (p != null) {
        minP = minP == null ? p : (p < minP ? p : minP);
        maxP = maxP == null ? p : (p > maxP ? p : maxP);
      }
    }
    _qtyLabel = qty <= 0
        ? 'qty unknown'
        : qty >= 1000
            ? '${(qty / 1000).toStringAsFixed(1)} t available'
            : '${qty.toStringAsFixed(0)} kg available';
    _priceLabel = minP == null
        ? null
        : minP == maxP
            ? 'GH₵ ${minP.toStringAsFixed(2)}/kg'
            : 'GH₵ ${minP.toStringAsFixed(2)} – ${maxP?.toStringAsFixed(2)}/kg';
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    final farmerCount = entries.length;
    final visible = entries.take(_showCount).toList();
    final hasMore = farmerCount > _showCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: _gradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _expanded ? _accent.withValues(alpha: 0.6) : Colors.white12,
          width: _expanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _bg.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header (always visible) ─────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() {
              _expanded = !_expanded;
              if (!_expanded) _showCount = _pageSize; // reset page on collapse
            }),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                        color: _accent.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Icon(Icons.grass_rounded, color: _accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.crop,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17)),
                      const SizedBox(height: 2),
                      Text(
                        '$farmerCount farmer${farmerCount == 1 ? '' : 's'} · $_qtyLabel',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_priceLabel != null)
                      Text(_priceLabel!,
                          style: TextStyle(
                              color: _accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _accent.withValues(alpha: 0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                          _expanded ? 'Hide' : 'View farmers',
                          style: TextStyle(
                              color: _accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: _accent,
                          size: 14,
                        ),
                      ]),
                    ),
                  ],
                ),
              ]),
            ),
          ),

          // ── Expanded: paginated farmer cards ────────────────────────────
          if (_expanded) ...[
            Divider(color: _accent.withValues(alpha: 0.25), height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Only build `visible` (≤ _showCount) cards at a time
                  for (final item in visible) ...[
                    _FarmerCard(
                      item: item,
                      pred: (item['prediction'] as Map<String, dynamic>?) ?? item,
                      buyerId: widget.buyerId,
                      cardColor: _farmerBg,
                      accentColor: _accent,
                    ),
                  ],
                  // "Show more" button — loads next page lazily
                  if (hasMore)
                    TextButton.icon(
                      onPressed: () => setState(
                          () => _showCount = (_showCount + _pageSize)
                              .clamp(0, farmerCount)),
                      icon: Icon(Icons.expand_more_rounded,
                          color: _accent, size: 18),
                      label: Text(
                        'Show more (${farmerCount - _showCount} remaining)',
                        style: TextStyle(color: _accent, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Individual farmer card ─────────────────────────────────────────────────────

class _FarmerCard extends StatefulWidget {
  const _FarmerCard({
    required this.item,
    required this.pred,
    required this.buyerId,
    this.cardColor,
    this.accentColor,
  });

  final Map<String, dynamic> item;
  final Map<String, dynamic> pred;
  final String buyerId;
  final Color? cardColor;
  final Color? accentColor;

  @override
  State<_FarmerCard> createState() => _FarmerCardState();
}

class _FarmerCardState extends State<_FarmerCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final item     = widget.item;
    final pred     = widget.pred;
    final buyerId  = widget.buyerId;
    final bg       = widget.cardColor ?? AgriColors.forestGreen;
    final accent   = widget.accentColor ?? AgriColors.mintGreen;

    final crop      = (item['crop']     ?? '').toString();
    final region    = (item['region']   ?? '').toString();
    final district  = (item['district'] ?? '').toString();
    final town      = (item['town']     ?? '').toString();
    final phone     = (item['phone']    ?? '').toString();
    final qtyKg     = (item['quantity_available_kg'] as num?)?.toDouble();
    final priceGhs  = (item['price_per_kg_ghs']      as num?)?.toDouble();
    final yieldKgHa = ((pred['predicted_yield_kg_per_ha'] ??
                        pred['adjusted_yield_kg_per_ha'] ?? 0) as num)
        .toDouble();
    final quality   = pred['quality_score'] as num?;
    final notes     = (item['notes'] ?? pred['notes'] ?? '').toString();
    final area      = ((item['area_hectares'] ??
                        pred['area_hectares'] ?? 0) as num)
        .toDouble();
    final submittedAt = (item['submitted_at'] ?? '').toString();
    final dateStr = submittedAt.length >= 10 ? submittedAt.substring(0, 10) : '';

    final location = [
      if (town.isNotEmpty) town,
      if (district.isNotEmpty) district,
      if (region.isNotEmpty) region,
    ].take(2).join(', ');

    return GestureDetector(
      onTap: () {
        setState(() => _expanded = !_expanded);
        context.read<BackendService>().logBuyerActivity(
          buyerId: buyerId,
          action: 'select',
          screen: 'produce_availability',
          crop: crop,
          region: region,
          district: district.isNotEmpty ? district : null,
          itemId: submittedAt,
          details: {'quantity_kg': qtyKg, 'price_ghs': priceGhs},
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _expanded
                ? accent.withValues(alpha: 0.5)
                : Colors.white12,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Coloured left accent bar
                Container(width: 5, color: accent),
                // Card content
                Expanded(
                  child: Container(
                    color: bg,
                    padding: const EdgeInsets.all(14),
                    child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person_outline_rounded,
                    color: accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(location.isEmpty ? region : location,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    Text(region,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11)),
                  ],
                ),
              ),
              if (quality != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AgriColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AgriColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star_rounded, color: AgriColors.gold, size: 12),
                    const SizedBox(width: 3),
                    Text(quality.toStringAsFixed(1),
                        style: const TextStyle(
                            color: AgriColors.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              const SizedBox(width: 8),
              Icon(
                _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: Colors.white54, size: 20,
              ),
            ]),

            const SizedBox(height: 10),
            Divider(color: accent.withValues(alpha: 0.2), height: 1),
            const SizedBox(height: 8),

            // ── Data tags (always visible) ─────────────────────────────
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (qtyKg != null && qtyKg > 0)
                _Tag(
                  icon: Icons.inventory_2_outlined,
                  label: qtyKg >= 1000
                      ? '${(qtyKg / 1000).toStringAsFixed(1)} t available'
                      : '${qtyKg.toStringAsFixed(0)} kg available',
                  color: accent,
                ),
              if (priceGhs != null)
                _Tag(
                  icon: Icons.attach_money_rounded,
                  label: 'GH₵ ${priceGhs.toStringAsFixed(2)}/kg',
                  color: AgriColors.gold,
                ),
              if (yieldKgHa > 0)
                _Tag(
                  icon: Icons.trending_up_rounded,
                  label: '${yieldKgHa.toStringAsFixed(0)} kg/ha',
                  color: accent,
                ),
              if (area > 0)
                _Tag(
                  icon: Icons.square_foot_rounded,
                  label: '${area.toStringAsFixed(1)} ha',
                  color: accent,
                ),
            ]),

            // ── Expanded details ───────────────────────────────────────
            if (_expanded) ...[
              const SizedBox(height: 10),
              Divider(color: accent.withValues(alpha: 0.2), height: 1),
              const SizedBox(height: 8),

              // Full location
              if (town.isNotEmpty || district.isNotEmpty) ...[
                _DetailRow(icon: Icons.location_on_outlined, label: 'Location',
                    value: [town, district, region].where((s) => s.isNotEmpty).join(', ')),
                const SizedBox(height: 8),
              ],

              // Phone
              if (phone.isNotEmpty) ...[
                _DetailRow(icon: Icons.phone_outlined, label: 'Contact', value: phone,
                    valueColor: AgriColors.mintGreen),
                const SizedBox(height: 8),
              ],

              // Date
              if (dateStr.isNotEmpty) ...[
                _DetailRow(icon: Icons.calendar_today_outlined, label: 'Submitted', value: dateStr),
                const SizedBox(height: 8),
              ],

              // Notes
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.notes_rounded, size: 14, color: Colors.white54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(notes,
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
                ]),
              ],
            ] else ...[
              // Collapsed hint
              if (phone.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Tap for contact & full details',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11)),
              ],
            ],
                  ],  // Column children
                ),    // Column
              ),      // inner Container
            ),        // Expanded
          ],          // Row children
        ),            // Row
      ),              // IntrinsicHeight
    ),                // ClipRRect
  ),                  // outer Container
);                    // GestureDetector — ends return statement
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: Colors.white54),
      const SizedBox(width: 8),
      Text('$label: ', style: const TextStyle(color: Colors.white54, fontSize: 12)),
      Expanded(
        child: Text(value,
            style: TextStyle(color: valueColor, fontSize: 12, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label, this.color = AgriColors.mintGreen});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Error / empty states ───────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded,
                size: 56, color: AgriColors.danger),
            const SizedBox(height: 16),
            Text('Could not load market data.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(error,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 5,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ]),
        ),
      );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.storefront_outlined, size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('Select a crop or region to see\navailable produce.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14),
              textAlign: TextAlign.center),
        ]),
      );
}
