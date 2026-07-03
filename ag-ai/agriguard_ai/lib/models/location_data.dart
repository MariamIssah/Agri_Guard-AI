class LocationData {
  const LocationData({
    this.country,
    this.region,
    this.district,
    this.town,
    this.latitude,
    this.longitude,
    this.isManualTown = false,
  });

  final String? country;
  final String? region;
  final String? district;
  final String? town;
  final double? latitude;
  final double? longitude;
  final bool isManualTown;

  bool get isComplete =>
      country != null &&
      country!.isNotEmpty &&
      region != null &&
      region!.isNotEmpty &&
      district != null &&
      district!.isNotEmpty &&
      town != null &&
      town!.isNotEmpty;

  LocationData copyWith({
    String? country,
    String? region,
    String? district,
    String? town,
    double? latitude,
    double? longitude,
    bool? isManualTown,
  }) {
    return LocationData(
      country: country ?? this.country,
      region: region ?? this.region,
      district: district ?? this.district,
      town: town ?? this.town,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isManualTown: isManualTown ?? this.isManualTown,
    );
  }

  @override
  String toString() {
    final parts = [town, district, region, country].whereType<String>().toList();
    return parts.join(', ');
  }
}
