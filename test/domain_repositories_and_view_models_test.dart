import 'package:livora_labs/services/livora_api.dart';
import 'package:livora_labs/domain/repositories/i_collection_repository.dart';
import 'package:livora_labs/features/recolector/active_route/view_model/collector_route_view_model.dart';
import 'package:livora_labs/services/telemetry_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livora_labs/core/api_client.dart';
import 'package:livora_labs/core/session.dart';
import 'package:livora_labs/domain/repositories/i_batch_repository.dart';
import 'package:livora_labs/domain/repositories/i_collector_repository.dart';
import 'package:livora_labs/domain/repositories/i_complaints_repository.dart';
import 'package:livora_labs/domain/repositories/i_wallet_repository.dart';
import 'package:livora_labs/domain/state/ui_state.dart';
import 'package:livora_labs/features/common/complaints/view_model/complaints_view_model.dart';
import 'package:livora_labs/features/recolector/available_requests/view_model/available_requests_view_model.dart';
import 'package:livora_labs/features/recolector/my_batch/view_model/my_batch_view_model.dart';
import 'package:livora_labs/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// MOCKS POLIMÓRFICOS (LSP & DIP)
// ---------------------------------------------------------------------------

class MockCollectorRepository implements ICollectorRepository {
  List<CollectionRequest> requestsToReturn = [];
  List<Batch> batchesToReturn = [];
  bool acceptCalled = false;
  String? acceptedId;

  @override
  Future<List<CollectionRequest>> getAvailableRequests({
    double? lat,
    double? lng,
    double radiusKm = 5.0,
    String? centerId,
    bool onlyActiveBatches = false,
  }) async {
    return requestsToReturn;
  }

  @override
  Future<List<Batch>> getOpenBatches() async {
    return batchesToReturn;
  }

  @override
  Future<void> acceptRequest(String requestId) async {
    acceptCalled = true;
    acceptedId = requestId;
  }

  @override
  Future<CollectionRequest> rejectOnSite(String requestId, String reason, [String? photoUrl]) async {
    throw UnimplementedError();
  }

  @override
  Future<CollectorReputation> getReputation() async {
    return CollectorReputation(
      score: 4.9,
      ratingCount: 25,
      totalPickups: 32,
      badge: 'PRO',
    );
  }
}

class MockWalletRepository implements IWalletRepository {
  String balanceToReturn = '150.00';

  @override
  Future<String> getBalance({bool forceRefresh = false}) async {
    return balanceToReturn;
  }

  @override
  Future<Map<String, dynamic>> sendTokens({required String toAddress, required double amount}) async {
    return {'transactionId': 'TX-MOCK-123'};
  }

  @override
  Future<Map<String, dynamic>> getRedemptionDetails(String scannedCode) async => {};

  @override
  Future<Map<String, dynamic>> confirmRedemption(String scannedCode) async => {};

  @override
  Future<Map<String, dynamic>> createPaymentSession(double amount) async => {};

  @override
  Future<List<WalletTransaction>> getTransactions({int page = 1, int limit = 20, String? direction}) async => [];
}

class MockComplaintsRepository implements IComplaintsRepository {
  bool shouldFail = false;

  @override
  Future<Map<String, dynamic>> submitComplaint({
    required String documentType,
    required String documentNumber,
    required String fullName,
    required String address,
    required String phone,
    required String email,
    required bool isMinor,
    String? representativeName,
    String? representativeDoc,
    required String goodType,
    required String goodDescription,
    double? amount,
    required String claimType,
    required String claimDetail,
    required String consumerRequest,
  }) async {
    if (shouldFail) {
      throw Exception('Error simulado al registrar queja');
    }
    return {
      'correlative': '00042-2026',
      'status': 'REGISTERED',
      'email': email,
    };
  }

  @override
  Future<Map<String, dynamic>> getComplaintStatus({
    required String correlativeNumber,
    required String documentNumber,
  }) async {
    return {'correlative': correlativeNumber, 'documentNumber': documentNumber, 'status': 'RECEIVED'};
  }
}

class MockBatchRepository implements IBatchRepository {
  List<Batch> batches = [];
  bool dispatchCalled = false;

  @override
  Future<List<Batch>> getBatches({bool forceRefresh = false, String? status}) async {
    if (status == 'IN_TRANSIT') {
      return batches.where((b) => b.status == 'IN_TRANSIT').toList();
    }
    if (status == 'DELIVERED') {
      return batches.where((b) => b.status == 'DELIVERED').toList();
    }
    return batches;
  }

  @override
  Future<Batch> getBatchDetail(String id, {bool forceRefresh = false}) async {
    return batches.firstWhere((b) => b.id == id);
  }

  @override
  Future<Batch> dispatchBatch(String batchId, String centerId) async {
    dispatchCalled = true;
    final b = batches.firstWhere((x) => x.id == batchId);
    return Batch(
      id: b.id,
      status: 'DISPATCHED',
      materialsActual: b.materialsActual,
      createdAt: b.createdAt,
    );
  }

  @override
  Future<Map<String, dynamic>> receiveBatch(
    String batchId,
    Map<String, double> weights,
  ) async {
    return {'status': 'ACCEPTED', 'batchId': batchId};
  }

  @override
  Future<List<Batch>> getOpenBatches({String? centerId}) async {
    return batches.where((b) => b.status == 'OPEN').toList();
  }

  @override
  Future<Map<String, dynamic>> consolidateBatches(List<String> batchIds) async {
    return {'consolidatedBatchId': 'batch-consolidated-001'};
  }
}

// ---------------------------------------------------------------------------
// SUITE DE PRUEBAS SOLID & MVVM
// ---------------------------------------------------------------------------

class MockCollectionRepository implements ICollectionRepository {
  bool arrivalConfirmed = false;
  String? confirmedId;

  @override
  Future<CollectionRequest> confirmArrival(String id) async {
    arrivalConfirmed = true;
    confirmedId = id;
    return CollectionRequest(
      id: id,
      status: 'ARRIVED',
      householdId: 'h-1',
      latitude: -12.0464,
      longitude: -77.0428,
      itemsEstimated: {'PET': 5.0},
    );
  }

  @override
  Future<CollectionRequest> getRequest(String id, {bool forceRefresh = false}) async {
    return CollectionRequest(
      id: id,
      status: 'EN_ROUTE',
      householdId: 'h-1',
      latitude: -12.0464,
      longitude: -77.0428,
      itemsEstimated: {'PET': 5.0},
    );
  }

  @override
  Stream<CollectionRequest> watchRequest(String id) async* {}

  @override
  Future<void> cancelRequest(String id, {String? reason}) async {}

  @override
  Future<void> editRequest(String id, {Map<String, double>? itemsEstimated, String? description}) async {}

  @override
  Future<void> selectBid(String requestId, String bidId) async {}

  @override
  Future<void> rateRequest(String id, {required int rating, String? feedback}) async {}

  @override
  Future<Map<String, dynamic>> calculateRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String profile = 'driving',
  }) async {
    return {'coordinates': <dynamic>[], 'distanceMeters': 1200.0, 'etaMinutes': 5};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PUCP Disoft & SOLID: Domain Repositories & LSP Compliance', () {
    test('Interfaces IWalletRepository, ICollectorRepository, IBatchRepository cumplen LSP', () {
      final IWalletRepository wallet = MockWalletRepository();
      expect(wallet, isA<IWalletRepository>());

      final ICollectorRepository collector = MockCollectorRepository();
      expect(collector, isA<ICollectorRepository>());

      final IBatchRepository batch = MockBatchRepository();
      expect(batch, isA<IBatchRepository>());

      final IComplaintsRepository complaint = MockComplaintsRepository();
      expect(complaint, isA<IComplaintsRepository>());
    });
  });

  group('MVVM & SRP: AvailableRequestsViewModel', () {
    late MockCollectorRepository mockCollector;
    late MockWalletRepository mockWallet;
    late SessionController session;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'livora_auth_token': 'dummy_token'});
      final prefs = await SharedPreferences.getInstance();
      final client = ApiClient(prefs);
      session = SessionController(client, prefs);
      mockCollector = MockCollectorRepository();
      mockWallet = MockWalletRepository();
    });

    test('AvailableRequestsViewModel transitions from initial to success state with filtered items', () async {
      final req1 = CollectionRequest(
        id: 'req-01',
        status: 'PENDING',
        itemsEstimated: {'PET': 10.0},
        assignedCenterId: 'center-surquillo',
      );
      final req2 = CollectionRequest(
        id: 'req-02',
        status: 'PENDING',
        itemsEstimated: {'CARTON': 5.0},
        assignedCenterId: 'center-miraflores',
      );
      mockCollector.requestsToReturn = [req1, req2];

      final vm = AvailableRequestsViewModel(
        collectorRepository: mockCollector,
        walletRepository: mockWallet,
        sessionController: session,
      );

      expect(vm.requestsState.isInitial, isTrue);

      await vm.load();

      expect(vm.requestsState.isSuccess, isTrue);
      expect(vm.requestsState.dataOrNull?.length, equals(2));
      expect(vm.walletEcoBalance, equals(150.0));

      // Filtro por centro
      await vm.setFilters(centerId: 'center-surquillo', onlyActiveBatches: false);
      expect(vm.requestsState.dataOrNull?.length, equals(1));
      expect(vm.requestsState.dataOrNull?.first.id, equals('req-01'));
    });

    test('AvailableRequestsViewModel acceptRequest delega al repositorio y actualiza estado', () async {
      final req = CollectionRequest(
        id: 'req-99',
        status: 'PENDING',
        itemsEstimated: {'PET': 20.0},
      );
      mockCollector.requestsToReturn = [req];

      final vm = AvailableRequestsViewModel(
        collectorRepository: mockCollector,
        walletRepository: mockWallet,
        sessionController: session,
      );

      await vm.load();
      final success = await vm.acceptRequest(req);

      expect(success, isTrue);
      expect(mockCollector.acceptCalled, isTrue);
      expect(mockCollector.acceptedId, equals('req-99'));
    });
  });

  group('MVVM & SRP: ComplaintsViewModel', () {
    test('ComplaintsViewModel registra queja exitosamente y expone correlativo', () async {
      final mockRepo = MockComplaintsRepository();
      final vm = ComplaintsViewModel(repository: mockRepo);

      expect(vm.submitState.isInitial, isTrue);
      expect(vm.registeredComplaint, isNull);

      final res = await vm.submitComplaint(
        documentType: 'DNI',
        documentNumber: '76543210',
        fullName: 'Consumidor Modelo',
        address: 'Av. Primavera 123, Surco',
        phone: '987654321',
        email: 'consumidor@ejemplo.com',
        isMinor: false,
        goodType: 'SERVICIO',
        goodDescription: 'Recolección a domicilio',
        claimType: 'RECLAMO',
        claimDetail: 'Retraso de recolección en fecha pactada',
        consumerRequest: 'Reprogramación y asignación de tokens',
      );

      expect(res, isNotNull);
      expect(res?['correlative'], equals('00042-2026'));
      expect(vm.submitState.isSuccess, isTrue);
      expect(vm.registeredComplaint?['correlative'], equals('00042-2026'));
    });

    test('ComplaintsViewModel maneja errores de red y expone UIState.error', () async {
      final mockRepo = MockComplaintsRepository()..shouldFail = true;
      final vm = ComplaintsViewModel(repository: mockRepo);

      final res = await vm.submitComplaint(
        documentType: 'DNI',
        documentNumber: '76543210',
        fullName: 'Consumidor Modelo',
        address: 'Av. Primavera 123',
        phone: '987654321',
        email: 'consumidor@ejemplo.com',
        isMinor: false,
        goodType: 'SERVICIO',
        goodDescription: 'Recolección',
        claimType: 'RECLAMO',
        claimDetail: 'Detalle',
        consumerRequest: 'Solución',
      );

      expect(res, isNull);
      expect(vm.submitState.isError, isTrue);
      expect((vm.submitState as UIError).message, contains('Error simulado'));
    });
  });

  group('MVVM & SRP: MyBatchViewModel', () {
    test('MyBatchViewModel clasifica lotes en ruta e historial y permite despacho', () async {
      final now = DateTime.now();
      final batch1 = Batch(
        id: 'batch-active-1',
        status: 'OPEN',
        materialsActual: {'PET': 15.0},
        createdAt: now,
      );
      final batch2 = Batch(
        id: 'batch-done-1',
        status: 'DELIVERED',
        materialsActual: {'CARTON': 25.0},
        createdAt: now,
      );

      final mockRepo = MockBatchRepository()..batches = [batch1, batch2];
      final vm = MyBatchViewModel(repository: mockRepo);

      await vm.loadBatches();

      expect(vm.openBatchesState.isSuccess, isTrue);
      expect(vm.openBatchesState.dataOrNull?.length, equals(1));
      expect(vm.openBatchesState.dataOrNull?.first.id, equals('batch-active-1'));

      expect(vm.historyBatchesState.isSuccess, isTrue);
      expect(vm.historyBatchesState.dataOrNull?.length, equals(1));
      expect(vm.historyBatchesState.dataOrNull?.first.id, equals('batch-done-1'));

      // Despacho
      await vm.dispatchBatch('batch-active-1', 'center-miraflores');
      expect(mockRepo.dispatchCalled, isTrue);
    });
  });
  group('MVVM & SRP: CollectorRouteViewModel', () {
    test('CollectorRouteViewModel.markArrived confirma llegada y apaga telemetria', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final mockApi = LivoraApi(ApiClient(prefs));
      final telemetry = TelemetryService(api: mockApi);
      final mockRepo = MockCollectionRepository();
      final req = CollectionRequest(
        id: 'req-route-1',
        status: 'EN_ROUTE',
        householdId: 'h-1',
        latitude: -12.0464,
        longitude: -77.0428,
        itemsEstimated: {'PET': 5.0},
      );

      final vm = CollectorRouteViewModel(
        initialRequest: req,
        repository: mockRepo,
        telemetryService: telemetry,
        initialCollectorLat: -12.0450,
        initialCollectorLng: -77.0410,
      );

      final ok = await vm.markArrived();
      expect(ok, isTrue);
      expect(mockRepo.arrivalConfirmed, isTrue);
      expect(mockRepo.confirmedId, equals('req-route-1'));
      vm.dispose();
    });
  });

}
