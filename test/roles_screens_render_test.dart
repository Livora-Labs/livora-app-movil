import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:livora_labs/core/api_client.dart';
import 'package:livora_labs/core/formats.dart';
import 'package:livora_labs/core/session.dart';
import 'package:livora_labs/models/models.dart';
import 'package:livora_labs/services/livora_api.dart';
import 'package:livora_labs/services/livora_realtime.dart';
import 'package:livora_labs/services/network_connectivity_service.dart';
import 'package:livora_labs/features/hogar/dashboard/views/hogar_dashboard_view.dart';
import 'package:livora_labs/screens/hogar/widgets/hogar_first_steps_dialog.dart';
import 'package:livora_labs/screens/hogar/gamification/hogar_forest_screen.dart';
import 'package:livora_labs/screens/recolector/available_requests_screen.dart';
import 'package:livora_labs/screens/acopio/center_batches_screen.dart';
import 'package:livora_labs/screens/tienda/store_dashboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      HogarFirstStepsDialog.prefKey: true,
      'has_seen_collector_first_steps_v1': true,
    });
  });

  Widget createTestApp({
    required SessionController session,
    required LivoraApi api,
    required LivoraRealtime realtime,
    required Widget child,
  }) {
    final connectivity = NetworkConnectivityService();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionController>.value(value: session),
        ChangeNotifierProvider<NetworkConnectivityService>.value(value: connectivity),
        Provider<LivoraApi>.value(value: api),
        ChangeNotifierProvider<LivoraRealtime>.value(value: realtime),
      ],
      child: MaterialApp(home: child),
    );
  }

  group('Roles Screens Render Validation', () {
    testWidgets('Rol HOGAR: HogarDashboardView renderiza sin errores de flex o borders',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final client = ApiClient(prefs);
      final session = SessionController(client, prefs);
      final user = AuthUser(
        id: 'u-hogar',
        email: 'ninja@livora.pe',
        role: Roles.hogar,
        name: 'Ninja',
        address: 'Av. Larco 123, Miraflores',
      );
      await session.restore();
      await session.updateUser(user);

      final livoraApi = LivoraApi(client);
      final realtime = LivoraRealtime(client);

      await tester.pumpWidget(
        createTestApp(
          session: session,
          api: livoraApi,
          realtime: realtime,
          child: const HogarDashboardView(),
        ),
      );

      await tester.pump();
      expect(find.byType(HogarDashboardView), findsOneWidget);
      expect(find.text('Hola, Ninja'), findsOneWidget);
    });

    testWidgets('Rol HOGAR: HogarForestScreen renderiza sin error de border no uniforme',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final client = ApiClient(prefs);
      final session = SessionController(client, prefs);
      final user = AuthUser(
        id: 'u-hogar',
        email: 'ninja@livora.pe',
        role: Roles.hogar,
        name: 'Ninja',
      );
      await session.restore();
      await session.updateUser(user);

      final livoraApi = LivoraApi(client);
      final realtime = LivoraRealtime(client);

      await tester.pumpWidget(
        createTestApp(
          session: session,
          api: livoraApi,
          realtime: realtime,
          child: const HogarForestScreen(),
        ),
      );

      await tester.pump();
      expect(find.byType(HogarForestScreen), findsOneWidget);
    });

    testWidgets('Rol RECOLECTOR: AvailableRequestsScreen renderiza sin errores',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final client = ApiClient(prefs);
      final session = SessionController(client, prefs);
      final user = AuthUser(
        id: 'u-recolector',
        email: 'recolector@livora.pe',
        role: Roles.recolector,
        name: 'Carlos Recolector',
      );
      await session.restore();
      await session.updateUser(user);

      final livoraApi = LivoraApi(client);
      final realtime = LivoraRealtime(client);

      await tester.pumpWidget(
        createTestApp(
          session: session,
          api: livoraApi,
          realtime: realtime,
          child: const AvailableRequestsScreen(),
        ),
      );

      await tester.pump();
      expect(find.byType(AvailableRequestsScreen), findsOneWidget);
    });

    testWidgets('Rol CENTRO_ACOPIO: CenterBatchesScreen renderiza sin errores',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final client = ApiClient(prefs);
      final session = SessionController(client, prefs);
      final user = AuthUser(
        id: 'u-acopio',
        email: 'acopio@livora.pe',
        role: Roles.centroAcopio,
        name: 'Acopio Central',
      );
      await session.restore();
      await session.updateUser(user);

      final livoraApi = LivoraApi(client);
      final realtime = LivoraRealtime(client);

      await tester.pumpWidget(
        createTestApp(
          session: session,
          api: livoraApi,
          realtime: realtime,
          child: const CenterBatchesScreen(),
        ),
      );

      await tester.pump();
      expect(find.byType(CenterBatchesScreen), findsOneWidget);
    });

    testWidgets('Rol TIENDA: StoreDashboard renderiza sin errores',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final client = ApiClient(prefs);
      final session = SessionController(client, prefs);
      final user = AuthUser(
        id: 'u-tienda',
        email: 'tienda@livora.pe',
        role: Roles.tienda,
        name: 'Bodega EcoVerde',
      );
      await session.restore();
      await session.updateUser(user);

      final livoraApi = LivoraApi(client);
      final realtime = LivoraRealtime(client);

      await tester.pumpWidget(
        createTestApp(
          session: session,
          api: livoraApi,
          realtime: realtime,
          child: const StoreDashboard(),
        ),
      );

      await tester.pump();
      expect(find.byType(StoreDashboard), findsOneWidget);
    });
  });
}
