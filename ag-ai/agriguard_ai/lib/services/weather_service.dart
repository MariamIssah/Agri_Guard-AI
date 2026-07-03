import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather_data.dart';
import '../utils/location_matcher.dart';

class WeatherException implements Exception {
  WeatherException(this.message, {this.isInvalidKey = false});
  final String message;
  final bool isInvalidKey;

  @override
  String toString() => message;
}

class WeatherService {
  static const _baseUrl = 'https://api.openweathermap.org/data/2.5';

  Future<WeatherData> fetchWeather({
    required String apiKey,
    required double latitude,
    required double longitude,
    String? locationLabel,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw WeatherException('OpenWeather API key is required.');
    }

    final currentUri = Uri.parse(
      '$_baseUrl/weather?lat=$latitude&lon=$longitude'
      '&appid=${apiKey.trim()}&units=metric',
    );
    final forecastUri = Uri.parse(
      '$_baseUrl/forecast?lat=$latitude&lon=$longitude'
      '&appid=${apiKey.trim()}&units=metric&cnt=8',
    );

    final responses = await Future.wait([
      http.get(currentUri).timeout(const Duration(seconds: 20)),
      http.get(forecastUri).timeout(const Duration(seconds: 20)),
    ]);

    final currentResponse = responses[0];
    final forecastResponse = responses[1];

    if (currentResponse.statusCode != 200) {
      final msg = _parseError(currentResponse.body) ??
          'Weather request failed (${currentResponse.statusCode})';
      throw WeatherException(
        msg,
        isInvalidKey: currentResponse.statusCode == 401 ||
            msg.toLowerCase().contains('invalid api key') ||
            msg.toLowerCase().contains('unauthorized'),
      );
    }
    if (forecastResponse.statusCode != 200) {
      final msg = _parseError(forecastResponse.body) ??
          'Forecast request failed (${forecastResponse.statusCode})';
      throw WeatherException(
        msg,
        isInvalidKey: forecastResponse.statusCode == 401 ||
            msg.toLowerCase().contains('invalid api key') ||
            msg.toLowerCase().contains('unauthorized'),
      );
    }

    final current = jsonDecode(currentResponse.body) as Map<String, dynamic>;
    final forecast = jsonDecode(forecastResponse.body) as Map<String, dynamic>;

    final main = current['main'] as Map<String, dynamic>;
    final wind = current['wind'] as Map<String, dynamic>? ?? {};
    final weatherList = current['weather'] as List<dynamic>;
    final weather = weatherList.first as Map<String, dynamic>;

    final rainNext24h = _sumForecastRain(forecast);

    final label = locationLabel ??
        (current['name'] as String?) ??
        'Lat ${latitude.toStringAsFixed(2)}, Lon ${longitude.toStringAsFixed(2)}';

    final windDeg = (wind['deg'] as num?)?.toDouble() ?? 0;

    return WeatherData(
      temperatureC: (main['temp'] as num).toDouble(),
      feelsLikeC: (main['feels_like'] as num).toDouble(),
      humidity: (main['humidity'] as num).round(),
      windSpeedKmh: ((wind['speed'] as num?)?.toDouble() ?? 0) * 3.6,
      windDirection: windDirectionFromDegrees(windDeg),
      description: _capitalize(weather['description'] as String? ?? ''),
      locationLabel: label,
      rainfallNext24hMm: rainNext24h,
      updatedAt: DateTime.now(),
      iconCode: weather['icon'] as String? ?? '01d',
    );
  }

  double _sumForecastRain(Map<String, dynamic> forecast) {
    final list = forecast['list'] as List<dynamic>? ?? [];
    var total = 0.0;
    for (final item in list) {
      final map = item as Map<String, dynamic>;
      final rain = map['rain'] as Map<String, dynamic>?;
      if (rain != null) {
        total += (rain['3h'] as num?)?.toDouble() ?? 0;
      }
    }
    return total;
  }

  String? _parseError(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['message'] as String?;
    } catch (_) {
      return null;
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
