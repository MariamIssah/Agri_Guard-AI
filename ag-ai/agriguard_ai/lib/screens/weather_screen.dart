import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_localizations.dart';

import '../models/weather_data.dart';
import '../services/api_key_service.dart';
import '../services/location_service.dart';
import '../services/location_session.dart';
import '../services/weather_service.dart';
import '../utils/app_theme.dart';
import '../utils/location_matcher.dart';
import '../widgets/weather_api_setup.dart';

const _ghanaRegionCoords = <String, (double, double)>{
  'Greater Accra': (5.6037, -0.1870),
  'Ashanti': (6.6885, -1.6244),
  'Western': (5.0544, -2.0878),
  'Eastern': (6.5720, -0.4501),
  'Central': (5.1052, -1.2466),
  'Northern': (9.5616, -0.8881),
  'Volta': (6.9249, 0.4250),
  'Bono': (7.9408, -2.3298),
  'Ahafo': (7.6020, -2.5897),
  'Bono East': (7.7500, -1.0500),
  'Western North': (6.3000, -2.5000),
  'Oti': (8.0000, 0.3000),
  'North East': (10.5000, -0.5000),
  'Savannah': (9.3000, -1.2000),
  'Upper East': (10.7500, -0.9500),
  'Upper West': (10.2700, -2.2500),
};

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final _locationService = LocationService();
  final _weatherService = WeatherService();

  WeatherData? _weather;
  bool _loading = true;
  bool _needsApiKey = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWeather());
  }

  Future<void> _loadWeather() async {
    if (!mounted) return;

    final apiKeys = context.read<ApiKeyService>();
    if (!apiKeys.hasWeatherKey) {
      setState(() {
        _loading = false;
        _needsApiKey = true;
        _error = null;
        _weather = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _needsApiKey = false;
      _error = null;
    });

    try {
      final session = context.read<LocationSession>();
      session.setLoading(true);

      final location = await _locationService.detectCurrentLocation();
      if (!mounted) return;
      session.setLocation(location);

      if (location.latitude == null || location.longitude == null) {
        throw LocationException('Could not read GPS coordinates.');
      }

      final label = formatLocationLabel(
        town: location.town,
        district: location.district,
        region: location.region,
        country: location.country,
      );

      final weather = await _weatherService.fetchWeather(
        apiKey: apiKeys.effectiveWeatherKey,
        latitude: location.latitude!,
        longitude: location.longitude!,
        locationLabel: label,
      );

      if (!mounted) return;
      setState(() {
        _weather = weather;
        _loading = false;
      });
      session.setLoading(false);
    } on LocationException catch (e) {
      _handleError(e.message);
    } on WeatherException catch (e) {
      if (e.isInvalidKey) {
        await context.read<ApiKeyService>().clearOpenWeatherKey();
        if (!mounted) return;
        setState(() {
          _loading = false;
          _needsApiKey = true;
          _error = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AgriColors.danger,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        _handleError(e.message);
      }
    } catch (e) {
      _handleError('Failed to load weather: $e');
    }
  }

  void _handleError(String message) {
    if (!mounted) return;
    context.read<LocationSession>().setError(message);
    setState(() {
      _error = message;
      _loading = false;
      _needsApiKey = false;
    });
  }

  Future<void> _loadWeatherForRegion(String region) async {
    final coords = _ghanaRegionCoords[region];
    if (coords == null) return;

    final apiKeys = context.read<ApiKeyService>();
    if (!apiKeys.hasWeatherKey) {
      setState(() {
        _needsApiKey = true;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final weather = await _weatherService.fetchWeather(
        apiKey: apiKeys.effectiveWeatherKey,
        latitude: coords.$1,
        longitude: coords.$2,
        locationLabel: region,
      );
      if (!mounted) return;
      setState(() {
        _weather = weather;
        _loading = false;
      });
    } on WeatherException catch (e) {
      if (e.isInvalidKey) {
        await context.read<ApiKeyService>().clearOpenWeatherKey();
        if (!mounted) return;
        setState(() {
          _loading = false;
          _needsApiKey = true;
          _error = null;
        });
      } else {
        _handleError(e.message);
      }
    } catch (e) {
      _handleError('Failed to load weather for $region: $e');
    }
  }

  IconData _weatherIcon(String code) {
    if (code.startsWith('09') || code.startsWith('10')) {
      return Icons.grain_rounded;
    }
    if (code.startsWith('11')) return Icons.thunderstorm_rounded;
    if (code.startsWith('13')) return Icons.ac_unit_rounded;
    if (code.startsWith('50')) return Icons.foggy;
    if (code.startsWith('02') ||
        code.startsWith('03') ||
        code.startsWith('04')) {
      return Icons.wb_cloudy_rounded;
    }
    return Icons.wb_sunny_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('weather_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.key_outlined),
            tooltip: context.t('weather_change_key'),
            onPressed: () => setState(() {
              _needsApiKey = true;
              _error = null;
            }),
          ),
          IconButton(
            icon: const Icon(Icons.my_location_rounded),
            tooltip: context.t('weather_refresh'),
            onPressed: _loading ? null : _loadWeather,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadWeather,
        color: AgriColors.forestGreen,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 16),
                  Center(child: Text(context.t('weather_detecting'))),
                ],
              )
            : _needsApiKey
                ? WeatherApiSetup(onSaved: _loadWeather)
                : _error != null
                    ? _errorView()
                    : _weatherView(_weather!),
      ),
    );
  }

  Widget _errorView() {
    return _RegionFallbackView(
      error: _error!,
      onRetryGps: _loadWeather,
      onRegionSelected: _loadWeatherForRegion,
      bottomPad: MediaQuery.viewPaddingOf(context).bottom,
      tryAgainLabel: context.t('weather_try_again'),
    );
  }

  Widget _weatherView(WeatherData w) {
    final session = context.watch<LocationSession>();
    final coords = session.current;
    final botPad = MediaQuery.viewPaddingOf(context).bottom;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 16, 16, botPad + 20),
      children: [
        // ── Hero banner ─────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Icon(_weatherIcon(w.iconCode), size: 64, color: Colors.white),
              const SizedBox(height: 8),
              Text(
                '${w.temperatureC.round()}°C',
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                w.description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                w.locationLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              // Min / Max / Feels like row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _heroBadge('Low', '${w.tempMinC.round()}°C'),
                  _heroBadge('Feels like', '${w.feelsLikeC.round()}°C'),
                  _heroBadge('High', '${w.tempMaxC.round()}°C'),
                ],
              ),
              if (coords?.latitude != null) ...[
                const SizedBox(height: 8),
                Text(
                  'GPS ${coords!.latitude!.toStringAsFixed(3)}, '
                  '${coords.longitude!.toStringAsFixed(3)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Updated ${_hm(w.updatedAt)} · OpenWeather',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Sunrise / Sunset strip ──────────────────────────────────────────
        if (w.sunriseTime != null && w.sunsetTime != null)
          _sunStrip(w.sunriseTime!, w.sunsetTime!),

        const SizedBox(height: 20),
        _sectionHeader('Current Conditions'),
        const SizedBox(height: 12),

        // ── Temperature detail card ─────────────────────────────────────────
        _DetailCard(
          icon: Icons.thermostat_rounded,
          color: AgriColors.dangerRed,
          title: 'Temperature',
          value: '${w.temperatureC.round()}°C',
          rows: [
            _Row('Feels like', '${w.feelsLikeC.round()}°C'),
            _Row('Today range', '${w.tempMinC.round()}°C – ${w.tempMaxC.round()}°C'),
          ],
          context: w.temperatureContext,
        ),
        const SizedBox(height: 10),

        // ── Humidity detail card ────────────────────────────────────────────
        _DetailCard(
          icon: Icons.water_drop_rounded,
          color: AgriColors.skyBlue,
          title: 'Humidity',
          value: '${w.humidity}%',
          rows: [
            _Row('Level', _humidityLabel(w.humidity)),
          ],
          context: w.humidityContext,
          severity: _humiditySeverity(w.humidity),
        ),
        const SizedBox(height: 10),

        // ── Rainfall detail card ────────────────────────────────────────────
        _DetailCard(
          icon: Icons.grain_rounded,
          color: const Color(0xFF1E88E5),
          title: 'Rainfall (Next 24h)',
          value: '${w.rainfallNext24hMm.toStringAsFixed(1)} mm',
          rows: [
            _Row('Intensity', _rainLabel(w.rainfallNext24hMm)),
          ],
          context: w.rainfallContext,
          severity: _rainSeverity(w.rainfallNext24hMm),
        ),
        const SizedBox(height: 10),

        // ── Wind detail card ────────────────────────────────────────────────
        _DetailCard(
          icon: Icons.air_rounded,
          color: AgriColors.wheatGold,
          title: 'Wind',
          value: '${w.windSpeedKmh.round()} km/h',
          rows: [
            _Row('Direction', 'From ${w.windDirection}'),
            _Row('Condition', _windLabel(w.windSpeedKmh)),
          ],
          context: w.windContext,
          severity: _windSeverity(w.windSpeedKmh),
        ),
        const SizedBox(height: 10),

        // ── Cloud cover card ────────────────────────────────────────────────
        _DetailCard(
          icon: Icons.wb_cloudy_rounded,
          color: const Color(0xFF78909C),
          title: 'Cloud Cover',
          value: '${w.cloudCoverPct}%',
          rows: [
            _Row('Sky', _cloudLabel(w.cloudCoverPct)),
          ],
          context: w.cloudContext,
        ),
        const SizedBox(height: 10),

        // ── Pressure & Visibility row ───────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _MiniCard(
                icon: Icons.speed_rounded,
                color: const Color(0xFF7B1FA2),
                title: 'Pressure',
                value: '${w.pressureHpa} hPa',
                note: w.pressureContext,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniCard(
                icon: Icons.visibility_rounded,
                color: const Color(0xFF00796B),
                title: 'Visibility',
                value: '${w.visibilityKm.toStringAsFixed(1)} km',
                note: w.visibilityKm >= 8
                    ? 'Clear visibility'
                    : w.visibilityKm >= 4
                        ? 'Reduced — possible haze or fog'
                        : 'Poor — foggy or dusty conditions',
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        _sectionHeader('Farming Advisory'),
        const SizedBox(height: 12),

        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (var i = 0; i < w.farmingAdvisories.length; i++) ...[
                  if (i > 0) const Divider(height: 20),
                  _advisoryRow(
                    i == 0
                        ? Icons.check_circle_outline_rounded
                        : Icons.tips_and_updates_outlined,
                    i == 0 ? AgriColors.leafGreen : AgriColors.forestGreen,
                    w.farmingAdvisories[i],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _heroBadge(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _sunStrip(DateTime sunrise, DateTime sunset) {
    final daylight = sunset.difference(sunrise);
    final h = daylight.inHours;
    final m = daylight.inMinutes % 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _sunItem(Icons.wb_twilight_rounded, 'Sunrise', _hm(sunrise),
              const Color(0xFFFF8F00)),
          Container(width: 1, height: 32, color: const Color(0xFFFFE082)),
          _sunItem(Icons.nights_stay_rounded, 'Sunset', _hm(sunset),
              const Color(0xFF5C6BC0)),
          Container(width: 1, height: 32, color: const Color(0xFFFFE082)),
          _sunItem(Icons.wb_sunny_outlined, 'Daylight', '${h}h ${m}m',
              const Color(0xFFFFA000)),
        ],
      ),
    );
  }

  Widget _sunItem(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF795548))),
      ],
    );
  }

  Widget _sectionHeader(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _advisoryRow(IconData icon, Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  String _hm(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ── Label helpers ─────────────────────────────────────────────────────────

  String _humidityLabel(int h) {
    if (h >= 85) return 'Very high';
    if (h >= 70) return 'High';
    if (h >= 50) return 'Moderate';
    if (h >= 30) return 'Low';
    return 'Very low';
  }

  String _rainLabel(double mm) {
    if (mm >= 20) return 'Heavy rain';
    if (mm >= 10) return 'Moderate rain';
    if (mm >= 3) return 'Light rain';
    if (mm >= 1) return 'Very light rain';
    return 'No rain expected';
  }

  String _windLabel(double kmh) {
    if (kmh >= 40) return 'Strong wind';
    if (kmh >= 25) return 'Moderate wind';
    if (kmh >= 10) return 'Light breeze';
    return 'Calm';
  }

  String _cloudLabel(int pct) {
    if (pct >= 80) return 'Overcast';
    if (pct >= 50) return 'Mostly cloudy';
    if (pct >= 20) return 'Partly cloudy';
    return 'Clear sky';
  }

  // 0 = normal, 1 = warning, 2 = alert
  int _humiditySeverity(int h) => h >= 80 ? 2 : h >= 70 ? 1 : 0;
  int _rainSeverity(double mm) => mm >= 10 ? 2 : mm >= 3 ? 1 : 0;
  int _windSeverity(double kmh) => kmh >= 40 ? 2 : kmh >= 25 ? 1 : 0;
}

// ── Detail card ─────────────────────────────────────────────────────────────

class _Row {
  const _Row(this.label, this.value);
  final String label;
  final String value;
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.rows,
    required this.context,
    this.severity = 0,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final List<_Row> rows;
  final String context;
  final int severity; // 0 = ok, 1 = warning, 2 = alert

  @override
  Widget build(BuildContext ctx) {
    final bg = Theme.of(ctx).cardColor;
    final severityColor = severity == 2
        ? const Color(0xFFE53935)
        : severity == 1
            ? const Color(0xFFFFA726)
            : AgriColors.leafGreen;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          // Detail rows
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in rows) ...[
                  Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(
                          r.label,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(ctx)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        r.value,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                const Divider(height: 14),
                // Farming context note
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.eco_rounded,
                        size: 15, color: severityColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context,
                        style: TextStyle(
                          fontSize: 12.5,
                          color:
                              Theme.of(ctx).colorScheme.onSurface,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mini card (Pressure / Visibility) ────────────────────────────────────────

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.note,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String note;

  @override
  Widget build(BuildContext ctx) {
    return Card(
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(ctx).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              note,
              style: TextStyle(
                fontSize: 11.5,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Region fallback ───────────────────────────────────────────────────────────

class _RegionFallbackView extends StatefulWidget {
  const _RegionFallbackView({
    required this.error,
    required this.onRetryGps,
    required this.onRegionSelected,
    required this.bottomPad,
    required this.tryAgainLabel,
  });

  final String error;
  final VoidCallback onRetryGps;
  final ValueChanged<String> onRegionSelected;
  final double bottomPad;
  final String tryAgainLabel;

  @override
  State<_RegionFallbackView> createState() => _RegionFallbackViewState();
}

class _RegionFallbackViewState extends State<_RegionFallbackView> {
  String? _selectedRegion;

  @override
  Widget build(BuildContext context) {
    final regions = _ghanaRegionCoords.keys.toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding:
          EdgeInsets.fromLTRB(24, 24, 24, widget.bottomPad + 24),
      children: [
        const Icon(Icons.location_off_rounded,
            size: 56, color: AgriColors.danger),
        const SizedBox(height: 16),
        Text(
          widget.error,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.5),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: widget.onRetryGps,
          icon: const Icon(Icons.my_location_rounded),
          label: Text(widget.tryAgainLabel),
        ),
        const SizedBox(height: 28),
        const Divider(),
        const SizedBox(height: 16),
        Text(
          'Or select your Ghana region manually',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: _selectedRegion,
          decoration: const InputDecoration(
            labelText: 'Region',
            prefixIcon: Icon(Icons.map_outlined),
          ),
          items: regions
              .map((r) => DropdownMenuItem(
                  value: r,
                  child:
                      Text(r, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) => setState(() => _selectedRegion = v),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _selectedRegion == null
                ? null
                : () => widget.onRegionSelected(_selectedRegion!),
            icon: const Icon(Icons.wb_sunny_rounded),
            label: const Text('Load Weather for Region'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AgriColors.forestGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
