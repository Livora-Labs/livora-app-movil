import 'package:flutter_test/flutter_test.dart';
import 'package:livora_labs/models/models.dart';

void main() {
  group('CollectionRequest & Financial Escrow Calculations', () {
    test('Calcula requiredEscrow como el 50% del valor estimado total', () {
      final request = CollectionRequest(
        id: 'req-1',
        status: 'PENDING',
        assignmentMode: 'AUTOMATIC',
        itemsEstimated: {
          'PET': 10.0,
          'CARTON': 4.0,
        },
        agreedRates: {
          'PET': 1.00,
          'CARTON': 0.50,
        },
      );

      // Total estimated = 10*1.00 + 4*0.50 = S/ 12.00
      // requiredEscrow = 50% de 12.00 = 6.00
      expect(request.requiredEscrow, 6.00);
      expect(request.totalEstimatedKg, 14.0);
    });

    test('Usa escrowLocked si ya fue congelado por el backend', () {
      final request = CollectionRequest(
        id: 'req-2',
        status: 'ACCEPTED',
        assignmentMode: 'AUTOMATIC',
        itemsEstimated: {'PET': 20.0},
        agreedRates: {'PET': 1.20},
        escrowLocked: 12.00,
      );

      expect(request.requiredEscrow, 12.00);
    });

    test('AcopioBid parsea correctamente ganancias estimadas para Hogar', () {
      final bid = AcopioBid(
        id: 'bid-1',
        requestId: 'req-100',
        centerId: 'center-1',
        proposedRates: {'PET': 1.20},
        totalEstimatedPenn: 24.00,
        totalEstimatedEco: 9.60,
        status: 'PENDING',
        centerName: 'Ecoreciclaje Lima',
      );

      expect(bid.totalEstimatedPenn, 24.00);
      expect(bid.totalEstimatedEco, 9.60); // 40% de 24
      expect(bid.centerName, 'Ecoreciclaje Lima');
    });

    test('parseMaterials maneja llaves en minúsculas y mayúsculas limpiamente', () {
      final raw = {'pet': 5.5, 'CARTON': 10, 'Vidrio': '3.2'};
      final parsed = parseMaterials(raw);

      expect(parsed['pet'], 5.5);
      expect(parsed['CARTON'], 10.0);
      expect(parsed['Vidrio'], 3.2);
    });
  });
}
