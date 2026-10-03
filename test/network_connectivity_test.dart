import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livora_labs/services/network_connectivity_service.dart';

/// Regresión: la sonda de alcance resolvía `8.8.8.8` con
/// `InternetAddress.lookup` cuando el DNS del backend fallaba. Al ser una IP
/// literal, esa resolución nunca toca la red y devuelve éxito incluso en modo
/// avión, así que el servicio reportaba ONLINE estando sin internet — justo en
/// el caso más común de la calle: WiFi conectado sin salida (portal cautivo,
/// router caído). Sin banner y sin encolar nada.
class _FakeConnectivity implements Connectivity {
  _FakeConnectivity(this._results);

  final List<ConnectivityResult> _results;
  final StreamController<List<ConnectivityResult>> _controller =
      StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => _results;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  /// Espera a que la comprobación inicial (asíncrona) del servicio termine.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

  group('NetworkConnectivityService', () {
    test('con radio activa pero sin salida real queda OFFLINE', () async {
      final service = NetworkConnectivityService(
        connectivity: _FakeConnectivity([ConnectivityResult.wifi]),
        // Nada es alcanzable: simula el WiFi sin internet.
        reachabilityProbe: (host, port, timeout) async => false,
      );
      addTearDown(service.dispose);
      await settle();

      expect(service.hasHardwareConnection, isTrue,
          reason: 'el WiFi sí está conectado');
      expect(service.isOnline, isFalse,
          reason: 'sin alcance real tiene que reportar offline');
      expect(service.state, NetworkReachabilityState.offline);
    });

    test('con radio activa y backend alcanzable queda ONLINE', () async {
      final service = NetworkConnectivityService(
        connectivity: _FakeConnectivity([ConnectivityResult.mobile]),
        reachabilityProbe: (host, port, timeout) async => true,
      );
      addTearDown(service.dispose);
      await settle();

      expect(service.isOnline, isTrue);
      expect(service.state, NetworkReachabilityState.online);
    });

    test('sin ninguna interfaz no llega a sondear', () async {
      var probed = false;
      final service = NetworkConnectivityService(
        connectivity: _FakeConnectivity([ConnectivityResult.none]),
        reachabilityProbe: (host, port, timeout) async {
          probed = true;
          return true;
        },
      );
      addTearDown(service.dispose);
      await settle();

      expect(service.hasHardwareConnection, isFalse);
      expect(service.isOnline, isFalse);
      expect(probed, isFalse, reason: 'sin radio no hace falta gastar la sonda');
    });

    test('checkReachabilityNow refleja la recuperación', () async {
      var reachable = false;
      final service = NetworkConnectivityService(
        connectivity: _FakeConnectivity([ConnectivityResult.wifi]),
        reachabilityProbe: (host, port, timeout) async => reachable,
      );
      addTearDown(service.dispose);
      await settle();
      expect(service.isOnline, isFalse);

      reachable = true;
      expect(await service.checkReachabilityNow(), isTrue);
      expect(service.isOnline, isTrue);
    });
  });

  group('por qué la sonda vieja no servía', () {
    test('resolver una IP literal inalcanzable "funciona" sin red', () async {
      // 192.0.2.1 es TEST-NET-1: no existe ruta posible hacia ella.
      final result = await InternetAddress.lookup('192.0.2.1');
      expect(result, isNotEmpty,
          reason: 'lookup de una IP literal no prueba conectividad alguna');
    });

    test('en cambio una conexión TCP a esa IP no se completa', () async {
      await expectLater(
        Socket.connect('192.0.2.1', 53,
            timeout: const Duration(milliseconds: 300)),
        throwsA(isA<Exception>()),
      );
    });
  });
}
