enum AiTradeDirectionMode { auto, longOnly, shortOnly }

extension AiTradeDirectionModeX on AiTradeDirectionMode {
  String get key => switch (this) {
    AiTradeDirectionMode.auto => 'auto',
    AiTradeDirectionMode.longOnly => 'long_only',
    AiTradeDirectionMode.shortOnly => 'short_only',
  };

  String get label => switch (this) {
    AiTradeDirectionMode.auto => 'Auto',
    AiTradeDirectionMode.longOnly => 'Long Only',
    AiTradeDirectionMode.shortOnly => 'Short Only',
  };

  String get promptLabel => switch (this) {
    AiTradeDirectionMode.auto => 'Auto long/short',
    AiTradeDirectionMode.longOnly => 'Long only',
    AiTradeDirectionMode.shortOnly => 'Short only',
  };
}

AiTradeDirectionMode aiTradeDirectionModeFromKey(String? value) {
  return AiTradeDirectionMode.values.firstWhere(
    (mode) => mode.key == value,
    orElse: () => AiTradeDirectionMode.auto,
  );
}
