import 'package:flutter_test/flutter_test.dart';
import 'package:ifutures/services/reconnect_backoff.dart';

void main() {
  test('reconnect delay doubles and caps at the maximum', () {
    expect(reconnectDelayForAttempt(0), Duration.zero);
    expect(reconnectDelayForAttempt(1), const Duration(seconds: 1));
    expect(reconnectDelayForAttempt(2), const Duration(seconds: 2));
    expect(reconnectDelayForAttempt(3), const Duration(seconds: 4));
    expect(reconnectDelayForAttempt(6), const Duration(seconds: 30));
  });
}
