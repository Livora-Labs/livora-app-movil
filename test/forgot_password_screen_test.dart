import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:livora_labs/core/api_client.dart';
import 'package:livora_labs/screens/auth/forgot_password_screen.dart';
import 'package:livora_labs/services/livora_api.dart';

class MockLivoraApi extends LivoraApi {
  MockLivoraApi(super.client);

  String? lastRequestedEmail;
  bool shouldThrow = false;

  @override
  Future<void> forgotPassword(String email) async {
    lastRequestedEmail = email;
    if (shouldThrow) {
      throw ApiException('Error de conexión con el servidor', statusCode: 500);
    }
  }
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  Widget createWidgetUnderTest(MockLivoraApi mockApi) {
    return MultiProvider(
      providers: [
        Provider<LivoraApi>.value(value: mockApi),
      ],
      child: const MaterialApp(
        home: ForgotPasswordScreen(),
      ),
    );
  }

  testWidgets('ForgotPasswordScreen muestra campos y valida email antes de enviar', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final client = ApiClient(prefs);
    final mockApi = MockLivoraApi(client);

    await tester.pumpWidget(createWidgetUnderTest(mockApi));
    await tester.pumpAndSettle();

    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);

    // Intentar enviar vacío
    await tester.tap(find.text('Enviar enlace de recuperación'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresa tu correo electrónico'), findsOneWidget);
    expect(mockApi.lastRequestedEmail, isNull);

    // Ingresar email inválido
    await tester.enterText(find.byType(TextFormField), 'invalido');
    await tester.tap(find.text('Enviar enlace de recuperación'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresa un correo electrónico válido'), findsOneWidget);
    expect(mockApi.lastRequestedEmail, isNull);

    // Ingresar email válido
    await tester.enterText(find.byType(TextFormField), 'usuario@livora.pe');
    await tester.tap(find.text('Enviar enlace de recuperación'));
    await tester.pumpAndSettle();

    expect(mockApi.lastRequestedEmail, equals('usuario@livora.pe'));
    expect(find.text('Revisa tu bandeja de entrada'), findsOneWidget);
    expect(find.textContaining('Al terminar, podrás cerrar la pestaña del navegador'), findsOneWidget);
    expect(find.text('Volver al inicio de sesión'), findsOneWidget);
  });
}
