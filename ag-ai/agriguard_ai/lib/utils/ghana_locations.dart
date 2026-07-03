import '../models/region.dart';

const defaultCountry = 'Ghana';

/// All 16 regions of Ghana — preloaded like `regions` table seed data.
const ghanaRegionsDb = <GhanaRegion>[
  GhanaRegion(regionId: 1, regionName: 'Ashanti', capital: 'Kumasi'),
  GhanaRegion(regionId: 2, regionName: 'Bono', capital: 'Sunyani'),
  GhanaRegion(regionId: 3, regionName: 'Bono East', capital: 'Techiman'),
  GhanaRegion(regionId: 4, regionName: 'Ahafo', capital: 'Goaso'),
  GhanaRegion(regionId: 5, regionName: 'Central', capital: 'Cape Coast'),
  GhanaRegion(regionId: 6, regionName: 'Eastern', capital: 'Koforidua'),
  GhanaRegion(regionId: 7, regionName: 'Greater Accra', capital: 'Accra'),
  GhanaRegion(regionId: 8, regionName: 'North East', capital: 'Nalerigu'),
  GhanaRegion(regionId: 9, regionName: 'Northern', capital: 'Tamale'),
  GhanaRegion(regionId: 10, regionName: 'Oti', capital: 'Dambai'),
  GhanaRegion(regionId: 11, regionName: 'Savannah', capital: 'Damongo'),
  GhanaRegion(regionId: 12, regionName: 'Upper East', capital: 'Bolgatanga'),
  GhanaRegion(regionId: 13, regionName: 'Upper West', capital: 'Wa'),
  GhanaRegion(regionId: 14, regionName: 'Volta', capital: 'Ho'),
  GhanaRegion(regionId: 15, regionName: 'Western', capital: 'Sekondi-Takoradi'),
  GhanaRegion(
    regionId: 16,
    regionName: 'Western North',
    capital: 'Sefwi Wiawso',
  ),
];

List<String> get ghanaRegionNames =>
    ghanaRegionsDb.map((r) => r.regionName).toList();

GhanaRegion? regionByName(String? name) {
  if (name == null) return null;
  for (final r in ghanaRegionsDb) {
    if (r.regionName == name) return r;
  }
  return null;
}

String? capitalForRegion(String? regionName) =>
    regionByName(regionName)?.capital;

/// Districts loaded dynamically per selected region (MVP local dataset).
const districtsByRegion = <String, List<String>>{
  'Ashanti': [
    'Kumasi Metro',
    'Ejisu Municipal',
    'Obuasi Municipal',
    'Mampong Municipal',
  ],
  'Bono': [
    'Sunyani Municipal',
    'Berekum East',
    'Dormaa East',
  ],
  'Bono East': [
    'Techiman Municipal',
    'Kintampo North',
    'Atebubu-Amantin',
  ],
  'Ahafo': [
    'Asunafo North',
    'Asutifi South',
    'Goaso Municipal',
  ],
  'Central': [
    'Cape Coast Metro',
    'Mfantsiman Municipal',
    'Agona East',
  ],
  'Eastern': [
    'New Juaben North',
    'Akwapem North',
    'Kwahu East',
  ],
  'Greater Accra': [
    'Accra Metro',
    'Tema Metro',
    'Ga East',
  ],
  'North East': [
    'East Mamprusi Municipal',
    'West Mamprusi Municipal',
    'Bunkpurugu-Nakpanduri',
  ],
  'Northern': [
    'Tamale Metro',
    'Savelugu Municipal',
    'Yendi Municipal',
  ],
  'Oti': [
    'Krachi East',
    'Nkwanta South',
    'Jasikan',
  ],
  'Savannah': [
    'West Gonja Municipal',
    'East Gonja Municipal',
    'Central Gonja',
  ],
  'Upper East': [
    'Bolgatanga Municipal',
    'Kassena Nankana Municipal',
    'Bawku Municipal',
  ],
  'Upper West': [
    'Wa Municipal',
    'Lawra Municipal',
    'Jirapa Municipal',
  ],
  'Volta': [
    'Ho Municipal',
    'Ketu South Municipal',
    'Hohoe Municipal',
  ],
  'Western': [
    'Sekondi-Takoradi Metro',
    'Tarkwa-Nsuaem Municipal',
    'Ahanta West Municipal',
  ],
  'Western North': [
    'Sefwi Wiawso Municipal',
    'Bibiani-Anhwiaso-Bekwai Municipal',
    'Aowin Municipal',
  ],
};

/// Towns/communities loaded dynamically per selected district.
const townsByDistrict = <String, List<String>>{
  'Kumasi Metro': ['Kumasi', 'Asokwa', 'Suame', 'Bantama'],
  'Ejisu Municipal': ['Ejisu', 'Bonwire', 'Krapa', 'Fumesua'],
  'Obuasi Municipal': ['Obuasi', 'Tutuka'],
  'Mampong Municipal': ['Mampong', 'Asante Mampong'],
  'Sunyani Municipal': ['Sunyani', 'Abesim', 'Nkwabeng'],
  'Berekum East': ['Berekum', 'Jinijini'],
  'Dormaa East': ['Dormaa Ahenkro', 'Wamfie'],
  'Techiman Municipal': ['Techiman', 'Tuobodom'],
  'Kintampo North': ['Kintampo', 'Busima'],
  'Atebubu-Amantin': ['Atebubu', 'Amantin'],
  'Goaso Municipal': ['Goaso', 'Ayomso'],
  'Asunafo North': ['Goaso', 'Kasapin'],
  'Asutifi South': ['Kenyasi', 'Hwidiem'],
  'Cape Coast Metro': ['Cape Coast', 'Elmina', 'Kakumdo'],
  'Mfantsiman Municipal': ['Saltpond', 'Mankessim'],
  'Agona East': ['Nsaba', 'Kwanyako'],
  'New Juaben North': ['Koforidua', 'Oyoko'],
  'Akwapem North': ['Akropong', 'Mampong Akuapem'],
  'Kwahu East': ['Abetifi', 'Pepease'],
  'Accra Metro': ['Accra', 'Osu', 'Labadi', 'Kaneshie'],
  'Tema Metro': ['Tema', 'Community 1', 'Ashaiman'],
  'Ga East': ['Abokobi', 'Dome', 'Haatso'],
  'East Mamprusi Municipal': ['Nalerigu', 'Gambaga'],
  'West Mamprusi Municipal': ['Walewale', 'Janga'],
  'Bunkpurugu-Nakpanduri': ['Bunkpurugu', 'Nakpanduri'],
  'Tamale Metro': ['Tamale', 'Lamashegu', 'Sagnarigu'],
  'Savelugu Municipal': ['Savelugu', 'Nanton'],
  'Yendi Municipal': ['Yendi', 'Gushiegu'],
  'Krachi East': ['Dambai', 'Kete Krachi'],
  'Nkwanta South': ['Nkwanta', 'Kpassa'],
  'Jasikan': ['Jasikan', 'Bodada'],
  'West Gonja Municipal': ['Damongo', 'Daboya'],
  'East Gonja Municipal': ['Salaga', 'Kpandai'],
  'Central Gonja': ['Buipe', 'Makango'],
  'Bolgatanga Municipal': ['Bolgatanga', 'Zaare'],
  'Kassena Nankana Municipal': ['Navrongo', 'Paga'],
  'Bawku Municipal': ['Bawku', 'Zebilla'],
  'Wa Municipal': ['Wa', 'Busa'],
  'Lawra Municipal': ['Lawra', 'Eremon'],
  'Jirapa Municipal': ['Jirapa', 'Han'],
  'Ho Municipal': ['Ho', 'Klefe'],
  'Ketu South Municipal': ['Denu', 'Aflao'],
  'Hohoe Municipal': ['Hohoe', 'Alavanyo'],
  'Sekondi-Takoradi Metro': ['Sekondi', 'Takoradi', 'Kwesimintsim'],
  'Tarkwa-Nsuaem Municipal': ['Tarkwa', 'Nsuta'],
  'Ahanta West Municipal': ['Agona Nkwanta', 'Apowa'],
  'Sefwi Wiawso Municipal': ['Sefwi Wiawso', 'Asawinso'],
  'Bibiani-Anhwiaso-Bekwai Municipal': ['Bibiani', 'Anhwiaso'],
  'Aowin Municipal': ['Enchi', 'Nyankomase'],
};

List<String> districtsForRegion(String? region) {
  if (region == null) return [];
  return districtsByRegion[region] ?? [];
}

List<String> townsForDistrict(String? district) {
  if (district == null) return [];
  return townsByDistrict[district] ?? [];
}

/// Region filter list for search (includes "All Regions").
List<String> get regionFilterOptions => ['All Regions', ...ghanaRegionNames];

/// Static helper class — use in new screens for clean access.
abstract final class GhanaLocations {
  static List<String> get regions => ghanaRegionNames;
  static List<String> districtsFor(String region) => districtsForRegion(region);
  static List<String> townsFor(String district) => townsForDistrict(district);
}

// ── Region capital coordinates (for weather API) ───────────────────────────────
/// Lat/lon of each region's capital city. Used to auto-fetch weather.
const _regionCoords = <String, (double lat, double lon)>{
  'Ashanti':       (6.6885,   -1.6244),
  'Bono':          (7.3349,   -2.3123),
  'Bono East':     (7.5884,   -1.0384),
  'Ahafo':         (6.8031,   -2.5169),
  'Central':       (5.1315,   -1.2795),
  'Eastern':       (6.0887,   -0.2634),
  'Greater Accra': (5.6037,   -0.1870),
  'North East':    (10.5278,  -0.3628),
  'Northern':      (9.4008,   -0.8393),
  'Oti':           (7.9008,    0.0300),
  'Savannah':      (9.0800,   -1.8200),
  'Upper East':    (10.7866,  -0.8487),
  'Upper West':    (10.0601,  -2.5099),
  'Volta':         (6.6048,    0.4709),
  'Western':       (4.9344,   -1.7403),
  'Western North': (6.2054,   -2.4858),
};

/// Returns the (latitude, longitude) for the capital of [region], or null if unknown.
(double lat, double lon)? coordsForRegion(String? region) {
  if (region == null) return null;
  return _regionCoords[region];
}
