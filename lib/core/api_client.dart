import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

  /// El backend limita a 100 peticiones por 60 s por IP (ThrottlerModule).
  /// Ante un 429 reintentamos con backoff en lugar de martillar el endpoint.
  static const _maxRateLimitRetries = 2;

  final SharedPreferences _prefs;
  final http.Client _client;
  String? authToken;

  /// Generador de UUID v4 seguro para trazabilidad e idempotencia.
  static String generateUuid() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // versión 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variante RFC 4122
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  /// Obtiene o inicializa el Correlation ID persistente para la sesión.
  String get correlationId {
    var cid = _prefs.getString('livora_correlation_id');
    if (cid == null || cid.isEmpty) {
      cid = generateUuid();
      _prefs.setString('livora_correlation_id', cid);
    }
    return cid;
  }

  /// Se invoca cuando una petición autenticada recibe 401. Debe intentar
  /// renovar la sesión (`POST /auth/refresh`) y devolver el nuevo access token,
  /// o `null` si no se pudo renovar. Lo enchufa [SessionController]; si
  /// devuelve un token, la petición original se reintenta una sola vez.
  Future<String?> Function()? onTokenExpired;

  /// Futuro en vuelo compartido para deduplicar peticiones concurrentes de refresco.
  Future<String?>? _inFlightRefresh;

  /// Coordina la renovación del token garantizando que múltiples peticiones
  /// concurrentes que reciban 401 compartan la misma llamada en vuelo.
  Future<String?> _requestTokenRefresh() {
    if (_inFlightRefresh != null) {
      return _inFlightRefresh!;
    }
    if (onTokenExpired == null) {
      return Future.value(null);
    }

    final future = onTokenExpired!().whenComplete(() {
      _inFlightRefresh = null;
    });
    _inFlightRefresh = future;
    return future;
  }

  /// API del sistema sobre Stellar/Soroban (configurable vía variable de compilación o EnvConfig).
  static String get defaultBaseUrl => EnvConfig.apiBaseUrl;

  /// URL canónica del backend. En producción está blindada y no puede ser manipulada por el usuario.
  String get baseUrl => defaultBaseUrl;

  /// Purga cualquier URL personalizada residual de versiones anteriores en SharedPreferences
  /// garantizando que la aplicación use siempre el endpoint oficial de Stellar.
  Future<void> migrateLegacyBaseUrl() async {
    await _prefs.remove(_baseUrlKey);
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
    request.headers['X-Correlation-ID'] = correlationId;
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
        'La conexión tardó más de lo esperado. Por favor, reintenta.',
        statusCode: 408,
        code: 'TIMEOUT',
      );
    } on http.ClientException {
      throw ApiException(
        'No pudimos conectar con el servicio. Verifica tu conexión a internet e inténtalo de nuevo.',
        statusCode: 0,
        code: 'NETWORK_ERROR',
      );
    } on SocketException {
      throw ApiException(
        'No pudimos conectar con el servicio. Verifica tu conexión a internet e inténtalo de nuevo.',
        statusCode: 0,
        code: 'NETWORK_ERROR',
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
      final renewedToken = await _requestTokenRefresh();
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
    request.headers['X-Correlation-ID'] = correlationId;

    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    if (authToken != null) {
      request.headers['Authorization'] = 'Bearer $authToken';
    }

    final upperMethod = method.toUpperCase();
    final isCriticalMutation = upperMethod == 'POST' &&
        (path.contains('/stores/redemptions/confirm') ||
            path.contains('/receive') ||
            path.contains('/b2b-transfers') ||
            path.contains('/stores/settlements') ||
            path.contains('/collection-requests') ||
            path.contains('/complaints'));

    if (isCriticalMutation) {
      request.headers['Idempotency-Key'] = generateUuid();
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
        'La conexión tardó más de lo esperado. Por favor, reintenta.',
        statusCode: 408,
        code: 'TIMEOUT',
      );
    } on http.ClientException {
      throw ApiException(
        'No pudimos conectar con el servicio. Verifica tu conexión a internet e inténtalo de nuevo.',
        statusCode: 0,
        code: 'NETWORK_ERROR',
      );
    } on SocketException {
      throw ApiException(
        'No pudimos conectar con el servicio. Verifica tu conexión a internet e inténtalo de nuevo.',
        statusCode: 0,
        code: 'NETWORK_ERROR',
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

    // Rate limit (100 req / 60 s): esperamos y reintentamos con backoff exponencial.
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
        'Demasiados intentos. Por favor, espera un momento antes de reintentar.',
        statusCode: 429,
        code: _errorCode(decoded) ?? 'RATE_LIMIT',
      );
    }

    // El accessToken de Supabase vive 1 h. Ante un 401 en una petición
    // autenticada intentamos renovar la sesión una sola vez (compartida en vuelo) y repetimos.
    if (response.statusCode == 401 &&
        !refreshed &&
        path != '/auth/refresh' &&
        authToken != null &&
        onTokenExpired != null) {
      final renewedToken = await _requestTokenRefresh();
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

  /// Respeta el header `Retry-After` del throttler (segundos o fecha); si no viene,
  /// aplica backoff exponencial (2 s, 4 s) para no martillar el endpoint.
  Duration _retryDelay(http.Response response, int attempt) {
    final retryHeader = response.headers['retry-after']?.trim();
    if (retryHeader != null && retryHeader.isNotEmpty) {
      final seconds = int.tryParse(retryHeader);
      if (seconds != null && seconds > 0) {
        return Duration(seconds: min(seconds, 30));
      }
      final date = DateTime.tryParse(retryHeader);
      if (date != null) {
        final diff = date.difference(DateTime.now()).inSeconds;
        if (diff > 0) {
          return Duration(seconds: min(diff, 30));
        }
      }
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

/// Convierte el cuerpo de error del backend en un mensaje claro para el usuario.
///
/// Soporta:
/// 1. Formato Livora: `{ "error": { "code", "message", "details"? } }`
/// 2. Formato estándar NestJS: `{ "message": "..." | ["...", ...], "error": "...", "statusCode": 400 }`
/// 3. RFC 7807 Problem Details: `{ "title": "...", "detail": "...", "status": 400 }`
/// 4. Sanitización estricta de excepciones técnicas (IPs, puertos, URLs, Postgres, Prisma, JWT, TypeErrors).
String apiErrorMessage(dynamic body, int status) {
  final ipRegex = RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b');
  final portRegex = RegExp(r':\d{2,5}\b');
  final urlRegex = RegExp(r'https?://[^\s]+', caseSensitive: false);
  final stackTraceRegex = RegExp(
    r'(?:at\s+[\w\.<>$]+|\.ts:\d+|\.js:\d+|\.dart:\d+|node_modules|stack\s*trace)',
    caseSensitive: false,
  );

  String? joinIfList(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is List) {
      final items = value
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .toList();
      if (items.isNotEmpty) return items.join('\n');
    }
    return null;
  }

  String? cleanMessage(String? msg) {
    if (msg == null || msg.trim().isEmpty) return null;
    var text = msg.trim();
    final lower = text.toLowerCase();

    // Sanitización estricta de trazas internas y términos de bases de datos/ORM
    if (stackTraceRegex.hasMatch(text) ||
        lower.contains('prisma') ||
        lower.contains('postgres') ||
        lower.contains('typeerror') ||
        lower.contains('syntaxerror') ||
        lower.contains('foreign key') ||
        lower.contains('unique constraint') ||
        lower.contains('database error') ||
        lower.contains('internal server error') ||
        lower.contains('unhandled exception') ||
        lower.contains('nullpointer') ||
        lower.contains('socketexception') ||
        lower.contains('clientexception')) {
      return status >= 500
          ? 'Ocurrió un problema en nuestros servidores. Estamos trabajando para solucionarlo.'
          : 'Ocurrió un problema al procesar la solicitud. Por favor, inténtalo de nuevo.';
    }

    // Sanitización de términos de autenticación y permisos
    if (lower == 'unauthorized' ||
        lower.contains('invalid credentials') ||
        lower.contains('jwt') ||
        lower.contains('token expired') ||
        lower.contains('invalid token')) {
      return 'Credenciales incorrectas o sesión expirada. Por favor, inicia sesión de nuevo.';
    }
    if (lower == 'forbidden' ||
        lower.contains('access denied') ||
        lower.contains('missing permission') ||
        lower.contains('insufficient permissions')) {
      return 'No tienes permisos para realizar esta acción.';
    }
    if (lower == 'bad request') {
      return 'Solicitud incorrecta. Por favor, verifica los datos enviados.';
    }
    if (lower == 'not found' ||
        lower.contains('route not found') ||
        lower.contains('cannot find')) {
      return 'El recurso solicitado no fue encontrado.';
    }

    // Limpieza de URLs, direcciones IP y puertos expuestos
    if (ipRegex.hasMatch(text) || portRegex.hasMatch(text) || urlRegex.hasMatch(text)) {
      final hadConnectionKeyword = lower.contains('contactar') ||
          lower.contains('conectar') ||
          lower.contains('conexi') ||
          lower.contains('connect') ||
          lower.contains('failed');
      text = text
          .replaceAll(urlRegex, '')
          .replaceAll(ipRegex, '')
          .replaceAll(portRegex, '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (text.isEmpty || text.length < 5 || hadConnectionKeyword) {
        return 'No pudimos conectar con el servicio. Verifica tu conexión a internet e inténtalo de nuevo.';
      }
    }

    return text;
  }

  if (body is Map) {
    final error = body['error'];
    if (error is Map) {
      final details = joinIfList(error['details']);
      if (details != null) {
        final cleaned = cleanMessage(details);
        if (cleaned != null) return cleaned;
      }
      final message = cleanMessage(joinIfList(error['message']));
      if (message != null) return message;
    }
    if (error is String && error.trim().isNotEmpty) {
      final cleaned = cleanMessage(error);
      if (cleaned != null) return cleaned;
    }

    // RFC 7807: details / detail / title
    final details = joinIfList(body['details'] ?? body['detail']);
    if (details != null) {
      final cleaned = cleanMessage(details);
      if (cleaned != null) return cleaned;
    }

    // Formato estándar de NestJS: { "message": "..." | ["...", ...] }
    final message = cleanMessage(joinIfList(body['message']));
    if (message != null) return message;

    final title = cleanMessage(joinIfList(body['title']));
    if (title != null) return title;
  }

  switch (status) {
    case 0:
      return 'No pudimos conectar con el servicio. Verifica tu conexión a internet e inténtalo de nuevo.';
    case 400:
      return 'Solicitud incorrecta. Por favor, verifica los datos enviados.';
    case 401:
      return 'Credenciales incorrectas o sesión expirada. Por favor, inicia sesión de nuevo.';
    case 403:
      return 'No tienes permisos para realizar esta acción.';
    case 404:
      return 'El recurso solicitado no fue encontrado.';
    case 408:
      return 'La conexión tardó más de lo esperado. Por favor, reintenta.';
    case 409:
      return 'Conflicto en la solicitud. Es posible que el recurso ya exista.';
    case 422:
      return 'Los datos proporcionados no son válidos.';
    case 429:
      return 'Demasiados intentos. Por favor, espera un momento antes de reintentar.';
    case 500:
      return 'Ocurrió un problema en nuestros servidores. Estamos trabajando para solucionarlo.';
    case 502:
    case 503:
    case 504:
      return 'El servicio no está disponible temporalmente. Inténtalo más tarde.';
    default:
      return 'Ocurrió un problema inesperado. Por favor, inténtalo de nuevo.';
  }
}
