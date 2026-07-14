import 'package:flutter_test/flutter_test.dart';
import 'package:ifutures/models/live_order.dart';

void main() {
  const ownerId = 'a1b2c3d4';

  LiveOrder order({required String clientOrderId, String type = 'LIMIT'}) {
    return LiveOrder(
      symbol: 'ARIAUSDT',
      orderId: '123',
      clientOrderId: clientOrderId,
      side: 'BUY',
      type: type,
      price: 1,
      quantity: 2,
      reduceOnly: false,
      updatedAt: DateTime.utc(2026),
    );
  }

  test('scoped entry IDs retain generic bot display behavior', () {
    final entry = order(clientOrderId: 'ifut-entry-$ownerId-mabc1234-1');

    expect(entry.isBotOwned, isTrue);
    expect(entry.isBotEntryOrder, isTrue);
    expect(entry.isOwnedBy(ownerId), isTrue);
    expect(entry.isEntryOrderOwnedBy(ownerId), isTrue);
    expect(entry.isExitOrderOwnedBy(ownerId), isFalse);
    expect(entry.isOwnedBy('z9y8x7w6'), isFalse);
    expect(entry.summary, contains('[iFutures]'));
  });

  test('scoped exit and protection IDs distinguish their roles', () {
    final exit = order(clientOrderId: 'ifut-exit-$ownerId-mabc1234-2');
    final protection = order(
      clientOrderId: 'ifut-tp-$ownerId-mabc1234-3',
      type: 'TAKE_PROFIT_MARKET',
    );

    expect(exit.isOwnedBy(ownerId), isTrue);
    expect(exit.isEntryOrderOwnedBy(ownerId), isFalse);
    expect(exit.isExitOrderOwnedBy(ownerId), isTrue);
    expect(protection.isOwnedBy(ownerId), isTrue);
    expect(protection.isEntryOrderOwnedBy(ownerId), isFalse);
    expect(protection.isExitOrderOwnedBy(ownerId), isFalse);
    expect(protection.isProtectionOrder, isTrue);
  });

  test('legacy and malformed IDs are never claimed by an owner', () {
    final legacy = order(clientOrderId: 'ifut-entry-$ownerId-1');
    final malformed = order(
      clientOrderId: 'ifut-entry-$ownerId-mabc1234-1-extra',
    );

    expect(legacy.isBotOwned, isTrue);
    expect(legacy.isBotEntryOrder, isTrue);
    expect(legacy.isOwnedBy(ownerId), isFalse);
    expect(malformed.isOwnedBy(ownerId), isFalse);
    expect(malformed.isOwnedBy(ownerId.toUpperCase()), isFalse);
  });
}
