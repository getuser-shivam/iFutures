import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/trading_provider.dart';
import '../../models/ai_provider.dart';
import '../../models/rsi_strategy_preset.dart';
import '../../models/strategy_mode.dart';
import '../../trading/algo_strategy.dart';
import '../../theme/app_theme.dart';
import '../common/app_toast.dart';

class ModeSelector extends ConsumerStatefulWidget {
  const ModeSelector({super.key});

  @override
  ConsumerState<ModeSelector> createState() => _ModeSelectorState();
}

class _ModeSelectorState extends ConsumerState<ModeSelector> {
  bool _isSwitching = false;

  Future<void> _switchMode(
    StrategyMode nextMode, {
    required String symbol,
    required StrategyMode currentMode,
  }) async {
    if (_isSwitching || nextMode == currentMode) return;
    setState(() => _isSwitching = true);
    try {
      final disarm = await ref
          .read(tradingRuntimeSafetyProvider)
          .disarmBeforeRuntimeChange(
            symbol: symbol,
            reason: 'strategy_mode_changed',
          );
      if (!disarm.canProceed) {
        throw disarm.error ?? 'unknown order-reconciliation failure';
      }
      ref.read(isBotRunningProvider(symbol).notifier).state = false;
      await ref
          .read(currentStrategyProvider.notifier)
          .setMode(nextMode, symbol: symbol);
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        'Strategy switch blocked because working orders could not be safely reconciled: $error',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.gpp_bad_outlined,
        duration: const Duration(seconds: 5),
      );
    } finally {
      if (mounted) {
        setState(() => _isSwitching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            _isSwitching
                ? null
                : () => _switchMode(
                    StrategyMode.algo,
                    symbol: symbol,
                    currentMode: currentMode,
                  ),
            tooltip: currentPreset == null
                ? 'Switch to custom RSI settings'
                : '${currentPreset.label}: ${currentPreset.summary}',
          ),
          const SizedBox(width: 6),
          _buildOption(
            'AI',
            currentMode == StrategyMode.ai,
            _isSwitching
                ? null
                : () => _switchMode(
                    StrategyMode.ai,
                    symbol: symbol,
                    currentMode: currentMode,
                  ),
            tooltip:
                'Switch to ${aiProviderFromKey(settings.getAiProvider()).label} signal analysis',
          ),
          const SizedBox(width: 6),
          _buildOption(
            'MANUAL',
            currentMode == StrategyMode.manual,
            _isSwitching
                ? null
                : () => _switchMode(
                    StrategyMode.manual,
                    symbol: symbol,
                    currentMode: currentMode,
                  ),
            tooltip: 'Manual override mode',
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    String label,
    bool isSelected,
    VoidCallback? onTap, {
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
