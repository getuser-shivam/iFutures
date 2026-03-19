import 'dart:math' as math;

Duration reconnectDelayForAttempt(
  int attempt, {
  Duration initialDelay = const Duration(seconds: 1),
  Duration maxDelay = const Duration(seconds: 30),
}) {
  if (attempt <= 0) {
    return Duration.zero;
  }

  final initialMs = initialDelay.inMilliseconds;
  final maxMs = maxDelay.inMilliseconds;
  final candidateMs = initialMs * (1 << (attempt - 1));

  return Duration(milliseconds: math.min(candidateMs, maxMs));
}
