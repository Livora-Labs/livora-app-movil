import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/livora_api.dart';
import '../services/offline_queue_manager.dart';
import 'api_client.dart';
import 'formats.dart';

/// Estado de autenticación de la app (sesión Supabase + usuario actual).
class SessionController extends ChangeNotifier {
  SessionController(this._api, this._prefs) {
    _api.onTokenExpired = _refreshSession;
  }

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _tokenKey = 'livora_token';
  static const _refreshTokenKey = 'livora_refresh_token';
  static const _expiresAtKey = 'livora_token_expires_at';
  static const _userKey = 'livora_user';
  static const _kycStatusKey = 'livora_kyc_status';

  final ApiClient _api;
  final SharedPreferences _prefs;

  AuthUser? _user;
  String? _refreshToken;
  DateTime? _expiresAt;
  Future<String?>? _inFlightRefresh;
  CollectionRequest? _activeRequest;
  KycStatus _kycStatus = KycStatus.unverified;

  /// Callback opcional invocado al cerrar sesión o eliminar la cuenta (desconecta sockets, etc.).
  VoidCallback? onLogout;

  AuthUser? get user => _user;
  bool get isAuthenticated => _user != null;

  /// Estado de verificación de identidad KYC para el usuario (recolector).
  KycStatus get kycStatus => _kycStatus;

  /// Solicitud de recolección en curso para el hogar actual (si existe).
  CollectionRequest? get activeRequest => _activeRequest;

  /// `true` cuando existe una orden en curso ('PENDING', 'ACCEPTED', 'AUCTION_OPEN', etc.).
  bool get hasActiveRequest => _activeRequest != null;

  /// Actualiza la solicitud activa global y notifica a los observadores.
  void updateActiveRequest(CollectionRequest? req) {
    if (_activeRequest?.id != req?.id ||
        _activeRequest?.status != req?.status ||
        _activeRequest?.bids.length != req?.bids.length ||
        _activeRequest?.collectorName != req?.collectorName) {
      _activeRequest = req;
      notifyListeners();
    }
  }

  /// Actualiza el estado KYC y lo persiste localmente.
  void updateKycStatus(KycStatus status) {
    if (_kycStatus != status) {
      _kycStatus = status;
      _prefs.setString(_kycStatusKey, status.toBackendString());
      notifyListeners();
    }
  }

  /// Consulta el estado KYC actualizado del recolector en el backend.
  Future<void> refreshKycStatus(LivoraApi api) async {
    if (_user?.role != Roles.recolector) return;
    try {
      final app = await api.kycApplication();
      updateKycStatus(app.kycStatus);
    } catch (_) {
      // Si falla la red, preserva el estado guardado en SharedPreferences
    }
  }

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

  /// Restaura la sesión guardada al abrir la app de forma segura.
  Future<void> restore() async {
    final token = await _secureStorage.read(key: _tokenKey) ??
        _prefs.getString(_tokenKey);
    final rawUser = _prefs.getString(_userKey);
    if (token == null || rawUser == null) return;
    try {
      _api.authToken = token;
      _user = AuthUser.fromJson(jsonDecode(rawUser) as Map<String, dynamic>);
      if (_user?.role == 'ADMIN' || _user?.role == 'EMPRESA_B2B') {
        await logout();
        return;
      }
      _refreshToken = await _secureStorage.read(key: _refreshTokenKey) ??
          _prefs.getString(_refreshTokenKey);
      final expiresAt = _prefs.getString(_expiresAtKey);
      _expiresAt = expiresAt == null ? null : DateTime.tryParse(expiresAt);
      final kycRaw = _prefs.getString(_kycStatusKey);
      _kycStatus = KycStatus.fromString(kycRaw);
    } catch (_) {
      await logout();
      return;
    }
    // Si el token guardado ya venció, renovamos antes de mostrar la app para
    // que el usuario no vea errores en la primera pantalla.
    if (isTokenExpired) await _refreshSession();
  }

  /// Canjea el refresh token por una sesión nueva de forma atómica y deduplicada.
  /// Devuelve el nuevo access token, o `null` si no se pudo renovar (en cuyo caso cierra la sesión).
  Future<String?> _refreshSession() {
    if (_inFlightRefresh != null) {
      return _inFlightRefresh!;
    }
    _inFlightRefresh = _performRefresh();
    return _inFlightRefresh!;
  }

  Future<String?> _performRefresh() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) {
      _inFlightRefresh = null;
      return null;
    }
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
    } catch (_) {
      await logout();
      return null;
    } finally {
      _inFlightRefresh = null;
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
    String? termsVersion,
    String? privacyVersion,
    String? documentHash,
    bool marketingAccepted = false,
  }) async {
    await _api.post(
      '/auth/register',
      body: {
        'email': email,
        'password': password,
        'role': role,
        if (termsVersion != null) 'termsVersion': termsVersion,
        if (privacyVersion != null) 'privacyVersion': privacyVersion,
        if (documentHash != null) 'documentHash': documentHash,
        'marketingAccepted': marketingAccepted,
      },
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

    final candidateUser = AuthUser.fromJson(userJson);
    if (candidateUser.role == 'ADMIN' || candidateUser.role == 'EMPRESA_B2B') {
      throw const WebExclusiveRoleException();
    }

    _api.authToken = token;
    _user = candidateUser;
    _refreshToken = data['refreshToken'] as String?;
    final expiresIn = (data['expiresIn'] as num?)?.toInt();
    _expiresAt = expiresIn == null
        ? null
        : DateTime.now().add(Duration(seconds: expiresIn));

    // Guardar tokens cifrados por hardware (EncryptedSharedPreferences / Keychain)
    await _secureStorage.write(key: _tokenKey, value: token);
    await _prefs.remove(_tokenKey);

    await _prefs.setString(_userKey, jsonEncode(_user!.toJson()));
    if (_refreshToken != null) {
      await _secureStorage.write(key: _refreshTokenKey, value: _refreshToken!);
      await _prefs.remove(_refreshTokenKey);
    } else {
      await _secureStorage.delete(key: _refreshTokenKey);
      await _prefs.remove(_refreshTokenKey);
    }
    if (_expiresAt != null) {
      await _prefs.setString(_expiresAtKey, _expiresAt!.toIso8601String());
    } else {
      await _prefs.remove(_expiresAtKey);
    }
    notifyListeners();
  }

  /// Elimina la cuenta (Ley N.° 29733 - ARCO) y purga toda la sesión y base de datos local.
  Future<void> deleteAccount() async {
    try {
      await _api.delete('/users/me');
    } finally {
      await logout();
    }
  }

  /// Cierra la sesión, purga SharedPreferences, vacía Hive y notifica a los observadores.
  Future<void> logout() async {
    _api.authToken = null;
    _user = null;
    _refreshToken = null;
    _expiresAt = null;
    _inFlightRefresh = null;
    _activeRequest = null;
    _kycStatus = KycStatus.unverified;

    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_refreshTokenKey);
    await _prefs.remove(_expiresAtKey);
    await _prefs.remove(_userKey);
    await _prefs.remove(_kycStatusKey);

    // Purga completa de base de datos local Hive y reset de contadores offline
    await OfflineQueueManager.clearQueue();

    // Notificación a observadores externos (ej. desconexión de Socket.IO)
    onLogout?.call();

    notifyListeners();
  }
}

/// Excepción lanzada cuando una cuenta exclusiva de escritorio/web intenta iniciar sesión en móvil.
class WebExclusiveRoleException implements Exception {
  const WebExclusiveRoleException();

  String get message =>
      'Acceso exclusivo web: Las cuentas de Empresa B2B y Administrador deben gestionarse desde la plataforma web de Livora.';

  @override
  String toString() => message;
}
