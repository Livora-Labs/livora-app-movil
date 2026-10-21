/// Contrato formal de dominio para comercios aliados y catálogo de canjes (Rol TIENDA y HOGAR).
/// Principio SOLID: Dependency Inversion Principle (DIP) e Interface Segregation (ISP).
abstract class IStoreRepository {
  /// Obtiene la lista geolocalizada de tiendas aliadas donde canjear tokens.
  Future<List<Map<String, dynamic>>> fetchAlliedStores();

  /// Obtiene el perfil comercial de la tienda aliada autenticada.
  Future<Map<String, dynamic>?> getStoreProfile();

  /// Actualiza la información comercial de la tienda.
  Future<Map<String, dynamic>> updateStoreProfile({
    required String businessName,
    required String ruc,
    required String address,
    required String bankAccount,
    String? logoUrl,
  });

  /// Obtiene el historial de canjes y redenciones de cupones de la tienda.
  Future<List<dynamic>> getRedemptions({int page = 1, int limit = 20});

  /// Obtiene el historial de liquidaciones FIAT a cuenta bancaria CCI.
  Future<List<dynamic>> getSettlements({int page = 1, int limit = 20});

  /// Solicita una liquidación bancaria de tokens LIVO a Soles (PEN).
  Future<Map<String, dynamic>> requestSettlement(double amount);
}
