import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import '../utils/app_theme.dart';
import '../utils/ghana_locations.dart';

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
    try {
      final res = await context.read<BackendService>().getHarvestActuals(
        crop: _selectedCrop,
        region: _selectedRegion,
      );
      if (mounted) setState(() => _data = res);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    context.read<BackendService>().logBuyerActivity(
      buyerId: _buyerId,
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
            decoration: const InputDecoration(
              labelText: 'Crop',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            decoration: const InputDecoration(
              labelText: 'Region',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            Text('Farmers Available ($total)',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),

          // ── One card per farmer ────────────────────────────────────────
          ...entries.map((e) {
            final item = Map<String, dynamic>.from(e as Map);
            final pred = (item['prediction'] as Map<String, dynamic>?) ?? item;
            return _FarmerCard(item: item, pred: pred, buyerId: buyerId);
          }),
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
            const Text('No produce listed yet.',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'Farmers haven\'t submitted harvest reports\nfor this selection yet.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
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

// ── Individual farmer card ─────────────────────────────────────────────────────

class _FarmerCard extends StatefulWidget {
  const _FarmerCard({
    required this.item,
    required this.pred,
    required this.buyerId,
  });

  final Map<String, dynamic> item;
  final Map<String, dynamic> pred;
  final String buyerId;

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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AgriColors.forestGreen,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _expanded ? AgriColors.mintGreen.withValues(alpha: 0.5) : Colors.white12,
            width: _expanded ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AgriColors.mintGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.agriculture_rounded,
                    color: AgriColors.mintGreen, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(crop,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    Text(location.isEmpty ? region : location,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
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

            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 10),

            // ── Data tags (always visible) ─────────────────────────────
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (qtyKg != null && qtyKg > 0)
                _Tag(
                  icon: Icons.inventory_2_outlined,
                  label: qtyKg >= 1000
                      ? '${(qtyKg / 1000).toStringAsFixed(1)} t available'
                      : '${qtyKg.toStringAsFixed(0)} kg available',
                ),
              if (priceGhs != null)
                _Tag(
                  icon: Icons.attach_money_rounded,
                  label: 'GH₵ ${priceGhs.toStringAsFixed(2)}/kg',
                  highlight: true,
                ),
              if (yieldKgHa > 0)
                _Tag(
                  icon: Icons.trending_up_rounded,
                  label: '${yieldKgHa.toStringAsFixed(0)} kg/ha',
                ),
              if (area > 0)
                _Tag(
                  icon: Icons.square_foot_rounded,
                  label: '${area.toStringAsFixed(1)} ha',
                ),
            ]),

            // ── Expanded details ───────────────────────────────────────
            if (_expanded) ...[
              const SizedBox(height: 12),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 10),

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
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
              ],
            ],
          ],
        ),
      ),
    );
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
  const _Tag({required this.icon, required this.label, this.highlight = false});
  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AgriColors.gold : AgriColors.mintGreen;
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
            const Text('Could not load market data.',
                style: TextStyle(color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(error,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
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
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.storefront_outlined, size: 64, color: Colors.white38),
          SizedBox(height: 16),
          Text('Select a crop or region to see\navailable produce.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center),
        ]),
      );
}
