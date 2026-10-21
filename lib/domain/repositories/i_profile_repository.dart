import '../../models/models.dart';

/// Contrato formal de dominio para gestión de perfiles, credenciales y consentimientos legales.
/// Principio SOLID: Dependency Inversion Principle (DIP).
abstract class IProfileRepository {
  /// Obtiene los datos del perfil del usuario autenticado.
  Future<AuthUser> getProfile();

  /// Actualiza los datos personales, de contacto y coordenadas del usuario.
  Future<AuthUser> updateProfile({
    required AuthUser currentUser,
    String? name,
    String? phone,
    String? address,
    double? latitude,
    double? longitude,
  });

  /// Registra el consentimiento independiente para comunicaciones comerciales.
  Future<AuthUser> updateMarketingConsent({
    required AuthUser currentUser,
    required bool accepted,
  });

  /// Actualiza la contraseña del usuario.
  Future<void> changePassword({
    required String newPassword,
    String? currentPassword,
  });

  /// Elimina definitivamente la cuenta del usuario (Derecho al Olvido / ARCO).
  Future<void> deleteAccount({String? password});
}
