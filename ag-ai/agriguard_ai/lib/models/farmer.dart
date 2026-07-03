import 'location_data.dart';

/// Schema mirror for Agri-Guard database (MVP in-memory model).
class Farmer {
  const Farmer({
    required this.farmerId,
    required this.fullName,
    required this.phoneNumber,
    required this.location,
    required this.registrationDate,
  });

  final String farmerId;
  final String fullName;
  final String phoneNumber;
  final LocationData location;
  final DateTime registrationDate;

  String? get country => location.country;
  String? get region => location.region;
  String? get district => location.district;
  String? get town => location.town;
  double? get latitude => location.latitude;
  double? get longitude => location.longitude;
}
