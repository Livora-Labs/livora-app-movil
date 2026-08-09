import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    // El registro no devuelve token: iniciamos sesión de inmediato.
    await login(email, password);
  }

  Future<void> logout() async {
    _api.authToken = null;
    _user = null;
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_userKey);
    notifyListeners();
  }
}
