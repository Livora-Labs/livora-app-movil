import '../../domain/repositories/i_profile_repository.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';

/// Repositorio desacoplado para la gestión de perfil de usuario,
/// credenciales, domicilio y consentimientos regulatorios (GDPR / Ley 29733).
class ProfileRepository implements IProfileRepository {
  ProfileRepository({
    required LivoraApi api,
  }) : _api = api;

  final LivoraApi _api;

  @override
  Future<AuthUser> getProfile() async {
    return _api.getMe();
  }

  @override
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

  @override
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

  @override
  Future<void> changePassword({
    required String newPassword,
    String? currentPassword,
  }) async {
    await _api.changePassword(
      newPassword: newPassword,
      currentPassword: currentPassword,
    );
  }

  @override
  Future<void> deleteAccount({String? password}) async {
    await _api.deleteAccount();
  }
}
