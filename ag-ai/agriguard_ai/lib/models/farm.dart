import 'location_data.dart';

/// Schema mirror for Agri-Guard database (MVP in-memory model).
class Farm {
  const Farm({
    required this.farmId,
    required this.farmerId,
    required this.farmName,
    required this.farmSize,
    required this.cropType,
    required this.location,
  });

  final String farmId;
  final String farmerId;
  final String farmName;
  final String farmSize;
  final String cropType;
  final LocationData location;

  double? get latitude => location.latitude;
  double? get longitude => location.longitude;
  String? get region => location.region;
  String? get district => location.district;
  String? get town => location.town;
}
