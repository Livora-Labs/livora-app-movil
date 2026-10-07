import 'package:flutter/material.dart';
import '../../features/hogar/dashboard/views/hogar_dashboard_view.dart';

/// Pantalla principal del HOGAR.
/// Delega de forma transparente en la arquitectura desacoplada [HogarDashboardView] (Clean Architecture MVVM).
class HogarDashboard extends StatelessWidget {
  const HogarDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const HogarDashboardView();
  }
}
