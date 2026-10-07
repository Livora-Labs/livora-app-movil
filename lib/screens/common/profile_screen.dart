import 'package:flutter/material.dart';
import '../../features/common/profile/views/profile_view.dart';

/// Pantalla de Perfil de Usuario de Livora.
/// Delega de forma transparente en la arquitectura desacoplada [ProfileView] (Clean Architecture MVVM).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfileView();
  }
}
