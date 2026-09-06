import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../core/paging_controller.dart';
import 'livora_empty_state.dart';
import 'livora_shimmer.dart';

/// Vista de lista paginada universal de 60 FPS.
/// Soporta esqueletos Shimmer iniciales, scroll infinito diferido, tarjeta de reintento
/// en línea (InlineRetryTile), Pull-to-Refresh y padding inferior anti-solapamiento (80dp).
class PaginatedListView<T> extends StatefulWidget {
  const PaginatedListView({
    super.key,
    required this.controller,
    required this.itemBuilder,
    this.scrollController,
    this.emptyState,
    this.header,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 80),
    this.separator,
    this.shimmerItemCount = 5,
  });

  final PagingController<T> controller;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final ScrollController? scrollController;
  final Widget? emptyState;
  final Widget? header;
  final EdgeInsetsGeometry padding;
  final Widget? separator;
  final int shimmerItemCount;

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  late final ScrollController _scrollController;
  bool _ownsScrollController = false;

  @override
  void initState() {
    super.initState();
    if (widget.scrollController != null) {
      _scrollController = widget.scrollController!;
    } else {
      _scrollController = ScrollController();
      _ownsScrollController = true;
    }
    widget.controller.attachScrollController(_scrollController);
  }

  @override
  void didUpdateWidget(covariant PaginatedListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollController != oldWidget.scrollController) {
      if (_ownsScrollController) {
        _scrollController.dispose();
        _ownsScrollController = false;
      }
      if (widget.scrollController != null) {
        _scrollController = widget.scrollController!;
      } else {
        _scrollController = ScrollController();
        _ownsScrollController = true;
      }
      widget.controller.attachScrollController(_scrollController);
    } else if (widget.controller != oldWidget.controller) {
      widget.controller.attachScrollController(_scrollController);
    }
  }

  @override
  void dispose() {
    if (_ownsScrollController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;

        // 1. Estado inicial de carga (Shimmer skeletons)
        if (ctrl.isLoadingFirstPage) {
          return Column(
            children: [
              if (widget.header != null) widget.header!,
              Expanded(
                child: LivoraShimmerList(
                  itemCount: widget.shimmerItemCount,
                  padding: widget.padding,
                ),
              ),
            ],
          );
        }

        // 2. Error crítico en la primera página
        if (ctrl.firstPageError != null && ctrl.items.isEmpty) {
          return RefreshIndicator(
            onRefresh: ctrl.refresh,
            color: LivoraColors.forest,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: widget.padding,
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        size: 54,
                        color: LivoraColors.coral,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No se pudo cargar la información',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: LivoraColors.deep,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          ctrl.firstPageError.toString().replaceFirst('Exception: ', ''),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: LivoraColors.slate,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          ctrl.loadFirstPage();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Reintentar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LivoraColors.forest,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        // 3. Estado Vacío (Empty State)
        if (ctrl.isEmpty) {
          return RefreshIndicator(
            onRefresh: ctrl.refresh,
            color: LivoraColors.forest,
            child: Column(
              children: [
                if (widget.header != null) widget.header!,
                Expanded(
                  child: widget.emptyState ??
                      const LivoraEmptyState(
                        icon: Icons.inbox_outlined,
                        title: 'No hay elementos',
                        message: 'No se encontraron registros en este momento.',
                      ),
                ),
              ],
            ),
          );
        }

        // 4. Lista virtualizada con soporte para scroll infinito y tarjeta de reintento
        final hasFooter = ctrl.isLoadingNextPage || ctrl.nextPageError != null;
        final totalCount = (widget.header != null ? 1 : 0) +
            ctrl.items.length +
            (hasFooter ? 1 : 0);

        return RefreshIndicator(
          onRefresh: ctrl.refresh,
          color: LivoraColors.forest,
          child: ListView.separated(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: widget.padding,
            itemCount: totalCount,
            separatorBuilder: (context, index) {
              if (widget.header != null && index == 0) {
                return const SizedBox.shrink();
              }
              return widget.separator ?? const SizedBox.shrink();
            },
            itemBuilder: (context, index) {
              int actualIndex = index;
              if (widget.header != null) {
                if (index == 0) return widget.header!;
                actualIndex--;
              }

              if (actualIndex < ctrl.items.length) {
                return widget.itemBuilder(
                  context,
                  ctrl.items[actualIndex],
                  actualIndex,
                );
              }

              // Footer: Loading o Reintento en línea
              if (ctrl.isLoadingNextPage) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(LivoraColors.forest),
                      ),
                    ),
                  ),
                );
              }

              if (ctrl.nextPageError != null) {
                return _InlineRetryTile(
                  error: ctrl.nextPageError.toString(),
                  onRetry: () {
                    HapticFeedback.lightImpact();
                    ctrl.retryNextPage();
                  },
                );
              }

              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }
}

/// Tarjeta de reintento en línea al fallar la paginación infinita
class _InlineRetryTile extends StatelessWidget {
  const _InlineRetryTile({
    required this.error,
    required this.onRetry,
  });

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: LivoraColors.coral.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: LivoraColors.coral.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: LivoraColors.coral,
            size: 22,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'No se pudieron cargar más elementos',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: LivoraColors.deep,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Reintentar'),
            style: TextButton.styleFrom(
              foregroundColor: LivoraColors.forest,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
