import 'package:flutter/material.dart';
import '../../features/hogar/request_detail/views/request_detail_view.dart';

/// Detalle de una solicitud de recolección (vista del HOGAR).
/// Arquitectura refactorizada hacia MVVM con micro-componentes especializados (<250 líneas)
/// y Repositorio desacoplado con soporte de caché local Hive (Offline-First).
class RequestDetailScreen extends StatelessWidget {
  const RequestDetailScreen({
    super.key,
    required this.requestId,
  });

  final String requestId;

  @override
  Widget build(BuildContext context) {
    return RequestDetailView(requestId: requestId);
  }
}
