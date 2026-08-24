import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';

import '../models/models.dart';
import 'api_client.dart';

/// Estado de autenticación de la app (sesión Supabase + usuario actual).
class SessionController extends ChangeNotifier {
  SessionController(this._api, this._prefs) {
    _api.onTokenExpired = _refreshSession;
  }

  static const _tokenKey = 'livora_token';
  static const _refreshTokenKey = 'livora_refresh_token';
  static const _expiresAtKey = 'livora_token_expires_at';
  static const _userKey = 'livora_user';

  final ApiClient _api;
  final SharedPreferences _prefs;

  AuthUser? _user;
  String? _refreshToken;
  DateTime? _expiresAt;
  bool _refreshing = false;

  AuthUser? get user => _user;
  bool get isAuthenticated => _user != null;

  /// Token de refresco emitido por Supabase; se canjea en `POST /auth/refresh`
  /// por una sesión nueva. Supabase lo rota en cada uso, así que siempre se
  /// guarda el último recibido.
  String? get refreshToken => _refreshToken;

  /// Momento en el que caduca el `accessToken` (login + `expiresIn`).
  DateTime? get expiresAt => _expiresAt;

  /// `true` cuando el access token ya caducó (o está por caducar en <1 min).
  bool get isTokenExpired {
    final expiresAt = _expiresAt;
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(
      expiresAt.subtract(const Duration(minutes: 1)),
    );
  }

  /// Restaura la sesión guardada al abrir la app.
  Future<void> restore() async {
    final token = _prefs.getString(_tokenKey);
    final rawUser = _prefs.getString(_userKey);
    if (token == null || rawUser == null) return;
    try {
      _api.authToken = token;
      _user = AuthUser.fromJson(jsonDecode(rawUser) as Map<String, dynamic>);
      _refreshToken = _prefs.getString(_refreshTokenKey);
      final expiresAt = _prefs.getString(_expiresAtKey);
      _expiresAt = expiresAt == null ? null : DateTime.tryParse(expiresAt);
    } catch (_) {
      await logout();
      return;
    }
    // Si el token guardado ya venció, renovamos antes de mostrar la app para
    // que el usuario no vea errores en la primera pantalla.
    if (isTokenExpired) await _refreshSession();
  }

  /// Canjea el refresh token por una sesión nueva. Devuelve el nuevo access
  /// token, o `null` si no se pudo renovar (en cuyo caso cierra la sesión).
  ///
  /// La engancha [ApiClient.onTokenExpired]: cualquier 401 dispara un intento
  /// de renovación y repite la petición original una sola vez.
  Future<String?> _refreshSession() async {
    final refreshToken = _refreshToken;
    // El propio /auth/refresh puede responder 401; el flag evita reentrar.
    if (refreshToken == null || _refreshing) return null;
    _refreshing = true;
    try {
      final data = await _api.post(
        '/auth/refresh',
        body: {'refreshToken': refreshToken},
      );
      await _startSession(data, 'Respuesta de renovación de sesión inválida');
      return _api.authToken;
    } on ApiException {
      // Refresh vencido o revocado: no hay forma de seguir, al login.
      await logout();
      return null;
    } finally {
      _refreshing = false;
    }
  }

  Future<void> login(String email, String password) async {
    final data = await _api.post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    await _startSession(data, 'Respuesta de inicio de sesión inválida');
  }

  /// Paso 1 del registro: el backend guarda los datos en Redis (TTL 10 min) y
  /// envía un OTP de 6 dígitos al correo. Todavía no hay cuenta ni token.
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

  /// Paso 2 del registro: valida el OTP, crea la cuenta y abre la sesión.
  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    final data = await _api.post(
      '/auth/verify-email',
      body: {'email': email, 'code': code},
    );
    await _startSession(data, 'Respuesta de verificación inválida');
  }

  /// Reenvía el OTP. El backend aplica un cooldown de 60 s.
  Future<void> resendOtp(String email) async {
    await _api.post('/auth/resend-otp', body: {'email': email});
  }

  /// Guarda tokens + perfil a partir de la respuesta de login/verify-email.
  Future<void> _startSession(dynamic data, String errorMessage) async {
    if (data is! Map<String, dynamic>) throw ApiException(errorMessage);
    final token = data['accessToken'] as String?;
    final userJson = data['user'];
    if (token == null || userJson is! Map<String, dynamic>) {
      throw ApiException(errorMessage);
    }

    _api.authToken = token;
    _user = AuthUser.fromJson(userJson);
    _refreshToken = data['refreshToken'] as String?;
    final expiresIn = (data['expiresIn'] as num?)?.toInt();
    _expiresAt = expiresIn == null
        ? null
        : DateTime.now().add(Duration(seconds: expiresIn));

    await _prefs.setString(_tokenKey, token);
    await _prefs.setString(_userKey, jsonEncode(_user!.toJson()));
    if (_refreshToken != null) {
      await _prefs.setString(_refreshTokenKey, _refreshToken!);
    } else {
      await _prefs.remove(_refreshTokenKey);
    }
    if (_expiresAt != null) {
      await _prefs.setString(_expiresAtKey, _expiresAt!.toIso8601String());
    } else {
      await _prefs.remove(_expiresAtKey);
    }
    notifyListeners();
  }

  /// Elimina la cuenta (GDPR) y cierra la sesión localmente.
  Future<void> deleteAccount() async {
    await _api.delete('/users/me');
    await logout();
  }

  Future<void> logout() async {
    _api.authToken = null;
    _user = null;
    _refreshToken = null;
    _expiresAt = null;
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_refreshTokenKey);
    await _prefs.remove(_expiresAtKey);
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
