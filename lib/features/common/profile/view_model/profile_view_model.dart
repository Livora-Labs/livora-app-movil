import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../data/repositories/profile_repository.dart';
import '../../../../domain/state/ui_state.dart';
import '../../../../models/models.dart';
import '../../../../services/location_service.dart';

/// ViewModel desacoplado para la gestión del perfil del usuario.
class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({
    required ProfileRepository repository,
    required AuthUser initialUser,
  })  : _repository = repository,
        _user = initialUser,
        _state = UIState.success(initialUser);

  final ProfileRepository _repository;
  AuthUser _user;
  UIState<AuthUser> _state;

  AuthUser get user => _user;
  UIState<AuthUser> get state => _state;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  bool _isFetchingGps = false;
  bool get isFetchingGps => _isFetchingGps;

  String? _feedbackMessage;
  String? get feedbackMessage => _feedbackMessage;

  void clearFeedback() {
    _feedbackMessage = null;
    notifyListeners();
  }

  /// Recarga el perfil desde el servidor.
  Future<void> reloadProfile() async {
    _state = UIState.loading(cachedData: _user);
    notifyListeners();

    try {
      final updated = await _repository.getProfile();
      _user = updated;
      _state = UIState.success(updated);
    } catch (e) {
      _state = UIState.error(
        'No se pudo actualizar el perfil',
        cachedData: _user,
      );
    }
    notifyListeners();
  }

  /// Actualiza los datos personales y de domicilio.
  Future<bool> updateProfile({
    required String name,
    required String phone,
    required String address,
    double? latitude,
    double? longitude,
  }) async {
    _isSaving = true;
    notifyListeners();

    try {
      final updated = await _repository.updateProfile(
        currentUser: _user,
        name: name.trim(),
        phone: phone.trim(),
        address: address.trim(),
        latitude: latitude,
        longitude: longitude,
      );
      _user = updated;
      _state = UIState.success(updated);
      _feedbackMessage = 'Perfil actualizado correctamente';
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _feedbackMessage = 'Error al actualizar el perfil';
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  /// Actualiza el consentimiento de marketing.
  Future<void> setMarketingConsent(bool accepted) async {
    try {
      final updated = await _repository.updateMarketingConsent(
        currentUser: _user,
        accepted: accepted,
      );
      _user = updated;
      _state = UIState.success(updated);
      notifyListeners();
    } catch (_) {}
  }

  /// Obtiene la ubicación GPS actual y la dirección por geocodificación inversa.
  Future<Map<String, dynamic>?> fetchCurrentGps() async {
    _isFetchingGps = true;
    notifyListeners();

    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos == null) {
        _isFetchingGps = false;
        notifyListeners();
        return null;
      }

      final address = await LocationService.reverseGeocode(
        pos.latitude,
        pos.longitude,
      );

      _isFetchingGps = false;
      notifyListeners();

      return {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'address': address ?? '',
      };
    } catch (_) {
      _isFetchingGps = false;
      notifyListeners();
      return null;
    }
  }

  /// Cambia la contraseña de acceso.
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _isSaving = true;
    notifyListeners();

    try {
      await _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      _feedbackMessage = 'Contraseña actualizada con éxito';
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _feedbackMessage = e.toString();
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  /// Elimina definitivamente la cuenta.
  Future<bool> deleteAccount({required String password}) async {
    _isSaving = true;
    notifyListeners();

    try {
      await _repository.deleteAccount(password: password);
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _feedbackMessage = e.toString();
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }
}
