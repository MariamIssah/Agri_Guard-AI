/// Mirrors `regions` table: region_id, region_name, capital.
class GhanaRegion {
  const GhanaRegion({
    required this.regionId,
    required this.regionName,
    required this.capital,
  });

  final int regionId;
  final String regionName;
  final String capital;

  /// SQL-style row for documentation / future DB seeding.
  String get seedRow => '$regionId, $regionName, $capital';
}
