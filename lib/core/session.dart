import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';

import '../models/models.dart';
import 'api_client.dart';

/// Estado de autenticación de la app (token JWT + usuario actual).
class SessionController extends ChangeNotifier {
  SessionController(this._api, this._prefs);

  static const _tokenKey = 'livora_token';
  static const _userKey = 'livora_user';

  final ApiClient _api;
  final SharedPreferences _prefs;

  AuthUser? _user;

  AuthUser? get user => _user;
  bool get isAuthenticated => _user != null;

  /// Restaura la sesión guardada al abrir la app.
  Future<void> restore() async {
    final token = _prefs.getString(_tokenKey);
    final rawUser = _prefs.getString(_userKey);
    if (token == null || rawUser == null) return;
    try {
      _api.authToken = token;
      _user = AuthUser.fromJson(jsonDecode(rawUser) as Map<String, dynamic>);
    } catch (_) {
      await logout();
    }
  }

  Future<void> login(String email, String password) async {
    final data = await _api.post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    if (data is! Map<String, dynamic>) {
      throw ApiException('Respuesta de inicio de sesión inválida');
    }
    final token = data['accessToken'] as String?;
    final userJson = data['user'];
    if (token == null || userJson is! Map<String, dynamic>) {
      throw ApiException('Respuesta de inicio de sesión inválida');
    }
    _api.authToken = token;
    _user = AuthUser.fromJson(userJson);
    await _prefs.setString(_tokenKey, token);
    await _prefs.setString(_userKey, jsonEncode(_user!.toJson()));
    notifyListeners();
  }

  Future<void> register({
    required String email,
    required String password,
    required String role,
  }) async {
    await _api.post(
      '/auth/register',
      body: {'email': email, 'password': password, 'role': role},
    );
  }

  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    final data = await _api.post(
      '/auth/verify-email',
      body: {'email': email, 'code': code},
    );
    if (data is! Map<String, dynamic>) {
      throw ApiException('Respuesta de verificación de correo inválida');
    }
    final token = data['accessToken'] as String?;
    final userJson = data['user'];
    if (token == null || userJson is! Map<String, dynamic>) {
      throw ApiException('Respuesta de verificación de correo inválida');
    }
    _api.authToken = token;
    _user = AuthUser.fromJson(userJson);
    await _prefs.setString(_tokenKey, token);
    await _prefs.setString(_userKey, jsonEncode(_user!.toJson()));
    notifyListeners();
  }

  Future<void> resendOtp({required String email}) async {
    await _api.post(
      '/auth/resend-otp',
      body: {'email': email},
    );
  }

  Future<void> logout() async {
    _api.authToken = null;
    _user = null;
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_userKey);

    // Purga completa de base de datos local Hive
    try {
      if (Hive.isBoxOpen('offline_verifications')) {
        await Hive.box('offline_verifications').clear();
      } else {
        final box = await Hive.openBox('offline_verifications');
        await box.clear();
      }
    } catch (e) {
      debugPrint('Error al limpiar base de datos local Hive: $e');
    }

    notifyListeners();
  }
}
