import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livora_labs/core/api_client.dart';
import 'package:livora_labs/core/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sesión guardada como la deja un login previo.
Map<String, Object> storedSession({required DateTime expiresAt}) => {
      'livora_token': 'token-viejo',
      'livora_refresh_token': 'refresh-viejo',
      'livora_token_expires_at': expiresAt.toIso8601String(),
      'livora_user': jsonEncode({
        'id': '2662a97f',
        'email': 'hogar@livora.com',
        'role': 'HOGAR',
        'walletAddress':
            'GDI6B7HL5S76PSL4GTCM6G4TQIGQ45VYHJLP7XXS332LGH4BSX6U5YQM',
      }),
    };

/// Respuesta de /auth/refresh con el mismo shape que login/verify-email.
String refreshPayload() => jsonEncode({
      'accessToken': 'token-nuevo',
      'refreshToken': 'refresh-nuevo',
      'expiresIn': 3600,
      'tokenType': 'bearer',
      'user': {
        'id': '2662a97f',
        'email': 'hogar@livora.com',
        'role': 'HOGAR',
        'walletAddress':
            'GDI6B7HL5S76PSL4GTCM6G4TQIGQ45VYHJLP7XXS332LGH4BSX6U5YQM',
      },
    });

const _unauthorized =
    '{"error":{"code":"UNAUTHORIZED","message":"Credenciales inválidas"}}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> calls;

  setUp(() => calls = []);

  /// Registra cada petición como "METHOD /path (token)".
  void record(http.Request request) {
    final auth = request.headers['Authorization']?.replaceAll('Bearer ', '');
    calls.add('${request.method} ${request.url.path} ($auth)');
  }

  test('un 401 renueva la sesión y reintenta la petición original', () async {
    SharedPreferences.setMockInitialValues(
      storedSession(expiresAt: DateTime.now().add(const Duration(hours: 1))),
    );
    final prefs = await SharedPreferences.getInstance();

    final client = MockClient((request) async {
      record(request);
      if (request.url.path == '/auth/refresh') {
        return http.Response(refreshPayload(), 200);
      }
      final token = request.headers['Authorization'];
      return token == 'Bearer token-nuevo'
          ? http.Response('[{"id":"n1"}]', 200)
          : http.Response(_unauthorized, 401);
    });

    final api = ApiClient(prefs, client: client);
    final session = SessionController(api, prefs);
    await session.restore();

    final result = await api.get('/notifications');

    expect(result, [
      {'id': 'n1'}
    ]);
    expect(calls, [
      'GET /notifications (token-viejo)',
      'POST /auth/refresh (token-viejo)',
      'GET /notifications (token-nuevo)',
    ]);
    // La sesión nueva queda persistida, con el refresh token rotado.
    expect(api.authToken, 'token-nuevo');
    expect(session.refreshToken, 'refresh-nuevo');
    expect(prefs.getString('livora_token'), 'token-nuevo');
    expect(prefs.getString('livora_refresh_token'), 'refresh-nuevo');
    expect(session.isAuthenticated, isTrue);
  });

  test('si el refresh token ya no sirve, cierra la sesión sin reintentar en bucle',
      () async {
    SharedPreferences.setMockInitialValues(
      storedSession(expiresAt: DateTime.now().add(const Duration(hours: 1))),
    );
    final prefs = await SharedPreferences.getInstance();

    final client = MockClient((request) async {
      record(request);
      return http.Response(_unauthorized, 401);
    });

    final api = ApiClient(prefs, client: client);
    final session = SessionController(api, prefs);
    await session.restore();

    await expectLater(
      api.get('/notifications'),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
      ),
    );

    // Sin reentradas: la original, el refresh fallido, y nada más.
    expect(calls, [
      'GET /notifications (token-viejo)',
      'POST /auth/refresh (token-viejo)',
    ]);
    expect(session.isAuthenticated, isFalse);
    expect(prefs.getString('livora_token'), isNull);
    expect(prefs.getString('livora_refresh_token'), isNull);
  });

  test('al restaurar con el token vencido renueva antes de mostrar la app',
      () async {
    SharedPreferences.setMockInitialValues(
      storedSession(
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    );
    final prefs = await SharedPreferences.getInstance();

    final client = MockClient((request) async {
      record(request);
      return http.Response(refreshPayload(), 200);
    });

    final api = ApiClient(prefs, client: client);
    final session = SessionController(api, prefs);
    await session.restore();

    expect(calls, ['POST /auth/refresh (token-viejo)']);
    expect(api.authToken, 'token-nuevo');
    expect(session.isTokenExpired, isFalse);
  });

  test('sin sesión previa no se llama a /auth/refresh', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final client = MockClient((request) async {
      record(request);
      return http.Response(_unauthorized, 401);
    });

    final api = ApiClient(prefs, client: client);
    final session = SessionController(api, prefs);
    await session.restore();

    await expectLater(api.get('/notifications'), throwsA(isA<ApiException>()));

    // Sin token no hay nada que renovar: una sola petición.
    expect(calls, ['GET /notifications (null)']);
    expect(session.isAuthenticated, isFalse);
  });
}
