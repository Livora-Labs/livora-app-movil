import 'package:flutter_test/flutter_test.dart';
import 'package:livora_labs/core/api_client.dart';
import 'package:livora_labs/core/session.dart';
import 'package:livora_labs/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('sin sesión muestra la pantalla de inicio de sesión',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = ApiClient(prefs);
    final session = SessionController(api, prefs);
    await session.restore();

    await tester.pumpWidget(LivoraApp(api: api, session: session));
    await tester.pump();

    expect(find.text('LIVORA'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('¿No tienes cuenta? Regístrate'), findsOneWidget);
  });
}
