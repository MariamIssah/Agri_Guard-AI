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
  final _manualDistrictController = TextEditingController();
  final _manualTownController = TextEditingController();

  String? _country = defaultCountry;
  String? _region;
  String? _district;
  String? _town;
  double? _latitude;
  double? _longitude;
  bool _useManualDistrict = false;
  bool _useManualTown = false;
  bool _detecting = false;

  @override
  void dispose() {
    _manualDistrictController.dispose();
    _manualTownController.dispose();
    super.dispose();
  }

  void _notify() {
    final district = _useManualDistrict
        ? _manualDistrictController.text.trim()
        : _district;
    final town = _useManualTown
        ? _manualTownController.text.trim()
        : _town;
    widget.onChanged(
      LocationData(
        country: _country,
        region: _region,
        district: district?.isEmpty ?? true ? null : district,
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
      final districtInList =
          loc.district != null && districtList.contains(loc.district);

      final townList = townsForDistrict(districtInList ? loc.district : null);
      final townInList = loc.town != null && townList.contains(loc.town);

      setState(() {
        _country = loc.country ?? defaultCountry;
        _region = loc.region;
        _latitude = loc.latitude;
        _longitude = loc.longitude;

        // District: use dropdown if matched, manual text field otherwise
        if (districtInList) {
          _useManualDistrict = false;
          _district = loc.district;
          _manualDistrictController.clear();
        } else if (loc.district != null && loc.district!.isNotEmpty) {
          _useManualDistrict = true;
          _district = null;
          _manualDistrictController.text = loc.district!;
        } else {
          _useManualDistrict = false;
          _district = null;
          _manualDistrictController.clear();
        }

        // When district is manual, town must also be manual
        if (_useManualDistrict) {
          _useManualTown = true;
          _town = null;
          _manualTownController.text = loc.town ?? '';
        } else if (townInList) {
          _useManualTown = false;
          _town = loc.town;
          _manualTownController.clear();
        } else if (loc.town != null && loc.town!.isNotEmpty) {
          _useManualTown = true;
          _town = null;
          _manualTownController.text = loc.town!;
        } else {
          _useManualTown = false;
          _town = null;
          _manualTownController.clear();
        }
      });
      _notify();

      if (mounted) {
        context.read<LocationSession>().setLocation(loc);
        final label = loc.isComplete
            ? 'Location detected: ${loc.town}, ${loc.region}'
            : loc.region != null
                ? 'Region detected: ${loc.region}  (${loc.latitude?.toStringAsFixed(3)}, ${loc.longitude?.toStringAsFixed(3)})'
                : 'GPS captured (${loc.latitude?.toStringAsFixed(4)}, ${loc.longitude?.toStringAsFixed(4)})';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(label),
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

  List<String> get _districtItems => districtsForRegion(_region);

  List<String> get _townItems =>
      _useManualDistrict ? [] : townsForDistrict(_district);

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

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
            _detecting
                ? 'Detecting location...'
                : 'Use My Current Location (GPS)',
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
                  _coordRow(
                    context,
                    'District',
                    _useManualDistrict
                        ? _manualDistrictController.text
                        : _district,
                  ),
                  _coordRow(
                    context,
                    'Town',
                    _useManualTown
                        ? _manualTownController.text
                        : _town,
                  ),
                  _coordRow(
                    context, 'GPS', '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}'),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Or select / enter manually',
          style: TextStyle(fontSize: 13, color: onSurfaceVariant),
        ),
        const SizedBox(height: 12),

        // ── Country ───────────────────────────────────────────────
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: _country,
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

        // ── Region ────────────────────────────────────────────────
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: _region,
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
            _useManualDistrict = false;
            _useManualTown = false;
            _manualDistrictController.clear();
            _manualTownController.clear();
            _notify();
          }),
        ),
        const SizedBox(height: 14),

        // ── District manual toggle ─────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter district manually',
                    style: TextStyle(fontSize: 14, color: onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'If your district is not in the list',
                    style: TextStyle(fontSize: 12, color: onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Switch(
              value: _useManualDistrict,
              activeTrackColor: AgriColors.mintGreen,
              thumbColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? AgriColors.forestGreen
                    : null,
              ),
              onChanged: (v) => setState(() {
                _useManualDistrict = v;
                _district = null;
                _town = null;
                if (!v) {
                  _manualDistrictController.clear();
                  _useManualTown = false;
                  _manualTownController.clear();
                } else {
                  // Manual district forces manual town too
                  _useManualTown = true;
                }
                _notify();
              }),
            ),
          ],
        ),
        if (_useManualDistrict) ...[
          TextFormField(
            controller: _manualDistrictController,
            decoration: const InputDecoration(
              labelText: 'District / Municipality',
              prefixIcon: Icon(Icons.location_city_outlined),
              hintText: 'e.g. Tamale Metro',
            ),
            onChanged: (_) => _notify(),
          ),
        ] else ...[
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _district,
            decoration: const InputDecoration(
              labelText: 'District',
              prefixIcon: Icon(Icons.location_city_outlined),
            ),
            items: _districtItems
                .map((d) => DropdownMenuItem(
                      value: d,
                      child: Text(d, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: _districtItems.isEmpty
                ? null
                : (v) => setState(() {
                      _district = v;
                      _town = null;
                      _notify();
                    }),
          ),
        ],
        const SizedBox(height: 14),

        // ── Town manual toggle ─────────────────────────────────────
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
              onChanged: _useManualDistrict
                  ? null // locked on when district is manual
                  : (v) => setState(() {
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
              hintText: 'e.g. Tamale, Kumbungu, Savelugu...',
            ),
            onChanged: (_) => _notify(),
          ),
        ] else ...[
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _town,
            decoration: const InputDecoration(
              labelText: 'Town',
              prefixIcon: Icon(Icons.place_outlined),
            ),
            items: _townItems
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: _townItems.isEmpty
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
