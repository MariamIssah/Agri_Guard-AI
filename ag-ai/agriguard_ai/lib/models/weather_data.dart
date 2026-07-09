class WeatherData {
  const WeatherData({
    required this.temperatureC,
    required this.feelsLikeC,
    required this.tempMinC,
    required this.tempMaxC,
    required this.humidity,
    required this.windSpeedKmh,
    required this.windDirection,
    required this.description,
    required this.locationLabel,
    required this.rainfallNext24hMm,
    required this.pressureHpa,
    required this.cloudCoverPct,
    required this.visibilityKm,
    this.sunriseTime,
    this.sunsetTime,
    required this.updatedAt,
    required this.iconCode,
  });

  final double temperatureC;
  final double feelsLikeC;
  final double tempMinC;
  final double tempMaxC;
  final int humidity;
  final double windSpeedKmh;
  final String windDirection;
  final String description;
  final String locationLabel;
  final double rainfallNext24hMm;
  final int pressureHpa;
  final int cloudCoverPct;
  final double visibilityKm;
  final DateTime? sunriseTime;
  final DateTime? sunsetTime;
  final DateTime updatedAt;
  final String iconCode;

  // ── Farming context helpers ──────────────────────────────────────────────

  String get temperatureContext {
    if (temperatureC < 15) return 'Cool — growth may be slow for most crops.';
    if (temperatureC < 22) return 'Mild — good for leafy vegetables and legumes.';
    if (temperatureC < 30) return 'Optimal range for maize, tomato, and cassava.';
    if (temperatureC < 36) return 'Hot — water crops early morning to reduce stress.';
    return 'Very hot — shade young seedlings and irrigate frequently.';
  }

  String get humidityContext {
    if (humidity >= 85) {
      return 'Very high — high fungal disease risk. '
          'Check for early blight, downy mildew, and leaf rust.';
    }
    if (humidity >= 70) {
      return 'High — monitor crops for fungal infections. '
          'Avoid wetting foliage when irrigating.';
    }
    if (humidity >= 50) {
      return 'Moderate — comfortable growing conditions for most crops.';
    }
    if (humidity >= 30) {
      return 'Low — crops may experience moisture stress. '
          'Increase irrigation frequency.';
    }
    return 'Very dry — risk of wilting. Irrigate and mulch to retain soil moisture.';
  }

  String get rainfallContext {
    if (rainfallNext24hMm >= 20) {
      return 'Heavy rain expected — delay all spraying and fertilizer '
          'application. Check drainage channels.';
    }
    if (rainfallNext24hMm >= 10) {
      return 'Moderate rain — delay fertilizer application. '
          'Good natural irrigation for field crops.';
    }
    if (rainfallNext24hMm >= 3) {
      return 'Light rain — acceptable for most field activities. '
          'Hold off on chemical applications.';
    }
    if (rainfallNext24hMm >= 1) {
      return 'Very light rain — field work can continue as normal.';
    }
    return humidity < 50
        ? 'No rain — ensure crops have adequate irrigation today.'
        : 'No rain expected — good day for spraying and field operations.';
  }

  String get windContext {
    if (windSpeedKmh >= 40) {
      return 'Strong winds — do not spray pesticides or apply foliar '
          'fertilizers. Secure farm structures.';
    }
    if (windSpeedKmh >= 25) {
      return 'Moderate wind — avoid spraying. Wind may damage tall crops '
          'like maize and sorghum.';
    }
    if (windSpeedKmh >= 10) {
      return 'Light breeze from $windDirection — acceptable for spraying. '
          'Apply in the early morning for best results.';
    }
    return 'Calm conditions — ideal for pesticide and fertilizer application.';
  }

  String get cloudContext {
    if (cloudCoverPct >= 80) {
      return 'Overcast — reduced solar radiation. '
          'Monitor for fungal conditions in dense canopy crops.';
    }
    if (cloudCoverPct >= 50) {
      return 'Partly cloudy — diffuse light reduces heat stress on seedlings.';
    }
    if (cloudCoverPct >= 20) {
      return 'Mostly clear — good photosynthesis conditions for all crops.';
    }
    return 'Clear sky — maximum sunlight. Water crops to offset heat.';
  }

  String get pressureContext {
    if (pressureHpa >= 1020) {
      return 'High pressure — stable, settled weather expected.';
    }
    if (pressureHpa >= 1000) {
      return 'Normal pressure — weather conditions are stable.';
    }
    return 'Low pressure — unsettled weather, possible rain or storms ahead.';
  }

  List<String> get farmingAdvisories {
    final tips = <String>[];

    // Rain advisory
    if (rainfallNext24hMm >= 10) {
      tips.add(
        'Rain expected (${rainfallNext24hMm.toStringAsFixed(1)} mm / 24h) — '
        'delay fertilizer and pesticide applications.',
      );
    } else if (rainfallNext24hMm < 1 && humidity < 45) {
      tips.add(
        'Dry conditions — irrigate crops, especially seedlings and '
        'flowering plants.',
      );
    } else {
      tips.add('Good overall conditions for field work today.');
    }

    // Humidity / disease advisory
    if (humidity >= 80) {
      tips.add(
        'High humidity (${humidity}%) — inspect crops for early signs of '
        'blight, rust, or mildew. Consider preventive fungicide.',
      );
    } else if (humidity < 40) {
      tips.add(
        'Low humidity — spider mites and aphids thrive in dry conditions. '
        'Check undersides of leaves.',
      );
    }

    // Temperature advisory
    if (temperatureC >= 35) {
      tips.add(
        'Heat stress risk (${temperatureC.round()}°C) — water crops before '
        '9 am and after 4 pm. Mulch to cool soil.',
      );
    } else if (temperatureC < 18) {
      tips.add(
        'Cool temperatures — plant growth will be slow. '
        'Hold off transplanting until temperatures rise.',
      );
    }

    // Wind advisory
    if (windSpeedKmh >= 25) {
      tips.add('Strong winds — avoid spraying until winds drop below 15 km/h.');
    }

    return tips.take(3).toList();
  }
}
