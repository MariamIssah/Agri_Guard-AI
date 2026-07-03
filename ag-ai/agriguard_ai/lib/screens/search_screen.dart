import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import '../utils/app_theme.dart';
import '../utils/ghana_locations.dart';
import '../utils/mock_produce_data.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  String? _regionFilter;

  List<ProduceRecord> get _results {
    var list = searchProduce(_query);
    if (_regionFilter != null && _regionFilter != 'All Regions') {
      list = list.where((r) => r.region == _regionFilter).toList();
    }
    return list;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: Text(context.t('search_title'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: context.t('search_hint'),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _query = v),
              onSubmitted: (v) {
                if (v.trim().isEmpty) return;
                context.read<BackendService>().logBuyerActivity(
                  buyerId: context.read<AuthService>().currentUser?.id ?? 'guest',
                  action: 'search',
                  screen: 'search',
                  query: v.trim(),
                  region: _regionFilter,
                );
              },
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: quickSearchCrops
                  .map(
                    (crop) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(crop),
                        onPressed: () {
                          _controller.text = crop;
                          setState(() => _query = crop);
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _regionFilter ?? 'All Regions',
              decoration: InputDecoration(
                labelText: context.t('search_filter_region'),
                prefixIcon: const Icon(Icons.map_outlined),
                isDense: true,
              ),
              items: regionFilterOptions
                  .map((r) => DropdownMenuItem(value: r, child: Text(r, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => _regionFilter = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_results.length} result(s)',
                style: TextStyle(fontSize: 13, color: onSurfaceVariant),
              ),
            ),
          ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      context.t('no_produce_results'),
                      style: TextStyle(color: onSurfaceVariant),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_query.isNotEmpty) ...[
                        Text(
                          context.t('search_by_location'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...groupByLocation(_results).map(_locationCard),
                        const SizedBox(height: 16),
                        Text(
                          context.t('search_individual_records'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      ..._results.map(_recordCard),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _locationCard(ProduceLocationSummary s) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      color: AgriColors.forestGreen.withValues(alpha: 0.04),
      child: ListTile(
        onTap: () => _showLocationDetail(context, s),
        leading: const Icon(Icons.place_rounded, color: AgriColors.forestGreen),
        title: Text(
          '${s.town}, ${s.region} Region',
          style: TextStyle(fontWeight: FontWeight.w600, color: onSurface),
        ),
        subtitle: Text(
          '${s.crop}\n'
          '${context.t('search_predicted_quantity', args: {'quantity': s.predictedQuantity})}\n'
          '${context.t('search_farmers', args: {'count': s.farmerCount.toString()})}',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right_rounded,
            color: AgriColors.forestGreen, size: 18),
      ),
    );
  }

  Widget _recordCard(ProduceRecord r) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => _showRecordDetail(context, r),
        leading: CircleAvatar(
          backgroundColor: AgriColors.leafGreen.withValues(alpha: 0.15),
          child: const Icon(Icons.grass_rounded, color: AgriColors.forestGreen),
        ),
        title: Text(
          r.crop,
          style: TextStyle(fontWeight: FontWeight.w600, color: onSurface),
        ),
        subtitle: Text(
          '${r.town}, ${r.region} · ${r.district}\n'
          '${context.t('search_farmer_label', args: {'name': r.farmer})}\n'
          '${context.t('search_qty_label', args: {'quantity': r.quantity})} · ${context.t('search_harvest_label', args: {'harvest': r.harvest})}',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              r.confidence,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AgriColors.forestGreen,
                fontSize: 12,
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AgriColors.forestGreen, size: 16),
          ],
        ),
      ),
    );
  }

  void _showLocationDetail(BuildContext context, ProduceLocationSummary s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 16, 24, MediaQuery.viewPaddingOf(ctx).bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(ctx).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.place_rounded,
                    color: AgriColors.forestGreen, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${s.town}, ${s.region} Region',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _DetailRow2(Icons.grass_rounded, 'Crop', s.crop,
                AgriColors.forestGreen),
            _DetailRow2(
                Icons.inventory_2_outlined,
                'Predicted Quantity',
                s.predictedQuantity,
                AgriColors.leafGreen),
            _DetailRow2(Icons.people_outline, 'Active Farmers',
                '${s.farmerCount}', AgriColors.sky),
          ],
        ),
      ),
    );
  }

  void _showRecordDetail(BuildContext context, ProduceRecord r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 16, 24, MediaQuery.viewPaddingOf(ctx).bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(ctx).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      AgriColors.leafGreen.withValues(alpha: 0.15),
                  child: const Icon(Icons.grass_rounded,
                      color: AgriColors.forestGreen),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.crop,
                          style: Theme.of(ctx)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      Text(
                        '${r.town}, ${r.region}',
                        style: TextStyle(
                            color: Theme.of(ctx)
                                .colorScheme
                                .onSurfaceVariant,
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AgriColors.forestGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(r.confidence,
                      style: const TextStyle(
                          color: AgriColors.forestGreen,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _DetailRow2(Icons.person_outline, 'Farmer', r.farmer,
                AgriColors.forestGreen),
            _DetailRow2(Icons.location_city_outlined, 'District', r.district,
                AgriColors.sky),
            _DetailRow2(Icons.inventory_2_outlined, 'Quantity', r.quantity,
                AgriColors.leafGreen),
            _DetailRow2(Icons.event_available_rounded, 'Harvest Period',
                r.harvest, AgriColors.wheatGold),
          ],
        ),
      ),
    );
  }
}

class _DetailRow2 extends StatelessWidget {
  const _DetailRow2(this.icon, this.label, this.value, this.color);
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant)),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

