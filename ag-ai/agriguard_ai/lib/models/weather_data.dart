class WeatherData {
  const WeatherData({
    required this.temperatureC,
    required this.feelsLikeC,
    required this.humidity,
    required this.windSpeedKmh,
    required this.windDirection,
    required this.description,
    required this.locationLabel,
    required this.rainfallNext24hMm,
    required this.updatedAt,
    required this.iconCode,
  });

  final double temperatureC;
  final double feelsLikeC;
  final int humidity;
  final double windSpeedKmh;
  final String windDirection;
  final String description;
  final String locationLabel;
  final double rainfallNext24hMm;
  final DateTime updatedAt;
  final String iconCode;

  List<String> get farmingAdvisories {
    final tips = <String>[];

    if (rainfallNext24hMm >= 5) {
      tips.add(
        'Rain expected (${rainfallNext24hMm.toStringAsFixed(1)} mm in 24h) — '
        'delay fertilizer application.',
      );
    } else if (rainfallNext24hMm < 1 && humidity < 50) {
      tips.add('Dry conditions — ensure crops have adequate irrigation.');
    } else {
      tips.add('Good conditions for field work today.');
    }

    if (humidity >= 75) {
      tips.add('High humidity — monitor crops for fungal disease risk.');
    }

    if (windSpeedKmh >= 30) {
      tips.add('Strong winds — avoid spraying pesticides today.');
    } else if (tips.length < 3) {
      tips.add('Check leaf moisture and pest activity during morning rounds.');
    }

    return tips.take(3).toList();
  }
}
