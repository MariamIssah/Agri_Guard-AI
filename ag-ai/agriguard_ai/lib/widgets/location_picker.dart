import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/location_data.dart';
import '../services/location_service.dart';
import '../services/location_session.dart';
import '../utils/app_theme.dart';
import '../utils/ghana_locations.dart';

// Sentinel value used as the dropdown item that triggers manual text entry.
const _kOther = '__other__';

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
  final _districtController = TextEditingController();
  final _townController = TextEditingController();

  String? _country = defaultCountry;
  String? _region;

  /// Null  → nothing chosen yet.
  /// _kOther → user chose "Other", show text field.
  /// anything else → a value from the hardcoded list.
  String? _districtDropdown;
  String? _townDropdown;

  bool _detecting = false;
  double? _latitude;
  double? _longitude;

  bool get _districtIsManual => _districtDropdown == _kOther;
  bool get _townIsManual =>
      _districtIsManual || _townDropdown == _kOther;

  // The actual district/town values sent to the parent.
  String? get _effectiveDistrict => _districtIsManual
      ? _districtController.text.trim().nullIfEmpty
      : _districtDropdown;

  String? get _effectiveTown => _townIsManual
      ? _townController.text.trim().nullIfEmpty
      : _townDropdown;

  @override
  void dispose() {
    _districtController.dispose();
    _townController.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged(
      LocationData(
        country: _country,
        region: _region,
        district: _effectiveDistrict,
        town: _effectiveTown,
        latitude: _latitude,
        longitude: _longitude,
        isManualTown: _townIsManual,
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

      final townList =
          townsForDistrict(districtInList ? loc.district : null);
      final townInList =
          loc.town != null && townList.contains(loc.town);

      setState(() {
        _country = loc.country ?? defaultCountry;
        _region = loc.region;
        _latitude = loc.latitude;
        _longitude = loc.longitude;

        // District
        if (districtInList) {
          _districtDropdown = loc.district;
          _districtController.clear();
        } else if (loc.district != null && loc.district!.isNotEmpty) {
          _districtDropdown = _kOther;
          _districtController.text = loc.district!;
        } else {
          _districtDropdown = null;
          _districtController.clear();
        }

        // Town
        if (_districtIsManual) {
          _townDropdown = _kOther;
          _townController.text = loc.town ?? '';
        } else if (townInList) {
          _townDropdown = loc.town;
          _townController.clear();
        } else if (loc.town != null && loc.town!.isNotEmpty) {
          _townDropdown = _kOther;
          _townController.text = loc.town!;
        } else {
          _townDropdown = null;
          _townController.clear();
        }
      });
      _notify();

      if (mounted) {
        context.read<LocationSession>().setLocation(loc);
        final label = loc.isComplete
            ? 'Location detected: ${loc.town}, ${loc.region}'
            : loc.region != null
                ? 'Region detected: ${loc.region} '
                    '(${loc.latitude?.toStringAsFixed(3)}, '
                    '${loc.longitude?.toStringAsFixed(3)})'
                : 'GPS captured (${loc.latitude?.toStringAsFixed(4)}, '
                    '${loc.longitude?.toStringAsFixed(4)})';
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

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final districtItems = districtsForRegion(_region);
    final townItems = _districtIsManual
        ? <String>[]
        : townsForDistrict(_districtDropdown);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ────────────────────────────────────────────────────
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

        // ── GPS button ────────────────────────────────────────────────
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

        // ── GPS result card ───────────────────────────────────────────
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
                  _coordRow(context, 'District', _effectiveDistrict),
                  _coordRow(context, 'Town', _effectiveTown),
                  _coordRow(
                    context,
                    'GPS',
                    '${_latitude!.toStringAsFixed(4)}, '
                        '${_longitude!.toStringAsFixed(4)}',
                  ),
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

        // ── Country ───────────────────────────────────────────────────
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

        // ── Region ────────────────────────────────────────────────────
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
            _districtDropdown = null;
            _townDropdown = null;
            _districtController.clear();
            _townController.clear();
            _notify();
          }),
        ),
        const SizedBox(height: 14),

        // ── District ──────────────────────────────────────────────────
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: _districtDropdown,
          decoration: const InputDecoration(
            labelText: 'District',
            prefixIcon: Icon(Icons.location_city_outlined),
            helperText: 'Select from the list or choose "Other" to type yours',
          ),
          items: [
            // All hardcoded districts for the chosen region
            ...districtItems.map(
              (d) => DropdownMenuItem(
                value: d,
                child: Text(d, overflow: TextOverflow.ellipsis),
              ),
            ),
            // Always-visible "Other" option
            DropdownMenuItem(
              value: _kOther,
              child: Row(
                children: [
                  Icon(Icons.edit_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Other — type your district',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
          onChanged: _region == null
              ? null
              : (v) => setState(() {
                    _districtDropdown = v;
                    _townDropdown = null;
                    _districtController.clear();
                    _townController.clear();
                    if (v == _kOther) {
                      // town must also be manual when district is free-text
                      _townDropdown = _kOther;
                    }
                    _notify();
                  }),
        ),

        // Text field shown when "Other" is chosen for district
        if (_districtIsManual) ...[
          const SizedBox(height: 10),
          TextFormField(
            controller: _districtController,
            decoration: const InputDecoration(
              labelText: 'District / Municipality name',
              prefixIcon: Icon(Icons.location_city_outlined),
              hintText: 'e.g. Kumbungu District, Nkoranza North…',
            ),
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => _notify(),
          ),
        ],
        const SizedBox(height: 14),

        // ── Town ──────────────────────────────────────────────────────
        if (_districtIsManual) ...[
          // District is free-text → town must be free-text too
          TextFormField(
            controller: _townController,
            decoration: const InputDecoration(
              labelText: 'Town / Community',
              prefixIcon: Icon(Icons.place_outlined),
              hintText: 'e.g. Kumbungu, Tolon, Wulensi…',
            ),
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => _notify(),
          ),
        ] else ...[
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _townDropdown,
            decoration: const InputDecoration(
              labelText: 'Town / Community',
              prefixIcon: Icon(Icons.place_outlined),
              helperText:
                  'Select from the list or choose "Other" to type yours',
            ),
            items: [
              ...townItems.map(
                (t) => DropdownMenuItem(
                  value: t,
                  child: Text(t, overflow: TextOverflow.ellipsis),
                ),
              ),
              DropdownMenuItem(
                value: _kOther,
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Other — type your town',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            onChanged: _districtDropdown == null
                ? null
                : (v) => setState(() {
                      _townDropdown = v;
                      _townController.clear();
                      _notify();
                    }),
          ),

          // Text field shown when "Other" is chosen for town
          if (_townIsManual && !_districtIsManual) ...[
            const SizedBox(height: 10),
            TextFormField(
              controller: _townController,
              decoration: const InputDecoration(
                labelText: 'Town / Community name',
                prefixIcon: Icon(Icons.place_outlined),
                hintText: 'e.g. Kumbungu, Tolon, Wulensi…',
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => _notify(),
            ),
          ],
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

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}

/// Validates that a [LocationData] from [LocationPicker] is complete.
String? validateLocation(LocationData? location) {
  if (location == null || !location.isComplete) {
    return 'Please set a complete location (GPS or manual selection)';
  }
  return null;
}
