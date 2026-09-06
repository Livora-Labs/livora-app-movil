import 'package:flutter/material.dart';
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
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _toggleRead(AppNotification item) async {
    final api = context.read<LivoraApi>();
    setState(() {
      _items = [
        for (final n in _items ?? <AppNotification>[])
          n.id == item.id
              ? AppNotification(
                  id: n.id,
                  title: n.title,
                  message: n.message,
                  type: n.type,
                  isRead: !item.isRead,
                  createdAt: n.createdAt,
                )
              : n,
      ];
    });
    try {
      await api.markNotification(item.id, isRead: !item.isRead);
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
      _load();
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
              onTap: () => _toggleRead(item),
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
      appBar: livoraAppBar(context, 'Notificaciones'),
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
