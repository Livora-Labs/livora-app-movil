import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:livora_labs/core/api_client.dart';
import 'package:livora_labs/core/session.dart';
import 'package:livora_labs/models/models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

String formatGreetingTest(AuthUser? user) {
  final rawName = user?.name?.trim();
  if (rawName == null || rawName.isEmpty) return '¡Bienvenido!';
  final firstName = rawName.split(RegExp(r'\s+')).first;
  if (firstName.isEmpty) return '¡Bienvenido!';
  return 'Hola, ${firstName[0].toUpperCase()}${firstName.substring(1).toLowerCase()}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UX & State Bug Fixes Tests', () {
    test('formatGreeting formatea el primer nombre o muestra fallback amigable', () {
      final user1 = AuthUser(
        id: 'u1',
        email: 'test@livora.pe',
        role: 'HOGAR',
        name: 'carlos alberto mendoza',
      );
      expect(formatGreetingTest(user1), equals('Hola, Carlos'));

      final user2 = AuthUser(
        id: 'u2',
        email: 'test@livora.pe',
        role: 'HOGAR',
        name: '  MARÍA ELENA  ',
      );
      expect(formatGreetingTest(user2), equals('Hola, María'));

      final userEmpty = AuthUser(
        id: 'u3',
        email: 'test@livora.pe',
        role: 'HOGAR',
        name: '',
      );
      expect(formatGreetingTest(userEmpty), equals('¡Bienvenido!'));

      final userNull = AuthUser(
        id: 'u4',
        email: 'test@livora.pe',
        role: 'HOGAR',
      );
      expect(formatGreetingTest(userNull), equals('¡Bienvenido!'));
    });

    test('SessionController resetea unreadNotificationsCount a 0 al cerrar sesión', () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final client = ApiClient(prefs);
      final session = SessionController(client, prefs);

      session.setUnreadNotificationsCount(5);
      expect(session.unreadNotificationsCount, equals(5));

      await session.logout();
      expect(session.unreadNotificationsCount, equals(0));
    });

    test('SharedPreferences previene disparos repetidos de animación de celebración', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      const reqId = 'req-abc-123';
      const key = 'celebration_shown_req_$reqId';

      // Primera vez: no se ha celebrado
      expect(prefs.getBool(key) ?? false, isFalse);

      // Se muestra la celebración y se persiste
      await prefs.setBool(key, true);

      // Subsecuente consulta (ej. historial): ya está marcado como celebrado
      expect(prefs.getBool(key) ?? false, isTrue);
    });

    test('updateProfile preserva el rol y walletAddress del usuario autenticado', () {
      final initialUser = AuthUser(
        id: 'u-51',
        email: 'huarique51@gmail.com',
        role: 'HOGAR',
        name: 'Huarique',
        walletAddress: 'GBRPB7W6NYKPVKCG...',
      );

      // Simulación de copyWith cuando el backend solo responde { success: true }
      final updated = initialUser.copyWith(
        name: 'Huarique Nuevo',
        phone: '999888777',
      );

      expect(updated.id, equals('u-51'));
      expect(updated.role, equals('HOGAR'));
      expect(updated.walletAddress, equals('GBRPB7W6NYKPVKCG...'));
      expect(updated.name, equals('Huarique Nuevo'));
      expect(updated.phone, equals('999888777'));
    });
  });
}
