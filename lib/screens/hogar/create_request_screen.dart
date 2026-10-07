import 'package:flutter/material.dart';
import '../../features/hogar/create_request/views/create_request_view.dart';

/// Pantalla de Creación de Solicitudes de Recolección (HOGAR).
/// Delega de forma transparente en la arquitectura desacoplada [CreateRequestView] (Clean Architecture MVVM).
class CreateRequestScreen extends StatelessWidget {
  const CreateRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CreateRequestView();
  }
}
