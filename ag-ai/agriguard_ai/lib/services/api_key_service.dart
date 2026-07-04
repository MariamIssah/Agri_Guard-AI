import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class ApiKeyService extends ChangeNotifier {
  static const _weatherKeyPref = 'openweather_api_key';
  static const _backendUrlPref  = 'backend_base_url';

  String? _openWeatherKey;
  String? _backendUrl;
  bool _loaded = false;

  String? get openWeatherKey => _openWeatherKey;
  bool get isLoaded => _loaded;

  bool get hasWeatherKey =>
      (_openWeatherKey != null && _openWeatherKey!.isNotEmpty) ||
      ApiConfig.openWeatherApiKey.isNotEmpty;

  String get effectiveWeatherKey =>
      _openWeatherKey?.trim().isNotEmpty == true
          ? _openWeatherKey!.trim()
          : ApiConfig.openWeatherApiKey;

  static const _productionUrl = 'https://agriguard-ai-production.up.railway.app';

  /// Always returns the production Railway URL — ignores any saved local URL.
  String get effectiveBackendUrl => _productionUrl;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _openWeatherKey = prefs.getString(_weatherKeyPref);
    final saved = prefs.getString(_backendUrlPref);
    // Auto-discard any malformed URL so the compile-time default takes over.
    _backendUrl = (saved != null && _isValidUrl(saved)) ? saved : null;
    if (saved != null && _backendUrl == null) {
      await prefs.remove(_backendUrlPref);
    }
    _loaded = true;
    notifyListeners();
  }

  static bool _isValidUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  Future<void> saveOpenWeatherKey(String key) async {
    final trimmed = key.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_weatherKeyPref, trimmed);
    _openWeatherKey = trimmed;
    notifyListeners();
  }

  Future<void> clearOpenWeatherKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_weatherKeyPref);
    _openWeatherKey = null;
    notifyListeners();
  }

  /// Returns null on success, or an error message if the URL is invalid.
  Future<String?> saveBackendUrl(String url) async {
    final trimmed = url.trim().replaceAll(RegExp(r'/$'), '');
    if (!_isValidUrl(trimmed)) {
      return 'Invalid URL — must start with http:// or https:// and have a valid host';
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backendUrlPref, trimmed);
    _backendUrl = trimmed;
    notifyListeners();
    return null;
  }

  Future<void> clearBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_backendUrlPref);
    _backendUrl = null;
    notifyListeners();
  }
}
