import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livora_labs/core/formats.dart';
import 'package:livora_labs/core/session.dart';

void main() {
  group('Purga y Validación de Roles en App Móvil', () {
    test('Roles autorizados en móvil son exactamente HOGAR, RECOLECTOR, CENTRO_ACOPIO y TIENDA', () {
      expect(Roles.hogar, 'HOGAR');
      expect(Roles.recolector, 'RECOLECTOR');
      expect(Roles.centroAcopio, 'CENTRO_ACOPIO');
      expect(Roles.tienda, 'TIENDA');
    });

    test('Roles.label formatea TIENDA como Tienda / Comercio Aliado', () {
      expect(Roles.label(Roles.tienda), 'Tienda / Comercio Aliado');
      expect(Roles.label(Roles.hogar), 'Hogar');
      expect(Roles.label(Roles.recolector), 'Recolector');
      expect(Roles.label(Roles.centroAcopio), 'Centro de Acopio');
    });

    test('Roles.icon devuelve Icons.storefront_rounded para TIENDA', () {
      expect(Roles.icon(Roles.tienda), Icons.storefront_rounded);
      expect(Roles.icon(Roles.hogar), Icons.home_rounded);
      expect(Roles.icon(Roles.recolector), Icons.local_shipping_rounded);
      expect(Roles.icon(Roles.centroAcopio), Icons.warehouse_rounded);
    });

    test('WebExclusiveRoleException cuenta con mensaje explicativo corporativo', () {
      const exception = WebExclusiveRoleException();
      expect(
        exception.message,
        contains('Acceso exclusivo web: Las cuentas de Empresa B2B y Administrador'),
      );
    });
  });
}
