import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/backend_service.dart';
import '../services/user_session.dart';
import '../utils/app_theme.dart';
import '../utils/ghana_locations.dart';
import 'my_submissions_screen.dart';

class PredictionScreen extends StatelessWidget {
  const PredictionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final role = context.watch<UserSession>().role;
    final backend = context.read<BackendService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabColor = isDark ? AgriColors.mintGreen : AgriColors.forestGreen;

    // Buyers see market forecast only
    if (role == UserRole.buyer) {
      return Scaffold(
        appBar: AppBar(title: const Text('Market Forecast')),
        body: _BuyerForecastTab(backend: backend),
      );
    }

    // Farmers: Yield Forecast (pre-harvest) + Report Harvest (post-harvest actual)
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Produce Prediction'),
          bottom: TabBar(
            labelColor: tabColor,
            unselectedLabelColor:
                Theme.of(context).colorScheme.onSurfaceVariant,
            indicatorColor: tabColor,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Yield Forecast'),
              Tab(text: 'Report Harvest'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _FarmerPreHarvestTab(backend: backend),
            _FarmerPostHarvestTab(backend: backend),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Farmer: Pre-harvest yield forecast â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _FarmerPreHarvestTab extends StatefulWidget {
  const _FarmerPreHarvestTab({required this.backend});
  final BackendService backend;

  @override
  State<_FarmerPreHarvestTab> createState() => _FarmerPreHarvestTabState();
}

class _FarmerPreHarvestTabState extends State<_FarmerPreHarvestTab> {
  final _formKey = GlobalKey<FormState>();
  final _cropCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  String? _region;
  String? _district;
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void dispose() {
    _cropCtrl.dispose();
    _areaCtrl.dispose();
    super.dispose();
  }

  Future<void> _predict() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final user = context.read<AuthService>().currentUser;
      final res = await widget.backend.predictPreHarvest({
        'farmer_id': user?.id ?? 'guest',
        'crop': _cropCtrl.text.trim(),
        'region': _region!,
        'area_hectares': double.parse(_areaCtrl.text.trim()),
        if (_district != null) 'district': _district,
        'year': DateTime.now().year,
      });
      setState(() => _result = res);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final districts =
        _region != null ? GhanaLocations.districtsFor(_region!) : <String>[];
    final botPad = MediaQuery.viewPaddingOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, botPad + 20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              icon: Icons.schedule_rounded,
              title: 'Yield Forecast',
              subtitle:
                  'Enter your crop details to predict how much you will harvest this season.',
              color: AgriColors.forestGreen,
            ),
            const SizedBox(height: 24),

            TextFormField(
              controller: _cropCtrl,
              decoration: const InputDecoration(
                labelText: 'Crop type',
                prefixIcon: Icon(Icons.grass_rounded),
                hintText: 'e.g. Maize, Rice, Cassava',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter crop type' : null,
            ),
            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              isExpanded: true,
              // ignore: deprecated_member_use
              value: _region,
              decoration: const InputDecoration(
                labelText: 'Region',
                prefixIcon: Icon(Icons.map_outlined),
              ),
              items: GhanaLocations.regions
                  .map((r) => DropdownMenuItem(value: r, child: Text(r, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() {
                _region = v;
                _district = null;
              }),
              validator: (v) => v == null ? 'Select a region' : null,
            ),
            const SizedBox(height: 14),

            if (districts.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                isExpanded: true,
                // ignore: deprecated_member_use
                value: _district,
                decoration: const InputDecoration(
                  labelText: 'District (optional)',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
                items: districts
                    .map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setState(() => _district = v),
              ),
              const SizedBox(height: 14),
            ],

            TextFormField(
              controller: _areaCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Farm area (hectares)',
                prefixIcon: Icon(Icons.square_foot_rounded),
                suffixText: 'ha',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter farm area';
                if (double.tryParse(v.trim()) == null) return 'Invalid number';
                return null;
              },
            ),
            const SizedBox(height: 24),

            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _predict,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.analytics_rounded),
                label: Text(_loading ? 'Predicting…' : 'Get Yield Forecast'),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              _ErrorCard(message: _error!),
            ],

            if (_result != null) ...[
              const SizedBox(height: 24),
              _PreHarvestResult(data: _result!),
            ],
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Farmer: Post-harvest actual submission â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _FarmerPostHarvestTab extends StatefulWidget {
  const _FarmerPostHarvestTab({required this.backend});
  final BackendService backend;

  @override
  State<_FarmerPostHarvestTab> createState() => _FarmerPostHarvestTabState();
}

class _FarmerPostHarvestTabState extends State<_FarmerPostHarvestTab> {
  final _formKey = GlobalKey<FormState>();
  final _cropCtrl       = TextEditingController();
  final _areaCtrl       = TextEditingController();
  final _actualKgCtrl   = TextEditingController();
  final _phoneCtrl      = TextEditingController();
  final _townCtrl       = TextEditingController();
  final _qtyForSaleCtrl = TextEditingController();
  final _priceCtrl      = TextEditingController();
  final _qualityCtrl    = TextEditingController();
  final _notesCtrl      = TextEditingController();
  String? _region;
  String? _district;
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _cropCtrl, _areaCtrl, _actualKgCtrl, _phoneCtrl,
      _townCtrl, _qtyForSaleCtrl, _priceCtrl, _qualityCtrl, _notesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final user = context.read<AuthService>().currentUser;
      final actualKg = double.parse(_actualKgCtrl.text.trim());
      final res = await widget.backend.submitPostHarvest({
        'farmer_id':      user?.id ?? 'guest',
        'crop':           _cropCtrl.text.trim(),
        'region':         _region!,
        'area_hectares':  double.parse(_areaCtrl.text.trim()),
        'actual_yield_kg': actualKg,
        if (_district != null) 'district': _district,
        if (_phoneCtrl.text.trim().isNotEmpty)
          'phone': _phoneCtrl.text.trim(),
        if (_townCtrl.text.trim().isNotEmpty)
          'town': _townCtrl.text.trim(),
        'quantity_available_kg': _qtyForSaleCtrl.text.trim().isNotEmpty
            ? double.tryParse(_qtyForSaleCtrl.text.trim()) ?? actualKg
            : actualKg,
        if (_priceCtrl.text.trim().isNotEmpty)
          'price_per_kg_ghs': double.tryParse(_priceCtrl.text.trim()),
        if (_qualityCtrl.text.trim().isNotEmpty)
          'quality_score': double.tryParse(_qualityCtrl.text.trim()),
        if (_notesCtrl.text.trim().isNotEmpty)
          'notes': _notesCtrl.text.trim(),
        'year': DateTime.now().year,
      });
      setState(() => _result = res);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final districts =
        _region != null ? GhanaLocations.districtsFor(_region!) : <String>[];
    final botPad = MediaQuery.viewPaddingOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, botPad + 20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              icon: Icons.check_circle_outline_rounded,
              title: 'Report Your Harvest',
              subtitle:
                  'Submit your actual yield so buyers can find and contact you.',
              color: AgriColors.gold,
            ),
            const SizedBox(height: 24),

            // ── Harvest details ─────────────────────────────────────────────
            Text('Harvest Details',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AgriColors.forestGreen,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),

            TextFormField(
              controller: _cropCtrl,
              decoration: const InputDecoration(
                labelText: 'Crop type',
                prefixIcon: Icon(Icons.grass_rounded),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter crop type' : null,
            ),
            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _region,
              decoration: const InputDecoration(
                labelText: 'Region',
                prefixIcon: Icon(Icons.map_outlined),
              ),
              items: GhanaLocations.regions
                  .map((r) => DropdownMenuItem(value: r, child: Text(r, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() { _region = v; _district = null; }),
              validator: (v) => v == null ? 'Select a region' : null,
            ),
            const SizedBox(height: 14),

            if (districts.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _district,
                decoration: const InputDecoration(
                  labelText: 'District (optional)',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
                items: districts
                    .map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setState(() => _district = v),
              ),
              const SizedBox(height: 14),
            ],

            TextFormField(
              controller: _townCtrl,
              decoration: const InputDecoration(
                labelText: 'Town / Community (optional)',
                prefixIcon: Icon(Icons.place_outlined),
                hintText: 'e.g. Ejisu, Kintampo',
              ),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _areaCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Harvested area (ha)',
                prefixIcon: Icon(Icons.square_foot_rounded),
                suffixText: 'ha',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter farm area';
                if (double.tryParse(v.trim()) == null) return 'Invalid number';
                return null;
              },
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _actualKgCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Total harvest weight (kg)',
                prefixIcon: Icon(Icons.scale_rounded),
                suffixText: 'kg',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter actual yield';
                if (double.tryParse(v.trim()) == null) return 'Invalid number';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ── Buyer contact info ──────────────────────────────────────────
            Text('For Buyers',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AgriColors.forestGreen,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('This information will be visible to buyers sourcing produce.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),

            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                prefixIcon: Icon(Icons.phone_outlined),
                hintText: '024 XXX XXXX',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your phone number' : null,
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _qtyForSaleCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Quantity available for sale (kg)',
                prefixIcon: Icon(Icons.inventory_2_outlined),
                suffixText: 'kg',
                hintText: 'Leave blank to use full harvest weight',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (double.tryParse(v.trim()) == null) return 'Invalid number';
                return null;
              },
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Price per kg (GHS, optional)',
                prefixIcon: Icon(Icons.attach_money_rounded),
                suffixText: 'GHS/kg',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (double.tryParse(v.trim()) == null) return 'Invalid number';
                return null;
              },
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _qualityCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Quality score (1–10, optional)',
                prefixIcon: Icon(Icons.star_outline_rounded),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = double.tryParse(v.trim());
                if (n == null || n < 1 || n > 10) return 'Enter 1–10';
                return null;
              },
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Additional notes (optional)',
                prefixIcon: Icon(Icons.notes_rounded),
                hintText: 'e.g. Delivery available, organic farming',
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.upload_rounded),
                label:
                    Text(_loading ? 'Submitting…' : 'Submit Harvest Report'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AgriColors.gold,
                    foregroundColor: Colors.white),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              _ErrorCard(message: _error!),
            ],

            if (_result != null) ...[
              const SizedBox(height: 24),
              _PostHarvestResult(data: _result!),
            ],

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MySubmissionsScreen()),
              ),
              icon: const Icon(Icons.history_rounded),
              label: const Text('View my past submissions'),
            ),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Buyer: Market forecast â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _BuyerForecastTab extends StatefulWidget {
  const _BuyerForecastTab({required this.backend});
  final BackendService backend;

  @override
  State<_BuyerForecastTab> createState() => _BuyerForecastTabState();
}

class _BuyerForecastTabState extends State<_BuyerForecastTab> {
  static const _crops = [
    'Maize', 'Rice', 'Cassava', 'Yam', 'Cocoa', 'Plantain',
    'Tomato', 'Pepper', 'Millet', 'Sorghum', 'Groundnut',
    'Cowpea', 'Soybean', 'Sweet Potato', 'Watermelon',
  ];

  String? _crop;
  String? _region;
  String? _district;
  final _yearCtrl = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void dispose() {
    _yearCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_crop == null && _region == null && _district == null) {
      setState(
          () => _error = 'Select at least one filter (crop or region).');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final year = int.tryParse(_yearCtrl.text.trim());
      final res = await widget.backend.buyerPredict({
        'crop': ?_crop,
        'region': ?_region,
        'district': ?_district,
        'year': ?year,
      });
      setState(() => _result = res);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final districts =
        _region != null ? GhanaLocations.districtsFor(_region!) : <String>[];
    final botPad = MediaQuery.viewPaddingOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, botPad + 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            icon: Icons.storefront_rounded,
            title: 'Market Forecast',
            subtitle:
                'Search predicted crop supply by crop, region, or district to plan your sourcing.',
            color: AgriColors.sky,
          ),
          const SizedBox(height: 24),

          DropdownButtonFormField<String>(
            isExpanded: true,
            // ignore: deprecated_member_use
            value: _crop,
            decoration: const InputDecoration(
              labelText: 'Crop (optional)',
              prefixIcon: Icon(Icons.grass_rounded),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Any crop')),
              ..._crops.map(
                  (c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (v) => setState(() => _crop = v),
          ),
          const SizedBox(height: 14),

          DropdownButtonFormField<String>(
            isExpanded: true,
            // ignore: deprecated_member_use
            value: _region,
            decoration: const InputDecoration(
              labelText: 'Region (optional)',
              prefixIcon: Icon(Icons.map_outlined),
            ),
            items: [
              const DropdownMenuItem(
                  value: null, child: Text('All regions')),
              ...GhanaLocations.regions
                  .map((r) => DropdownMenuItem(value: r, child: Text(r, overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (v) => setState(() {
              _region = v;
              _district = null;
            }),
          ),
          const SizedBox(height: 14),

          if (districts.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              isExpanded: true,
              // ignore: deprecated_member_use
              value: _district,
              decoration: const InputDecoration(
                labelText: 'District (optional)',
                prefixIcon: Icon(Icons.location_city_outlined),
              ),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('All districts')),
                ...districts.map(
                    (d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) => setState(() => _district = v),
            ),
            const SizedBox(height: 14),
          ],

          TextFormField(
            controller: _yearCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Year (optional, default ${DateTime.now().year})',
              prefixIcon: const Icon(Icons.calendar_today_rounded),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _search,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search_rounded),
              label:
                  Text(_loading ? 'Searching…' : 'Search Supply Forecast'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AgriColors.sky,
                  foregroundColor: Colors.white),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            _ErrorCard(message: _error!),
          ],

          if (_result != null) ...[
            const SizedBox(height: 24),
            _BuyerResult(data: _result!),
          ],
        ],
      ),
    );
  }
}

// â”€â”€ Result widgets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _PreHarvestResult extends StatelessWidget {
  const _PreHarvestResult({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final pred = data['prediction'] as Map<String, dynamic>? ?? {};
    final disease = pred['disease_assessment'] as Map<String, dynamic>? ?? {};
    final yieldKgHa = pred['predicted_yield_kg_per_ha'] ?? 0;
    final adjustedYield = pred['adjusted_yield_kg_per_ha'] ?? yieldKgHa;
    final productionT = pred['predicted_production_tonnes'] ?? 0;
    final ciLo = pred['confidence_interval_lower'] ?? 0;
    final ciHi = pred['confidence_interval_upper'] ?? 0;
    final r2 = pred['model_r2_score'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResultHeader(
          icon: Icons.eco_rounded,
          label: pred['crop']?.toString() ?? '—',
          sublabel:
              '${pred['region'] ?? '—'}${pred['district'] != null ? ' · ${pred['district']}' : ''}',
          gradient: Theme.of(context).brightness == Brightness.dark
              ? darkHeaderGradient
              : lightHeaderGradient,
        ),
        const SizedBox(height: 16),
        _MetricGrid(items: [
          _Metric(
              'Predicted Yield',
              '${(adjustedYield as num).toStringAsFixed(0)} kg/ha',
              Icons.trending_up_rounded,
              AgriColors.forestGreen),
          _Metric(
              'Est. Production',
              '${(productionT as num).toStringAsFixed(2)} t',
              Icons.inventory_2_outlined,
              AgriColors.leafGreen),
          _Metric(
              'Model R²',
              '${((r2 as num) * 100).toStringAsFixed(1)}%',
              Icons.verified_outlined,
              AgriColors.gold),
          _Metric(
              'Disease Risk',
              '${(((disease['risk'] ?? 0) as num) * 100).toStringAsFixed(0)}%',
              Icons.healing_rounded,
              AgriColors.danger),
        ]),
        const SizedBox(height: 12),
        _InfoCard(
          title: 'Confidence Interval',
          child: Text(
            '${(ciLo as num).toStringAsFixed(0)} – ${(ciHi as num).toStringAsFixed(0)} kg/ha',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _PostHarvestResult extends StatelessWidget {
  const _PostHarvestResult({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final record = data['record'] as Map<String, dynamic>? ?? {};
    final cmp = data['model_comparison'] as Map<String, dynamic>?;
    final yieldKgHa = record['actual_yield_kg_per_ha'] ?? 0;
    final productionT = record['actual_production_tonnes'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AgriColors.forestGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AgriColors.forestGreen.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AgriColors.forestGreen, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Harvest data submitted successfully. Thank you!',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _MetricGrid(items: [
          _Metric(
              'Actual Yield',
              '${(yieldKgHa as num).toStringAsFixed(0)} kg/ha',
              Icons.trending_up_rounded,
              AgriColors.forestGreen),
          _Metric(
              'Total Produce',
              '${(productionT as num).toStringAsFixed(2)} t',
              Icons.inventory_2_outlined,
              AgriColors.gold),
        ]),
        if (cmp != null) ...[
          const SizedBox(height: 12),
          _InfoCard(
            title: 'vs. Model Prediction',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Model predicted: ${cmp['model_predicted_yield_kg_per_ha']} kg/ha'),
                Text(
                    'Actual:         ${cmp['actual_yield_kg_per_ha']} kg/ha'),
                if (cmp['deviation_pct'] != null)
                  Text(
                    'Deviation: ${(cmp['deviation_pct'] as num) > 0 ? '+' : ''}${cmp['deviation_pct']}%',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: (cmp['deviation_pct'] as num).abs() < 15
                          ? AgriColors.forestGreen
                          : AgriColors.danger,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BuyerResult extends StatelessWidget {
  const _BuyerResult({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    final entries = (data['entries'] ?? data['predictions']) as List<dynamic>? ?? [];
    final query = data['query'] as Map<String, dynamic>? ?? {};

    final totalEntries = summary['total_entries'] ?? entries.length;
    final totalProdT = (summary['total_predicted_production_tonnes'] ??
        summary['total_production_tonnes'] ?? 0) as num;
    final avgYield =
        (summary['average_yield_kg_per_ha'] ?? summary['avg_yield_kg_per_ha'] ?? 0) as num;
    final totalKg =
        (summary['total_predicted_yield_kg'] ?? summary['total_yield_kg'] ?? 0) as num;

    final sublabelParts = [
      if (query['region'] != null) query['region'].toString(),
      if (query['district'] != null) query['district'].toString(),
      if (query['year'] != null) query['year'].toString(),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResultHeader(
          icon: Icons.storefront_rounded,
          label: query['crop']?.toString() ?? 'All Crops',
          sublabel:
              sublabelParts.isEmpty ? 'All Ghana' : sublabelParts.join(' · '),
          gradient: const LinearGradient(
            colors: [AgriColors.sky, Color(0xFF0D47A1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        const SizedBox(height: 16),
        _MetricGrid(items: [
          _Metric('Farm Entries', '$totalEntries',
              Icons.people_outline_rounded, AgriColors.sky),
          _Metric('Avg Yield', '${avgYield.toStringAsFixed(0)} kg/ha',
              Icons.trending_up_rounded, AgriColors.forestGreen),
          _Metric('Est. Production', '${totalProdT.toStringAsFixed(1)} t',
              Icons.inventory_2_outlined, AgriColors.leafGreen),
          _Metric('Total Yield', '${(totalKg / 1000).toStringAsFixed(1)} t',
              Icons.scale_rounded, AgriColors.gold),
        ]),
        if (entries.isNotEmpty) ...[
          const SizedBox(height: 16),
          _InfoCard(
            title: 'Farm Forecasts (${entries.length})',
            child: Column(
              children: entries.take(10).toList().asMap().entries.map((e) {
                final i = e.key;
                final item = e.value as Map<String, dynamic>? ?? {};
                final pred =
                    item['prediction'] as Map<String, dynamic>? ?? item;
                final yieldVal = (pred['predicted_yield_kg_per_ha'] ??
                    pred['adjusted_yield_kg_per_ha'] ?? 0) as num;
                return Column(
                  children: [
                    if (i > 0) const Divider(height: 16, thickness: 0.5),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['crop']?.toString() ??
                                    pred['crop']?.toString() ??
                                    'Entry ${i + 1}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                              ),
                              if ((item['region'] ?? pred['region'])?.toString() case final r?)
                                Text(r, style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        Text(
                          '${yieldVal.toStringAsFixed(0)} kg/ha',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AgriColors.forestGreen,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          if (entries.length > 10)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+ ${entries.length - 10} more farms',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ],
    );
  }
}

// â”€â”€ Shared UI components â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Dark mode: solid colored bg with white text; light mode: tinted bg with colored text
    final bgStart = isDark ? color.withValues(alpha: 0.30) : color.withValues(alpha: 0.15);
    final bgEnd   = isDark ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.05);
    final borderAlpha = isDark ? 0.45 : 0.2;
    final titleColor = isDark ? Colors.white : null;
    final subtitleColor = isDark ? Colors.white70 : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bgStart, bgEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: borderAlpha)),
      ),
      child: Row(
        children: [
          Icon(icon, color: isDark ? Colors.white : color, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: titleColor)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: subtitleColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.gradient,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                Text(sublabel,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});
  final List<_Metric> items;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.4,
      children: items.map((m) => _MetricCard(metric: m)).toList(),
    );
  }
}

class _Metric {
  _Metric(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});
  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Dark: solid colored background â†’ white text for contrast
    // Light: lightly tinted background â†’ colored text
    final bgColor = isDark
        ? metric.color.withValues(alpha: 0.80)
        : metric.color.withValues(alpha: 0.08);
    final contentColor = isDark ? Colors.white : metric.color;
    final labelColor = isDark ? Colors.white70 : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: metric.color.withValues(alpha: isDark ? 0.4 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(metric.icon, color: contentColor, size: 20),
          const SizedBox(height: 6),
          Text(metric.value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: contentColor)),
          Text(metric.label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: labelColor),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AgriColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AgriColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AgriColors.danger),
          const SizedBox(width: 12),
          Expanded(
              child: Text(message,
                  style: const TextStyle(color: AgriColors.danger))),
        ],
      ),
    );
  }
}

