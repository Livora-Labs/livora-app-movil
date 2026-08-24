import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:livora_labs/core/api_client.dart';

void main() {
  group('apiErrorMessage', () {
    test('usa details cuando el message es el genérico de validación', () {
      // Respuesta real de POST /auth/register con contraseña débil.
      final body = jsonDecode('''
      {"error":{"code":"BAD_REQUEST",
        "message":"Error de validación en los parámetros de entrada",
        "details":["La contraseña debe contener al menos una mayúscula, una minúscula, un número y un símbolo especial"]}}
      ''');
      expect(
        apiErrorMessage(body, 400),
        'La contraseña debe contener al menos una mayúscula, una minúscula, '
        'un número y un símbolo especial',
      );
    });

    test('junta varios details en líneas separadas', () {
      final body = {
        'error': {
          'code': 'BAD_REQUEST',
          'message': 'Error de validación en los parámetros de entrada',
          'details': ['El correo electrónico no es válido', 'Mínimo 8'],
        },
      };
      expect(
        apiErrorMessage(body, 400),
        'El correo electrónico no es válido\nMínimo 8',
      );
    });

    test('usa message cuando no hay details', () {
      final body = jsonDecode(
        '{"error":{"code":"BAD_REQUEST","message":"El código OTP ha expirado o no existe"}}',
      );
      expect(
        apiErrorMessage(body, 400),
        'El código OTP ha expirado o no existe',
      );
    });

    test('soporta el formato estándar de NestJS', () {
      expect(apiErrorMessage({'message': 'Forbidden'}, 403), 'Forbidden');
      expect(apiErrorMessage({'message': ['a', 'b']}, 400), 'a\nb');
    });

    test('cae al mensaje genérico si el cuerpo no aporta nada', () {
      expect(apiErrorMessage(null, 500), 'Error del servidor (HTTP 500)');
      expect(apiErrorMessage({'error': {}}, 502), 'Error del servidor (HTTP 502)');
      expect(
        apiErrorMessage({'error': {'details': []}}, 400),
        'Error del servidor (HTTP 400)',
      );
    });
  });

  group('apiErrorCode', () {
    test('extrae el code del backend', () {
      final body = jsonDecode(
        '{"error":{"code":"UNAUTHORIZED","message":"Credenciales inválidas"}}',
      );
      expect(apiErrorCode(body), 'UNAUTHORIZED');
    });

    test('devuelve null cuando no hay code', () {
      expect(apiErrorCode({'message': 'x'}), isNull);
      expect(apiErrorCode(null), isNull);
    });
  });
}
