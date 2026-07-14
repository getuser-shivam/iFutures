const String ariausdtSymbol = 'ARIAUSDT';
const String triausdtSymbol = 'TRIAUSDT';
const String sirenusdtSymbol = 'SIRENUSDT';
const String truusdtSymbol = 'TRUUSDT';
const String btcusdtSymbol = 'BTCUSDT';
const String defaultSymbol = ariausdtSymbol;

const List<String> coreTradingSymbols = [
  ariausdtSymbol,
  triausdtSymbol,
  sirenusdtSymbol,
  btcusdtSymbol,
];

const List<String> defaultSymbols = [
  ...coreTradingSymbols,
  'GALAUSDT',
  'ETHUSDT',
  'BNBUSDT',
  'SOLUSDT',
  truusdtSymbol,
];

const List<String> marketWatchlistSymbols = [
  btcusdtSymbol,
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
