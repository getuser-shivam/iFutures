import 'package:flutter_test/flutter_test.dart';
import 'package:ifutures/models/price_alert.dart';

void main() {
  test('price alert matches the configured direction', () {
    const above = PriceAlert(
      id: 'a1',
      symbol: 'GALAUSDT',
      direction: PriceAlertDirection.above,
      threshold: 0.75,
      createdAt: DateTime(2026, 1, 1),
    );
    const below = PriceAlert(
      id: 'b1',
      symbol: 'GALAUSDT',
      direction: PriceAlertDirection.below,
      threshold: 0.65,
      createdAt: DateTime(2026, 1, 1),
    );

    expect(above.matches(0.8), isTrue);
    expect(above.matches(0.7), isFalse);
    expect(below.matches(0.6), isTrue);
    expect(below.matches(0.7), isFalse);
  });

  test('price alert serializes and deserializes cleanly', () {
    const original = PriceAlert(
      id: 'alert-1',
      symbol: 'GALAUSDT',
      direction: PriceAlertDirection.below,
      threshold: 0.42,
      createdAt: DateTime(2026, 1, 1, 12, 30),
      enabled: false,
      triggeredAt: DateTime(2026, 1, 2, 8, 45),
    );

    final decoded = PriceAlert.fromJson(original.toJson());

    expect(decoded.id, original.id);
    expect(decoded.symbol, original.symbol);
    expect(decoded.direction, original.direction);
    expect(decoded.threshold, original.threshold);
    expect(decoded.createdAt, original.createdAt);
    expect(decoded.enabled, original.enabled);
    expect(decoded.triggeredAt, original.triggeredAt);
  });

  test('price alert can trigger and rearm cleanly', () {
    const original = PriceAlert(
      id: 'alert-2',
      symbol: 'GALAUSDT',
      direction: PriceAlertDirection.above,
      threshold: 0.99,
      createdAt: DateTime(2026, 1, 1, 12, 30),
    );

    final triggered = original.trigger(DateTime(2026, 1, 2, 8, 45));
    final rearmed = triggered.rearm();

    expect(triggered.isTriggered, isTrue);
    expect(triggered.isActive, isFalse);
    expect(rearmed.enabled, isTrue);
    expect(rearmed.triggeredAt, isNull);
    expect(rearmed.isActive, isTrue);
  });

  test('formatPriceValue trims unnecessary trailing zeros', () {
    expect(formatPriceValue(1234.5), '1,234.5');
    expect(formatPriceValue(0.0001234), '0.000123');
    expect(formatPriceValue(42.0), '42');
  });
}
