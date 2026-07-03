class ProduceRecord {
  const ProduceRecord({
    required this.crop,
    required this.town,
    required this.region,
    required this.district,
    required this.farmer,
    required this.quantity,
    required this.harvest,
    required this.confidence,
    this.farmerCount,
  });

  final String crop;
  final String town;
  final String region;
  final String district;
  final String farmer;
  final String quantity;
  final String harvest;
  final String confidence;
  final int? farmerCount;
}

const mockProduceRecords = [
  ProduceRecord(
    crop: 'Maize',
    town: 'Ejisu',
    region: 'Ashanti',
    district: 'Ejisu Municipal',
    farmer: 'Kwame Mensah',
    quantity: '120 bags',
    harvest: 'August 2026',
    confidence: '82%',
    farmerCount: 8,
  ),
  ProduceRecord(
    crop: 'Maize',
    town: 'Techiman',
    region: 'Bono East',
    district: 'Techiman Municipal',
    farmer: 'Kofi Asante',
    quantity: '90 bags',
    harvest: 'September 2026',
    confidence: '76%',
    farmerCount: 5,
  ),
  ProduceRecord(
    crop: 'Rice',
    town: 'Tamale',
    region: 'Northern',
    district: 'Tamale Metro',
    farmer: 'Ama Osei',
    quantity: '900 bags',
    harvest: 'September 2026',
    confidence: '76%',
    farmerCount: 12,
  ),
  ProduceRecord(
    crop: 'Tomato',
    town: 'Techiman',
    region: 'Bono East',
    district: 'Techiman Municipal',
    farmer: 'Abena Boateng',
    quantity: '650 crates',
    harvest: 'July 2026',
    confidence: '74%',
    farmerCount: 6,
  ),
  ProduceRecord(
    crop: 'Cassava',
    town: 'Koforidua',
    region: 'Eastern',
    district: 'New Juaben North',
    farmer: 'Yaw Darko',
    quantity: '5,600 bags',
    harvest: 'October 2026',
    confidence: '71%',
    farmerCount: 9,
  ),
  ProduceRecord(
    crop: 'Yam',
    town: 'Bolgatanga',
    region: 'Northern',
    district: 'Bolgatanga Municipal',
    farmer: 'Fatima Ibrahim',
    quantity: '420 tons',
    harvest: 'November 2026',
    confidence: '69%',
    farmerCount: 4,
  ),
  ProduceRecord(
    crop: 'Onion',
    town: 'Navrongo',
    region: 'Upper East',
    district: 'Kassena Nankana',
    farmer: 'Ibrahim Musah',
    quantity: '380 crates',
    harvest: 'June 2026',
    confidence: '73%',
    farmerCount: 3,
  ),
];

List<ProduceRecord> searchProduce(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return mockProduceRecords;

  return mockProduceRecords.where((r) {
    return r.crop.toLowerCase().contains(q) ||
        r.town.toLowerCase().contains(q) ||
        r.region.toLowerCase().contains(q) ||
        r.district.toLowerCase().contains(q) ||
        r.farmer.toLowerCase().contains(q) ||
        r.quantity.toLowerCase().contains(q);
  }).toList();
}

/// Groups search results by town + region for buyer location view.
List<ProduceLocationSummary> groupByLocation(List<ProduceRecord> records) {
  final map = <String, ProduceLocationSummary>{};
  for (final r in records) {
    final key = '${r.town}|${r.region}|${r.crop}';
    final existing = map[key];
    if (existing == null) {
      map[key] = ProduceLocationSummary(
        crop: r.crop,
        town: r.town,
        region: r.region,
        district: r.district,
        predictedQuantity: r.quantity,
        farmerCount: r.farmerCount ?? 1,
      );
    } else {
      map[key] = existing.copyWith(
        farmerCount: existing.farmerCount + (r.farmerCount ?? 1),
      );
    }
  }
  return map.values.toList();
}

class ProduceLocationSummary {
  const ProduceLocationSummary({
    required this.crop,
    required this.town,
    required this.region,
    required this.district,
    required this.predictedQuantity,
    required this.farmerCount,
  });

  final String crop;
  final String town;
  final String region;
  final String district;
  final String predictedQuantity;
  final int farmerCount;

  ProduceLocationSummary copyWith({int? farmerCount}) {
    return ProduceLocationSummary(
      crop: crop,
      town: town,
      region: region,
      district: district,
      predictedQuantity: predictedQuantity,
      farmerCount: farmerCount ?? this.farmerCount,
    );
  }
}

const quickSearchCrops = [
  'Maize',
  'Rice',
  'Tomato',
  'Cassava',
  'Yam',
  'Onion',
];
