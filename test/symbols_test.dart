import 'package:flutter_test/flutter_test.dart';
import 'package:ifutures/constants/symbols.dart';

void main() {
  test('ARIA is primary and the core futures symbols are always available', () {
    expect(defaultSymbol, ariausdtSymbol);
    expect(defaultSymbols.first, ariausdtSymbol);
    expect(defaultSymbols, contains(ariausdtSymbol));
    expect(defaultSymbols, contains(triausdtSymbol));
    expect(defaultSymbols, contains(sirenusdtSymbol));
    expect(defaultSymbols, contains(btcusdtSymbol));
    expect(defaultSymbols, contains(truusdtSymbol));
  });

  test('normalizeSymbolList uppercases and deduplicates symbols', () {
    final symbols = normalizeSymbolList(
      [' galausdt ', 'triausdt', 'BTCUSDT', 'btcUsdt'],
      requiredSymbols: [...coreTradingSymbols, truusdtSymbol],
    );

    expect(symbols, [
      'GALAUSDT',
      'TRIAUSDT',
      'BTCUSDT',
      'ARIAUSDT',
      'SIRENUSDT',
      'TRUUSDT',
    ]);
  });
}
