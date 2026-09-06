import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livora_labs/core/api_client.dart';
import 'package:livora_labs/core/session.dart';
import 'package:livora_labs/services/livora_api.dart';
import 'package:livora_labs/services/livora_realtime.dart';
import 'package:livora_labs/main.dart';
import 'package:livora_labs/widgets/livora_logo.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('sin sesión muestra la pantalla de inicio de sesión',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = ApiClient(prefs);
    final session = SessionController(api, prefs);
    await session.restore();
    final livoraApi = LivoraApi(api);
    final realtime = LivoraRealtime(api);

    await tester.pumpWidget(LivoraApp(
      api: api,
      session: session,
      livoraApi: livoraApi,
      realtime: realtime,
    ));
    await tester.pump();

    expect(find.byType(LivoraWordmark), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('¿No tienes cuenta? Regístrate'), findsOneWidget);
  });
}
