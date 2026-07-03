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
import '../widgets/agri_info_card.dart';
import '../widgets/weather_api_setup.dart';

// Approximate centre-point coordinates for each of Ghana's 16 regions.
// Used as GPS fallback when device location is unavailable.
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

  Future<void> _refreshLocationAndWeather() async {
    if (!mounted) return;
    await _loadWeather();
  }

  Future<void> _loadWeatherForRegion(String region) async {
    final coords = _ghanaRegionCoords[region];
    if (coords == null) return;

    final apiKeys = context.read<ApiKeyService>();
    if (!apiKeys.hasWeatherKey) {
      setState(() { _needsApiKey = true; _error = null; });
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      final weather = await _weatherService.fetchWeather(
        apiKey: apiKeys.effectiveWeatherKey,
        latitude: coords.$1,
        longitude: coords.$2,
        locationLabel: region,
      );
      if (!mounted) return;
      setState(() { _weather = weather; _loading = false; });
    } on WeatherException catch (e) {
      if (e.isInvalidKey) {
        await context.read<ApiKeyService>().clearOpenWeatherKey();
        if (!mounted) return;
        setState(() { _loading = false; _needsApiKey = true; _error = null; });
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
    if (code.startsWith('02') || code.startsWith('03') || code.startsWith('04')) {
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
            onPressed: () {
              setState(() {
                _needsApiKey = true;
                _error = null;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.my_location_rounded),
            tooltip: context.t('weather_refresh'),
            onPressed: _loading ? null : _refreshLocationAndWeather,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshLocationAndWeather,
        color: AgriColors.forestGreen,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      context.t('weather_detecting'),
                    ),
                  ),
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
    final botPad = MediaQuery.viewPaddingOf(context).bottom;
    return _RegionFallbackView(
      error: _error!,
      onRetryGps: _refreshLocationAndWeather,
      onRegionSelected: _loadWeatherForRegion,
      bottomPad: botPad,
      tryAgainLabel: context.t('weather_try_again'),
    );
  }

  Widget _weatherView(WeatherData weather) {
    final session = context.watch<LocationSession>();
    final coords = session.current;
    final botPad = MediaQuery.viewPaddingOf(context).bottom;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 20, 20, botPad + 20),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AgriColors.sky,
                AgriColors.sky.withValues(alpha: 0.80),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Icon(_weatherIcon(weather.iconCode), size: 64, color: Colors.white),
              const SizedBox(height: 12),
              Text(
                '${weather.temperatureC.round()}Â°C',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '${weather.description} · ${weather.locationLabel}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 15,
                ),
              ),
              if (coords?.latitude != null && coords?.longitude != null) ...[
                const SizedBox(height: 6),
                Text(
                  'GPS: ${coords!.latitude!.toStringAsFixed(4)}, '
                  '${coords.longitude!.toStringAsFixed(4)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Updated: ${_formatTime(weather.updatedAt)} · OpenWeather',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Current Conditions',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        AgriInfoCard(
          title: 'Temperature',
          value: '${weather.temperatureC.round()}Â°C',
          subtitle: 'Feels like ${weather.feelsLikeC.round()}Â°C',
          icon: Icons.thermostat_rounded,
          accentColor: AgriColors.dangerRed,
        ),
        const SizedBox(height: 10),
        AgriInfoCard(
          title: 'Humidity',
          value: '${weather.humidity}%',
          subtitle: weather.humidity >= 70 ? 'High moisture' : 'Moderate moisture',
          icon: Icons.water_drop_rounded,
          accentColor: AgriColors.skyBlue,
        ),
        const SizedBox(height: 10),
        AgriInfoCard(
          title: 'Rainfall',
          value: '${weather.rainfallNext24hMm.toStringAsFixed(1)} mm',
          subtitle: 'Expected in next 24 hrs',
          icon: Icons.grain_rounded,
          accentColor: AgriColors.leafGreen,
        ),
        const SizedBox(height: 10),
        AgriInfoCard(
          title: 'Wind Speed',
          value: '${weather.windSpeedKmh.round()} km/h',
          subtitle: 'From ${weather.windDirection}',
          icon: Icons.air_rounded,
          accentColor: AgriColors.wheatGold,
        ),
        const SizedBox(height: 24),
        Text(
          'Farming Advisory',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (var i = 0; i < weather.farmingAdvisories.length; i++) ...[
                  if (i > 0) const Divider(height: 24),
                  _advisoryRow(
                    i == 0
                        ? Icons.check_circle_outline
                        : Icons.tips_and_updates_outlined,
                    i == 0 ? AgriColors.leafGreen : AgriColors.forestGreen,
                    weather.farmingAdvisories[i],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
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
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// â”€â”€ Manual region fallback view â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
      padding: EdgeInsets.fromLTRB(24, 24, 24, widget.bottomPad + 24),
      children: [
        const Icon(Icons.location_off_rounded,
            size: 56, color: AgriColors.danger),
        const SizedBox(height: 16),
        Text(
          widget.error,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface, height: 1.5),
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
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          isExpanded: true,
          // ignore: deprecated_member_use
          value: _selectedRegion,
          decoration: const InputDecoration(
            labelText: 'Region',
            prefixIcon: Icon(Icons.map_outlined),
          ),
          items: regions
              .map((r) => DropdownMenuItem(value: r, child: Text(r, overflow: TextOverflow.ellipsis)))
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
                foregroundColor: Colors.white),
          ),
        ),
      ],
    );
  }
}

