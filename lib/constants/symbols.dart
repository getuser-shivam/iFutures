const String defaultSymbol = 'GALAUSDT';
const String triausdtSymbol = 'TRIAUSDT';

const List<String> defaultSymbols = [
  defaultSymbol,
  'BTCUSDT',
  'ETHUSDT',
  'BNBUSDT',
  'SOLUSDT',
  triausdtSymbol,
];

const List<String> marketWatchlistSymbols = [
  'BTCUSDT',
  'ETHUSDT',
  'BNBUSDT',
  'SOLUSDT',
];

List<String> normalizeSymbolList(
  Iterable<String> symbols, {
  Iterable<String> requiredSymbols = const [],
}) {
  final seen = <String>{};
  final normalized = <String>[];

  void addSymbol(String symbol) {
    final value = symbol.trim().toUpperCase();
    if (value.isEmpty || !seen.add(value)) {
      return;
    }
    normalized.add(value);
  }

  for (final symbol in symbols) {
    addSymbol(symbol);
  }

  for (final symbol in requiredSymbols) {
    addSymbol(symbol);
  }

  return normalized;
}
