import 'dart:async';
import '../../models/models.dart';
import '../../services/livora_api.dart';

/// Repositorio desacoplado para la gestión de perfil de usuario,
/// credenciales, domicilio y consentimientos regulatorios (GDPR / Ley 29733).
class ProfileRepository {
  ProfileRepository({
    required LivoraApi api,
  }) : _api = api;

  final LivoraApi _api;

  /// Obtiene los datos frescos del perfil del usuario.
  Future<AuthUser> getProfile() async {
    return _api.getMe();
  }

  /// Actualiza los datos de contacto y domicilio del usuario.
  Future<AuthUser> updateProfile({
    required AuthUser currentUser,
    String? name,
    String? phone,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    await _api.updateProfile(
      name: name,
      phone: phone,
      address: address,
      latitude: latitude,
      longitude: longitude,
    );

    try {
      final fresh = await _api.getMe();
      if (fresh.role.isNotEmpty) {
        return fresh;
      }
    } catch (_) {}

    return currentUser.copyWith(
      name: name,
      phone: phone,
      address: address,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Actualiza la preferencia explícita de consentimiento para comunicaciones comerciales.
  Future<AuthUser> updateMarketingConsent({
    required AuthUser currentUser,
    required bool accepted,
  }) async {
    await _api.updateProfile(marketingAccepted: accepted);
    try {
      final fresh = await _api.getMe();
      if (fresh.role.isNotEmpty) {
        return fresh;
      }
    } catch (_) {}

    return currentUser.copyWith(marketingAccepted: accepted);
  }

  /// Cambia la contraseña de acceso del usuario autenticado.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  /// Solicita el borrado definitivo de cuenta de conformidad con los derechos ARCO.
  Future<void> deleteAccount({String? password}) async {
    await _api.deleteAccount();
  }
}
