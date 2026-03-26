import 'package:flutter_test/flutter_test.dart';
import 'package:ifutures/constants/symbols.dart';

void main() {
  test('default symbols include TRIAUSDT', () {
    expect(defaultSymbols, contains(triausdtSymbol));
  });

  test('normalizeSymbolList uppercases and deduplicates symbols', () {
    final symbols = normalizeSymbolList(
      [' galausdt ', 'triausdt', 'BTCUSDT', 'btcUsdt'],
      requiredSymbols: [triausdtSymbol],
    );

    expect(symbols, ['GALAUSDT', 'TRIAUSDT', 'BTCUSDT']);
  });
}
