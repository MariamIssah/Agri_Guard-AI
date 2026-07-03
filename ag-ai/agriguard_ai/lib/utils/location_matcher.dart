import 'package:geocoding/geocoding.dart';

import 'ghana_locations.dart';

/// Maps device reverse-geocode results to Ghana admin names where possible.
class LocationMatcher {
  static String? matchRegion(Placemark placemark) {
    final candidates = [
      placemark.administrativeArea,
      placemark.subAdministrativeArea,
      placemark.locality,
      placemark.subLocality,
    ].whereType<String>().map(_normalize).where((s) => s.isNotEmpty);

    for (final candidate in candidates) {
      for (final region in ghanaRegionsDb) {
        final name = _normalize(region.regionName);
        final capital = _normalize(region.capital);
        if (candidate.contains(name) ||
            name.contains(candidate) ||
            candidate.contains(capital) ||
            capital.contains(candidate)) {
          return region.regionName;
        }
      }
    }

    final admin = placemark.administrativeArea?.trim();
    if (admin != null && admin.isNotEmpty) {
      return admin.replaceAll(' Region', '').trim();
    }
    return null;
  }

  static String? matchDistrict(String? region, Placemark placemark) {
    if (region == null) {
      return placemark.subAdministrativeArea?.trim();
    }

    final candidates = [
      placemark.subAdministrativeArea,
      placemark.locality,
      placemark.subLocality,
    ].whereType<String>().map(_normalize);

    for (final district in districtsForRegion(region)) {
      final normalized = _normalize(district);
      for (final candidate in candidates) {
        if (candidate.contains(normalized) || normalized.contains(candidate)) {
          return district;
        }
      }
    }

    return placemark.subAdministrativeArea?.trim() ??
        placemark.locality?.trim();
  }

  static String? matchTown(String? district, Placemark placemark) {
    final fromDevice = placemark.locality?.trim() ??
        placemark.subLocality?.trim() ??
        placemark.name?.trim();

    if (district == null || fromDevice == null) return fromDevice;

    final towns = townsForDistrict(district);
    final normalizedDevice = _normalize(fromDevice);
    for (final town in towns) {
      if (_normalize(town) == normalizedDevice) return town;
    }
    return fromDevice;
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(' region', '').trim();
}

String formatLocationLabel({
  String? town,
  String? district,
  String? region,
  String? country,
}) {
  final parts = [town, district, region, country]
      .whereType<String>()
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'Current location';
  return parts.take(3).join(', ');
}

String windDirectionFromDegrees(double degrees) {
  const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  final index = ((degrees + 22.5) % 360 / 45).floor();
  return dirs[index];
}
