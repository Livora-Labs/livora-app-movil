import 'package:flutter_test/flutter_test.dart';
import 'package:livora_labs/core/api_client.dart';
import 'package:livora_labs/services/livora_realtime.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regresión: `connect()` lanzaba `UnsupportedError` para cualquier usuario con
/// sesión porque fijaba los reintentos con `double.infinity.toInt()`, que en
/// Dart no devuelve un entero grande sino que lanza excepción.
///
/// El fallo era silencioso y se llevaba por delante todo lo que venía después
/// de `connect()` en sus tres llamadores: la comprobación de notificaciones no
/// leídas al abrir la app y el vaciado de la cola offline al volver la red.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ApiClient> clientWith({String? token}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return ApiClient(prefs)..authToken = token;
  }

  test('connect() con sesión activa no lanza', () async {
    final api = await clientWith(token: 'token-de-prueba');
    final realtime = LivoraRealtime(api);
    addTearDown(realtime.dispose);

    expect(() => realtime.connect(), returnsNormally);
  });

  test('connect() es idempotente: llamarlo dos veces tampoco lanza', () async {
    final api = await clientWith(token: 'token-de-prueba');
    final realtime = LivoraRealtime(api);
    addTearDown(realtime.dispose);

    realtime.connect();
    expect(() => realtime.connect(), returnsNormally);
  });

  test('sin token no intenta conectarse', () async {
    final api = await clientWith();
    final realtime = LivoraRealtime(api);
    addTearDown(realtime.dispose);

    expect(() => realtime.connect(), returnsNormally);
    expect(realtime.isConnected, isFalse);
    expect(realtime.role, isNull);
  });

  test('los streams de eventos son broadcast y sobreviven sin conexión', () {
    final realtime = LivoraRealtime(ApiClientStub());
    addTearDown(realtime.dispose);

    final stream = realtime.on(RealtimeEvents.collectionCreated);
    expect(stream.isBroadcast, isTrue);
    // Dos pantallas pueden escuchar el mismo evento sin pisarse.
    final a = stream.listen((_) {});
    final b = stream.listen((_) {});
    addTearDown(a.cancel);
    addTearDown(b.cancel);
  });
}

/// Cliente mínimo para los casos que no tocan la red ni las preferencias.
class ApiClientStub extends ApiClient {
  ApiClientStub() : super(_FakePrefs());
}

class _FakePrefs implements SharedPreferences {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
