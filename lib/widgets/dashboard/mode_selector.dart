import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/trading_provider.dart';
import '../../models/ai_provider.dart';
import '../../models/rsi_strategy_preset.dart';
import '../../models/strategy_mode.dart';
import '../../trading/algo_strategy.dart';
import '../../trading/ai_strategy.dart';
import '../../trading/manual_strategy.dart';
import '../../theme/app_theme.dart';

class ModeSelector extends ConsumerWidget {
  const ModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStrategy = ref.watch(currentStrategyProvider);
    final currentMode = ref.watch(currentStrategyModeProvider);
    final settings = ref.watch(settingsServiceProvider);
    final symbol = ref.watch(selectedSymbolProvider);
    if (currentStrategy == null) return const SizedBox.shrink();

    final currentPreset = currentStrategy is RsiStrategy
        ? findRsiStrategyPreset(
            period: settings.getRsiPeriod(),
            overbought: settings.getRsiOverbought(),
            oversold: settings.getRsiOversold(),
          )
        : null;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOption(
            'ALGO',
            currentMode == StrategyMode.algo,
            () => ref
                .read(currentStrategyProvider.notifier)
                .setMode(StrategyMode.algo, symbol: symbol),
            tooltip: currentPreset == null
                ? 'Switch to custom RSI settings'
                : '${currentPreset.label}: ${currentPreset.summary}',
          ),
          const SizedBox(width: 6),
          _buildOption(
            'AI',
            currentMode == StrategyMode.ai,
            () => ref
                .read(currentStrategyProvider.notifier)
                .setMode(StrategyMode.ai, symbol: symbol),
            tooltip:
                'Switch to ${aiProviderFromKey(settings.getAiProvider()).label} signal analysis',
          ),
          const SizedBox(width: 6),
          _buildOption(
            'MANUAL',
            currentMode == StrategyMode.manual,
            () => ref
                .read(currentStrategyProvider.notifier)
                .setMode(StrategyMode.manual, symbol: symbol),
            tooltip: 'Manual override mode',
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    String label,
    bool isSelected,
    VoidCallback onTap, {
    String? tooltip,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: Tooltip(
        message: tooltip ?? label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.glowAmber : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.glowAmber : AppColors.border,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.glowAmber.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [],
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
