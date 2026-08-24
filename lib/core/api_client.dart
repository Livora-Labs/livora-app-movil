import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:shared_preferences/shared_preferences.dart';
import 'env_config.dart';

/// Error de la API de Livora con mensaje legible para el usuario.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;

  /// Código de negocio del backend: `{ "error": { "code": "...", ... } }`.
  final String? code;

  bool get isUnauthorized => statusCode == 401;
  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => message;
}

/// Cliente HTTP hacia el backend NestJS de Livora.
class ApiClient {
  ApiClient(this._prefs, {http.Client? client})
      : _client = client ?? http.Client();

  static const _baseUrlKey = 'livora_base_url';
  static const _legacyBaseUrlMigratedKey = 'livora_base_url_stellar_migrated';

  /// URLs del entorno Arbitrum que quedaron guardadas en instalaciones previas.
  static const _legacyBaseUrls = {
    'http://52.200.2.107',
    'https://52.200.2.107',
    'https://52.200.2.107.sslip.io',
    'https://livora-api-service.onrender.com',
  };

  /// El backend limita a 100 peticiones por 60 s por IP (ThrottlerModule).
  /// Ante un 429 reintentamos con backoff en lugar de martillar el endpoint.
  static const _maxRateLimitRetries = 2;

  final SharedPreferences _prefs;
  final http.Client _client;
  String? authToken;

  /// Se invoca cuando una petición autenticada recibe 401. Debe intentar
  /// renovar la sesión (`POST /auth/refresh`) y devolver el nuevo access token,
  /// o `null` si no se pudo renovar. Lo enchufa [SessionController]; si
  /// devuelve un token, la petición original se reintenta una sola vez.
  Future<String?> Function()? onTokenExpired;

  /// API de producción sobre Stellar/Soroban (AWS EC2 + TLS por sslip.io).
  /// Para otro entorno cámbiala desde el diálogo "Servidor" de la app.
  static const defaultBaseUrl = EnvConfig.apiBaseUrl;

  String get baseUrl {
    final saved = _prefs.getString(_baseUrlKey);
    if (saved == null || saved.trim().isEmpty) return defaultBaseUrl;
    return saved.trim();
  }

  Future<void> setBaseUrl(String url) async {
    final cleaned = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (cleaned.isEmpty) {
      await _prefs.remove(_baseUrlKey);
    } else {
      await _prefs.setString(_baseUrlKey, cleaned);
    }
  }

  /// Migración única para instalaciones que ya tenían guardada la URL del
  /// entorno Arbitrum: se borra la preferencia para que caigan en el nuevo
  /// [defaultBaseUrl] de Stellar. Si el usuario vuelve a fijarla a mano desde
  /// el diálogo "Servidor", su elección se respeta (la migración no se repite).
  Future<void> migrateLegacyBaseUrl() async {
    if (_prefs.getBool(_legacyBaseUrlMigratedKey) == true) return;
    await _prefs.setBool(_legacyBaseUrlMigratedKey, true);

    final saved = _prefs.getString(_baseUrlKey)?.trim();
    if (saved == null) return;
    final normalized = saved.replaceAll(RegExp(r'/+$'), '').toLowerCase();
    if (_legacyBaseUrls.contains(normalized)) {
      await _prefs.remove(_baseUrlKey);
    }
  }

  Future<dynamic> get(String path, {Map<String, Object?>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<dynamic> delete(String path, {Object? body}) =>
      _send('DELETE', path, body: body);

  /// Sube un archivo por multipart. El backend expone `POST /uploads` con el
  /// campo `file` y un `purpose` que decide bucket y tipos permitidos.
  ///
  /// Comparte con [_send] el manejo de sesión: ante un 401 renueva el token y
  /// reintenta una sola vez.
  Future<dynamic> uploadFile(
    String path, {
    required String filePath,
    required String fieldName,
    Map<String, String> fields = const {},
    bool refreshed = false,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path, null));
    request.headers['Accept'] = 'application/json';
    if (authToken != null) {
      request.headers['Authorization'] = 'Bearer $authToken';
    }
    request.fields.addAll(fields);
    request.files.add(
      await http.MultipartFile.fromPath(
        fieldName,
        filePath,
        contentType: _mediaTypeFor(filePath),
      ),
    );

    http.Response response;
    try {
      final streamed = await _client.send(request).timeout(
            const Duration(seconds: 120),
          );
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException(
        'La subida tardó demasiado. Revisa tu conexión e inténtalo de nuevo.',
      );
    } on http.ClientException {
      throw ApiException(
        'No se pudo conectar con $baseUrl. Revisa la URL del servidor y tu conexión.',
      );
    }

    dynamic decoded;
    if (response.bodyBytes.isNotEmpty) {
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        decoded = null;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;

    if (response.statusCode == 401 &&
        !refreshed &&
        authToken != null &&
        onTokenExpired != null) {
      final renewedToken = await onTokenExpired!();
      if (renewedToken != null) {
        return uploadFile(
          path,
          filePath: filePath,
          fieldName: fieldName,
          fields: fields,
          refreshed: true,
        );
      }
    }

    throw ApiException(
      _errorMessage(decoded, response.statusCode),
      statusCode: response.statusCode,
      code: _errorCode(decoded),
    );
  }

  /// El backend valida el mime type contra una lista blanca por `purpose`, así
  /// que hay que declararlo: `MultipartFile` por defecto manda
  /// `application/octet-stream` y sería rechazado siempre.
  MediaType _mediaTypeFor(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    return switch (extension) {
      'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
      'png' => MediaType('image', 'png'),
      'pdf' => MediaType('application', 'pdf'),
      _ => MediaType('application', 'octet-stream'),
    };
  }

  /// Comprueba que el backend responde antes de operar (`GET /health`).
  Future<bool> healthCheck() async {
    try {
      final raw = await get('/health');
      return raw is Map && raw['status'] == 'ok';
    } on ApiException {
      return false;
    }
  }

  Uri _uri(String path, Map<String, Object?>? query) {
    final params = <String, String>{};
    query?.forEach((key, value) {
      if (value != null) params[key] = '$value';
    });
    return Uri.parse('$baseUrl$path')
        .replace(queryParameters: params.isEmpty ? null : params);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    int attempt = 0,
    bool refreshed = false,
  }) async {
    final request = http.Request(method, _uri(path, query));
    request.headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    if (authToken != null) {
      request.headers['Authorization'] = 'Bearer $authToken';
    }

    http.Response response;
    try {
      // Margen amplio: algunos entornos tardan en "despertar" tras inactividad.
      final streamed = await _client.send(request).timeout(
            const Duration(seconds: 60),
          );
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException(
        'El servidor no respondió. Si acaba de despertar, intenta de nuevo en '
        'unos segundos ($baseUrl).',
      );
    } on http.ClientException {
      throw ApiException(
        'No se pudo conectar con $baseUrl. Revisa la URL del servidor y tu conexión.',
      );
    }

    dynamic decoded;
    if (response.bodyBytes.isNotEmpty) {
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        decoded = null;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    // Rate limit (100 req / 60 s): esperamos y reintentamos con backoff.
    if (response.statusCode == 429 && attempt < _maxRateLimitRetries) {
      await Future<void>.delayed(_retryDelay(response, attempt));
      return _send(
        method,
        path,
        query: query,
        body: body,
        attempt: attempt + 1,
      );
    }

    if (response.statusCode == 429) {
      throw ApiException(
        'Demasiadas peticiones al servidor. Espera un momento y vuelve a intentarlo.',
        statusCode: 429,
        code: _errorCode(decoded),
      );
    }

    // El accessToken de Supabase vive 1 h. Ante un 401 en una petición
    // autenticada intentamos renovar la sesión una sola vez y repetimos.
    if (response.statusCode == 401 &&
        !refreshed &&
        authToken != null &&
        onTokenExpired != null) {
      final renewedToken = await onTokenExpired!();
      if (renewedToken != null) {
        return _send(
          method,
          path,
          query: query,
          body: body,
          attempt: attempt,
          refreshed: true,
        );
      }
    }

    if (response.statusCode == 401) {
      throw ApiException(
        'Tu sesión expiró o las credenciales no son válidas. Inicia sesión nuevamente.',
        statusCode: 401,
        code: _errorCode(decoded),
      );
    }

    throw ApiException(
      _errorMessage(decoded, response.statusCode),
      statusCode: response.statusCode,
      code: _errorCode(decoded),
    );
  }

  /// Respeta el header `Retry-After` del throttler; si no viene, backoff
  /// exponencial (2 s, 4 s) para no reintentar de inmediato.
  Duration _retryDelay(http.Response response, int attempt) {
    final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
    if (retryAfter != null && retryAfter > 0) {
      return Duration(seconds: min(retryAfter, 30));
    }
    return Duration(seconds: 2 * pow(2, attempt).toInt());
  }

  String? _errorCode(dynamic body) => apiErrorCode(body);

  String _errorMessage(dynamic body, int status) =>
      apiErrorMessage(body, status);
}

/// Extrae el `code` de `{ "error": { "code", ... } }`.
String? apiErrorCode(dynamic body) {
  if (body is Map) {
    final error = body['error'];
    if (error is Map) {
      final code = error['code'];
      if (code is String && code.isNotEmpty) return code;
    }
  }
  return null;
}

/// Convierte el cuerpo de error del backend en un mensaje para el usuario.
///
/// El filtro global de Livora responde
/// `{ "error": { "code", "message", "details"? } }`. En los errores de
/// validación `message` es genérico ("Error de validación en los parámetros de
/// entrada") y el motivo real viene en `details` como lista de strings, así que
/// `details` tiene prioridad.
String apiErrorMessage(dynamic body, int status) {
  String? joinIfList(dynamic value) {
    if (value is String && value.isNotEmpty) return value;
    if (value is List) {
      final items = value
          .map((item) => '$item')
          .where((item) => item.isNotEmpty)
          .toList();
      if (items.isNotEmpty) return items.join('\n');
    }
    return null;
  }

  String? cleanMessage(String? msg) {
    if (msg == null || msg.isEmpty) return null;
    final lower = msg.toLowerCase();
    if (lower == 'unauthorized' || lower.contains('invalid credentials') || lower.contains('jwt')) {
      return 'Credenciales incorrectas o sesión expirada. Por favor, inicia sesión de nuevo.';
    }
    if (lower == 'forbidden' || lower.contains('access denied') || lower.contains('missing permission')) {
      return 'No tienes permisos para realizar esta acción.';
    }
    if (lower == 'bad request') {
      return 'Solicitud incorrecta. Por favor, verifica los datos enviados.';
    }
    if (lower == 'not found' || lower.contains('route not found')) {
      return 'El recurso solicitado no fue encontrado.';
    }
    if (lower == 'internal server error' || lower.contains('database error')) {
      return 'Error interno en el servidor. Por favor, inténtalo de nuevo más tarde.';
    }
    return msg;
  }

  if (body is Map) {
    final error = body['error'];
    if (error is Map) {
      final details = joinIfList(error['details']);
      if (details != null) return details;
      final message = cleanMessage(joinIfList(error['message']));
      if (message != null) return message;
    }
    if (error is String && error.isNotEmpty) {
      final cleaned = cleanMessage(error);
      if (cleaned != null) return cleaned;
    }
    // Formato estándar de NestJS: { "message": "..." | ["...", ...] }
    final message = cleanMessage(joinIfList(body['message']));
    if (message != null) return message;
  }

  switch (status) {
    case 400:
      return 'Solicitud incorrecta. Por favor, verifica los datos enviados.';
    case 401:
      return 'Credenciales incorrectas o sesión expirada. Por favor, inicia sesión de nuevo.';
    case 403:
      return 'No tienes permisos para realizar esta acción.';
    case 404:
      return 'El recurso solicitado no fue encontrado.';
    case 409:
      return 'Conflicto en la solicitud. Es posible que el recurso ya exista.';
    case 422:
      return 'Los datos proporcionados no son válidos.';
    case 429:
      return 'Demasiadas solicitudes. Por favor, espera un momento y vuelve a intentarlo.';
    case 500:
      return 'Error interno en el servidor. Por favor, inténtalo de nuevo más tarde.';
    case 502:
    case 503:
    case 504:
      return 'El servicio no está disponible temporalmente. Inténtalo más tarde.';
    default:
      return 'Error del servidor (HTTP $status)';
  }
}
