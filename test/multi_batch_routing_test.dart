import 'package:flutter_test/flutter_test.dart';
import 'package:livora_labs/models/models.dart';

void main() {
  group('Multi-Batch & Segmented Center Architecture Tests', () {
    test('CollectionRequest calcula tarifa promedio y márgenes fiduciarios', () {
      final req = CollectionRequest(
        id: 'req-1',
        householdId: 'h-1',
        assignedCenterId: 'center-1',
        assignedCenterName: 'Acopio ReciclaYa',
        status: 'PENDING',
        itemsEstimated: {'PET': 10.0, 'CARTON': 10.0},
        agreedRates: {'PET': 2.0, 'CARTON': 1.0}, // Total = 20 + 10 = 30 PEN
      );

      expect(req.totalEstimatedKg, equals(20.0));
      expect(req.totalEstimatedValuePEN, equals(30.0));
      expect(req.collectorMarginPEN, equals(15.0)); // 50%
      expect(req.requiredEscrow, equals(15.0)); // 50%
      expect(req.averageRatePerKg, equals(1.5)); // 30 / 20 = 1.5 PEN/kg
    });

    test('Batch calcula totalEstimatedKg consolidado de todas sus solicitudes', () {
      final req1 = CollectionRequest(
        id: 'req-1',
        householdId: 'h-1',
        assignedCenterId: 'center-1',
        status: 'ACCEPTED',
        itemsEstimated: {'PET': 15.0},
      );
      final req2 = CollectionRequest(
        id: 'req-2',
        householdId: 'h-2',
        assignedCenterId: 'center-1',
        status: 'COMPLETED',
        itemsEstimated: {'VIDRIO': 25.0},
      );

      final batch = Batch(
        id: 'batch-abc',
        status: 'OPEN',
        destinationCenterId: 'center-1',
        destinationCenterName: 'Acopio ReciclaYa',
        requests: [req1, req2],
      );

      expect(batch.totalEstimatedKg, equals(40.0));
      expect(batch.requests.length, equals(2));
      expect(batch.estimatedMaterials['PET'], equals(15.0));
      expect(batch.estimatedMaterials['VIDRIO'], equals(25.0));
    });

    test('Batch deserializa correctamente destinationCenterAddress y campos de acopio', () {
      final json = {
        'id': 'batch-xyz-12345',
        'status': 'OPEN',
        'destinationCenterId': 'center-456',
        'destinationCenter': {
          'id': 'center-456',
          'name': 'Ecológica Lima Norte',
          'email': 'acopio@ecologica.pe',
          'address': 'Av. Los Recicladores 123',
        },
        'requests': [],
      };

      final batch = Batch.fromJson(json);

      expect(batch.id, equals('batch-xyz-12345'));
      expect(batch.shortId, equals('BATCH-XY'));
      expect(batch.destinationCenterId, equals('center-456'));
      expect(batch.destinationCenterName, equals('Ecológica Lima Norte'));
      expect(batch.destinationCenterAddress, equals('Av. Los Recicladores 123'));
    });
  });
}
