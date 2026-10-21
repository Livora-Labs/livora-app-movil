import '../../domain/repositories/i_store_repository.dart';
import '../../services/livora_api.dart';

/// Repositorio desacoplado para operaciones comerciales de tiendas aliadas.
/// Implementa [IStoreRepository] garantizando aislamiento de la capa de transporte HTTP.
class StoreRepository implements IStoreRepository {
  StoreRepository({
    required LivoraApi api,
  }) : _api = api;

  final LivoraApi _api;

  @override
  Future<List<Map<String, dynamic>>> fetchAlliedStores() {
    return _api.fetchAlliedStores();
  }

  @override
  Future<Map<String, dynamic>?> getStoreProfile() {
    return _api.getStoreProfile();
  }

  @override
  Future<Map<String, dynamic>> updateStoreProfile({
    required String businessName,
    required String ruc,
    required String address,
    required String bankAccount,
    String? logoUrl,
  }) {
    return _api.updateStoreProfile(
      businessName: businessName,
      ruc: ruc,
      address: address,
      bankAccount: bankAccount,
      logoUrl: logoUrl,
    );
  }

  @override
  Future<List<dynamic>> getRedemptions({int page = 1, int limit = 20}) {
    return _api.storeRedemptions(page: page, limit: limit);
  }

  @override
  Future<List<dynamic>> getSettlements({int page = 1, int limit = 20}) {
    return _api.storeSettlements(page: page, limit: limit);
  }

  @override
  Future<Map<String, dynamic>> requestSettlement(double amount) {
    return _api.requestSettlement(amount);
  }
}
