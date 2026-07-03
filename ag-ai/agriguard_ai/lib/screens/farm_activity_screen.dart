import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/api_key_service.dart';
import '../services/backend_service.dart';
import '../services/weather_service.dart';
import '../utils/app_theme.dart';
import '../utils/ghana_locations.dart';

class FarmActivityScreen extends StatefulWidget {
  const FarmActivityScreen({super.key});

  @override
  State<FarmActivityScreen> createState() => _FarmActivityScreenState();
}

class _FarmActivityScreenState extends State<FarmActivityScreen> {
  final _formKey = GlobalKey<FormState>();

  // Core
  String? _crop;
  String? _region;
  String? _currentStage;
  DateTime? _plantingDate;
  DateTime? _recordDate;

  // Weather
  final _tempMinCtrl  = TextEditingController();
  final _tempMaxCtrl  = TextEditingController();
  final _rainfallCtrl = TextEditingController();
  bool   _weatherLoading = false;
  String? _weatherStatus;   // shown below the weather section

  // Fertilizer
  bool   _fertApplied  = false;
  final  _fertTypeCtrl = TextEditingController();
  final  _fertKgHaCtrl = TextEditingController();

  // Pests / disease
  bool   _pestObserved     = false;
  final  _pestDescCtrl     = TextEditingController();
  bool   _diseaseObserved  = false;
  final  _diseaseDescCtrl  = TextEditingController();
  bool   _irrigationApplied = false;

  final _notesCtrl = TextEditingController();

  List<Map<String, dynamic>> _activities = [];
  bool _loadingHistory = true;
  bool _submitting = false;

  static const _stages = [
    'Land Preparation',
    'Planting',
    'Vegetative Growth',
    'Flowering',
    'Grain Filling',
    'Harvest Ready',
  ];

  static const _crops = [
    'Maize', 'Rice', 'Cassava', 'Yam', 'Tomato', 'Pepper',
    'Groundnut', 'Cocoa', 'Plantain', 'Millet', 'Sorghum',
    'Cowpea', 'Soybean', 'Sweet Potato', 'Watermelon',
  ];

  @override
  void initState() {
    super.initState();
    _recordDate = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadActivities();
      // Auto-fetch weather if the farmer already has a saved region
      final user = context.read<AuthService>().currentUser;
      if (user?.region != null) {
        _region = user!.region;
        _fetchWeather(_region!);
      }
    });
  }

  Future<void> _fetchWeather(String region) async {
    final coords = coordsForRegion(region);
    if (coords == null) return;

    final apiKeys = context.read<ApiKeyService>();
    final key = apiKeys.effectiveWeatherKey;
    if (key.isEmpty) {
      setState(() => _weatherStatus =
          'Add an OpenWeather API key in Profile → Settings to auto-fill weather.');
      return;
    }

    setState(() { _weatherLoading = true; _weatherStatus = 'Fetching weather for $region…'; });
    try {
      final weather = await WeatherService().fetchWeather(
        apiKey: key,
        latitude: coords.$1,
        longitude: coords.$2,
        locationLabel: region,
      );
      if (!mounted) return;
      // Only overwrite fields if they are still empty (don't clobber manual edits)
      if (_tempMinCtrl.text.isEmpty) {
        _tempMinCtrl.text =
            (weather.temperatureC - 4).clamp(-5, 50).toStringAsFixed(1);
      }
      if (_tempMaxCtrl.text.isEmpty) {
        _tempMaxCtrl.text = weather.temperatureC.toStringAsFixed(1);
      }
      if (_rainfallCtrl.text.isEmpty) {
        _rainfallCtrl.text =
            weather.rainfallNext24hMm.toStringAsFixed(1);
      }
      setState(() {
        _weatherLoading = false;
        _weatherStatus =
            '${weather.description} · ${weather.temperatureC.toStringAsFixed(1)}°C · ${weather.humidity}% humidity  (auto-filled)';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _weatherLoading = false;
        _weatherStatus = 'Could not fetch weather: $e';
      });
    }
  }

  @override
  void dispose() {
    for (final c in [
      _tempMinCtrl, _tempMaxCtrl, _rainfallCtrl,
      _fertTypeCtrl, _fertKgHaCtrl,
      _pestDescCtrl, _diseaseDescCtrl, _notesCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  String _prefsKey() {
    final user = context.read<AuthService>().currentUser;
    return 'farm_diary_${user?.id ?? 'guest'}';
  }

  Future<void> _loadActivities() async {
    setState(() => _loadingHistory = true);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey());
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        setState(() => _activities = list.cast<Map<String, dynamic>>());
      } catch (_) {}
    }
    setState(() => _loadingHistory = false);
  }

  Future<void> _saveActivitiesLocally() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey(), jsonEncode(_activities));
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _pickDate(bool isPlanting) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: AgriColors.forestGreen),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() { if (isPlanting) _plantingDate = picked; else _recordDate = picked; });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_crop == null || _region == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select your crop and region.'),
        backgroundColor: AgriColors.danger,
      ));
      return;
    }
    setState(() => _submitting = true);

    final user   = context.read<AuthService>().currentUser;
    final farmerId = user?.id ?? 'guest';

    final entry = {
      'farmer_id':           farmerId,
      'crop':                _crop!,
      'region':              _region!,
      'growth_stage':        _currentStage,
      'planting_date':       _plantingDate?.toIso8601String().substring(0, 10),
      'record_date':         (_recordDate ?? DateTime.now()).toIso8601String().substring(0, 10),
      'temp_min_c':          double.tryParse(_tempMinCtrl.text.trim()),
      'temp_max_c':          double.tryParse(_tempMaxCtrl.text.trim()),
      'rainfall_mm':         double.tryParse(_rainfallCtrl.text.trim()),
      'fertilizer_applied':  _fertApplied,
      'fertilizer_type':     _fertApplied ? _fertTypeCtrl.text.trim() : null,
      'fertilizer_kg_ha':    _fertApplied ? double.tryParse(_fertKgHaCtrl.text.trim()) : null,
      'pest_observed':       _pestObserved,
      'pest_description':    _pestObserved ? _pestDescCtrl.text.trim() : null,
      'disease_observed':    _diseaseObserved,
      'disease_description': _diseaseObserved ? _diseaseDescCtrl.text.trim() : null,
      'irrigation_applied':  _irrigationApplied,
      'notes':               _notesCtrl.text.trim(),
      'recorded_at':         DateTime.now().toIso8601String(),
    };

    // Save to local history immediately
    setState(() {
      _activities.insert(0, entry);
      _resetForm();
    });
    await _saveActivitiesLocally();

    // Then push to Neon in the background
    try {
      await context.read<BackendService>().submitDiaryEntry({
        'farmer_id':           entry['farmer_id'],
        'crop':                entry['crop'],
        'region':              entry['region'],
        'growth_stage':        entry['growth_stage'],
        'planting_date':       entry['planting_date'],
        'record_date':         entry['record_date'],
        'temp_min_c':          entry['temp_min_c'],
        'temp_max_c':          entry['temp_max_c'],
        'rainfall_mm':         entry['rainfall_mm'],
        'fertilizer_applied':  entry['fertilizer_applied'],
        'fertilizer_type':     entry['fertilizer_type'],
        'fertilizer_kg_ha':    entry['fertilizer_kg_ha'],
        'pest_observed':       entry['pest_observed'],
        'pest_description':    entry['pest_description'],
        'disease_observed':    entry['disease_observed'],
        'disease_description': entry['disease_description'],
        'irrigation_applied':  entry['irrigation_applied'],
        'notes':               entry['notes'],
      });
    } catch (_) {
      // Silently ignore — data is saved locally and will help local history
    }

    setState(() => _submitting = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Activity logged successfully.'),
        backgroundColor: AgriColors.forestGreen,
      ));
    }
  }

  void _resetForm() {
    _crop = null; _region = null; _currentStage = null;
    _plantingDate = null; _recordDate = DateTime.now();
    _fertApplied = false; _pestObserved = false;
    _diseaseObserved = false; _irrigationApplied = false;
    _weatherStatus = null; _weatherLoading = false;
    for (final c in [
      _tempMinCtrl, _tempMaxCtrl, _rainfallCtrl,
      _fertTypeCtrl, _fertKgHaCtrl,
      _pestDescCtrl, _diseaseDescCtrl, _notesCtrl,
    ]) { c.clear(); }
  }

  Future<void> _deleteActivity(int index) async {
    setState(() => _activities.removeAt(index));
    await _saveActivitiesLocally();
  }

  @override
  Widget build(BuildContext context) {
    final botPad = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(title: Text(context.t('farm_activity_title'))),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, botPad + 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── History ───────────────────────────────────────────────────────
            if (_loadingHistory)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(),
              ))
            else if (_activities.isNotEmpty) ...[
              Row(children: [
                const Icon(Icons.history_rounded, color: AgriColors.forestGreen),
                const SizedBox(width: 8),
                Text('My Diary (${_activities.length} entries)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),
              ..._activities.asMap().entries.map((e) => _ActivityCard(
                    activity: e.value,
                    onDelete: () => _deleteActivity(e.key),
                  )),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
            ],

            // ── Form header ───────────────────────────────────────────────────
            Row(children: [
              const Icon(Icons.add_circle_outline_rounded, color: AgriColors.leafGreen),
              const SizedBox(width: 8),
              Text('Log Today\'s Activity',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            Text('Each log entry improves in-season yield predictions.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),

            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Crop + Region
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    // ignore: deprecated_member_use
                    value: _crop,
                    decoration: const InputDecoration(
                        labelText: 'Crop *', prefixIcon: Icon(Icons.grass_rounded)),
                    items: _crops.map((c) =>
                        DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setState(() => _crop = v),
                    validator: (v) => v == null ? 'Select your crop' : null,
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    // ignore: deprecated_member_use
                    value: _region,
                    decoration: const InputDecoration(
                        labelText: 'Region *', prefixIcon: Icon(Icons.map_outlined)),
                    items: GhanaLocations.regions.map((r) =>
                        DropdownMenuItem(value: r, child: Text(r, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) {
                      setState(() { _region = v; _weatherStatus = null; });
                      if (v != null) {
                        // Clear weather fields so auto-fill kicks in fresh
                        _tempMinCtrl.clear();
                        _tempMaxCtrl.clear();
                        _rainfallCtrl.clear();
                        _fetchWeather(v);
                      }
                    },
                    validator: (v) => v == null ? 'Select your region' : null,
                  ),
                  const SizedBox(height: 14),

                  // Planting date + record date
                  _dateField(label: 'Planting Date', value: _formatDate(_plantingDate),
                      onTap: () => _pickDate(true)),
                  const SizedBox(height: 14),
                  _dateField(label: 'Today\'s Record Date *',
                      value: _formatDate(_recordDate), onTap: () => _pickDate(false)),
                  const SizedBox(height: 14),

                  // Growth stage
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    // ignore: deprecated_member_use
                    value: _currentStage,
                    decoration: InputDecoration(
                        labelText: context.t('farm_activity_crop_stage'),
                        prefixIcon: const Icon(Icons.timeline_rounded)),
                    items: _stages.map((s) =>
                        DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _currentStage = v),
                    validator: (v) => v == null ? 'Select growth stage' : null,
                  ),
                  const SizedBox(height: 20),

                  // ── Weather (auto-filled from OpenWeather) ───────────────────
                  Row(
                    children: [
                      const Icon(Icons.wb_sunny_outlined,
                          size: 18, color: AgriColors.gold),
                      const SizedBox(width: 6),
                      const Text("Today's Weather",
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const Spacer(),
                      if (_weatherLoading)
                        const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (_region != null)
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          tooltip: 'Refresh weather',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            _tempMinCtrl.clear();
                            _tempMaxCtrl.clear();
                            _rainfallCtrl.clear();
                            _fetchWeather(_region!);
                          },
                        ),
                    ],
                  ),
                  if (_weatherStatus != null) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(
                        _weatherStatus!.startsWith('Could not') ||
                                _weatherStatus!.startsWith('Add an')
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 14,
                        color: _weatherStatus!.startsWith('Could not') ||
                                _weatherStatus!.startsWith('Add an')
                            ? AgriColors.gold
                            : AgriColors.mintGreen,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _weatherStatus!,
                          style: TextStyle(
                            fontSize: 11,
                            color: _weatherStatus!.startsWith('Could not') ||
                                    _weatherStatus!.startsWith('Add an')
                                ? AgriColors.gold
                                : Colors.white70,
                          ),
                        ),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextFormField(
                      controller: _tempMinCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Min Temp (°C)',
                          prefixIcon: Icon(Icons.thermostat_outlined)),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(
                      controller: _tempMaxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Max Temp (°C)',
                          prefixIcon: Icon(Icons.thermostat_rounded)),
                    )),
                  ]),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _rainfallCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Rainfall (mm)',
                        prefixIcon: Icon(Icons.water_drop_outlined)),
                  ),
                  const SizedBox(height: 20),

                  // ── Fertilizer ──────────────────────────────────────────────
                  _SectionLabel(icon: Icons.science_outlined, title: 'Fertilizer'),
                  SwitchListTile(
                    value: _fertApplied,
                    onChanged: (v) => setState(() => _fertApplied = v),
                    title: const Text('Fertilizer applied today'),
                    activeColor: AgriColors.forestGreen,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_fertApplied) ...[
                    TextFormField(
                      controller: _fertTypeCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Fertilizer type (e.g. NPK, Urea)',
                          prefixIcon: Icon(Icons.science_rounded)),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fertKgHaCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Amount applied (kg/ha)',
                          prefixIcon: Icon(Icons.scale_outlined)),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // ── Pests & Disease ─────────────────────────────────────────
                  _SectionLabel(icon: Icons.bug_report_outlined, title: 'Pests & Disease'),
                  SwitchListTile(
                    value: _pestObserved,
                    onChanged: (v) => setState(() => _pestObserved = v),
                    title: const Text('Pests observed'),
                    activeColor: AgriColors.danger,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_pestObserved) ...[
                    TextFormField(
                      controller: _pestDescCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Describe the pest / damage',
                          prefixIcon: Icon(Icons.pest_control_outlined)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SwitchListTile(
                    value: _diseaseObserved,
                    onChanged: (v) => setState(() => _diseaseObserved = v),
                    title: const Text('Disease symptoms observed'),
                    activeColor: AgriColors.danger,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_diseaseObserved) ...[
                    TextFormField(
                      controller: _diseaseDescCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Describe the symptoms',
                          prefixIcon: Icon(Icons.local_hospital_outlined)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SwitchListTile(
                    value: _irrigationApplied,
                    onChanged: (v) => setState(() => _irrigationApplied = v),
                    title: const Text('Irrigation applied today'),
                    activeColor: AgriColors.sky,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Additional notes (optional)',
                        prefixIcon: Icon(Icons.notes_rounded)),
                  ),
                  const SizedBox(height: 28),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded),
                      label: Text(_submitting ? 'Saving…' : context.t('farm_activity_save')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField({required String label, required String value, required VoidCallback onTap}) {
    final isEmpty = value == 'Select date';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label,
            prefixIcon: const Icon(Icons.calendar_today_outlined)),
        child: Text(value,
            style: TextStyle(color: isEmpty
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)
                : Theme.of(context).colorScheme.onSurface)),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: AgriColors.forestGreen),
      const SizedBox(width: 8),
      Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700, color: AgriColors.forestGreen)),
    ]);
  }
}

// ── Activity card ─────────────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity, required this.onDelete});
  final Map<String, dynamic> activity;
  final VoidCallback onDelete;

  String _fmt(String? iso) {
    if (iso == null) return '—';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    final crop     = activity['crop']?.toString() ?? '—';
    final stage    = activity['growth_stage']?.toString() ?? activity['stage']?.toString() ?? '—';
    final region   = activity['region']?.toString() ?? '';
    final recorded = _fmt(activity['record_date']?.toString() ?? activity['recorded_at']?.toString());
    final hasPest  = activity['pest_observed'] == true;
    final hasDisease = activity['disease_observed'] == true;
    final hasFert  = activity['fertilizer_applied'] == true;
    final tMax     = activity['temp_max_c'];
    final rain     = activity['rainfall_mm'];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: AgriColors.forestGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.event_note_rounded, color: AgriColors.forestGreen, size: 20),
        ),
        title: Text('$crop · $stage',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$region · $recorded',
            style: Theme.of(context).textTheme.bodySmall),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (hasPest || hasDisease)
            const Icon(Icons.warning_amber_rounded, color: AgriColors.gold, size: 18),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AgriColors.danger, size: 20),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Remove Entry?'),
                content: const Text('This removes it from your local diary.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  TextButton(
                    onPressed: () { Navigator.pop(context); onDelete(); },
                    child: const Text('Remove', style: TextStyle(color: AgriColors.danger)),
                  ),
                ],
              ),
            ),
          ),
        ]),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Divider(height: 1),
              const SizedBox(height: 10),
              if (tMax != null) _row(context, Icons.thermostat_rounded, 'Max Temp', '$tMax °C'),
              if (rain != null) _row(context, Icons.water_drop_outlined, 'Rainfall', '$rain mm'),
              if (hasFert)  _row(context, Icons.science_outlined, 'Fertilizer',
                  activity['fertilizer_type']?.toString() ?? 'Applied'),
              if (hasPest)  _row(context, Icons.bug_report_outlined, 'Pest',
                  activity['pest_description']?.toString() ?? 'Observed', color: AgriColors.danger),
              if (hasDisease) _row(context, Icons.local_hospital_outlined, 'Disease',
                  activity['disease_description']?.toString() ?? 'Observed', color: AgriColors.danger),
              if ((activity['notes'] ?? '').toString().isNotEmpty)
                _row(context, Icons.notes_rounded, 'Notes', activity['notes'].toString()),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext ctx, IconData icon, String label, String value,
      {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: color ?? AgriColors.forestGreen),
        const SizedBox(width: 8),
        SizedBox(width: 90,
            child: Text(label, style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant))),
        Expanded(child: Text(value,
            style: TextStyle(fontWeight: FontWeight.w500, color: color))),
      ]),
    );
  }
}
