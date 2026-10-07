/// Estados sellados inmutables para la capa de presentación (Dart 3 Sealed Classes).
/// Proporciona tipado estricto y exhaustividad en pattern matching para vistas UI.
sealed class UIState<T> {
  const UIState();

  const factory UIState.initial() = UIInitial<T>;
  const factory UIState.loading({T? cachedData}) = UILoading<T>;
  const factory UIState.success(T data) = UISuccess<T>;
  const factory UIState.empty({String? message}) = UIEmpty<T>;
  const factory UIState.error(String message, {bool isNetworkError, T? cachedData}) = UIError<T>;

  bool get isInitial => this is UIInitial<T>;
  bool get isLoading => this is UILoading<T>;
  bool get isSuccess => this is UISuccess<T>;
  bool get isError => this is UIError<T>;
  bool get isEmpty => this is UIEmpty<T>;

  T? get dataOrNull => switch (this) {
        UISuccess<T>(:final data) => data,
        UILoading<T>(:final cachedData) => cachedData,
        UIError<T>(:final cachedData) => cachedData,
        _ => null,
      };

  String? get errorMessageOrNull => switch (this) {
        UIError<T>(:final message) => message,
        _ => null,
      };
}

final class UIInitial<T> extends UIState<T> {
  const UIInitial();
}

final class UILoading<T> extends UIState<T> {
  final T? cachedData;
  const UILoading({this.cachedData});
}

final class UISuccess<T> extends UIState<T> {
  final T data;
  const UISuccess(this.data);
}

final class UIEmpty<T> extends UIState<T> {
  final String? message;
  const UIEmpty({this.message});
}

final class UIError<T> extends UIState<T> {
  final String message;
  final bool isNetworkError;
  final T? cachedData;

  const UIError(
    this.message, {
    this.isNetworkError = false,
    this.cachedData,
  });
}
