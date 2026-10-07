import 'package:flutter_test/flutter_test.dart';
import 'package:livora_labs/domain/state/ui_state.dart';
import 'package:livora_labs/models/models.dart';

void main() {
  group('Clean Architecture: UIState & Domain Tests', () {
    test('UIState transitions maintain immutability and cached data integrity', () {
      const initial = UIState<String>.initial();
      expect(initial.isInitial, isTrue);
      expect(initial.dataOrNull, isNull);

      const loading = UIState<String>.loading(cachedData: 'cached_item');
      expect(loading.isLoading, isTrue);
      expect(loading.dataOrNull, equals('cached_item'));

      const success = UIState<String>.success('fresh_item');
      expect(success.isSuccess, isTrue);
      expect(success.dataOrNull, equals('fresh_item'));

      const error = UIState<String>.error('network_timeout', cachedData: 'cached_item', isNetworkError: true);
      expect(error.isError, isTrue);
      expect(error.dataOrNull, equals('cached_item'));
      expect((error as UIError<String>).isNetworkError, isTrue);
      expect(error.message, equals('network_timeout'));

      const empty = UIState<String>.empty();
      expect(empty.isEmpty, isTrue);
      expect(empty.dataOrNull, isNull);
    });

    test('Batch serialization and deserialization preserves all fields', () {
      final now = DateTime.now();
      final batch = Batch(
        id: 'batch-test-999',
        status: 'IN_TRANSIT',
        materialsActual: {'PET': 12.5, 'CARTON': 8.0},
        collectorId: 'collector-1',
        collectorName: 'Juan Pérez',
        destinationCenterId: 'center-1',
        destinationCenterName: 'Ecopunto Miraflores',
        hasDiscrepancy: false,
        fiatSettled: true,
        createdAt: now,
      );

      final json = batch.toJson();
      expect(json['id'], equals('batch-test-999'));
      expect(json['status'], equals('IN_TRANSIT'));
      expect(json['materialsActual'], isA<Map>());
      expect(json['materialsActual']['PET'], equals(12.5));
      expect(json['collectorName'], equals('Juan Pérez'));
      expect(json['fiatSettled'], isTrue);

      final deserialized = Batch.fromJson(json);
      expect(deserialized.id, equals(batch.id));
      expect(deserialized.status, equals(batch.status));
      expect(deserialized.totalActualKg, equals(20.5));
      expect(deserialized.shortId, equals('BATCH-TE'));
    });

    test('AuctionBid model serializes and parses rates correctly', () {
      final bid = AuctionBid(
        id: 'bid-100',
        centerId: 'center-surquillo',
        centerName: 'Acopio Surquillo',
        totalEstimatedPenn: 45.50,
        totalEstimatedLivo: 18.20,
        pricePerKg: {'PET': 1.50, 'CARTON': 0.80},
        status: 'PENDING',
      );

      final json = bid.toJson();
      expect(json['id'], equals('bid-100'));
      expect(json['totalEstimatedPenn'], equals(45.50));
      expect(json['totalEstimatedLivo'], equals(18.20));

      final restored = AuctionBid.fromJson(json);
      expect(restored.id, equals('bid-100'));
      expect(restored.centerName, equals('Acopio Surquillo'));
      expect(restored.pricePerKg['PET'], equals(1.50));
    });

    test('CollectorLocationTelemetry serializes GPS coordinates and speed accurately', () {
      const telemetry = CollectorLocationTelemetry(
        latitude: -12.0864,
        longitude: -77.0351,
        heading: 180.5,
        speed: 15.2,
        distanceRemainingMeters: 320.0,
        etaMinutes: 4,
        transportType: 'MOTO_CARGA',
      );

      final json = telemetry.toJson();
      expect(json['latitude'], equals(-12.0864));
      expect(json['longitude'], equals(-77.0351));
      expect(json['speed'], equals(15.2));
      expect(json['transportType'], equals('MOTO_CARGA'));

      final restored = CollectorLocationTelemetry.fromJson(json);
      expect(restored.latitude, equals(-12.0864));
      expect(restored.heading, equals(180.5));
      expect(restored.etaMinutes, equals(4));
    });
  });
}
