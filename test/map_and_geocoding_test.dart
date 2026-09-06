import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:livora_labs/models/models.dart';
import 'package:livora_labs/services/location_service.dart';
import 'package:livora_labs/widgets/center_picker_pin.dart';
import 'package:livora_labs/widgets/collector_request_marker.dart';
import 'package:livora_labs/widgets/store_category_marker.dart';
import 'package:livora_labs/widgets/view_toggle_segmented_button.dart';

class MockHttpClient {
  MockHttpClient(this.handler);
  final Future<http.Response> Function(Uri uri, Map<String, String>? headers) handler;

  Future<http.Response> get(Uri uri, {Map<String, String>? headers}) => handler(uri, headers);
}

void main() {
  group("Módulo 1: Geocodificación Inversa Nominatim (LocationService)", () {
    test("reverseGeocode estructura correctamente vía, número y distrito", () async {
      final mock = MockHttpClient((uri, headers) async {
        expect(headers?["User-Agent"], "LivoraApp/3.0.0 (pe.livora.app)");
        final jsonStr = jsonEncode({
          "address": {
            "road": "Av. Alfredo Benavides",
            "house_number": "1230",
            "suburb": "Miraflores",
            "city": "Lima",
          },
          "display_name": "Av. Alfredo Benavides 1230, Miraflores, Lima, Perú",
        });
        return http.Response(jsonStr, 200);
      });

      final result = await LocationService.reverseGeocode(-12.12, -77.02, client: mock);
      expect(result, "Av. Alfredo Benavides 1230, Miraflores");
    });

    test("reverseGeocode retorna null ante error HTTP de Nominatim sin romper la ejecución", () async {
      final mock = MockHttpClient((uri, headers) async {
        return http.Response("Rate limit exceeded", 429);
      });

      final result = await LocationService.reverseGeocode(-12.12, -77.02, client: mock);
      expect(result, isNull);
    });
  });

  group("Módulo 2: Selector Dual ViewToggleSegmentedButton", () {
    testWidgets("renderiza opciones Lista y Mapa y reacciona al tap", (tester) async {
      MapListViewMode selected = MapListViewMode.list;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ViewToggleSegmentedButton(
                  selectedMode: selected,
                  onChanged: (newMode) {
                    setState(() => selected = newMode);
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text("Lista"), findsOneWidget);
      expect(find.text("Mapa Radar"), findsOneWidget);

      await tester.tap(find.text("Mapa Radar"));
      await tester.pumpAndSettle();

      expect(selected, MapListViewMode.map);
    });
  });

  group("Módulo 3: Marcadores Dinámicos y Microinteracciones de Mapa", () {
    testWidgets("CenterPickerPin renderiza correctamente y eleva el pin al arrastrar", (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CenterPickerPin(isDragging: true),
          ),
        ),
      );

      expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);
    });

    testWidgets("CollectorRequestMarker renderiza badge de recompensa y abre detalle en tap", (tester) async {
      bool tapped = false;
      final request = CollectionRequest(
        id: "req-test-123456",
        status: "PENDING",
        assignmentMode: "AUTOMATIC",
        itemsEstimated: {"PET": 20.0},
        agreedRates: {"PET": 1.0},
        escrowLocked: 10.0,
        latitude: -12.0864,
        longitude: -77.0351,
        bids: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CollectorRequestMarker(
              request: request,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      // Margen del recolector = 50% de 20.0 = 10.0 ECO
      expect(find.text("+10.0 ECO"), findsOneWidget);
      expect(find.byIcon(Icons.local_drink_rounded), findsOneWidget);

      await tester.tap(find.byType(CollectorRequestMarker));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets("StoreCategoryMarker renderiza nombre de tienda e ícono según categoría", (tester) async {
      bool tapped = false;
      final store = {
        "id": "store-1",
        "name": "BioFeria Miraflores",
        "category": "BioFerias",
        "latitude": -12.12,
        "longitude": -77.03,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StoreCategoryMarker(
              store: store,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text("BioFeria Miraflores"), findsOneWidget);
      expect(find.byIcon(Icons.eco_rounded), findsOneWidget);

      await tester.tap(find.byType(StoreCategoryMarker));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });
}
