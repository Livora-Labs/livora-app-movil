import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Error de la API de Livora con mensaje legible para el usuario.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Cliente HTTP hacia el backend NestJS de Livora.
class ApiClient {
  ApiClient(this._prefs);

  static const _baseUrlKey = 'livora_base_url';

  final SharedPreferences _prefs;
  String? authToken;

  /// API de producción (AWS EC2). Para otro entorno cámbiala desde el
  /// diálogo "Servidor" de la app (Render: https://livora-api-service.onrender.com,
  /// emulador Android: http://10.0.2.2:3000, iOS/macOS: http://localhost:3000).
  static const defaultBaseUrl = 'http://52.200.2.107';

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

  Future<dynamic> get(String path, {Map<String, Object?>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

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
      // Margen amplio: algunos entornos (p. ej. Render gratuito) tardan
      // hasta ~1 minuto en "despertar" tras inactividad.
      final streamed = await request.send().timeout(
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

    if (response.statusCode == 401) {
      throw ApiException(
        'Tu sesión expiró o las credenciales no son válidas. Inicia sesión nuevamente.',
        statusCode: 401,
      );
    }

    throw ApiException(
      _errorMessage(decoded, response.statusCode),
      statusCode: response.statusCode,
    );
  }

  String _errorMessage(dynamic body, int status) {
    if (body is Map<String, dynamic>) {
      // Formato del filtro global de Livora: { "error": { "code", "message" } }
      final error = body['error'];
      if (error is Map) {
        final message = error['message'];
        if (message is String && message.isNotEmpty) return message;
      }
      if (error is String && error.isNotEmpty) return error;
      // Formato estándar de NestJS: { "message": "..." | ["...", ...] }
      final message = body['message'];
      if (message is String && message.isNotEmpty) return message;
      if (message is List && message.isNotEmpty) return message.join('\n');
    }
    return 'Error del servidor (HTTP $status)';
  }
}
