import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/location_data.dart';
import '../services/location_service.dart';
import '../services/location_session.dart';
import '../utils/app_theme.dart';
import '../utils/ghana_locations.dart';

class LocationPicker extends StatefulWidget {
  const LocationPicker({
    super.key,
    required this.onChanged,
    this.title = 'Location',
  });

  final ValueChanged<LocationData> onChanged;
  final String title;

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final _locationService = LocationService();
  final _manualTownController = TextEditingController();

  String? _country = defaultCountry;
  String? _region;
  String? _district;
  String? _town;
  double? _latitude;
  double? _longitude;
  bool _useManualTown = false;
  bool _detecting = false;

  @override
  void dispose() {
    _manualTownController.dispose();
    super.dispose();
  }

  void _notify() {
    final town = _useManualTown
        ? _manualTownController.text.trim()
        : _town;
    widget.onChanged(
      LocationData(
        country: _country,
        region: _region,
        district: _district,
        town: town?.isEmpty ?? true ? null : town,
        latitude: _latitude,
        longitude: _longitude,
        isManualTown: _useManualTown,
      ),
    );
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _detecting = true);
    try {
      final loc = await _locationService.detectCurrentLocation();
      if (!mounted) return;

      final districtList = districtsForRegion(loc.region);
      final townList = townsForDistrict(loc.district);
      final townInList = loc.town != null && townList.contains(loc.town);

      setState(() {
        _country = loc.country ?? defaultCountry;
        _region = loc.region;
        _district = loc.district != null && districtList.contains(loc.district)
            ? loc.district
            : loc.district;
        _latitude = loc.latitude;
        _longitude = loc.longitude;
        _useManualTown = loc.town != null && !townInList;
        if (_useManualTown) {
          _manualTownController.text = loc.town ?? '';
          _town = null;
        } else {
          _town = loc.town;
          _manualTownController.clear();
        }
      });
      _notify();

      if (mounted) {
        context.read<LocationSession>().setLocation(loc);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              loc.isComplete
                  ? 'Location detected: ${loc.town}, ${loc.region}'
                  : 'GPS captured (${loc.latitude?.toStringAsFixed(4)}, '
                      '${loc.longitude?.toStringAsFixed(4)})',
            ),
            backgroundColor: AgriColors.leafGreen,
          ),
        );
      }
    } on LocationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AgriColors.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location error: $e'),
            backgroundColor: AgriColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final districts = districtsForRegion(_region);
    final towns = townsForDistrict(_district);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.location_on_outlined,
                color: AgriColors.forestGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: onSurface,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _detecting ? null : _useCurrentLocation,
          icon: _detecting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location_rounded),
          label: Text(
            _detecting ? 'Detecting location...' : 'Use My Current Location',
          ),
        ),
        if (_latitude != null && _longitude != null) ...[
          const SizedBox(height: 12),
          Card(
            color: AgriColors.mintGreen.withValues(alpha: 0.2),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _coordRow(context, 'Country', _country),
                  _coordRow(context, 'Region', _region),
                  _coordRow(context, 'District', _district),
                  _coordRow(context, 'Town',
                      _useManualTown ? _manualTownController.text : _town),
                  _coordRow(context, 'Latitude',
                      _latitude?.toStringAsFixed(4)),
                  _coordRow(context, 'Longitude',
                      _longitude?.toStringAsFixed(4)),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Or select manually',
          style: TextStyle(fontSize: 13, color: onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _country,
          decoration: const InputDecoration(
            labelText: 'Country',
            prefixIcon: Icon(Icons.public),
          ),
          items: const [
            DropdownMenuItem(value: 'Ghana', child: Text('Ghana')),
          ],
          onChanged: (v) => setState(() {
            _country = v;
            _notify();
          }),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _region,
          decoration: InputDecoration(
            labelText: 'Region',
            prefixIcon: const Icon(Icons.map_outlined),
            helperText: _region != null
                ? 'Capital: ${capitalForRegion(_region)}'
                : null,
          ),
          items: ghanaRegionsDb
              .map(
                (r) => DropdownMenuItem(
                  value: r.regionName,
                  child: Text(
                    '${r.regionName} (${r.capital})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() {
            _region = v;
            _district = null;
            _town = null;
            _notify();
          }),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _district,
          decoration: const InputDecoration(
            labelText: 'District',
            prefixIcon: Icon(Icons.location_city_outlined),
          ),
          items: districts
              .map((d) => DropdownMenuItem(
                    value: d,
                    child: Text(d, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: districts.isEmpty
              ? null
              : (v) => setState(() {
                    _district = v;
                    _town = null;
                    _notify();
                  }),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter town/community manually',
                    style: TextStyle(fontSize: 14, color: onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'For communities not yet in the database',
                    style: TextStyle(fontSize: 12, color: onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            Switch(
              value: _useManualTown,
              activeTrackColor: AgriColors.mintGreen,
              thumbColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? AgriColors.forestGreen
                    : null,
              ),
              onChanged: (v) => setState(() {
                _useManualTown = v;
                if (!v) _manualTownController.clear();
                _notify();
              }),
            ),
          ],
        ),
        if (_useManualTown) ...[
          TextFormField(
            controller: _manualTownController,
            decoration: const InputDecoration(
              labelText: 'Town / Community Name',
              prefixIcon: Icon(Icons.edit_location_alt_outlined),
              hintText: 'e.g. Small village name',
            ),
            onChanged: (_) => _notify(),
          ),
        ] else ...[
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _town,
            decoration: const InputDecoration(
              labelText: 'Town',
              prefixIcon: Icon(Icons.place_outlined),
            ),
            items: towns
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: towns.isEmpty
                ? null
                : (v) => setState(() {
                      _town = v;
                      _notify();
                    }),
          ),
        ],
      ],
    );
  }

  Widget _coordRow(BuildContext context, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(fontSize: 12, color: onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Validates that a [LocationData] from [LocationPicker] is complete.
String? validateLocation(LocationData? location) {
  if (location == null || !location.isComplete) {
    return 'Please set a complete location (GPS or manual selection)';
  }
  return null;
}
