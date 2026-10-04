import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../core/session.dart';
import '../../core/stellar.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../services/livora_realtime.dart';
import '../../services/location_service.dart';
import '../../widgets/common.dart';
import '../../widgets/livora_map_tile_layer.dart';
import 'auction_bids_screen.dart';
import 'widgets/material_slider_card.dart';

/// Detalle de una solicitud de recolección (vista del HOGAR).
class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  CollectionRequest? _request;
  String? _error;
  bool _cancelling = false;
  String? _selectingBidId;
  String? _cachedPin;

  StreamSubscription<Map<String, dynamic>>? _locationSub;
  StreamSubscription<Map<String, dynamic>>? _arrivedSub;
  StreamSubscription<Map<String, dynamic>>? _bidSub;
  StreamSubscription<Map<String, dynamic>>? _updateSub;
  Timer? _bidToastTimer;
  Map<String, dynamic>? _incomingBidToast;
  int _bidToastSecondsLeft = 10;
  Timer? _bidCountdownTimer;

  LatLng? _collectorPos;
  double _collectorHeading = 0.0;
  int? _etaMinutes;
  double? _distanceMeters;
  bool _geofenceAlertTriggered = false;
  final MapController _mapController = MapController();
  List<LatLng> _polylinePoints = [];
  String? _transportType;
  DateTime? _lastRouteFetch;
  Timer? _routeRefreshTimer;
  bool _firstMapFitDone = false;
  DateTime? _lastLocationPing;
  Timer? _staleCheckTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeRealtime();
    _staleCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && _request?.status == 'EN_ROUTE') {
        setState(() {});
      }
    });
  }

  void _triggerBidPopup(Map<String, dynamic> data) {
    _bidToastTimer?.cancel();
    _bidCountdownTimer?.cancel();
    setState(() {
      _incomingBidToast = data;
      _bidToastSecondsLeft = 10;
    });

    _bidCountdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_bidToastSecondsLeft <= 1) {
        t.cancel();
      } else {
        setState(() => _bidToastSecondsLeft--);
      }
    });

    _bidToastTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _incomingBidToast = null;
        });
      }
    });
  }

  void _fitMapBounds() {
    if (_collectorPos == null || _request == null) return;
    try {
      final points = _polylinePoints.isNotEmpty
          ? _polylinePoints
          : [LatLng(_request!.latitude, _request!.longitude), _collectorPos!];
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(40),
        ),
      );
    } catch (_) {}
  }

  Future<void> _fetchOsrmRoute({bool silent = false}) async {
    if (_collectorPos == null || _request == null) return;
    final now = DateTime.now();
    if (_lastRouteFetch != null &&
        now.difference(_lastRouteFetch!).inSeconds < 8 &&
        _polylinePoints.isNotEmpty) {
      return;
    }
    _lastRouteFetch = now;

    String profile = 'driving';
    final transport = _transportType ?? _request?.collectorLocation?.transportType;
    if (transport == 'A_PIE') {
      profile = 'walking';
    } else if (transport == 'BICICLETA' || transport == 'TRICICLO') {
      profile = 'cycling';
    }

    try {
      final res = await context.read<LivoraApi>().calculateRoute(
            originLat: _collectorPos!.latitude,
            originLng: _collectorPos!.longitude,
            destLat: _request!.latitude,
            destLng: _request!.longitude,
            profile: profile,
          );

      final geometry = res['geometry'] as Map<String, dynamic>?;
      final coords = geometry?['coordinates'] as List<dynamic>?;

      if (coords != null && coords.isNotEmpty && mounted) {
        final points = coords.map((c) {
          final pair = c as List<dynamic>;
          return LatLng(
            (pair[1] as num).toDouble(),
            (pair[0] as num).toDouble(),
          );
        }).toList();

        setState(() {
          _polylinePoints = points;
          if (res['distanceMeters'] != null) {
            _distanceMeters = (res['distanceMeters'] as num).toDouble();
          }
          if (res['etaMinutes'] != null) {
            _etaMinutes = (res['etaMinutes'] as num).toInt();
          }
        });
        if (!_firstMapFitDone) {
          _firstMapFitDone = true;
          _fitMapBounds();
        }
      }
    } catch (e) {
      debugPrint('[HogarRoute] Error calculando ruta OSRM: $e');
    }
  }

  void _subscribeRealtime() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final realtime = context.read<LivoraRealtime>();
      _locationSub = realtime.on(RealtimeEvents.collectorLocation).listen((data) {
        if (data['requestId'] == widget.requestId && mounted) {
          final lat = (data['latitude'] as num?)?.toDouble();
          final lng = (data['longitude'] as num?)?.toDouble();
          final heading = (data['heading'] as num?)?.toDouble() ?? 0.0;
          final eta = (data['etaMinutes'] as num?)?.toInt();
          final dist = (data['distanceRemainingMeters'] as num?)?.toDouble();

          if (lat != null && lng != null) {
            final oldPos = _collectorPos;
            setState(() {
              _collectorPos = LatLng(lat, lng);
              _collectorHeading = heading;
              _etaMinutes = eta;
              _distanceMeters = dist;
              _lastLocationPing = DateTime.now();
              if (data['transportType'] != null) {
                _transportType = data['transportType'] as String;
              }
            });

            if (!_firstMapFitDone) {
              _firstMapFitDone = true;
              WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapBounds());
            }

            if (oldPos == null ||
                LocationService.distanceBetween(
                        oldPos.latitude, oldPos.longitude, lat, lng) >
                    30) {
              _fetchOsrmRoute(silent: true);
            }

            // Geocerca de 50 metros
            if (dist != null && dist <= 50 && !_geofenceAlertTriggered) {
              _geofenceAlertTriggered = true;
              HapticFeedback.heavyImpact();
              showAppSnack(
                context,
                'Tu recolector está a menos de 50 metros. Acércate a la puerta.',
              );
            }
          }
        }
      });

      _arrivedSub = realtime.on(RealtimeEvents.collectorArrived).listen((data) {
        if (data['requestId'] == widget.requestId && mounted) {
          HapticFeedback.vibrate();
          _load();
          showAppSnack(
            context,
            'El recolector ha llegado al domicilio. Muestra tu código PIN.',
          );
        }
      });

      _bidSub = realtime.on(RealtimeEvents.auctionBid).listen((data) {
        if (data['requestId'] == widget.requestId && mounted) {
          HapticFeedback.heavyImpact();
          _load();
          _triggerBidPopup(data);
        }
      });

      _updateSub = realtime.on(RealtimeEvents.collectionUpdated).listen((data) {
        if (data['id'] == widget.requestId && mounted) {
          _load();
        }
      });

      _routeRefreshTimer?.cancel();
      _routeRefreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
        if (_request?.status == 'EN_ROUTE') {
          _fetchOsrmRoute(silent: true);
        }
      });
    });
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _arrivedSub?.cancel();
    _bidSub?.cancel();
    _updateSub?.cancel();
    _bidToastTimer?.cancel();
    _bidCountdownTimer?.cancel();
    _routeRefreshTimer?.cancel();
    _staleCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final request = await context
          .read<LivoraApi>()
          .collectionRequestDetail(widget.requestId);
      if (mounted) {
        setState(() {
          _request = request;
          _error = null;
          if (request.verificationPin != null && request.verificationPin!.isNotEmpty) {
            _cachedPin = request.verificationPin;
          }
          if (request.collectorLocation != null) {
            final loc = request.collectorLocation!;
            _collectorPos = LatLng(loc.latitude, loc.longitude);
            _collectorHeading = loc.heading;
            _etaMinutes = loc.etaMinutes;
            _distanceMeters = loc.distanceRemainingMeters;
            _transportType = loc.transportType;
            _lastLocationPing = DateTime.now();
            _fetchOsrmRoute(silent: true);
          }
        });
        if (_collectorPos != null && !_firstMapFitDone) {
          _firstMapFitDone = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapBounds());
        }
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo cargar la solicitud');
    }
  }

  Future<void> _cancel() async {
    final hasCollector = _request?.status == 'ACCEPTED' || _request?.collectorName != null;
    final confirmed = await confirmDialog(
      context,
      title: 'Cancelar solicitud',
      message: hasCollector
          ? 'Un recolector ya ha sido asignado a tu recojo. Si cancelas ahora, se liberará el encargo. ¿Deseas cancelar la recolección?'
          : '¿Seguro que deseas cancelar esta solicitud de recolección?',
      confirmLabel: 'Sí, cancelar',
    );
    if (!confirmed || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await context
          .read<LivoraApi>()
          .updateCollectionStatus(widget.requestId, 'CANCELLED');
      if (mounted) {
        context.read<SessionController>().updateActiveRequest(null);
        showAppSnack(context, 'Solicitud cancelada');
        await _load();
      }
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _selectBid(String bidId) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Aceptar propuesta',
      message:
          '¿Deseas asignar esta recolección a este centro de acopio con sus tarifas?',
      confirmLabel: 'Sí, aceptar',
    );
    if (!confirmed || !mounted) return;

    setState(() => _selectingBidId = bidId);
    try {
      await context.read<LivoraApi>().selectBid(widget.requestId, bidId);
      if (mounted) {
        showAppSnack(context, 'Centro de acopio asignado con éxito.');
        await _load();
      }
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _selectingBidId = null);
    }
  }

  void _showImageDialog(String url) {
    String effectiveUrl = url.trim();
    if (effectiveUrl.startsWith('ipfs://')) {
      final cid = effectiveUrl.replaceFirst('ipfs://', '').replaceFirst('ipfs/', '');
      effectiveUrl = 'https://ipfs.io/ipfs/$cid';
    } else if (RegExp(r'^Qm[1-9A-HJ-NP-za-km-z]{44}').hasMatch(effectiveUrl)) {
      effectiveUrl = 'https://ipfs.io/ipfs/$effectiveUrl';
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: Colors.black87,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: CachedNetworkImage(
                    imageUrl: effectiveUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const SizedBox(
                      height: 250,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: LivoraColors.forest,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 250,
                      padding: const EdgeInsets.all(20),
                      color: LivoraColors.paper,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image_outlined, size: 48, color: LivoraColors.slate),
                            SizedBox(height: 12),
                            Text(
                              'No se pudo cargar la imagen',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: LivoraColors.deep),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'El enlace puede haber expirado o la imagen no está disponible.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: LivoraColors.slate),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRatingDialog() async {
    int rating = 5;
    final feedbackCtrl = TextEditingController();
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.star, color: Color(0xFFF59E0B)),
              SizedBox(width: 8),
              Text('Calificar Servicio'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Cómo calificarías la atención y puntualidad del recolector?',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  return IconButton(
                    iconSize: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    icon: Icon(
                      starIndex <= rating ? Icons.star : Icons.star_border,
                      color: const Color(0xFFF59E0B),
                    ),
                    onPressed: submitting
                        ? null
                        : () => setDlgState(() => rating = starIndex),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: feedbackCtrl,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'Comentario opcional sobre el servicio...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      setDlgState(() => submitting = true);
                      try {
                        await context.read<LivoraApi>().rateCollectionRequest(
                              widget.requestId,
                              rating: rating,
                              feedback: feedbackCtrl.text.trim().isNotEmpty
                                  ? feedbackCtrl.text.trim()
                                  : null,
                            );
                        if (!context.mounted) return;
                        if (ctx.mounted) Navigator.pop(ctx);
                        showAppSnack(context, 'Calificación registrada con éxito.');
                        await _load();
                      } on ApiException catch (e) {
                        setDlgState(() => submitting = false);
                        if (context.mounted) showAppSnack(context, e.message, error: true);
                      } catch (_) {
                        setDlgState(() => submitting = false);
                        if (context.mounted) {
                          showAppSnack(context, 'Error al registrar calificación', error: true);
                        }
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog() async {
    final req = _request;
    if (req == null) return;

    final controllers = <String, TextEditingController>{};
    req.itemsEstimated.forEach((mat, wt) {
      controllers[mat] = TextEditingController(text: wt.toStringAsFixed(1));
    });
    final descCtrl = TextEditingController(text: req.description ?? '');
    bool saving = false;
    String? localError;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final unusedOptions = kMaterialOptions.where((opt) =>
              !controllers.keys.any((k) => k.toUpperCase() == opt.toUpperCase())).toList();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.edit_note, color: LivoraColors.forest),
                SizedBox(width: 8),
                Text('Editar Solicitud', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Modifica los materiales o cantidades estimadas:',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    if (controllers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No hay materiales agregados. Añade al menos uno abajo.',
                          style: TextStyle(fontSize: 12, color: Colors.redAccent),
                        ),
                      ),
                    ...controllers.entries.map(
                      (entry) {
                        final spec = kMaterialSpecs[entry.key.toUpperCase()];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                spec?.icon ?? Icons.recycling_rounded,
                                size: 18,
                                color: spec?.color ?? LivoraColors.forest,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  materialLabel(entry.key),
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: entry.value,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: kDecimalInputFormatters,
                                  onChanged: (_) {
                                    if (localError != null) setDlgState(() => localError = null);
                                  },
                                  decoration: const InputDecoration(
                                    suffixText: 'kg',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  ),
                                ),
                              ),
                              if (controllers.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18, color: Colors.black45),
                                  padding: const EdgeInsets.only(left: 4),
                                  constraints: const BoxConstraints(),
                                  tooltip: 'Eliminar material',
                                  onPressed: () {
                                    setDlgState(() {
                                      controllers.remove(entry.key)?.dispose();
                                      if (localError != null) localError = null;
                                    });
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    if (unusedOptions.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final opt in unusedOptions)
                            ActionChip(
                              label: Text('+ ${materialLabel(opt)}', style: const TextStyle(fontSize: 11)),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              onPressed: () {
                                setDlgState(() {
                                  controllers[opt] = TextEditingController(text: '1.0');
                                  if (localError != null) localError = null;
                                });
                              },
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Text(
                      'Notas o indicaciones:',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Indicaciones actualizadas para el recolector...',
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    if (localError != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, size: 16, color: Colors.red),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                localError!,
                                style: const TextStyle(fontSize: 12, color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        final updatedItems = <String, double>{};
                        double totalKg = 0;
                        controllers.forEach((k, v) {
                          final parsed = double.tryParse(v.text.replaceAll(',', '.')) ?? 0;
                          if (parsed > 0) {
                            updatedItems[k] = parsed;
                            totalKg += parsed;
                          }
                        });

                        if (updatedItems.isEmpty) {
                          setDlgState(() => localError = 'Ingresa al menos un material con peso mayor a 0 kg.');
                          return;
                        }
                        if (totalKg < 0.5) {
                          setDlgState(() => localError = 'El peso total estimado debe ser al menos 0.5 kg.');
                          return;
                        }

                        setDlgState(() {
                          saving = true;
                          localError = null;
                        });

                        try {
                          await context.read<LivoraApi>().editCollectionRequest(
                                widget.requestId,
                                itemsEstimated: updatedItems,
                                description: descCtrl.text.trim(),
                              );
                          if (!context.mounted) return;
                          if (ctx.mounted) Navigator.pop(ctx);
                          showAppSnack(context, 'Solicitud actualizada con éxito');
                          await _load();
                        } on ApiException catch (e) {
                          setDlgState(() => saving = false);
                          if (e.statusCode == 409 || e.message.contains('ya está en curso')) {
                            if (!context.mounted) return;
                            if (ctx.mounted) Navigator.pop(ctx);
                            await showDialog(
                              context: context,
                              builder: (alertCtx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: const Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Color(0xFFF59E0B)),
                                    SizedBox(width: 8),
                                    Text('No se puede modificar'),
                                  ],
                                ),
                                content: const Text(
                                  'Tu solicitud ya está en curso y no puede ser modificada',
                                  style: TextStyle(fontSize: 14),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(alertCtx),
                                    child: const Text('Entendido'),
                                  ),
                                ],
                              ),
                            );
                            await _load();
                          } else {
                            if (context.mounted) showAppSnack(context, e.message, error: true);
                          }
                        } catch (_) {
                          setDlgState(() => saving = false);
                          if (context.mounted) {
                            showAppSnack(context, 'Error al actualizar la solicitud', error: true);
                          }
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de solicitud'),
        actions: [
          if (request != null && request.status == 'PENDING')
            IconButton(
              icon: const Icon(Icons.edit_note),
              tooltip: 'Editar solicitud',
              onPressed: _showEditDialog,
            ),
        ],
      ),
      body: _error != null
          ? EmptyState(
              icon: Icons.cloud_off,
              title: 'No se pudo cargar la solicitud',
              message: _error,
            )
          : request == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          StatusChip(
                            label: request.status == 'PENDING' &&
                                    (request.assignedCenterId != null ||
                                        request.assignedCenterName != null)
                                ? 'Acopio Asignado'
                                : requestStatusLabel(request.status),
                            color: request.status == 'PENDING' &&
                                    (request.assignedCenterId != null ||
                                        request.assignedCenterName != null)
                                ? LivoraColors.forest
                                : requestStatusColor(request.status),
                          ),
                          const SizedBox(width: 8),
                          if (request.assignmentMode == 'AUCTION')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.indigo.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.indigo.shade200,
                                ),
                              ),
                              child: const Text(
                                'Subasta',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                ),
                              ),
                            ),
                          const Spacer(),
                          Text(
                            fmtDate(request.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: LivoraColors.ink.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                      if (request.assignedCenterId != null ||
                          request.assignedCenterName != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: LivoraColors.forest.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: LivoraColors.forest.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                radius: 18,
                                backgroundColor: LivoraColors.forest,
                                child: Icon(
                                  Icons.warehouse_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      request.assignedCenterName != null
                                          ? 'Centro de Acopio: ${request.assignedCenterName}'
                                          : 'Centro de Acopio Asignado',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: LivoraColors.forest,
                                      ),
                                    ),
                                    Text(
                                      (request.collectorId != null ||
                                              request.collectorName != null ||
                                              ['ACCEPTED', 'EN_ROUTE', 'ARRIVED']
                                                  .contains(request.status))
                                          ? 'Recolector asignado y en ruta para entrega a esta planta'
                                          : 'Tarifario cerrado · Esperando asignación de recolector',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: LivoraColors.ink.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Fotografía con miniatura expandible
                      if (request.photoUrl != null) ...[
                        GestureDetector(
                          onTap: () => _showImageDialog(request.photoUrl!),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: request.photoUrl!,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 800,
                                  memCacheHeight: 600,
                                  placeholder: (context, url) => Container(
                                    height: 180,
                                    color: LivoraColors.forest.withValues(alpha: 0.08),
                                    child: const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    height: 180,
                                    color: LivoraColors.paper,
                                    child: const Center(
                                      child: Icon(Icons.broken_image_outlined, size: 36),
                                    ),
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.zoom_in, color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'Ver foto completa',
                                        style: TextStyle(color: Colors.white, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Tarjeta de Credencial y Estado del Recolector Asignado
                      if (request.collectorId != null &&
                          ['ACCEPTED', 'EN_ROUTE', 'ARRIVED'].contains(request.status)) ...[
                        Card(
                          color: request.status == 'ARRIVED'
                              ? LivoraColors.forest.withValues(alpha: 0.08)
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: request.status == 'ARRIVED'
                                  ? LivoraColors.forest
                                  : LivoraColors.forest.withValues(alpha: 0.2),
                              width: request.status == 'ARRIVED' ? 2 : 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // Foto de Perfil del Recolector
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(28),
                                      child: request.collectorPhotoUrl != null &&
                                              request.collectorPhotoUrl!.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: request.collectorPhotoUrl!,
                                              width: 56,
                                              height: 56,
                                              fit: BoxFit.cover,
                                              placeholder: (c, u) => Container(
                                                width: 56,
                                                height: 56,
                                                color: LivoraColors.forest.withValues(alpha: 0.1),
                                                child: const Icon(Icons.person, color: LivoraColors.forest),
                                              ),
                                              errorWidget: (c, u, e) => Container(
                                                width: 56,
                                                height: 56,
                                                color: LivoraColors.forest.withValues(alpha: 0.1),
                                                child: const Icon(Icons.person, color: LivoraColors.forest),
                                              ),
                                            )
                                          : Container(
                                              width: 56,
                                              height: 56,
                                              decoration: BoxDecoration(
                                                color: LivoraColors.forest.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(28),
                                              ),
                                              child: const Icon(Icons.person, color: LivoraColors.forest, size: 28),
                                            ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  request.collectorName ?? 'Recolector Certificado',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 15,
                                                    color: LivoraColors.deep,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              const Icon(Icons.verified, color: LivoraColors.blue, size: 16),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                                              const SizedBox(width: 3),
                                              Text(
                                                request.collectorReputation.toStringAsFixed(1),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: LivoraColors.deep,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                request.collectorPhone != null
                                                    ? 'Tel: ${request.collectorPhone}'
                                                    : 'Recolector registrado',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: LivoraColors.ink.withValues(alpha: 0.7),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Banner de Estado de Trayecto
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: request.status == 'ARRIVED'
                                        ? LivoraColors.forest.withValues(alpha: 0.15)
                                        : LivoraColors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        request.status == 'ARRIVED'
                                            ? Icons.door_front_door_outlined
                                            : Icons.directions_bike_outlined,
                                        color: request.status == 'ARRIVED'
                                            ? LivoraColors.forest
                                            : LivoraColors.blue,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          request.status == 'ARRIVED'
                                              ? '¡El recolector está en tu puerta! Acércate con tus materiales.'
                                              : request.status == 'EN_ROUTE'
                                                  ? 'El recolector ha iniciado el trayecto hacia tu dirección.'
                                                  : 'Recolector asignado y preparando recolección.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: request.status == 'ARRIVED'
                                                ? LivoraColors.forest
                                                : LivoraColors.blue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // =======================================================
                      // MAPA DE TRACKING EN TIEMPO REAL (EN_ROUTE / ARRIVED)
                      // =======================================================
                      if (['EN_ROUTE', 'ARRIVED'].contains(request.status)) ...[
                        Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: request.status == 'ARRIVED'
                                  ? LivoraColors.forest
                                  : LivoraColors.blue.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Cabecera con ETA en vivo
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                color: request.status == 'ARRIVED'
                                    ? LivoraColors.forest.withValues(alpha: 0.12)
                                    : LivoraColors.blue.withValues(alpha: 0.08),
                                child: Row(
                                  children: [
                                    Icon(
                                      request.status == 'ARRIVED'
                                          ? Icons.check_circle
                                          : Icons.directions_bike,
                                      size: 18,
                                      color: request.status == 'ARRIVED'
                                          ? LivoraColors.forest
                                          : LivoraColors.blue,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        request.status == 'ARRIVED'
                                            ? '¡Tu recolector está en tu puerta!'
                                            : _etaMinutes != null
                                                ? 'Llegada estimada: ~$_etaMinutes min (${_distanceMeters != null ? (_distanceMeters! / 1000).toStringAsFixed(1) : ""} km)'
                                                : 'Recolector en camino hacia tu domicilio...',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: request.status == 'ARRIVED'
                                              ? LivoraColors.forest
                                              : LivoraColors.deep,
                                        ),
                                      ),
                                    ),
                                    if (request.status == 'EN_ROUTE')
                                      const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: LivoraColors.blue,
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // Banner de advertencia si la señal GPS está en pausa (> 60s)
                              if (request.status == 'EN_ROUTE' &&
                                  _lastLocationPing != null &&
                                  DateTime.now().difference(_lastLocationPing!).inSeconds >= 60)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  color: const Color(0xFFFEF3C7),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time_filled, size: 14, color: Color(0xFFB45309)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Señal en pausa hace ${(DateTime.now().difference(_lastLocationPing!).inSeconds / 60).floor() == 0 ? 1 : (DateTime.now().difference(_lastLocationPing!).inSeconds / 60).floor()} min (recolector en semáforo o cobertura reducida)',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF92400E),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Contenedor del Mapa
                              SizedBox(
                                height: 230,
                                child: Stack(
                                  children: [
                                    FlutterMap(
                                      mapController: _mapController,
                                      options: MapOptions(
                                        initialCenter: _collectorPos != null
                                            ? LatLng(
                                                (request.latitude + _collectorPos!.latitude) / 2,
                                                (request.longitude + _collectorPos!.longitude) / 2,
                                              )
                                            : LatLng(
                                                request.latitude,
                                                request.longitude,
                                              ),
                                        initialZoom: _collectorPos != null ? 14.5 : 16.0,
                                        maxZoom: 19,
                                        minZoom: 11,
                                      ),
                                      children: [
                                        const LivoraMapTileLayer(),

                                        // Geocerca de arribo (50m)
                                        CircleLayer(
                                          circles: [
                                            CircleMarker(
                                              point: LatLng(
                                                request.latitude,
                                                request.longitude,
                                              ),
                                              radius: 50,
                                              useRadiusInMeter: true,
                                              color: LivoraColors.forest.withValues(alpha: 0.15),
                                              borderColor: LivoraColors.forest,
                                              borderStrokeWidth: 2.0,
                                            ),
                                          ],
                                        ),

                                        // Trazado de ruta vehicular turn-by-turn OSRM
                                        if (_polylinePoints.isNotEmpty)
                                          PolylineLayer(
                                            polylines: [
                                              Polyline(
                                                points: _polylinePoints,
                                                strokeWidth: 4.8,
                                                color: const Color(0xFF2E7D32),
                                                strokeCap: StrokeCap.round,
                                                strokeJoin: StrokeJoin.round,
                                              ),
                                            ],
                                          )
                                        else if (_collectorPos != null)
                                          PolylineLayer(
                                            polylines: [
                                              Polyline(
                                                points: [
                                                  _collectorPos!,
                                                  LatLng(request.latitude, request.longitude),
                                                ],
                                                strokeWidth: 3.5,
                                                color: const Color(0xFF16A34A),
                                                strokeCap: StrokeCap.round,
                                              ),
                                            ],
                                          ),

                                        // Marcadores: Hogar y Recolector en vivo
                                        MarkerLayer(
                                          markers: [
                                            // Pin del Hogar (Destino)
                                            Marker(
                                              point: LatLng(
                                                request.latitude,
                                                request.longitude,
                                              ),
                                              width: 44,
                                              height: 44,
                                              child: const Icon(
                                                Icons.location_on,
                                                color: Color(0xFFC53030),
                                                size: 40,
                                              ),
                                            ),

                                            // Marcador del Recolector con Heading y halo visual
                                            if (_collectorPos != null)
                                              Marker(
                                                point: _collectorPos!,
                                                width: 46,
                                                height: 46,
                                                child: Transform.rotate(
                                                  angle: _collectorHeading * (pi / 180),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF15803D), // green 700
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: const Color(0xFF15803D).withValues(alpha: 0.4),
                                                          blurRadius: 8,
                                                          spreadRadius: 2,
                                                          offset: const Offset(0, 2),
                                                        ),
                                                      ],
                                                      border: Border.all(color: Colors.white, width: 2.5),
                                                    ),
                                                    padding: const EdgeInsets.all(4),
                                                    child: const Icon(
                                                      Icons.navigation,
                                                      color: Colors.white,
                                                      size: 22,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),

                                    // Botón flotante para re-encuadrar ruta y recolector
                                    if (_collectorPos != null)
                                      Positioned(
                                        top: 10,
                                        right: 10,
                                        child: InkWell(
                                          onTap: _fitMapBounds,
                                          borderRadius: BorderRadius.circular(20),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.15),
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.center_focus_strong, size: 16, color: LivoraColors.forest),
                                                SizedBox(width: 5),
                                                Text(
                                                  'Recentrar ruta',
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: LivoraColors.forest,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // PIN de Verificación en Cajas OTP (Disponible cuando hay recolector asignado o en camino)
                      if (['ACCEPTED', 'ASSIGNED', 'EN_ROUTE', 'ARRIVED'].contains(request.status)) ...[
                        Card(
                          color: LivoraColors.blue.withValues(alpha: 0.06),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: LivoraColors.blue, width: 1.5),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.key_rounded, color: LivoraColors.blue, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'PIN DE VERIFICACIÓN',
                                      style: TextStyle(
                                        color: LivoraColors.deep,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                OtpPinBox(
                                  pin: request.verificationPin ?? _cachedPin ?? '----',
                                  isActive: true,
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Dicta este PIN de 4 dígitos a tu recolector al momento de entregar los materiales.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: LivoraColors.ink,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Tarjeta explicativa de estado terminal no completado
                      if (['UNATTENDED', 'REJECTED_ON_SITE', 'EXPIRED', 'CANCELLED'].contains(request.status)) ...[
                        Builder(
                          builder: (context) {
                            final (icon, title, desc, color) = switch (request.status) {
                              'UNATTENDED' => (
                                  Icons.doorbell_outlined,
                                  'Visita no atendida en domicilio',
                                  'El recolector acudió a la dirección pero no se obtuvo respuesta en puerta. Puedes generar una nueva solicitud cuando estés disponible en casa.',
                                  Colors.amber.shade800,
                                ),
                              'REJECTED_ON_SITE' => (
                                  Icons.report_problem_outlined,
                                  'Recolección rechazada en sitio',
                                  'El material no cumplió con las condiciones mínimas de reciclaje (limpieza, separación adecuada o acceso restringido). Revisa las guías antes de volver a solicitar.',
                                  Colors.red.shade700,
                                ),
                              'EXPIRED' => (
                                  Icons.timer_off_outlined,
                                  'Tiempo límite expirado',
                                  'No se encontró un recolector disponible en la zona durante la ventana horaria activa. Te sugerimos solicitar nuevamente en horario diurno.',
                                  Colors.grey.shade700,
                                ),
                              'CANCELLED' => (
                                  Icons.cancel_outlined,
                                  'Solicitud cancelada',
                                  'Esta recolección fue cancelada. No se generó ningún débito de garantía ni transferencia de tokens.',
                                  Colors.grey.shade700,
                                ),
                              _ => (
                                  Icons.info_outline,
                                  'Solicitud no completada',
                                  'Esta solicitud concluyó sin concretar la recolección física.',
                                  Colors.grey.shade700,
                                ),
                            };

                            return Card(
                              color: color.withValues(alpha: 0.06),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: color.withValues(alpha: 0.3)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(icon, color: color, size: 24),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: color,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            desc,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: LivoraColors.ink.withValues(alpha: 0.85),
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Certificación Web3 Stellar (si está confirmada en blockchain)
                      if (request.txHash != null && Stellar.isValidTxHash(request.txHash)) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5B67E8).withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF5B67E8).withValues(alpha: 0.22),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.verified_rounded,
                                    color: Color(0xFF5B67E8),
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Certificado en Stellar Blockchain',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.5,
                                        color: LivoraColors.deep,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Hash acortado con acciones
                              Row(
                                children: [
                                  const Icon(
                                    Icons.link_rounded,
                                    size: 13,
                                    color: Color(0xFF5B67E8),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      Stellar.shortHash(request.txHash!),
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF5B67E8),
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'monospace',
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Botón: copiar hash completo
                                  _StellarActionButton(
                                    tooltip: 'Copiar hash de transacción',
                                    icon: Icons.copy_rounded,
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      Clipboard.setData(
                                        ClipboardData(
                                          text: Stellar.cleanTxHash(request.txHash!),
                                        ),
                                      );
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Hash copiado al portapapeles'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  // Botón: abrir en Stellar Expert
                                  _StellarActionButton(
                                    tooltip: 'Ver en Stellar Expert',
                                    icon: Icons.open_in_new_rounded,
                                    label: 'Explorer',
                                    onPressed: () => Stellar.openTxInExplorer(request.txHash),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Transacción inmutable y verificable en la red Stellar',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: LivoraColors.ink.withValues(alpha: 0.65),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Ofertas en Modo Subasta
                      if (request.assignmentMode == 'AUCTION' &&
                          request.bids.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SectionTitle(text: 'Ofertas de Acopio (${request.bids.length})'),
                            TextButton.icon(
                              onPressed: () async {
                                final updated = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AuctionBidsScreen(request: request),
                                  ),
                                );
                                if (updated == true) _load();
                              },
                              icon: const Icon(Icons.fullscreen, size: 16),
                              label: const Text('Ver pantalla completa', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        for (final bid in request.bids)
                          Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: bid.status == 'ACCEPTED'
                                    ? LivoraColors.green
                                    : Colors.grey.shade300,
                                width: bid.status == 'ACCEPTED' ? 2 : 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const CircleAvatar(
                                        radius: 14,
                                        backgroundColor: LivoraColors.paper,
                                        child: Icon(
                                          Icons.storefront,
                                          size: 16,
                                          color: LivoraColors.deep,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          sanitizedPersonName(
                                            bid.centerName,
                                            bid.centerEmail,
                                            defaultLabel: 'Centro de Acopio',
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      if (bid.status == 'ACCEPTED')
                                        const StatusChip(
                                          label: 'Aceptada',
                                          color: LivoraColors.green,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tarifas ofrecidas por kg: ${bid.proposedRates.entries.map((e) => '${materialLabel(e.key)}: S/ ${e.value.toStringAsFixed(2)}').join(' · ')}',
                                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Tu recompensa estimada:',
                                          style: TextStyle(fontSize: 12, color: Colors.black87),
                                        ),
                                        Text(
                                          '${bid.totalEstimatedEco.toStringAsFixed(2)} LIVO (≈ S/ ${bid.totalEstimatedEco.toStringAsFixed(2)})',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: LivoraColors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (bid.status != 'ACCEPTED' &&
                                      (request.status == 'PENDING' ||
                                          request.status == 'AUCTION_OPEN')) ...[
                                    const SizedBox(height: 10),
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
                                      onPressed: _selectingBidId != null ? null : () => _selectBid(bid.id),
                                      icon: _selectingBidId == bid.id
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.check, size: 16),
                                      label: Text(_selectingBidId == bid.id ? 'Aceptando…' : 'Aceptar esta oferta'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],

                      // Materiales Estimados vs Reales
                      if (request.actualWeights != null) ...[
                        _WeightReconciliationCard(request: request),
                      ] else ...[
                        const SectionTitle(text: 'Materiales Estimados'),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              children: [
                                for (final entry in request.itemsEstimated.entries) ...[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.recycling, size: 18, color: LivoraColors.green),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            materialLabel(entry.key),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: LivoraColors.deep,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          fmtKg(entry.value),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: LivoraColors.ink,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 12),
                                ],
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total estimado',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                    ),
                                    Text(
                                      fmtKg(request.totalEstimatedKg),
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Información del Servicio
                      const SectionTitle(text: 'Información del Servicio'),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              InfoRow(
                                label: 'Recolector asignado',
                                value: sanitizedPersonName(
                                  request.collectorName,
                                  request.collectorEmail,
                                  defaultLabel: 'Aún sin asignar',
                                ),
                              ),
                              if (request.assignedCenterName != null ||
                                  request.assignedCenterEmail != null)
                                InfoRow(
                                  label: 'Centro de Acopio',
                                  value: sanitizedPersonName(
                                    request.assignedCenterName,
                                    request.assignedCenterEmail,
                                    defaultLabel: 'Centro de Acopio',
                                  ),
                                ),
                              InfoRow(
                                label: 'Recompensa estimada',
                                value: request.hogarEstimatedEarningsPEN > 0
                                    ? '${request.hogarEstimatedEarningsPEN.toStringAsFixed(2)} LIVO (≈ S/ ${request.hogarEstimatedEarningsPEN.toStringAsFixed(2)})'
                                    : 'Recompensa calculada al pesar',
                              ),
                              InfoRow(
                                label: 'Notas',
                                value: request.description?.isNotEmpty == true
                                    ? request.description!
                                    : '—',
                              ),
                              InfoRow(
                                label: 'Dirección de recojo',
                                value: request.householdAddress?.isNotEmpty == true
                                    ? request.householdAddress!
                                    : (context.read<SessionController>().user?.address?.isNotEmpty == true
                                        ? context.read<SessionController>().user!.address!
                                        : 'Ubicación física registrada vía GPS'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Calificación del Servicio (COMPLETED)
                      if (request.status == 'COMPLETED') ...[
                        Card(
                          color: const Color(0xFFFFFBEB),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: Color(0xFFF59E0B), size: 22),
                                    const SizedBox(width: 8),
                                    Text(
                                      request.rating != null
                                          ? 'Servicio Calificado'
                                          : '¿Cómo estuvo la recolección?',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: Color(0xFF92400E),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (request.rating != null) ...[
                                  Row(
                                    children: [
                                      ...List.generate(5, (i) => Icon(
                                        i < request.rating! ? Icons.star : Icons.star_border,
                                        color: const Color(0xFFF59E0B),
                                        size: 20,
                                      )),
                                      const SizedBox(width: 8),
                                      Text(
                                        '(${request.rating} / 5)',
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                  if (request.feedback?.isNotEmpty == true) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      '"${request.feedback}"',
                                      style: const TextStyle(
                                        fontStyle: FontStyle.italic,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ] else ...[
                                  const Text(
                                    'Tu opinión ayuda a mejorar la reputación del recolector y mantener la calidad del servicio.',
                                    style: TextStyle(fontSize: 13, color: Color(0xFF78350F)),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF59E0B),
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(double.infinity, 44),
                                    ),
                                    onPressed: _showRatingDialog,
                                    icon: const Icon(Icons.star_rate),
                                    label: const Text('Calificar Recolector'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Botón para editar materiales en PENDING / AUCTION_ACTIVE
                      if (request.status == 'PENDING' ||
                          request.status == 'AUCTION_ACTIVE' ||
                          request.status == 'AUCTION_OPEN') ...[
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: LivoraColors.forest,
                            side: const BorderSide(color: LivoraColors.forest),
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          onPressed: _showEditDialog,
                          icon: const Icon(Icons.edit_note),
                          label: const Text('Editar materiales de la solicitud'),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Cancelación
                      if (request.status == 'PENDING' ||
                          request.status == 'ACCEPTED' ||
                          request.status == 'AUCTION_ACTIVE' ||
                          request.status == 'AUCTION_ASSIGNED' ||
                          request.status == 'AUCTION_OPEN')
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF8C3A3A),
                            side: const BorderSide(color: Color(0xFF8C3A3A)),
                            minimumSize: const Size(double.infinity, 48),
                          ),
                          onPressed: _cancelling ? null : _cancel,
                          icon: const Icon(Icons.cancel_outlined),
                          label: Text(
                            _cancelling ? 'Cancelando…' : 'Cancelar solicitud',
                          ),
                        ),
                     ],
                  ),
                ),
                if (_incomingBidToast != null)
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: _buildBidToastBanner(_incomingBidToast!),
                  ),
              ],
            ),
    );
  }

  Widget _buildBidToastBanner(Map<String, dynamic> data) {
    final centerName = data['centerName'] ?? 'Centro de Acopio';
    final penn = (data['totalEstimatedPenn'] as num?)?.toDouble() ?? 0.0;
    final livos = (data['totalEstimatedLivo'] as num?)?.toDouble() ?? 0.0;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      shadowColor: Colors.black45,
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.shade400, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade500,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.gavel, size: 14, color: Colors.black87),
                      SizedBox(width: 4),
                      Text(
                        '¡NUEVA PUJA RECIBIDA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_bidToastSecondsLeft}s',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.amberAccent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    _bidToastTimer?.cancel();
                    _bidCountdownTimer?.cancel();
                    setState(() => _incomingBidToast = null);
                  },
                  child: const Icon(Icons.close, size: 18, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              centerName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${livos.toStringAsFixed(2)} LIVO',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4ADE80),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(≈ S/ ${penn.toStringAsFixed(2)})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _bidToastSecondsLeft / 10.0,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade400),
                minHeight: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón compacto para acciones de la sección Stellar (copiar hash / abrir explorador).
class _StellarActionButton extends StatelessWidget {
  const _StellarActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.label,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF5B67E8);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: label != null
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 5)
              : const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              if (label != null) ...[
                const SizedBox(width: 4),
                Text(
                  label!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de conciliación detallada entre los pesos declarados por el hogar y
/// el pesaje certificado por la balanza digital del centro de acopio.
class _WeightReconciliationCard extends StatelessWidget {
  const _WeightReconciliationCard({required this.request});

  final CollectionRequest request;

  @override
  Widget build(BuildContext context) {
    final actual = request.actualWeights ?? const {};
    final estimated = request.itemsEstimated;
    final allKeys = <String>{...estimated.keys, ...actual.keys}.toList();

    final rewardEarned = request.householdRewardEarned > 0
        ? request.householdRewardEarned
        : request.hogarEstimatedEarningsPEN;

    final isDonation = request.isDonation;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: LivoraColors.forest.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: LivoraColors.forest.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.balance_rounded,
                    color: LivoraColors.forest,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pesaje y Liquidación Oficial',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: LivoraColors.deep,
                        ),
                      ),
                      Text(
                        'Certificado en báscula digital del acopio',
                        style: TextStyle(
                          fontSize: 12,
                          color: LivoraColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: LivoraColors.forest.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 14, color: LivoraColors.forest),
                      SizedBox(width: 4),
                      Text(
                        'PESADO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: LivoraColors.forest,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Encabezados de columnas
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Material',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: LivoraColors.ink),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Declarado',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: LivoraColors.ink),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Balanza',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: LivoraColors.forest),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Diferencia',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: LivoraColors.ink),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 8),

            // Filas de materiales
            for (final key in allKeys) ...[
              Builder(
                builder: (context) {
                  final est = estimated[key] ?? 0.0;
                  final act = actual[key] ?? 0.0;
                  final diff = act - est;
                  final isPositive = diff > 0.001;
                  final isNegative = diff < -0.001;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            materialLabel(key),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                              color: LivoraColors.deep,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            fmtKg(est),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 12, color: LivoraColors.ink),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            fmtKg(act),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: LivoraColors.forest,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            diff.abs() < 0.001
                                ? '0.0 kg'
                                : '${isPositive ? "+" : ""}${fmtKg(diff)}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isPositive
                                  ? LivoraColors.forest
                                  : (isNegative ? Colors.orange.shade800 : LivoraColors.ink),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            const Divider(height: 12),

            // Fila de Totales
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  const Expanded(
                    flex: 3,
                    child: Text(
                      'Total General',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: LivoraColors.deep,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      fmtKg(request.totalEstimatedKg),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      fmtKg(request.totalActualKg),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: LivoraColors.forest,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Builder(
                      builder: (context) {
                        final totalDiff = request.totalActualKg - request.totalEstimatedKg;
                        final isPos = totalDiff > 0.001;
                        final isNeg = totalDiff < -0.001;
                        return Text(
                          totalDiff.abs() < 0.001
                              ? '0.0 kg'
                              : '${isPos ? "+" : ""}${fmtKg(totalDiff)}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isPos
                                ? LivoraColors.forest
                                : (isNeg ? Colors.orange.shade800 : LivoraColors.ink),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Liquidación en LIVO destacada
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    LivoraColors.forest.withValues(alpha: 0.08),
                    LivoraColors.green.withValues(alpha: 0.14),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LivoraColors.forest.withValues(alpha: 0.2)),
              ),
              child: isDonation
                  ? const Row(
                      children: [
                        Icon(Icons.volunteer_activism_rounded, color: LivoraColors.forest, size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Entrega Solidaria: El 100% del valor del reciclaje fue cedido al recolector.',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: LivoraColors.forest,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.stars_rounded,
                            color: LivoraColors.forest,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Recompensa final liquidada',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: LivoraColors.ink,
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '${rewardEarned.toStringAsFixed(2)} LIVO',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 17,
                                      color: LivoraColors.forest,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '≈ S/ ${rewardEarned.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12.5,
                                      color: LivoraColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

