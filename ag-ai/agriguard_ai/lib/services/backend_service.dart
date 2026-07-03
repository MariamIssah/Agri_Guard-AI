import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'api_key_service.dart';

class BackendException implements Exception {
  BackendException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BackendService {
  /// Pass [apiKeyService] so the service picks up the runtime-saved URL.
  /// Falls back to compile-time [ApiConfig.backendBaseUrl] when not provided.
  BackendService({String? baseUrl, ApiKeyService? apiKeyService})
      : _baseUrl = baseUrl ??
            apiKeyService?.effectiveBackendUrl ??
            ApiConfig.backendBaseUrl;

  final String _baseUrl;

  Uri _ep(String path) => Uri.parse('$_baseUrl$path');

  // ── Auth ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> authRegister(Map<String, dynamic> payload) =>
      _post('/api/auth/register', payload);

  Future<Map<String, dynamic>> authLogin({
    required String email,
    required String password,
  }) =>
      _post('/api/auth/login', {'email': email, 'password': password});

  Future<Map<String, dynamic>> deleteAccount(String userId) async {
    final uri = _ep('/api/auth/delete-account')
        .replace(queryParameters: {'user_id': userId});
    final response = await http.delete(uri).timeout(const Duration(seconds: 15));
    return _handleResponse(response);
  }

  // ── Farm diary ────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> submitDiaryEntry(Map<String, dynamic> payload) =>
      _post('/api/diary', payload);

  Future<Map<String, dynamic>> getMyDiary(String farmerId) async {
    final uri = _ep('/api/diary/my-entries')
        .replace(queryParameters: {'farmer_id': farmerId});
    return _get(uri);
  }

  Future<Map<String, dynamic>> hideDiaryEntry({
    required String farmerId,
    required int entryId,
  }) async {
    final uri = _ep('/api/diary/hide').replace(queryParameters: {
      'farmer_id': farmerId,
      'entry_id': entryId.toString(),
    });
    final response = await http.delete(uri).timeout(const Duration(seconds: 15));
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getInSeasonForecast({
    required String farmerId,
    required String crop,
    required String plantingDate,
    double areaHectares = 1.0,
  }) async {
    final uri = _ep('/api/diary/in-season-forecast').replace(queryParameters: {
      'farmer_id': farmerId,
      'crop': crop,
      'planting_date': plantingDate,
      'area_hectares': areaHectares.toString(),
    });
    return _get(uri);
  }

  // ── Admin ─────────────────────────────────────────────────────────────────
  static const _adminKey = 'agriguard2025';

  Future<Map<String, dynamic>> adminStats() async {
    final uri = _ep('/api/admin/stats')
        .replace(queryParameters: {'admin_key': _adminKey});
    return _get(uri);
  }

  Future<Map<String, dynamic>> adminUsers({bool includeDeleted = true}) async {
    final uri = _ep('/api/admin/users').replace(queryParameters: {
      'admin_key': _adminKey,
      'include_deleted': includeDeleted.toString(),
    });
    return _get(uri);
  }

  Future<Map<String, dynamic>> adminSubmissions({bool includeHidden = true}) async {
    final uri = _ep('/api/admin/submissions').replace(queryParameters: {
      'admin_key': _adminKey,
      'include_hidden': includeHidden.toString(),
    });
    return _get(uri);
  }

  Future<Map<String, dynamic>> adminDiary({bool includeHidden = true}) async {
    final uri = _ep('/api/admin/diary').replace(queryParameters: {
      'admin_key': _adminKey,
      'include_hidden': includeHidden.toString(),
    });
    return _get(uri);
  }

  Future<Map<String, dynamic>> adminBuyerActivity({int limit = 500}) async {
    final uri = _ep('/api/admin/buyer-activity').replace(queryParameters: {
      'admin_key': _adminKey,
      'limit': limit.toString(),
    });
    return _get(uri);
  }

  // ── Buyer own activity history ────────────────────────────────────────────
  Future<Map<String, dynamic>> getMyActivity(String buyerId) async {
    final uri = _ep('/api/buyer/my-activity')
        .replace(queryParameters: {'buyer_id': buyerId});
    return _get(uri);
  }

  Future<Map<String, dynamic>> deleteActivityEntry({
    required String buyerId,
    required int entryId,
  }) async {
    final uri = _ep('/api/buyer/activity/entry').replace(queryParameters: {
      'buyer_id': buyerId,
      'entry_id': entryId.toString(),
    });
    final response = await http.delete(uri).timeout(const Duration(seconds: 15));
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> clearMyActivity(String buyerId) async {
    final uri = _ep('/api/buyer/activity/clear')
        .replace(queryParameters: {'buyer_id': buyerId});
    final response = await http.delete(uri).timeout(const Duration(seconds: 15));
    return _handleResponse(response);
  }

  // ── Profile update ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> updateProfile({
    required String userId,
    String? name,
    String? phone,
    String? region,
    String? district,
  }) =>
      _put('/api/auth/update-profile', {
        'user_id':  userId,
        if (name     != null) 'name':     name,
        if (phone    != null) 'phone':    phone,
        if (region   != null) 'region':   region,
        if (district != null) 'district': district,
      });

  // ── Buyer activity logging (fire-and-forget) ──────────────────────────────
  void logBuyerActivity({
    required String buyerId,
    required String action,
    String? screen,
    String? crop,
    String? region,
    String? district,
    String? itemId,
    String? query,
    Map<String, dynamic>? details,
  }) {
    // Fire and forget — never block the UI or throw
    _post('/api/buyer/activity', {
      'buyer_id': buyerId,
      'action':   action,
      if (screen   != null) 'screen':   screen,
      if (crop     != null) 'crop':     crop,
      if (region   != null) 'region':   region,
      if (district != null) 'district': district,
      if (itemId   != null) 'item_id':  itemId,
      if (query    != null) 'query':    query,
      if (details  != null) 'details':  details,
    }).catchError((_) {});
  }

  // ── Farm data ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> submitFarmData(Map<String, dynamic> payload) =>
      _post('/api/submit-farm-data', payload);

  // ── Yield prediction (legacy) ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getPrediction(Map<String, dynamic> payload) =>
      _post('/api/get-prediction', payload);

  // ── Pre-harvest prediction ────────────────────────────────────────────────
  Future<Map<String, dynamic>> predictPreHarvest(Map<String, dynamic> payload) {
    // Server expects 'area' (float); callers may send 'area_hectares' — normalise here.
    final mapped = Map<String, dynamic>.from(payload);
    if (mapped.containsKey('area_hectares') && !mapped.containsKey('area')) {
      mapped['area'] = mapped.remove('area_hectares');
    }
    return _post('/api/get-prediction', mapped);
  }

  // ── Post-harvest actual update ────────────────────────────────────────────
  Future<Map<String, dynamic>> submitPostHarvest(Map<String, dynamic> payload) =>
      _post('/api/predict/post-harvest', payload);

  // ── Harvest actuals (buyers) ──────────────────────────────────────────────
  Future<Map<String, dynamic>> getHarvestActuals({
    String? crop,
    String? region,
    String? district,
    int? year,
  }) async {
    final params = <String, String>{};
    if (crop != null) params['crop'] = crop;
    if (region != null) params['region'] = region;
    if (district != null) params['district'] = district;
    if (year != null) params['year'] = year.toString();

    final uri = _ep('/api/harvest/actuals').replace(queryParameters: params);
    return _get(uri);
  }

  // ── Regional forecast (ML model + FAOSTAT) ───────────────────────────────
  Future<Map<String, dynamic>> getRegionalForecast({int? year}) async {
    final params = <String, String>{};
    if (year != null) params['year'] = year.toString();
    final uri = _ep('/api/regional-forecast').replace(queryParameters: params);
    return _get(uri);
  }

  // ── Buyer aggregation ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>> buyerPredict(Map<String, dynamic> payload) =>
      _post('/api/buyer-predict', payload);

  // ── Disease diagnosis (text) ──────────────────────────────────────────────
  Future<Map<String, dynamic>> diagnoseDisease(Map<String, dynamic> payload) =>
      _post('/api/diagnose-disease', payload);

  // ── Disease diagnosis (image via base64) ─────────────────────────────────
  Future<Map<String, dynamic>> diagnoseDiseaseImage(Map<String, dynamic> payload) =>
      _post('/api/diagnose-disease-image', payload);

  // ── Disease diagnosis (image file multipart) ──────────────────────────────
  Future<Map<String, dynamic>> diagnoseDiseaseImageFile(
    File imageFile, {
    String? statedCrop,
  }) async {
    final request = http.MultipartRequest('POST', _ep('/api/diagnose-disease-image'));
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    if (statedCrop != null && statedCrop.isNotEmpty) {
      request.fields['stated_crop'] = statedCrop;
    }
    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    return _handleResponse(response);
  }

  // ── Farmer's own harvest submissions ─────────────────────────────────────
  Future<Map<String, dynamic>> getMySubmissions(String farmerId) async {
    final uri = _ep('/api/harvest/my-submissions')
        .replace(queryParameters: {'farmer_id': farmerId});
    return _get(uri);
  }

  Future<Map<String, dynamic>> hideSubmission({
    required String farmerId,
    required String submittedAt,
  }) async {
    final uri = _ep('/api/harvest/hide').replace(queryParameters: {
      'farmer_id': farmerId,
      'submitted_at': submittedAt,
    });
    final response = await http.delete(uri).timeout(const Duration(seconds: 15));
    return _handleResponse(response);
  }

  // ── Model retraining (admin / authorised trigger) ─────────────────────────
  Future<Map<String, dynamic>> triggerRetrain({
    String? historicalPath,
    String? submissionsPath,
    String? outputPath,
  }) async {
    final body = <String, dynamic>{};
    if (historicalPath != null) body['historical_path'] = historicalPath;
    if (submissionsPath != null) body['submissions_path'] = submissionsPath;
    if (outputPath != null) body['output_path'] = outputPath;
    return _post('/api/retrain', body);
  }

  // ── Health check ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> health() async {
    final response = await http.get(_ep('/health')).timeout(const Duration(seconds: 10));
    return _handleResponse(response);
  }

  // ── Internals ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> payload) async {
    final response = await http.put(
      _ep(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 20));
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> payload) async {
    final response = await http.post(
      _ep(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 30));
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = response.body.isNotEmpty
        ? jsonDecode(response.body) as Map<String, dynamic>
        : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) return body;

    final msg = body['error'] ?? body['detail'] ?? body['message'] ?? response.reasonPhrase ?? 'Request failed';
    throw BackendException(msg.toString());
  }
}
