import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:livora_labs/models/models.dart';

void main() {
  group('KycApplication', () {
    test('sin solicitud previa el backend devuelve NOT_SUBMITTED', () {
      final application = KycApplication.fromJson(
        jsonDecode('{"status":"NOT_SUBMITTED"}') as Map<String, dynamic>,
      );
      expect(application.isSubmitted, isFalse);
      expect(application.canSubmit, isTrue);
      expect(application.documentUrl, isNull);
    });

    test('parsea una solicitud en revisión', () {
      // Respuesta real de GET /collectors/me/kyc-application.
      final application = KycApplication.fromJson(
        jsonDecode(
          '{"status":"PENDING","documentUrl":"https://example.com/doc.pdf",'
          '"createdAt":"2026-08-24T10:23:29.011Z",'
          '"updatedAt":"2026-08-24T10:23:29.011Z"}',
        ) as Map<String, dynamic>,
      );
      expect(application.isSubmitted, isTrue);
      expect(application.isApproved, isFalse);
      // En revisión no se puede reenviar: evitaría duplicar solicitudes.
      expect(application.canSubmit, isFalse);
      expect(application.updatedAt?.isUtc, isFalse, reason: 'se pasa a local');
      expect(application.documentUrl, 'https://example.com/doc.pdf');
    });

    test('aprobada cierra el formulario', () {
      final application = KycApplication.fromJson(
        {'status': 'APPROVED'},
      );
      expect(application.isApproved, isTrue);
      expect(application.canSubmit, isFalse);
    });

    test('rechazada permite volver a enviar', () {
      final application = KycApplication.fromJson(
        {'status': 'REJECTED'},
      );
      expect(application.isRejected, isTrue);
      expect(application.isSubmitted, isTrue);
      expect(application.canSubmit, isTrue);
    });

    test('un status desconocido no habilita el envío por accidente', () {
      final application = KycApplication.fromJson({'status': 'EN_ESPERA'});
      expect(application.isSubmitted, isTrue);
      expect(application.canSubmit, isFalse);
    });
  });
}
