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
    defaultValue: 'https://agriguard-ai-production.up.railway.app',
  );

  // Google Web Client ID — paste the value from Google Cloud Console →
  // APIs & Services → Credentials → your Web OAuth 2.0 Client ID
  // It ends with .apps.googleusercontent.com
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '594118918172-0gfg5g2hhp31078g2g7ln2p1hh7ec8ij.apps.googleusercontent.com',
  );

  static bool get hasWeatherApiKey => openWeatherApiKey.isNotEmpty;
  static bool get hasGoogleClientId => googleWebClientId.isNotEmpty;
}
