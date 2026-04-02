import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/connection_status.dart';
import 'reconnect_backoff.dart';

typedef WebSocketStatusCallback = void Function(ConnectionStatus status);

class ReconnectingWebSocket {
  final Uri url;
  final WebSocketStatusCallback? onStatusChanged;
  final Duration initialRetryDelay;
  final Duration maxRetryDelay;

  late final StreamController<String> _controller = StreamController<String>(
    onListen: _start,
    onCancel: close,
  );

  final Completer<void> _disposeSignal = Completer<void>();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _disposed = false;
  bool _started = false;
  int _failureStreak = 0;

  ReconnectingWebSocket({
    required this.url,
    this.onStatusChanged,
    this.initialRetryDelay = const Duration(seconds: 1),
    this.maxRetryDelay = const Duration(seconds: 30),
  });

  Stream<String> get stream => _controller.stream;

  void _start() {
    if (_started || _disposed) {
      return;
    }

    _started = true;
    unawaited(_run());
  }

  Future<void> close() async {
    if (_disposed) {
      return;
    }

    _disposed = true;
    if (!_disposeSignal.isCompleted) {
      _disposeSignal.complete();
    }

    await _subscription?.cancel();
    _subscription = null;

    await _channel?.sink.close();
    _channel = null;

    if (!_controller.isClosed) {
      await _controller.close();
    }
  }

  Future<void> _run() async {
    while (!_disposed) {
      onStatusChanged?.call(ConnectionStatus.connecting());

      final cycle = await _connectOnce();
      if (_disposed) {
        break;
      }

      final attempt = _failureStreak + 1;
      final delay = reconnectDelayForAttempt(
        attempt,
        initialDelay: initialRetryDelay,
        maxDelay: maxRetryDelay,
      );

      onStatusChanged?.call(
        ConnectionStatus.reconnecting(
          retryAttempt: attempt,
          retryDelayMs: delay.inMilliseconds,
          errorMessage: cycle.error?.toString(),
        ),
      );

      if (!await _waitForRetry(delay)) {
        break;
      }

      _failureStreak = cycle.hadMessages ? 0 : attempt;
    }
  }

  Future<_CycleResult> _connectOnce() async {
    var hadMessages = false;
    Object? error;

    try {
      _channel = WebSocketChannel.connect(url);
      final completer = Completer<void>();

      _subscription = _channel!.stream.listen(
        (event) {
          hadMessages = true;
          if (!_disposed && !_controller.isClosed) {
            _controller.add(event.toString());
          }
        },
        onError: (Object e, StackTrace stackTrace) {
          error = e;
          if (!completer.isCompleted) {
            completer.completeError(e, stackTrace);
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        cancelOnError: true,
      );

      try {
        await completer.future;
      } catch (_) {
        // Error is captured above and used to inform the next retry.
      } finally {
        await _subscription?.cancel();
        _subscription = null;
        await _channel?.sink.close();
        _channel = null;
      }
    } catch (e) {
      error = error ?? e;
    }

    return _CycleResult(hadMessages: hadMessages, error: error);
  }

  Future<bool> _waitForRetry(Duration delay) async {
    if (delay <= Duration.zero) {
      return !_disposed;
    }

    await Future.any([Future.delayed(delay), _disposeSignal.future]);

    return !_disposed;
  }
}

class _CycleResult {
  final bool hadMessages;
  final Object? error;

  const _CycleResult({required this.hadMessages, this.error});
}
