enum StrategyMode { manual, algo, ai }

extension StrategyModeX on StrategyMode {
  String get key => switch (this) {
    StrategyMode.manual => 'manual',
    StrategyMode.algo => 'algo',
    StrategyMode.ai => 'ai',
  };

  String get label => switch (this) {
    StrategyMode.manual => 'MANUAL',
    StrategyMode.algo => 'ALGO',
    StrategyMode.ai => 'AI',
  };
}

StrategyMode strategyModeFromKey(String? value) {
  return switch (value?.trim().toLowerCase()) {
    'algo' => StrategyMode.algo,
    'ai' => StrategyMode.ai,
    _ => StrategyMode.manual,
  };
}
