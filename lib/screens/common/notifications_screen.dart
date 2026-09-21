import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/formats.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../services/livora_api.dart';
import '../../widgets/common.dart';
import '../hogar/create_request_screen.dart';
import '../hogar/request_detail_screen.dart';
import '../shell/home_shell.dart';
import 'profile.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await context.read<LivoraApi>().notifications();
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
        final unread = items.where((n) => !n.isRead).length;
        context.read<SessionController>().setUnreadNotificationsCount(unread);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _handleTap(AppNotification item) async {
    HapticFeedback.lightImpact();
    if (!item.isRead) {
      final updatedList = [
        for (final n in _items ?? <AppNotification>[])
          n.id == item.id
              ? AppNotification(
                  id: n.id,
                  title: n.title,
                  message: n.message,
                  type: n.type,
                  isRead: true,
                  createdAt: n.createdAt,
                )
              : n,
      ];
      setState(() {
        _items = updatedList;
      });
      final unread = updatedList.where((n) => !n.isRead).length;
      context.read<SessionController>().setUnreadNotificationsCount(unread);
      context
          .read<LivoraApi>()
          .markNotification(item.id, isRead: true)
          .catchError((_) {});
    }

    final session = context.read<SessionController>();
    final user = session.user;
    final role = user?.role;
    final title = item.title.toLowerCase();
    final message = item.message.toLowerCase();

    if (role == Roles.hogar) {
      if (title.contains('acopio') ||
          title.contains('solicitud') ||
          title.contains('recolector') ||
          title.contains('subasta') ||
          title.contains('propuesta') ||
          message.contains('solicitud') ||
          message.contains('acopio')) {
        final activeReq = session.activeRequest;
        if (activeReq != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RequestDetailScreen(requestId: activeReq.id),
            ),
          );
        } else {
          HomeShell.switchTab(context, 0); // Inicio / Dashboard
        }
      } else if (title.contains('pago') ||
          title.contains('livo') ||
          title.contains('token') ||
          title.contains('billetera') ||
          message.contains('livo')) {
        HomeShell.switchTab(context, 1); // Billetera
      }
    } else if (role == Roles.recolector) {
      if (title.contains('solicitud') ||
          title.contains('radar') ||
          message.contains('solicitud')) {
        HomeShell.switchTab(context, 0); // Solicitudes
      } else if (title.contains('lote') ||
          title.contains('batch') ||
          message.contains('lote')) {
        HomeShell.switchTab(context, 1); // Mis lotes
      } else if (title.contains('pago') ||
          title.contains('livo') ||
          title.contains('billetera')) {
        HomeShell.switchTab(context, 2); // Billetera
      }
    } else if (role == Roles.centroAcopio) {
      if (title.contains('lote') ||
          title.contains('entrega') ||
          message.contains('lote')) {
        HomeShell.switchTab(context, 0); // Lotes
      } else if (title.contains('inventario') ||
          title.contains('material') ||
          message.contains('inventario')) {
        HomeShell.switchTab(context, 1); // Inventario
      } else if (title.contains('pago') ||
          title.contains('billetera') ||
          title.contains('livo')) {
        HomeShell.switchTab(context, 2); // Billetera
      }
    } else if (role == Roles.tienda) {
      if (title.contains('canje') ||
          title.contains('cobro') ||
          title.contains('pago') ||
          title.contains('billetera')) {
        HomeShell.switchTab(context, 2); // Billetera
      }
    }
  }

  Future<void> _markAllAsRead() async {
    final items = _items;
    if (items == null || items.isEmpty) return;
    final unread = items.where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;

    HapticFeedback.lightImpact();
    setState(() {
      _items = [
        for (final n in items)
          AppNotification(
            id: n.id,
            title: n.title,
            message: n.message,
            type: n.type,
            isRead: true,
            createdAt: n.createdAt,
          ),
      ];
    });
    context.read<SessionController>().setUnreadNotificationsCount(0);

    final api = context.read<LivoraApi>();
    try {
      await Future.wait(
        unread.map((n) => api.markNotification(n.id, isRead: true)),
      );
      if (mounted) {
        showAppSnack(context, 'Todas las notificaciones marcadas como leídas');
      }
    } catch (_) {
      // Ignorado, el estado local ya refleja la lectura
    }
  }

  (IconData, Color) _styleFor(String type) => switch (type) {
        'SUCCESS' => (Icons.check_circle_outline, LivoraColors.green),
        'WARNING' => (Icons.warning_amber_rounded, const Color(0xFFB7791F)),
        _ => (Icons.info_outline, LivoraColors.blue),
      };

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final hasUnread = items?.any((n) => !n.isRead) ?? false;

    Widget body;
    if (_error != null) {
      body = EmptyState(
        icon: Icons.cloud_off,
        title: 'No se pudieron cargar las notificaciones',
        message: _error,
      );
    } else if (items == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (items.isEmpty) {
      final session = context.watch<SessionController>();
      final user = session.user;
      final hasActive = session.hasActiveRequest;
      final activeReq = session.activeRequest;

      body = EmptyState(
        icon: Icons.notifications_none_outlined,
        title: 'Bandeja al día',
        message: 'Aquí verás avisos automáticos sobre tus solicitudes, lotes y pagos.',
        actions: user?.role == Roles.hogar
            ? [
                FilledButton.icon(
                  onPressed: () {
                    if (hasActive && activeReq != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              RequestDetailScreen(requestId: activeReq.id),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateRequestScreen(),
                        ),
                      );
                    }
                  },
                  icon: Icon(
                    hasActive ? Icons.assignment_outlined : Icons.recycling,
                  ),
                  label: Text(
                    hasActive
                        ? 'Ver solicitud en curso'
                        : 'Solicitar recolección',
                  ),
                ),
              ]
            : null,
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          final (icon, color) = _styleFor(item.type);
          return Card(
            child: ListTile(
              onTap: () => _handleTap(item),
              leading: Icon(icon, color: color),
              title: Text(
                item.title,
                style: TextStyle(
                  fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w800,
                  color: LivoraColors.deep,
                  fontSize: 14,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${item.message}\n${fmtDate(item.createdAt)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: LivoraColors.ink.withValues(alpha: 0.8),
                  ),
                ),
              ),
              trailing: item.isRead
                  ? null
                  : const CircleAvatar(
                      radius: 5,
                      backgroundColor: LivoraColors.cyan,
                    ),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          if (hasUnread)
            IconButton(
              icon: const Icon(Icons.done_all_rounded),
              tooltip: 'Marcar todas como leídas',
              onPressed: _markAllAsRead,
            ),
          const ProfileButton(),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: body is ListView
            ? body
            : LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: constraints.maxHeight,
                    child: body,
                  ),
                ),
              ),
      ),
    );
  }
}
