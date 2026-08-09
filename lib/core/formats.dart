import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Roles soportados por la plataforma.
class Roles {
  Roles._();

  static const hogar = 'HOGAR';
  static const recolector = 'RECOLECTOR';
  static const centroAcopio = 'CENTRO_ACOPIO';
  static const almacen = 'ALMACEN';

  static String label(String role) => switch (role) {
        hogar => 'Hogar',
        recolector => 'Recolector',
        centroAcopio => 'Centro de Acopio',
        almacen => 'Tienda / Almacén',
        'EMPRESA_B2B' => 'Empresa B2B',
        'ADMIN' => 'Administrador',
        _ => role,
      };

  static IconData icon(String role) => switch (role) {
        hogar => Icons.home_rounded,
        recolector => Icons.local_shipping_rounded,
        centroAcopio => Icons.warehouse_rounded,
        almacen => Icons.storefront_rounded,
        _ => Icons.person_rounded,
      };
}

/// Materiales sugeridos para reciclar (el backend acepta claves libres).
const kMaterialOptions = [
  'PET',
  'PLASTICO',
  'VIDRIO',
  'PAPEL',
  'CARTON',
  'METAL',
  'ALUMINIO',
];

String materialLabel(String key) => switch (key.toUpperCase()) {
      'PET' => 'PET',
      'PLASTICO' || 'PLASTIC' => 'Plástico',
      'VIDRIO' || 'GLASS' => 'Vidrio',
      'PAPEL' || 'PAPER' => 'Papel',
      'CARTON' || 'CARDBOARD' => 'Cartón',
      'METAL' => 'Metal',
      'ALUMINIO' || 'ALUMINUM' => 'Aluminio',
      'ORGANICO' || 'ORGANIC' => 'Orgánico',
      _ => key,
    };

/// Etiquetas en español para estados de solicitud de recolección.
String requestStatusLabel(String status) => switch (status) {
      'PENDING' => 'Pendiente',
      'ACCEPTED' => 'Aceptada',
      'COMPLETED' => 'Completada',
      'CANCELLED' => 'Cancelada',
      _ => status,
    };

Color requestStatusColor(String status) => switch (status) {
      'PENDING' => const Color(0xFFB7791F),
      'ACCEPTED' => LivoraColors.blue,
      'COMPLETED' => LivoraColors.green,
      'CANCELLED' => const Color(0xFF9E4B4B),
      _ => LivoraColors.ink,
    };

/// Etiquetas en español para estados de lote.
String batchStatusLabel(String status) => switch (status) {
      'OPEN' => 'Abierto',
      'IN_TRANSIT' => 'En tránsito',
      'PROCESSING' => 'Procesando',
      'RECEIVED' => 'Recibido',
      'CONSOLIDATED' => 'Consolidado',
      _ => status,
    };

Color batchStatusColor(String status) => switch (status) {
      'OPEN' => LivoraColors.cyan,
      'IN_TRANSIT' => LivoraColors.blue,
      'PROCESSING' => const Color(0xFFB7791F),
      'RECEIVED' => LivoraColors.green,
      'CONSOLIDATED' => LivoraColors.deep,
      _ => LivoraColors.ink,
    };

String _two(int n) => n.toString().padLeft(2, '0');

String fmtDate(DateTime? date) {
  if (date == null) return '—';
  return '${_two(date.day)}/${_two(date.month)}/${date.year} '
      '${_two(date.hour)}:${_two(date.minute)}';
}

/// Formatea kilogramos sin decimales innecesarios: 3 → "3 kg", 2.5 → "2.5 kg".
String fmtKg(double kg) {
  final rounded = (kg * 100).roundToDouble() / 100;
  final text = rounded == rounded.roundToDouble()
      ? rounded.toInt().toString()
      : rounded.toString();
  return '$text kg';
}

String fmtNumber(double value) {
  final rounded = (value * 100).roundToDouble() / 100;
  return rounded == rounded.roundToDouble()
      ? rounded.toInt().toString()
      : rounded.toString();
}

/// Resumen corto de un mapa de materiales: "PET 2.5 kg · Vidrio 3 kg".
String materialsSummary(Map<String, double> materials) {
  if (materials.isEmpty) return 'Sin materiales';
  return materials.entries
      .map((e) => '${materialLabel(e.key)} ${fmtKg(e.value)}')
      .join(' · ');
}
