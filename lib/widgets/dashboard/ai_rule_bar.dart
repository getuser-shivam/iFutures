import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ai_trade_direction_mode.dart';
import '../../models/strategy_mode.dart';
import '../../providers/trading_provider.dart';
import '../../theme/app_theme.dart';
import '../common/app_panel.dart';
import '../common/app_toast.dart';
import '../common/status_pill.dart';

class AiRuleBar extends ConsumerStatefulWidget {
  final String symbol;

  const AiRuleBar({super.key, required this.symbol});

  @override
  ConsumerState<AiRuleBar> createState() => _AiRuleBarState();
}

class _AiRuleBarState extends ConsumerState<AiRuleBar> {
  late TextEditingController _budgetController;
  late TextEditingController _leverageController;
  AiTradeDirectionMode _directionMode = AiTradeDirectionMode.auto;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _budgetController = TextEditingController();
    _leverageController = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final settings = ref.read(settingsServiceProvider);
    await settings.init();
    if (!mounted) return;
    setState(() {
      _directionMode = aiTradeDirectionModeFromKey(
        settings.getAiTradeDirectionMode(),
      );
      _budgetController.text = settings.getAiInvestmentUsdt()?.toString() ?? '';
      _leverageController.text = settings.getAiLeverage()?.toString() ?? '';
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _leverageController.dispose();
    super.dispose();
  }

  double? _parseDouble(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    final parsed = double.tryParse(normalized);
    return parsed?.isFinite == true ? parsed : null;
  }

  int? _parseInt(String value) {
    return int.tryParse(value.trim());
  }

  Future<void> _applyRules() async {
    final budget = _budgetController.text.trim().isEmpty
        ? null
        : _parseDouble(_budgetController.text);
    final leverage = _leverageController.text.trim().isEmpty
        ? null
        : _parseInt(_leverageController.text);

    if (_budgetController.text.trim().isNotEmpty &&
        (budget == null || budget <= 0)) {
      showAppToast(
        context,
        'AI margin budget must be greater than 0 USDT.',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
      return;
    }

    if (_leverageController.text.trim().isNotEmpty &&
        (leverage == null || leverage < 1 || leverage > 125)) {
      showAppToast(
        context,
        'AI leverage must be between 1x and 125x.',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });
    final currentMode = ref.read(currentStrategyModeProvider);
    try {
      if (currentMode == StrategyMode.ai) {
        final disarm = await ref
            .read(tradingRuntimeSafetyProvider)
            .disarmBeforeRuntimeChange(
              symbol: widget.symbol,
              reason: 'ai_rules_changed',
            );
        if (!disarm.canProceed) {
          throw disarm.error ?? 'unknown order-reconciliation failure';
        }
        ref.read(isBotRunningProvider(widget.symbol).notifier).state = false;
      }

      final settings = ref.read(settingsServiceProvider);
      await settings.init();
      await settings.setAiTradeDirectionMode(_directionMode.key);
      await settings.setAiInvestmentUsdt(budget);
      await settings.setAiLeverage(leverage);

      ref.invalidate(aiStrategyProvider(widget.symbol));
      ref.invalidate(aiServiceStatusProvider(widget.symbol));
      if (currentMode == StrategyMode.ai) {
        await ref
            .read(currentStrategyProvider.notifier)
            .setMode(StrategyMode.ai, symbol: widget.symbol, persist: false);
        ref.invalidate(tradingEngineProvider(widget.symbol));
      }
      ref.invalidate(decisionPlanStreamProvider(widget.symbol));

      if (!mounted) return;
      showAppToast(
        context,
        currentMode == StrategyMode.ai
            ? 'AI trade rules applied. Auto execution is disarmed; review and start it again.'
            : 'AI trade rules saved for the next AI-mode session.',
        backgroundColor: AppColors.positive.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.auto_awesome,
      );
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        'AI trade rules were not applied safely: $error',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.gpp_bad_outlined,
        duration: const Duration(seconds: 5),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentMode = ref.watch(currentStrategyModeProvider);
    final planAsync = ref.watch(decisionPlanStreamProvider(widget.symbol));

    if (_isLoading) {
      return const AppPanel(
        child: SizedBox(
          height: 88,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.psychology_alt_outlined,
                    color: AppColors.glowCyan,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'AI Trade Rules',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              StatusPill(
                label: currentMode == StrategyMode.ai
                    ? 'Live AI Mode'
                    : 'Used In AI Mode',
                color: currentMode == StrategyMode.ai
                    ? AppColors.positive
                    : AppColors.warning,
              ),
              planAsync.maybeWhen(
                data: (plan) => plan == null
                    ? const SizedBox.shrink()
                    : StatusPill(
                        label:
                            'Latest Plan: ${plan.actionLabel} | ${plan.orderTypeLabel}',
                        color: plan.isActionable
                            ? AppColors.glowCyan
                            : AppColors.textMuted,
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Set the AI side, leverage, and USDT margin budget here. API keys and provider setup stay in Settings, but trading rules belong on the desk.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mode in AiTradeDirectionMode.values)
                    ChoiceChip(
                      label: Text(mode.label),
                      selected: _directionMode == mode,
                      onSelected: (_) {
                        setState(() {
                          _directionMode = mode;
                        });
                      },
                    ),
                ],
              ),
              SizedBox(
                width: 170,
                child: TextField(
                  controller: _leverageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'AI Leverage (x)',
                    hintText: 'Uses default if blank',
                  ),
                ),
              ),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _budgetController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'AI Margin Budget (USDT)',
                    hintText: 'Uses default if blank',
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _isSaving ? null : _applyRules,
                icon: Icon(_isSaving ? Icons.hourglass_top : Icons.check),
                label: Text(_isSaving ? 'APPLYING...' : 'APPLY RULES'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
