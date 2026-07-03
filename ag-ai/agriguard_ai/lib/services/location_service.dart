import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../models/location_data.dart';
import '../utils/ghana_locations.dart';
import '../utils/location_matcher.dart';

class LocationException implements Exception {
  LocationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Real GPS + reverse geocoding. Falls back to coordinates-only if geocoding fails.
class LocationService {
  Future<LocationData> detectCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException(
        'Location services are off. Please enable GPS on your device.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw LocationException(
        'Location permission denied. Allow location access for Agri-Guard AI.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
        'Location permission permanently denied. Enable it in app settings.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );

    return _reverseGeocode(position.latitude, position.longitude);
  }

  Future<LocationData> _reverseGeocode(double lat, double lon) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isEmpty) {
        return LocationData(
          country: defaultCountry,
          latitude: lat,
          longitude: lon,
        );
      }

      final placemark = placemarks.first;
      final region = LocationMatcher.matchRegion(placemark);
      final district = LocationMatcher.matchDistrict(region, placemark);
      final town = LocationMatcher.matchTown(district, placemark);

      return LocationData(
        country: placemark.country ?? defaultCountry,
        region: region,
        district: district,
        town: town,
        latitude: lat,
        longitude: lon,
        isManualTown: district != null &&
            town != null &&
            !townsForDistrict(district).contains(town),
      );
    } catch (_) {
      return LocationData(
        country: defaultCountry,
        latitude: lat,
        longitude: lon,
      );
    }
  }
}
