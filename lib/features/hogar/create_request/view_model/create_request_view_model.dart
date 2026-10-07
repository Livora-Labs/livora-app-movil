import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/api_client.dart';
import '../../../../models/models.dart';
import '../../../../screens/hogar/widgets/material_slider_card.dart';
import '../../../../services/livora_api.dart';
import '../../../../services/location_service.dart';

/// ViewModel desacoplado para la creación de solicitudes de reciclaje (Hogar).
class CreateRequestViewModel extends ChangeNotifier {
  CreateRequestViewModel({
    required LivoraApi api,
    double initialLat = -12.0864,
    double initialLng = -77.0351,
  })  : _api = api,
        _latitude = initialLat,
        _longitude = initialLng;

  final LivoraApi _api;

  final Map<String, double> _materials = {
    'PET': 2.0,
    'CARTON': 1.0,
  };
  String _assignmentMode = 'AUTOMATIC';
  bool _isDonation = false;
  double _latitude;
  double _longitude;
  String _address = '';

  File? _photo;
  String? _photoUrl;
  bool _uploadingPhoto = false;
  bool _busy = false;
  bool _fetchingLocation = false;
  bool _geocodingAddress = false;

  Map<String, double> get materials => Map.unmodifiable(_materials);
  String get assignmentMode => _assignmentMode;
  bool get isDonation => _isDonation;
  double get latitude => _latitude;
  double get longitude => _longitude;
  String get address => _address;
  File? get photo => _photo;
  String? get photoUrl => _photoUrl;
  bool get uploadingPhoto => _uploadingPhoto;
  bool get isBusy => _busy;
  bool get isFetchingLocation => _fetchingLocation;
  bool get isGeocodingAddress => _geocodingAddress;

  double get totalKg => _materials.values.fold<double>(0.0, (s, w) => s + w);

  double get estimatedMarketPEN {
    double total = 0.0;
    _materials.forEach((mat, wt) {
      final spec = kMaterialSpecs[mat.toUpperCase()];
      final rate = spec?.avgMarketRatePerKg ?? 1.0;
      total += wt * rate;
    });
    return total;
  }

  double get estimatedLivoReward => _isDonation ? 0.0 : (estimatedMarketPEN * 0.25);
  double get estimatedCollectorPEN => _isDonation ? (estimatedMarketPEN * 0.95) : (estimatedMarketPEN * 0.70);
  double get estimatedLivoraFeePEN => estimatedMarketPEN * 0.05;

  double get estimatedCo2Saved {
    double co2 = 0.0;
    _materials.forEach((mat, wt) {
      final spec = kMaterialSpecs[mat.toUpperCase()];
      co2 += wt * (spec?.co2FactorPerKg ?? 1.0);
    });
    return co2;
  }

  double get estimatedWaterSaved {
    double water = 0.0;
    _materials.forEach((mat, wt) {
      final spec = kMaterialSpecs[mat.toUpperCase()];
      water += wt * (spec?.waterFactorPerKg ?? 15.0);
    });
    return water;
  }

  void setAssignmentMode(String mode) {
    if (_assignmentMode != mode) {
      _assignmentMode = mode;
      notifyListeners();
    }
  }

  void setIsDonation(bool value) {
    if (_isDonation != value) {
      _isDonation = value;
      notifyListeners();
    }
  }

  void updateMaterialWeight(String material, double weight) {
    if (weight <= 0) {
      _materials.remove(material);
    } else {
      _materials[material] = double.parse(weight.toStringAsFixed(2));
    }
    notifyListeners();
  }

  void setCoordinates(double lat, double lng) {
    _latitude = lat;
    _longitude = lng;
    notifyListeners();
    resolveAddress(lat, lng);
  }

  void setAddress(String addr) {
    _address = addr;
    notifyListeners();
  }

  Future<void> resolveAddress(double lat, double lng) async {
    _geocodingAddress = true;
    notifyListeners();

    try {
      final street = await LocationService.reverseGeocode(lat, lng, api: _api);
      if (street != null && street.isNotEmpty) {
        _address = street;
      }
    } catch (_) {}

    _geocodingAddress = false;
    notifyListeners();
  }

  Future<void> fetchCurrentGps() async {
    _fetchingLocation = true;
    notifyListeners();

    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null) {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        await resolveAddress(pos.latitude, pos.longitude);
      }
    } catch (_) {}

    _fetchingLocation = false;
    notifyListeners();
  }

  Future<void> pickAndUploadPhoto(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (picked == null) return;

      _photo = File(picked.path);
      _photoUrl = null;
      _uploadingPhoto = true;
      notifyListeners();

      final url = await _api.uploadFile(
        filePath: picked.path,
        purpose: 'collection',
      );
      _photoUrl = url;
      _uploadingPhoto = false;
      notifyListeners();
    } on ApiException catch (_) {
      _photo = null;
      _uploadingPhoto = false;
      notifyListeners();
    } catch (_) {
      _uploadingPhoto = false;
      notifyListeners();
    }
  }

  void removePhoto() {
    _photo = null;
    _photoUrl = null;
    notifyListeners();
  }

  Future<CollectionRequest?> submitRequest({
    required String fullAddress,
    String? reference,
    String? notes,
    bool? isDonation,
  }) async {
    if (totalKg < 0.5) return null;
    _busy = true;
    notifyListeners();

    try {
      final descriptionParts = [
        if (fullAddress.isNotEmpty) 'Dirección: $fullAddress',
        if (reference != null && reference.isNotEmpty) 'Referencia: $reference',
        if (notes != null && notes.isNotEmpty) notes,
      ];

      final donationFlag = isDonation ?? _isDonation;

      final req = await _api.createCollectionRequest(
        itemsEstimated: _materials,
        latitude: _latitude,
        longitude: _longitude,
        assignmentMode: _assignmentMode,
        address: fullAddress.isNotEmpty ? fullAddress : null,
        description: descriptionParts.isNotEmpty ? descriptionParts.join(' · ') : null,
        photoUrl: _photoUrl,
        isDonation: donationFlag,
      );

      _busy = false;
      notifyListeners();
      return req;
    } catch (e) {
      _busy = false;
      notifyListeners();
      return null;
    }
  }
}
