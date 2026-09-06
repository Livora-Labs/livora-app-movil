import 'dart:async';
import 'package:flutter/material.dart';

typedef PageFetcher<T> = Future<List<T>> Function(int page, int pageSize);
typedef ItemKeySelector<T> = Object Function(T item);

/// Controlador universal de paginación infinita (Infinite Scroll) optimizado para 60 FPS.
/// Gestiona la carga de la primera página, páginas subsiguientes, errores en línea,
/// deduplicación de elementos por clave única y ciclo de vida de scroll.
class PagingController<T> extends ChangeNotifier {
  PagingController({
    required this.fetcher,
    this.keySelector,
    this.pageSize = 15,
    this.scrollThreshold = 0.8,
  });

  final PageFetcher<T> fetcher;
  final ItemKeySelector<T>? keySelector;
  final int pageSize;
  final double scrollThreshold;

  List<T> _items = [];
  bool _isLoadingFirstPage = false;
  bool _isLoadingNextPage = false;
  Object? _firstPageError;
  Object? _nextPageError;
  bool _hasMore = true;
  int _currentPage = 1;
  bool _disposed = false;

  ScrollController? _attachedScrollController;

  List<T> get items => List.unmodifiable(_items);
  bool get isLoadingFirstPage => _isLoadingFirstPage;
  bool get isLoadingNextPage => _isLoadingNextPage;
  Object? get firstPageError => _firstPageError;
  Object? get nextPageError => _nextPageError;
  bool get hasMore => _hasMore;
  int get currentPage => _currentPage;
  bool get isEmpty => _items.isEmpty && !_isLoadingFirstPage && _firstPageError == null;

  void attachScrollController(ScrollController controller) {
    if (_attachedScrollController == controller) return;
    _detachScrollController();
    _attachedScrollController = controller;
    controller.addListener(_handleScroll);
  }

  void _detachScrollController() {
    _attachedScrollController?.removeListener(_handleScroll);
    _attachedScrollController = null;
  }

  void _handleScroll() {
    final controller = _attachedScrollController;
    if (controller == null || !controller.hasClients) return;
    final position = controller.position;
    if (position.maxScrollExtent <= 0) return;

    if (position.pixels >= position.maxScrollExtent * scrollThreshold) {
      if (!_isLoadingFirstPage && !_isLoadingNextPage && _hasMore && _nextPageError == null) {
        loadNextPage();
      }
    }
  }

  /// Carga la primera página (resetea el estado previo)
  Future<void> loadFirstPage() async {
    if (_disposed) return;
    _isLoadingFirstPage = true;
    _firstPageError = null;
    _nextPageError = null;
    _currentPage = 1;
    _hasMore = true;
    notifyListeners();

    try {
      final newItems = await fetcher(1, pageSize);
      if (_disposed) return;

      _items = _deduplicate(newItems);
      _hasMore = newItems.length >= pageSize;
      _isLoadingFirstPage = false;
      notifyListeners();
    } catch (e) {
      if (_disposed) return;
      _firstPageError = e;
      _isLoadingFirstPage = false;
      notifyListeners();
    }
  }

  /// Carga el siguiente lote de elementos en segundo plano
  Future<void> loadNextPage() async {
    if (_disposed || _isLoadingFirstPage || _isLoadingNextPage || !_hasMore) return;

    _isLoadingNextPage = true;
    _nextPageError = null;
    notifyListeners();

    final nextPage = _currentPage + 1;
    try {
      final newItems = await fetcher(nextPage, pageSize);
      if (_disposed) return;

      final combined = [..._items, ...newItems];
      _items = _deduplicate(combined);
      _currentPage = nextPage;
      _hasMore = newItems.length >= pageSize;
      _isLoadingNextPage = false;
      notifyListeners();
    } catch (e) {
      if (_disposed) return;
      _nextPageError = e;
      _isLoadingNextPage = false;
      notifyListeners();
    }
  }

  /// Reintento específico para la página siguiente si falló la conexión
  Future<void> retryNextPage() async {
    if (_nextPageError != null) {
      _nextPageError = null;
      notifyListeners();
      await loadNextPage();
    }
  }

  /// Refresco manual (Pull to Refresh)
  Future<void> refresh() async {
    await loadFirstPage();
  }

  /// Modifica un elemento en memoria para evitar refrescos innecesarios
  void updateItem(bool Function(T item) predicate, T Function(T current) update) {
    final index = _items.indexWhere(predicate);
    if (index != -1) {
      _items[index] = update(_items[index]);
      notifyListeners();
    }
  }

  /// Elimina un elemento en memoria
  void removeItem(bool Function(T item) predicate) {
    final initialLength = _items.length;
    _items.removeWhere(predicate);
    if (_items.length != initialLength) {
      notifyListeners();
    }
  }

  List<T> _deduplicate(List<T> list) {
    if (keySelector == null) return list;
    final seen = <Object>{};
    final result = <T>[];
    for (final item in list) {
      final key = keySelector!(item);
      if (seen.add(key)) {
        result.add(item);
      }
    }
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    _detachScrollController();
    super.dispose();
  }
}
