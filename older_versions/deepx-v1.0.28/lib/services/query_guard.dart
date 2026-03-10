import 'dart:async';

enum QueryFailureKind {
  network,
  timeout,
  server,
  unknown,
}

class QueryFailure implements Exception {
  const QueryFailure({
    required this.kind,
    required this.message,
    this.originalError,
  });

  final QueryFailureKind kind;
  final String message;
  final Object? originalError;

  bool get isNetwork =>
      kind == QueryFailureKind.network || kind == QueryFailureKind.timeout;
}

class QueryGuard {
  static const Duration defaultTimeout = Duration(seconds: 15);

  static Future<T> run<T>(
    Future<T> Function() action, {
    Duration timeout = defaultTimeout,
  }) async {
    try {
      return await action().timeout(timeout);
    } on TimeoutException catch (error) {
      throw QueryFailure(
        kind: QueryFailureKind.timeout,
        message:
            'No internet connection. Please check your network and retry.',
        originalError: error,
      );
    } catch (error) {
      throw classify(error);
    }
  }

  static QueryFailure classify(Object error) {
    if (error is QueryFailure) return error;

    final String raw = error.toString().toLowerCase();
    final String type = error.runtimeType.toString().toLowerCase();

    final bool networkByText = _looksLikeNetworkIssue(raw);
    final bool networkByType = type.contains('socket') ||
        type.contains('clientexception') ||
        type.contains('timeout') ||
        type.contains('fetch');

    if (networkByText || networkByType) {
      return QueryFailure(
        kind: QueryFailureKind.network,
        message:
            'No internet connection. Please check your network and retry.',
        originalError: error,
      );
    }

    if (raw.contains('permission') ||
        raw.contains('forbidden') ||
        raw.contains('unauthorized') ||
        raw.contains('not found') ||
        raw.contains('failed')) {
      return QueryFailure(
        kind: QueryFailureKind.server,
        message: 'Unable to load right now. Please retry.',
        originalError: error,
      );
    }

    return QueryFailure(
      kind: QueryFailureKind.unknown,
      message: 'Something went wrong. Please retry.',
      originalError: error,
    );
  }

  static bool _looksLikeNetworkIssue(String raw) {
    return raw.contains('network') ||
        raw.contains('socket') ||
        raw.contains('connection') ||
        raw.contains('offline') ||
        raw.contains('failed host lookup') ||
        raw.contains('xmlhttprequest') ||
        raw.contains('timed out') ||
        raw.contains('timeout');
  }
}
