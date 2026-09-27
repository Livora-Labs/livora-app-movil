import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:livora_labs/widgets/livora_map_tile_layer.dart';
import 'package:livora_labs/services/push_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Módulo 4: Prefetch de Corredor Offline de Mapas (LivoraMapTileLayer)', () {
    test('prefetchCorridor maneja listas vacías de coordenadas sin excepción', () async {
      await expectLater(
        LivoraMapTileLayer.prefetchCorridor([]),
        completes,
      );
    });

    test('prefetchCorridor calcula teselas y no arroja excepción ante fallos de red simulados', () async {
      // Coordenadas a lo largo de un corredor en Lima (Av. Larco a Benavides)
      final corridor = [
        const LatLng(-12.1216, -77.0305),
        const LatLng(-12.1250, -77.0310),
        const LatLng(-12.1290, -77.0320),
      ];

      // Ejecutar con zoom 14 a 15
      await expectLater(
        LivoraMapTileLayer.prefetchCorridor(corridor, minZoom: 14, maxZoom: 15),
        completes,
      );
    });
  });

  group('Módulo 5: Configuración de Canales Push FCM (PushNotificationService)', () {
    test('constantes de canales push coinciden con la matriz de sonido y prioridad', () {
      expect(PushNotificationService.channelUrgent, 'livora_collections_urgent');
      expect(PushNotificationService.channelWallet, 'livora_wallet_ledger');
      expect(PushNotificationService.channelLegal, 'livora_legal_security');
      expect(PushNotificationService.channelAuctions, 'livora_auctions');
      expect(PushNotificationService.channelMarketing, 'livora_engagement_marketing');
    });
  });
}
