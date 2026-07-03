import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import 'backend_service.dart';

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthService extends ChangeNotifier {
  static const _sessionKey = 'agri_session_v2';

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.role == UserRole.admin;

  final BackendService _backend;

  AuthService(this._backend);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_sessionKey);
    if (json != null) {
      try {
        _currentUser = UserModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
      } catch (_) {
        _currentUser = null;
      }
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required UserRole role,
    String? region,
    String? district,
    double? farmSizeHa,
  }) async {
    final id = 'AGRI-${DateTime.now().millisecondsSinceEpoch}';
    try {
      final res = await _backend.authRegister({
        'id': id,
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'phone': phone.trim(),
        'password': password,
        'role': role.name,
        'region': region,
        'district': district,
        'farm_size_ha': farmSizeHa,
      });
      final user = UserModel.fromJson(res['user'] as Map<String, dynamic>);
      await _saveSession(user);
    } on BackendException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw AuthException('Registration failed. Check your connection and try again.');
    }
  }

  Future<void> login({required String email, required String password}) async {
    try {
      final res = await _backend.authLogin(email: email.trim(), password: password);
      final user = UserModel.fromJson(res['user'] as Map<String, dynamic>);
      await _saveSession(user);
    } on BackendException catch (e) {
      final msg = e.message == 'invalid_credentials'
          ? 'Incorrect email or password.'
          : e.message;
      throw AuthException(msg);
    } catch (e) {
      throw AuthException('Login failed. Check your connection and try again.');
    }
  }

  Future<void> updateProfile({
    String? name,
    String? phone,
    String? region,
    String? district,
  }) async {
    final user = _currentUser;
    if (user == null) return;
    try {
      final res = await _backend.updateProfile(
        userId: user.id,
        name: name,
        phone: phone,
        region: region,
        district: district,
      );
      final updated = UserModel.fromJson(res['user'] as Map<String, dynamic>);
      await _saveSession(updated);
    } on BackendException catch (e) {
      throw AuthException(e.message);
    }
  }

  Future<void> deleteAccount() async {
    final user = _currentUser;
    if (user == null) return;
    try {
      await _backend.deleteAccount(user.id);
    } on BackendException catch (e) {
      throw AuthException(e.message);
    }
    await logout();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    _currentUser = null;
    notifyListeners();
  }

  Future<void> _saveSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(user.toJson()));
    _currentUser = user;
    notifyListeners();
  }
}
