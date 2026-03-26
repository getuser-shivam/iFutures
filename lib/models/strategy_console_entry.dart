enum StrategyConsoleLevel { info, success, warning, error }

class StrategyConsoleEntry {
  final DateTime timestamp;
  final StrategyConsoleLevel level;
  final String message;

  const StrategyConsoleEntry({
    required this.timestamp,
    required this.level,
    required this.message,
  });
}
