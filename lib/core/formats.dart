import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';

/// Formateador estricto para campos numéricos positivos con hasta 2 decimales:
/// Impide ingresar caracteres no numéricos o más de 2 posiciones decimales (ej. 1.50, impidiendo 0.000004).
final kDecimalInputFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
];

/// Formateador estricto para RUC peruano (exactamente 11 dígitos numéricos):
final kRucInputFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(11),
];

/// Formateador estricto para CCI peruano (exactamente 20 dígitos numéricos):
final kCciInputFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(20),
];

/// Validador estandarizado para RUC peruano (11 dígitos, comienza con 10 o 20):
String? validateRuc(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Ingresa el número de RUC';
  }
  final clean = value.replaceAll(RegExp(r'\D'), '');
  if (clean.length != 11) {
    return 'El RUC debe tener exactamente 11 dígitos';
  }
  if (!clean.startsWith('10') && !clean.startsWith('20')) {
    return 'El RUC debe iniciar con 10 o 20';
  }
  return null;
}

/// Validador estandarizado para CCI bancario (20 dígitos numéricos):
String? validateCci(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Ingresa el CCI bancario';
  }
  final clean = value.replaceAll(RegExp(r'\D'), '');
  if (clean.length != 20) {
    return 'El CCI debe tener exactamente 20 dígitos numéricos';
  }
  return null;
}

/// Validador estricto para peso mayor a 0 kg:
String? validatePositiveWeight(String? value) {
  return validateWeightKg(value, min: 0.01);
}

/// Validador estricto para montos mayores a 0:
String? validatePositiveAmount(String? value, {String unit = 'ECO'}) {
  return validateAmount(value, min: 0.01, unit: unit);
}

/// Validador estandarizado para campos de peso en kg:
/// Exige formato numérico positivo, mínimo operativo (0.5 kg por defecto) y bloquea 0 o 0.00.
String? validateWeightKg(String? value, {double min = 0.5}) {
  if (value == null || value.trim().isEmpty) {
    return 'Ingresa el peso en kg';
  }
  final parsed = double.tryParse(value.replaceAll(',', '.'));
  if (parsed == null) {
    return 'Ingresa un número válido';
  }
  if (parsed <= 0) {
    return 'El valor debe ser mayor a 0';
  }
  if (parsed < min) {
    return 'El peso mínimo aceptado es ${min.toStringAsFixed(1)} kg';
  }
  return null;
}

/// Validador estandarizado para montos en ECO / PEN:
/// Exige formato numérico positivo, mínimo operativo (0.10 por defecto) y bloquea 0 o 0.00.
String? validateAmount(String? value, {double min = 0.10, String unit = 'ECO'}) {
  if (value == null || value.trim().isEmpty) {
    return 'Ingresa el monto';
  }
  final parsed = double.tryParse(value.replaceAll(',', '.'));
  if (parsed == null) {
    return 'Ingresa un número válido';
  }
  if (parsed <= 0) {
    return 'El monto debe ser mayor a 0';
  }
  if (parsed < min) {
    return 'El monto mínimo es ${min.toStringAsFixed(2)} $unit';
  }
  return null;
}

/// Roles autorizados en la aplicación móvil.
class Roles {
  Roles._();

  static const hogar = 'HOGAR';
  static const recolector = 'RECOLECTOR';
  static const centroAcopio = 'CENTRO_ACOPIO';
  static const tienda = 'TIENDA';

  static String label(String role) => switch (role) {
        hogar => 'Hogar',
        recolector => 'Recolector',
        centroAcopio => 'Centro de Acopio',
        tienda => 'Tienda / Comercio Aliado',
        _ => role,
      };

  static IconData icon(String role) => switch (role) {
        hogar => Icons.home_rounded,
        recolector => Icons.local_shipping_rounded,
        centroAcopio => Icons.warehouse_rounded,
        tienda => Icons.storefront_rounded,
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
      'FLAGGED_FOR_REVIEW' => 'Observado',
      'DISPUTED' => 'En Disputa',
      'PROCESSING' => 'Procesando',
      'RECEIVED' => 'Recibido',
      'CONSOLIDATED' => 'Consolidado',
      _ => status,
    };

Color batchStatusColor(String status) => switch (status) {
      'OPEN' => LivoraColors.cyan,
      'IN_TRANSIT' => LivoraColors.blue,
      'FLAGGED_FOR_REVIEW' => LivoraColors.coral,
      'DISPUTED' => Colors.purple,
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
String fmtKg(Object? kg) {
  if (kg == null) return '0 kg';
  final numVal = kg is num ? kg.toDouble() : double.tryParse('$kg') ?? 0.0;
  final rounded = (numVal * 100).roundToDouble() / 100;
  final text = rounded == rounded.roundToDouble()
      ? rounded.toInt().toString()
      : rounded.toString();
  return '$text kg';
}

String fmtNumber(Object? value) {
  if (value == null) return '0';
  final numVal = value is num ? value.toDouble() : double.tryParse('$value') ?? 0.0;
  final rounded = (numVal * 100).roundToDouble() / 100;
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

/// Sanitiza y formatea nombres de personas/recolectores para no mostrar correos electrónicos crudos.
String sanitizedPersonName(String? name, String? email, {String defaultLabel = 'Recolector'}) {
  if (name != null && name.trim().isNotEmpty && !name.contains('@')) {
    return name.trim();
  }
  if (email != null && email.contains('@')) {
    final prefix = email.split('@').first;
    final cleaned = prefix
        .replaceAll(RegExp(r'[._\-]'), ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((w) => w.length > 1 ? w[0].toUpperCase() + w.substring(1).toLowerCase() : w.toUpperCase())
        .join(' ');
    if (cleaned.isNotEmpty) return cleaned;
  }
  return defaultLabel;
}

/// Sanitiza y formatea la razón social o nombre comercial del Centro de Acopio.
String sanitizedCenterName(String? name, String? email, {String defaultLabel = 'Centro de Acopio Autorizado'}) {
  if (name != null && name.trim().isNotEmpty && !name.contains('@')) {
    return name.trim();
  }
  if (email != null && email.contains('@')) {
    final prefix = email.split('@').first;
    final cleaned = prefix
        .replaceAll(RegExp(r'[._\-]'), ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((w) => w.length > 1 ? w[0].toUpperCase() + w.substring(1).toLowerCase() : w.toUpperCase())
        .join(' ');
    if (cleaned.isNotEmpty) return '$cleaned (Acopio)';
  }
  return defaultLabel;
}

/// Helper universal que garantiza que ningún correo electrónico sea expuesto como nombre.
String sanitizedName(String? name, {String fallback = 'Usuario'}) {
  if (name == null || name.trim().isEmpty) return fallback;
  final trimmed = name.trim();
  if (trimmed.contains('@')) {
    final prefix = trimmed.split('@').first;
    final cleaned = prefix
        .replaceAll(RegExp(r'[._\-]'), ' ')
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((w) => w.length > 1 ? w[0].toUpperCase() + w.substring(1).toLowerCase() : w.toUpperCase())
        .join(' ');
    return cleaned.isNotEmpty ? cleaned : fallback;
  }
  return trimmed;
}

/// Enmascara un Código de Cuenta Interbancario (CCI) peruano de 20 dígitos.
/// Detecta el banco de origen por su código de 3 dígitos y muestra ej: "BCP **0123".
String formatMaskedCci(String? cci) {
  if (cci == null || cci.trim().isEmpty) return 'No registrado';
  final digits = cci.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length < 4) return 'CCI no registrado';

  final prefix = digits.length >= 3 ? digits.substring(0, 3) : '';
  final bankName = switch (prefix) {
    '002' => 'BCP',
    '003' => 'Interbank',
    '011' => 'BBVA',
    '009' => 'Scotiabank',
    '018' => 'Banco de la Nación',
    '038' => 'BanBif',
    '023' => 'Banco Pichincha',
    '035' => 'Santander',
    _ => 'Banco',
  };

  final last4 = digits.substring(digits.length - 4);
  return '$bankName **$last4';
}

/// Sanitiza los datos de un cobro o canje POS para no exponer correos electrónicos de clientes,
/// priorizando su nombre o generando un identificador de ticket comercial (ej. "Cliente #8F92").
String formatCustomerTicket(dynamic item) {
  if (item == null) return 'Cliente';
  if (item is Map) {
    final rawName = item['user']?['name']?.toString() ?? item['userName']?.toString();
    if (rawName != null && rawName.trim().isNotEmpty && !rawName.contains('@')) {
      return rawName.trim();
    }
    final rawId = item['id']?.toString() ?? item['redemptionId']?.toString() ?? item['qrCodeRef']?.toString();
    if (rawId != null && rawId.isNotEmpty) {
      final clean = rawId.replaceAll('-', '').toUpperCase();
      final code = clean.length >= 4 ? clean.substring(0, 4) : clean;
      return 'Cliente #$code';
    }
    final email = item['user']?['email']?.toString();
    if (email != null && email.contains('@')) {
      final prefix = email.split('@').first;
      final code = prefix.length > 4 ? prefix.substring(0, 4).toUpperCase() : prefix.toUpperCase();
      return 'Cliente #$code';
    }
  }
  return 'Cliente';
}

