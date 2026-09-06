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
      expect(apiErrorMessage({'message': 'Forbidden'}, 403), 'No tienes permisos para realizar esta acción.');
      expect(apiErrorMessage({'message': ['a', 'b']}, 400), 'a\nb');
    });

    test('soporta RFC 7807 (detail y title)', () {
      expect(
        apiErrorMessage({'title': 'Conflict', 'detail': 'El recurso ya existe', 'status': 409}, 409),
        'El recurso ya existe',
      );
    });

    test('sanitiza excepciones tecnicas como Prisma, Postgres o TypeErrors', () {
      expect(
        apiErrorMessage({'message': 'PrismaClientKnownRequestError: P2002 Unique constraint failed'}, 500),
        'Ocurrió un problema en nuestros servidores. Estamos trabajando para solucionarlo.',
      );
      expect(
        apiErrorMessage({'error': {'message': 'PostgresError: relation users does not exist'}}, 500),
        'Ocurrió un problema en nuestros servidores. Estamos trabajando para solucionarlo.',
      );
    });

    test('sanitiza y remueve IPs, puertos y trazas de código', () {
      expect(
        apiErrorMessage({'message': 'Failed connecting to 10.0.2.2:3000 at Controller.get (app.ts:42)'}, 500),
        'Ocurrió un problema en nuestros servidores. Estamos trabajando para solucionarlo.',
      );
      expect(
        apiErrorMessage({'message': 'Error al contactar http://52.200.2.107:3000'}, 400),
        'No pudimos conectar con el servicio. Verifica tu conexión a internet e inténtalo de nuevo.',
      );
    });

    test('cae al mensaje amigable estandarizado para red, timeout, 500 y 429', () {
      expect(apiErrorMessage(null, 0), 'No pudimos conectar con el servicio. Verifica tu conexión a internet e inténtalo de nuevo.');
      expect(apiErrorMessage(null, 408), 'La conexión tardó más de lo esperado. Por favor, reintenta.');
      expect(apiErrorMessage(null, 500), 'Ocurrió un problema en nuestros servidores. Estamos trabajando para solucionarlo.');
      expect(apiErrorMessage({'error': {}}, 502), 'El servicio no está disponible temporalmente. Inténtalo más tarde.');
      expect(apiErrorMessage(null, 429), 'Demasiados intentos. Por favor, espera un momento antes de reintentar.');
      expect(
        apiErrorMessage({'error': {'details': []}}, 400),
        'Solicitud incorrecta. Por favor, verifica los datos enviados.',
      );
      expect(
        apiErrorMessage(null, 418),
        'Ocurrió un problema inesperado. Por favor, inténtalo de nuevo.',
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