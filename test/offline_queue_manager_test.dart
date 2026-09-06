import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livora_labs/core/api_client.dart';
import 'package:livora_labs/services/livora_api.dart';
import 'package:flutter/services.dart';
import 'package:livora_labs/services/offline_queue_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box box;
  late SharedPreferences prefs;
  late List<String> verifiedRequests;
  late int mockStatusCode;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'check') {
          return ['wifi'];
        }
        return null;
      },
    );
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_offline_test_');
    Hive.init(tempDir.path);
    box = await Hive.openBox('offline_verifications');
    await box.clear();

    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    verifiedRequests = [];
    mockStatusCode = 200;

    final mockClient = MockClient((request) async {
      if (request.url.path.contains('/verify')) {
        verifiedRequests.add(request.url.path);
        if (mockStatusCode == 200) {
          return http.Response(
            jsonEncode({
              'id': 'req-1',
              'status': 'COMPLETED',
              'itemsEstimated': {'PET': 2.0},
            }),
            200,
          );
        } else if (mockStatusCode == 400) {
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'BAD_REQUEST',
                'message': 'PIN incorrecto',
              }
            }),
            400,
          );
        } else {
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'INTERNAL_ERROR',
                'message': 'Servidor no disponible',
              }
            }),
            500,
          );
        }
      }
      return http.Response('{}', 200);
    });

    final apiClient = ApiClient(prefs, client: mockClient);
    final livoraApi = LivoraApi(apiClient);

    await OfflineQueueManager.init(livoraApi, box: box);
  });

  tearDown(() async {
    await box.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('enqueueVerification almacena datos con createdAt y actualiza pendingCountNotifier', () async {
    expect(OfflineQueueManager.pendingCountNotifier.value, 0);

    await OfflineQueueManager.enqueueVerification('req-101', '1234');
    await OfflineQueueManager.processQueue();

    expect(verifiedRequests.length, 1);
    expect(OfflineQueueManager.pendingCountNotifier.value, 0);
  });

  test('processQueue respeta orden estrictamente FIFO segun createdAt', () async {
    mockStatusCode = 200;

    final older = {
      'requestId': 'req-old',
      'pin': '1111',
      'createdAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
    };
    final newer = {
      'requestId': 'req-new',
      'pin': '2222',
      'createdAt': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
    };

    await box.put('req-new', jsonEncode(newer));
    await box.put('req-old', jsonEncode(older));

    expect(OfflineQueueManager.pendingCount, 2);

    await OfflineQueueManager.processQueue();

    expect(verifiedRequests, [
      '/collection-requests/req-old/verify',
      '/collection-requests/req-new/verify',
    ]);
    expect(box.isEmpty, isTrue);
    expect(OfflineQueueManager.pendingCountNotifier.value, 0);
  });

  test('descarta registros con mas de 24 horas de antiguedad (TTL) sin detener la cola', () async {
    final expired = {
      'requestId': 'req-expired',
      'pin': '9999',
      'createdAt': DateTime.now().subtract(const Duration(hours: 25)).toIso8601String(),
    };
    final valid = {
      'requestId': 'req-valid',
      'pin': '8888',
      'createdAt': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
    };

    await box.put('req-expired', jsonEncode(expired));
    await box.put('req-valid', jsonEncode(valid));

    await OfflineQueueManager.processQueue();

    expect(verifiedRequests, ['/collection-requests/req-valid/verify']);
    expect(box.containsKey('req-expired'), isFalse);
    expect(box.containsKey('req-valid'), isFalse);
    expect(OfflineQueueManager.pendingCountNotifier.value, 0);
  });

  test('error 400 (Bad Request / PIN invalido) purga de inmediato el registro (dead-letter)', () async {
    mockStatusCode = 400;

    final badRequest = {
      'requestId': 'req-bad',
      'pin': '0000',
      'createdAt': DateTime.now().toIso8601String(),
    };

    await box.put('req-bad', jsonEncode(badRequest));

    await OfflineQueueManager.processQueue();

    expect(verifiedRequests, ['/collection-requests/req-bad/verify']);
    expect(box.containsKey('req-bad'), isFalse);
    expect(OfflineQueueManager.pendingCountNotifier.value, 0);
  });

  test('error 500 (Servidor / Red) pausa la cola y mantiene los registros en Hive', () async {
    mockStatusCode = 500;

    final pendingRequest = {
      'requestId': 'req-server-fail',
      'pin': '5555',
      'createdAt': DateTime.now().toIso8601String(),
    };

    await box.put('req-server-fail', jsonEncode(pendingRequest));

    await OfflineQueueManager.processQueue();

    expect(verifiedRequests, ['/collection-requests/req-server-fail/verify']);
    expect(box.containsKey('req-server-fail'), isTrue);
    expect(OfflineQueueManager.pendingCountNotifier.value, 1);
  });

  test('clearQueue vacia la caja y resetea el ValueNotifier a 0', () async {
    await box.put('req-1', jsonEncode({'requestId': 'req-1', 'pin': '1234'}));
    await box.put('req-2', jsonEncode({'requestId': 'req-2', 'pin': '5678'}));

    expect(box.length, 2);

    await OfflineQueueManager.clearQueue();

    expect(box.isEmpty, isTrue);
    expect(OfflineQueueManager.pendingCountNotifier.value, 0);
  });
}