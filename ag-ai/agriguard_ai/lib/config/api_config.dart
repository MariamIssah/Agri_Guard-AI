/// API keys via --dart-define at run/build time.
///
/// Example:
/// flutter run --dart-define=OPENWEATHER_API_KEY=your_key_here
class ApiConfig {
  static const openWeatherApiKey = String.fromEnvironment(
    'OPENWEATHER_API_KEY',
    defaultValue: '49458ceca528cde928f113b06a7a29e4',
  );

  static const backendBaseUrl = String.fromEnvironment(
    'AGRI_GUARD_BACKEND_URL',
    defaultValue: 'http://127.0.0.1:8002',
  );

  static bool get hasWeatherApiKey => openWeatherApiKey.isNotEmpty;
}
