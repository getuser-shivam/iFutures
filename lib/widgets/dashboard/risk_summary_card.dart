import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/connection_status.dart';
import '../../models/protection_status.dart';
import '../../models/risk_settings.dart';
import '../../models/strategy_mode.dart';
import '../../providers/trading_provider.dart';
import '../../theme/app_theme.dart';
import '../../trading/manual_strategy.dart';
import '../../trading/strategy.dart';
import '../common/app_panel.dart';
import '../common/app_toast.dart';
import '../common/status_pill.dart';

class RiskSummaryCard extends ConsumerStatefulWidget {
  const RiskSummaryCard({super.key});

  @override
  ConsumerState<RiskSummaryCard> createState() => _RiskSummaryCardState();
}

class _RiskSummaryCardState extends ConsumerState<RiskSummaryCard> {
  late final TextEditingController _stopLossController;
  late final TextEditingController _takeProfitController;
  late final TextEditingController _tradeQuantityController;
  late final TextEditingController _targetProfitUsdtController;
  late final TextEditingController _maxLossUsdtController;
  late final TextEditingController _leverageController;
  late final TextEditingController _cooldownMinutesController;
  late final TextEditingController _protectionPauseMinutesController;
  late final TextEditingController _maxConsecutiveLossesController;
  late final TextEditingController _maxDrawdownController;

  bool _showProtectionFields = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String _savedStopLoss = '';
  String _savedTakeProfit = '';
  String _savedTradeQuantity = '';
  String _savedTargetProfitUsdt = '';
  String _savedMaxLossUsdt = '';
  String _savedLeverage = '';
  String _savedCooldownMinutes = '';
  String _savedProtectionPauseMinutes = '';
  String _savedMaxConsecutiveLosses = '';
  String _savedMaxDrawdown = '';

  @override
  void initState() {
    super.initState();
    _stopLossController = TextEditingController();
    _takeProfitController = TextEditingController();
    _tradeQuantityController = TextEditingController();
    _targetProfitUsdtController = TextEditingController();
    _maxLossUsdtController = TextEditingController();
    _leverageController = TextEditingController();
    _cooldownMinutesController = TextEditingController();
    _protectionPauseMinutesController = TextEditingController();
    _maxConsecutiveLossesController = TextEditingController();
    _maxDrawdownController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _stopLossController.dispose();
    _takeProfitController.dispose();
    _tradeQuantityController.dispose();
    _targetProfitUsdtController.dispose();
    _maxLossUsdtController.dispose();
    _leverageController.dispose();
    _cooldownMinutesController.dispose();
    _protectionPauseMinutesController.dispose();
    _maxConsecutiveLossesController.dispose();
    _maxDrawdownController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = ref.read(settingsServiceProvider);
    await settings.init();
    if (!mounted) {
      return;
    }
    _setSavedValues(
      RiskSettings(
        stopLossPercent: settings.getRiskStopLossPercent(),
        takeProfitPercent: settings.getRiskTakeProfitPercent(),
        tradeQuantity: settings.getRiskTradeQuantity(),
        investmentUsdt:
            settings.getRiskInvestmentUsdt() ?? settings.getRiskTradeQuantity(),
        targetProfitUsdt: settings.getRiskTargetProfitUsdt(),
        maxLossUsdt: settings.getRiskMaxLossUsdt(),
        leverage: settings.getRiskLeverage(),
        cooldownMinutes: settings.getRiskCooldownMinutes(),
        protectionPauseMinutes: settings.getRiskProtectionPauseMinutes(),
        maxConsecutiveLosses: settings.getRiskMaxConsecutiveLosses(),
        maxDrawdownPercent: settings.getRiskMaxDrawdownPercent(),
      ),
    );
    setState(() {
      _isLoading = false;
    });
  }

  void _setSavedValues(RiskSettings risk) {
    _savedStopLoss = risk.stopLossPercent.toString();
    _savedTakeProfit = risk.takeProfitPercent.toString();
    _savedTradeQuantity = (risk.investmentUsdt ?? risk.tradeQuantity)
        .toString();
    _savedTargetProfitUsdt = risk.targetProfitUsdt?.toString() ?? '';
    _savedMaxLossUsdt = risk.maxLossUsdt?.toString() ?? '';
    _savedLeverage = risk.leverage.toString();
    _savedCooldownMinutes = risk.cooldownMinutes.toString();
    _savedProtectionPauseMinutes = risk.protectionPauseMinutes.toString();
    _savedMaxConsecutiveLosses = risk.maxConsecutiveLosses.toString();
    _savedMaxDrawdown = risk.maxDrawdownPercent.toString();

    _stopLossController.text = _savedStopLoss;
    _takeProfitController.text = _savedTakeProfit;
    _tradeQuantityController.text = _savedTradeQuantity;
    _targetProfitUsdtController.text = _savedTargetProfitUsdt;
    _maxLossUsdtController.text = _savedMaxLossUsdt;
    _leverageController.text = _savedLeverage;
    _cooldownMinutesController.text = _savedCooldownMinutes;
    _protectionPauseMinutesController.text = _savedProtectionPauseMinutes;
    _maxConsecutiveLossesController.text = _savedMaxConsecutiveLosses;
    _maxDrawdownController.text = _savedMaxDrawdown;
  }

  bool get _hasUnsavedChanges {
    return _stopLossController.text.trim() != _savedStopLoss ||
        _takeProfitController.text.trim() != _savedTakeProfit ||
        _tradeQuantityController.text.trim() != _savedTradeQuantity ||
        _targetProfitUsdtController.text.trim() != _savedTargetProfitUsdt ||
        _maxLossUsdtController.text.trim() != _savedMaxLossUsdt ||
        _leverageController.text.trim() != _savedLeverage ||
        _cooldownMinutesController.text.trim() != _savedCooldownMinutes ||
        _protectionPauseMinutesController.text.trim() !=
            _savedProtectionPauseMinutes ||
        _maxConsecutiveLossesController.text.trim() !=
            _savedMaxConsecutiveLosses ||
        _maxDrawdownController.text.trim() != _savedMaxDrawdown;
  }

  double? _parseDouble(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    final parsed = double.tryParse(normalized);
    return parsed?.isFinite == true ? parsed : null;
  }

  int? _parseInt(String value) {
    return int.tryParse(value.trim());
  }

  Future<bool> _applyTradingControls() async {
    final stopLoss = _parseDouble(_stopLossController.text);
    final takeProfit = _parseDouble(_takeProfitController.text);
    final tradeQuantity = _parseDouble(_tradeQuantityController.text);
    final targetProfitUsdt = _targetProfitUsdtController.text.trim().isEmpty
        ? null
        : _parseDouble(_targetProfitUsdtController.text);
    final maxLossUsdt = _maxLossUsdtController.text.trim().isEmpty
        ? null
        : _parseDouble(_maxLossUsdtController.text);
    final leverage = _parseInt(_leverageController.text);
    final cooldownMinutes = _parseInt(_cooldownMinutesController.text);
    final protectionPauseMinutes = _parseInt(
      _protectionPauseMinutesController.text,
    );
    final maxConsecutiveLosses = _parseInt(
      _maxConsecutiveLossesController.text,
    );
    final maxDrawdownPercent = _parseDouble(_maxDrawdownController.text);

    if (stopLoss == null ||
        !stopLoss.isFinite ||
        stopLoss < 0 ||
        stopLoss > 100) {
      _showError('Stop loss must be a finite percentage from 0 to 100.');
      return false;
    }
    if (takeProfit == null ||
        !takeProfit.isFinite ||
        takeProfit < 0 ||
        takeProfit > 100) {
      _showError('Take profit must be a finite percentage from 0 to 100.');
      return false;
    }
    if (tradeQuantity == null ||
        !tradeQuantity.isFinite ||
        tradeQuantity <= 0 ||
        tradeQuantity > 1000000) {
      _showError(
        'Investment budget must be a finite value from 0.01 to 1,000,000 USDT.',
      );
      return false;
    }
    if (_targetProfitUsdtController.text.trim().isNotEmpty &&
        (targetProfitUsdt == null ||
            !targetProfitUsdt.isFinite ||
            targetProfitUsdt <= 0 ||
            targetProfitUsdt > 1000000)) {
      _showError(
        'USDT profit target must be blank or a finite value up to 1,000,000.',
      );
      return false;
    }
    if (_maxLossUsdtController.text.trim().isNotEmpty &&
        (maxLossUsdt == null ||
            !maxLossUsdt.isFinite ||
            maxLossUsdt <= 0 ||
            maxLossUsdt > 1000000)) {
      _showError(
        'USDT max loss must be blank or a finite value up to 1,000,000.',
      );
      return false;
    }
    if (leverage == null || leverage < 1 || leverage > 125) {
      _showError('Leverage must be between 1x and 125x.');
      return false;
    }
    final configuredNotional = tradeQuantity * leverage;
    if ((targetProfitUsdt != null && targetProfitUsdt >= configuredNotional) ||
        (maxLossUsdt != null && maxLossUsdt >= configuredNotional)) {
      _showError(
        'Each absolute TP/SL guard must be below the configured notional (${configuredNotional.toStringAsFixed(2)} USDT) so both long and short trigger prices stay positive.',
      );
      return false;
    }
    if (cooldownMinutes == null || cooldownMinutes < 0) {
      _showError('Cooldown must be 0 or a positive number of minutes.');
      return false;
    }
    if (protectionPauseMinutes == null || protectionPauseMinutes < 0) {
      _showError('Protection pause must be 0 or a positive number of minutes.');
      return false;
    }
    if (maxConsecutiveLosses == null || maxConsecutiveLosses < 0) {
      _showError('Max consecutive losses must be 0 or greater.');
      return false;
    }
    if (maxDrawdownPercent == null ||
        !maxDrawdownPercent.isFinite ||
        maxDrawdownPercent < 0 ||
        maxDrawdownPercent > 100) {
      _showError('Max realized drawdown must be from 0 to 100 percent.');
      return false;
    }
    if ((maxConsecutiveLosses > 0 || maxDrawdownPercent > 0) &&
        protectionPauseMinutes == 0) {
      _showError(
        'Set a protection pause above 0 minutes when a lock rule is enabled.',
      );
      return false;
    }

    setState(() {
      _isSaving = true;
    });

    final symbol = ref.read(selectedSymbolProvider);
    final settings = ref.read(settingsServiceProvider);
    final wasRunning = ref.read(isBotRunningProvider(symbol));
    final currentMode = ref.read(currentStrategyModeProvider);
    final currentPosition = ref
        .read(positionStreamProvider(symbol))
        .valueOrNull;
    if (currentPosition != null) {
      setState(() {
        _isSaving = false;
      });
      _showError(
        'Close the active position before replacing its risk configuration. Existing exchange protection is left untouched.',
      );
      return false;
    }

    final disarm = await ref
        .read(tradingRuntimeSafetyProvider)
        .disarmBeforeRuntimeChange(
          symbol: symbol,
          reason: 'risk_settings_changed',
        );
    if (!disarm.canProceed) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        _showError(
          'Could not confirm cancellation of working bot entries: ${disarm.error}',
        );
      }
      return false;
    }
    ref.read(isBotRunningProvider(symbol).notifier).state = false;

    try {
      await settings.init();
      await settings.setRiskStopLossPercent(stopLoss);
      await settings.setRiskTakeProfitPercent(takeProfit);
      await settings.setRiskInvestmentUsdt(tradeQuantity);
      await settings.setRiskTradeQuantity(tradeQuantity);
      await settings.setRiskTargetProfitUsdt(targetProfitUsdt);
      await settings.setRiskMaxLossUsdt(maxLossUsdt);
      await settings.setRiskLeverage(leverage);
      await settings.setRiskCooldownMinutes(cooldownMinutes);
      await settings.setRiskProtectionPauseMinutes(protectionPauseMinutes);
      await settings.setRiskMaxConsecutiveLosses(maxConsecutiveLosses);
      await settings.setRiskMaxDrawdownPercent(maxDrawdownPercent);

      _savedStopLoss = _stopLossController.text.trim();
      _savedTakeProfit = _takeProfitController.text.trim();
      _savedTradeQuantity = _tradeQuantityController.text.trim();
      _savedTargetProfitUsdt = _targetProfitUsdtController.text.trim();
      _savedMaxLossUsdt = _maxLossUsdtController.text.trim();
      _savedLeverage = _leverageController.text.trim();
      _savedCooldownMinutes = _cooldownMinutesController.text.trim();
      _savedProtectionPauseMinutes = _protectionPauseMinutesController.text
          .trim();
      _savedMaxConsecutiveLosses = _maxConsecutiveLossesController.text.trim();
      _savedMaxDrawdown = _maxDrawdownController.text.trim();

      ref.invalidate(riskSettingsProvider);
      ref.invalidate(aiStrategyProvider(symbol));
      if (currentMode != StrategyMode.manual) {
        await ref
            .read(currentStrategyProvider.notifier)
            .setMode(currentMode, symbol: symbol, persist: false);
      }
      ref.invalidate(tradingEngineProvider(symbol));
      ref.invalidate(decisionPlanStreamProvider(symbol));
      ref.invalidate(signalStreamProvider(symbol));
      ref.invalidate(protectionStatusProvider(symbol));
      ref.invalidate(positionStreamProvider(symbol));
      ref.invalidate(orderBookSnapshotProvider(symbol));
      ref.invalidate(tradeStreamProvider(symbol));
      ref.invalidate(accountTradeStreamProvider(symbol));
      ref.invalidate(connectionStatusProvider(symbol));

      final engine = await ref.read(tradingEngineProvider(symbol).future);
      await engine.refreshStrategyPlan();
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        _showError('Trading controls were not applied safely: $error');
      }
      return false;
    }

    if (!mounted) {
      return true;
    }
    setState(() {
      _isSaving = false;
    });
    showAppToast(
      context,
      wasRunning
          ? 'Trading controls updated. Auto execution is disarmed; review and arm it again.'
          : 'Trading controls updated on the dashboard.',
      backgroundColor: AppColors.positive.withValues(alpha: 0.95),
      foregroundColor: Colors.white,
      icon: Icons.tune,
    );
    return true;
  }

  Future<void> _startTrading() async {
    if (_hasUnsavedChanges) {
      final applied = await _applyTradingControls();
      if (!mounted || !applied) {
        return;
      }
    }
    final symbol = ref.read(selectedSymbolProvider);
    try {
      final engine = await ref.read(tradingEngineProvider(symbol).future);
      await engine.enableTrading();
      await engine.refreshStrategyPlan();
      ref.read(isBotRunningProvider(symbol).notifier).state = true;
    } catch (error) {
      ref.read(isBotRunningProvider(symbol).notifier).state = false;
      _showError('Auto execution could not start safely: $error');
    }
  }

  Future<void> _stopTrading() async {
    final symbol = ref.read(selectedSymbolProvider);
    final engine = await ref.read(tradingEngineProvider(symbol).future);
    ref.read(isBotRunningProvider(symbol).notifier).state = false;
    try {
      await engine.disarmTrading();
    } catch (error) {
      _showError(
        'Stopped auto execution, but entry cancellation needs attention: $error',
      );
    }
  }

  Future<void> _applyFiveDollarGuard() async {
    setState(() {
      _targetProfitUsdtController.text = '5';
      _maxLossUsdtController.text = '5';
      final currentBudget = _parseDouble(_tradeQuantityController.text) ?? 0;
      if (!currentBudget.isFinite || currentBudget < 10) {
        _tradeQuantityController.text = '10';
      }
    });
    await _applyTradingControls();
  }

  void _showError(String message) {
    showAppToast(
      context,
      message,
      backgroundColor: AppColors.negative.withValues(alpha: 0.95),
      foregroundColor: Colors.white,
      icon: Icons.error_outline,
    );
  }

  @override
  Widget build(BuildContext context) {
    final symbol = ref.watch(selectedSymbolProvider);
    final riskAsync = ref.watch(riskSettingsProvider);
    final protectionAsync = ref.watch(protectionStatusProvider(symbol));
    final connectionAsync = ref.watch(connectionStatusProvider(symbol));
    final planAsync = ref.watch(decisionPlanStreamProvider(symbol));
    final positionAsync = ref.watch(positionStreamProvider(symbol));
    final openOrdersAsync = ref.watch(openOrderStreamProvider(symbol));
    final engineAsync = ref.watch(tradingEngineProvider(symbol));
    final strategy = ref.watch(currentStrategyProvider);
    final isRunning = ref.watch(isBotRunningProvider(symbol));

    final protection = protectionAsync.maybeWhen(
      data: (value) => value,
      orElse: () => const ProtectionStatus.ready(),
    );
    final plan = planAsync.valueOrNull;
    final position = positionAsync.valueOrNull;
    final openOrders = openOrdersAsync.valueOrNull ?? const [];
    final connection = connectionAsync.valueOrNull;
    final currentRisk = riskAsync.valueOrNull;

    if (!_hasUnsavedChanges && currentRisk != null && !_isLoading) {
      final latestKey = [
        currentRisk.stopLossPercent,
        currentRisk.takeProfitPercent,
        currentRisk.investmentUsdt ?? currentRisk.tradeQuantity,
        currentRisk.targetProfitUsdt ?? '',
        currentRisk.maxLossUsdt ?? '',
        currentRisk.leverage,
        currentRisk.cooldownMinutes,
        currentRisk.protectionPauseMinutes,
        currentRisk.maxConsecutiveLosses,
        currentRisk.maxDrawdownPercent,
      ].join('|');
      final savedKey = [
        _savedStopLoss,
        _savedTakeProfit,
        _savedTradeQuantity,
        _savedTargetProfitUsdt,
        _savedMaxLossUsdt,
        _savedLeverage,
        _savedCooldownMinutes,
        _savedProtectionPauseMinutes,
        _savedMaxConsecutiveLosses,
        _savedMaxDrawdown,
      ].join('|');
      if (latestKey != savedKey) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_hasUnsavedChanges) {
            setState(() {
              _setSavedValues(currentRisk);
            });
          }
        });
      }
    }

    if (_isLoading && currentRisk == null) {
      return const AppPanel(
        child: SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final tradingState = _resolveTradingState(
      isRunning: isRunning,
      strategy: strategy,
      protection: protection,
      plan: plan,
      position: position,
      engineReady: engineAsync is AsyncData,
    );
    final marketPrice = plan?.currentPrice ?? position?.entryPrice;
    final deskQuantity =
        currentRisk?.resolveQuantity(marketPrice) ?? currentRisk?.tradeQuantity;
    final deskNotional = currentRisk?.resolveNotional(marketPrice);
    final deskMargin = currentRisk?.resolveEstimatedMargin(marketPrice);
    final positionExposure = position == null
        ? null
        : position.entryPrice * position.quantity;
    final positionMargin =
        positionExposure == null ||
            currentRisk == null ||
            currentRisk.leverage <= 0
        ? null
        : positionExposure / currentRisk.leverage;
    final activeTakeProfit = _resolveLiveTakeProfit(
      position: position,
      plan: plan,
      risk: currentRisk,
    );
    final activeStopLoss = _resolveLiveStopLoss(
      position: position,
      plan: plan,
      risk: currentRisk,
    );
    final activeEngine = engineAsync.valueOrNull;
    final hasConfirmedOwnedStop =
        position != null &&
        activeEngine != null &&
        openOrders.any(
          (order) =>
              order.symbol.toUpperCase() == position.symbol.toUpperCase() &&
              order.type.toUpperCase() == 'STOP_MARKET' &&
              order.isOwnedBy(activeEngine.clientOrderOwnerId) &&
              order.side.toUpperCase() == (position.isLong ? 'SELL' : 'BUY') &&
              (order.closePosition || order.reduceOnly),
        );

    return AppPanel(
      accent: tradingState.color,
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
                  Icon(Icons.tune, color: AppColors.glowAmber, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Trading Desk',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              StatusPill(label: tradingState.label, color: tradingState.color),
              StatusPill(
                label: _protectionLabel(protection),
                color: _protectionColor(protection.state),
              ),
              StatusPill(
                label: _marketLabel(connection),
                color: _marketColor(connection?.state),
              ),
              if (plan != null)
                StatusPill(
                  label: plan.summaryLabel,
                  color: _signalColor(plan.signal),
                ),
              if (plan != null)
                StatusPill(
                  label: 'Execution: ${plan.orderTypeLabel}',
                  color: _executionTypeColor(plan.orderTypeLabel),
                ),
              if (position != null)
                StatusPill(
                  label: hasConfirmedOwnedStop
                      ? 'EXCHANGE STOP CONFIRMED'
                      : 'NO CONFIRMED EXCHANGE STOP',
                  color: hasConfirmedOwnedStop
                      ? AppColors.positive
                      : AppColors.negative,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Start or stop automation here, and keep the desk-side risk rules here too. This keeps sizing, exits, and protection logic close to the live chart instead of buried in Settings.',
            style: const TextStyle(
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
              FilledButton.icon(
                onPressed:
                    strategy is ManualStrategy ||
                        isRunning ||
                        engineAsync.isLoading
                    ? null
                    : _startTrading,
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  strategy is ManualStrategy ? 'MANUAL MODE' : 'START AUTO',
                ),
              ),
              OutlinedButton.icon(
                onPressed: !isRunning || engineAsync.isLoading
                    ? null
                    : _stopTrading,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('STOP AUTO'),
              ),
              FilledButton.icon(
                onPressed: _isSaving ? null : _applyTradingControls,
                icon: Icon(_isSaving ? Icons.hourglass_top : Icons.save),
                label: Text(_isSaving ? 'APPLYING...' : 'SAVE CONTROLS'),
              ),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _applyFiveDollarGuard,
                icon: const Icon(Icons.shield_outlined),
                label: const Text(r'USE EST. $5 TP / $5 SL'),
              ),
              if (position != null)
                Text(
                  'Live ${position.isLong ? 'LONG' : 'SHORT'} ${_formatQuantity(position.quantity)} @ ${_formatPrice(position.entryPrice)}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (plan != null)
                Text(
                  'Next execution uses ${plan.orderTypeLabel.toUpperCase()}',
                  style: TextStyle(
                    color: _executionTypeColor(plan.orderTypeLabel),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (openOrders.isNotEmpty)
                Text(
                  '${openOrders.length} Binance working order${openOrders.length == 1 ? '' : 's'} active',
                  style: const TextStyle(
                    color: AppColors.glowCyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _DeskStat(
                  label: 'Budget',
                  value: _formatUsdt(currentRisk?.investmentUsdt),
                  helper: 'Margin budget per entry',
                  color: AppColors.glowCyan,
                ),
                _DeskStat(
                  label: 'Approx Qty',
                  value: _formatQuantity(deskQuantity),
                  helper: marketPrice == null
                      ? 'Waiting for live price'
                      : 'Converted at ${_formatPrice(marketPrice)}',
                  color: AppColors.textPrimary,
                ),
                _DeskStat(
                  label: 'Approx Notional',
                  value: _formatUsdt(deskNotional),
                  helper: 'Budget x leverage',
                  color: AppColors.glowAmber,
                ),
                _DeskStat(
                  label: 'Profit Guard',
                  value: _formatUsdt(
                    currentRisk?.resolveEstimatedTakeProfitUsdt(
                      marketPrice,
                      deskQuantity,
                    ),
                  ),
                  helper: currentRisk?.hasAbsoluteTakeProfit == true
                      ? 'Estimated gross PnL target'
                      : 'Derived from percentage',
                  color: AppColors.positive,
                ),
                _DeskStat(
                  label: 'Loss Guard',
                  value: _formatUsdt(
                    currentRisk?.resolveEstimatedMaxLossUsdt(
                      marketPrice,
                      deskQuantity,
                    ),
                  ),
                  helper: currentRisk?.hasAbsoluteStopLoss == true
                      ? 'Estimated gross max loss'
                      : 'Derived from percentage',
                  color: AppColors.negative,
                ),
                _DeskStat(
                  label: 'Est. Margin Use',
                  value: _formatUsdt(deskMargin),
                  helper: 'Approx margin per trade',
                  color: AppColors.positive,
                ),
                _DeskStat(
                  label: 'Configured TP Estimate',
                  value: _formatPrice(activeTakeProfit),
                  helper: position == null
                      ? 'No open position'
                      : 'Calculated target; verify working orders',
                  color: AppColors.positive,
                ),
                _DeskStat(
                  label: 'Configured SL Estimate',
                  value: _formatPrice(activeStopLoss),
                  helper: position == null
                      ? 'No open position'
                      : hasConfirmedOwnedStop
                      ? 'Matching exchange stop is confirmed'
                      : 'Estimate only; no matching stop confirmed',
                  color: AppColors.negative,
                ),
                _DeskStat(
                  label: 'Current Invested',
                  value: _formatUsdt(positionExposure),
                  helper: position == null
                      ? 'No open position'
                      : 'Entry x live qty',
                  color: AppColors.glowAmber,
                ),
                _DeskStat(
                  label: 'Current Margin',
                  value: _formatUsdt(positionMargin),
                  helper: position == null
                      ? 'No margin in use'
                      : '${currentRisk?.leverage ?? 1}x leverage estimate',
                  color: AppColors.glowCyan,
                ),
              ],
            ),
          ),
          if (strategy is ManualStrategy) ...[
            const SizedBox(height: 10),
            const Text(
              'Manual mode does not auto-buy or auto-sell. Use the manual ticket below to send the order yourself, or switch to AI/ALGO before pressing START AUTO.',
              style: TextStyle(
                color: AppColors.glowAmber,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          if (plan != null && plan.signal == TradingSignal.hold) ...[
            const SizedBox(height: 10),
            Text(
              'Why waiting: ${plan.rationale}',
              style: const TextStyle(
                color: AppColors.glowAmber,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          if (openOrders.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Live Binance Orders',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final order in openOrders.take(4))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              order.summary,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            'Qty ${_formatQuantity(order.quantity)}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 980
                  ? 4
                  : constraints.maxWidth >= 620
                  ? 2
                  : 1;
              final spacing = columns == 1 ? 0.0 : 12.0;
              final fieldWidth =
                  (constraints.maxWidth - (spacing * (columns - 1))) / columns;

              final fields = [
                _DeskField(
                  label: 'Stop Loss (%)',
                  controller: _stopLossController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  helper: 'Auto exit floor',
                ),
                _DeskField(
                  label: 'Take Profit (%)',
                  controller: _takeProfitController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  helper: 'Auto exit target',
                ),
                _DeskField(
                  label: 'Target Profit (USDT, est.)',
                  controller: _targetProfitUsdtController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  helper: 'Overrides TP % when filled; blank uses percent',
                ),
                _DeskField(
                  label: 'Max Loss (USDT, est.)',
                  controller: _maxLossUsdtController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  helper: 'Overrides SL %; fees/slippage can differ',
                ),
                _DeskField(
                  label: 'Investment (USDT)',
                  controller: _tradeQuantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  helper: 'Margin budget; quantity is converted automatically',
                ),
                _DeskField(
                  label: 'Leverage (x)',
                  controller: _leverageController,
                  keyboardType: TextInputType.number,
                  helper: 'Desk leverage cap',
                ),
              ];

              return Wrap(
                spacing: spacing,
                runSpacing: 12,
                children: [
                  for (final field in fields)
                    SizedBox(width: fieldWidth, child: field),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              setState(() {
                _showProtectionFields = !_showProtectionFields;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    color: AppColors.glowAmber,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Protection Rules',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _showProtectionFields ? 'Hide' : 'Show',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _showProtectionFields
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_showProtectionFields) ...[
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 980
                    ? 4
                    : constraints.maxWidth >= 620
                    ? 2
                    : 1;
                final spacing = columns == 1 ? 0.0 : 12.0;
                final fieldWidth =
                    (constraints.maxWidth - (spacing * (columns - 1))) /
                    columns;

                final fields = [
                  _DeskField(
                    label: 'Cooldown (min)',
                    controller: _cooldownMinutesController,
                    keyboardType: TextInputType.number,
                    helper: 'Pause after any exit',
                  ),
                  _DeskField(
                    label: 'Protection Pause (min)',
                    controller: _protectionPauseMinutesController,
                    keyboardType: TextInputType.number,
                    helper: 'Lock window',
                  ),
                  _DeskField(
                    label: 'Max Losses',
                    controller: _maxConsecutiveLossesController,
                    keyboardType: TextInputType.number,
                    helper: '0 disables',
                  ),
                  _DeskField(
                    label: 'Max Drawdown (%)',
                    controller: _maxDrawdownController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    helper: '0 disables',
                  ),
                ];

                return Wrap(
                  spacing: spacing,
                  runSpacing: 12,
                  children: [
                    for (final field in fields)
                      SizedBox(width: fieldWidth, child: field),
                  ],
                );
              },
            ),
          ],
          if (_hasUnsavedChanges) ...[
            const SizedBox(height: 12),
            const Text(
              'Desk controls changed. Save Controls to apply the new risk rules to the live engine.',
              style: TextStyle(color: AppColors.glowAmber, fontSize: 12),
            ),
          ],
          if ((protection.message ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              protection.message!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _protectionLabel(ProtectionStatus status) {
    return switch (status.state) {
      ProtectionState.ready => 'Protection: Clear',
      ProtectionState.cooldown => 'Protection: Cooldown',
      ProtectionState.locked => 'Protection: Locked',
    };
  }

  static Color _protectionColor(ProtectionState state) {
    return switch (state) {
      ProtectionState.ready => AppColors.positive,
      ProtectionState.cooldown => AppColors.glowAmber,
      ProtectionState.locked => AppColors.warning,
    };
  }

  static Color _signalColor(TradingSignal signal) {
    return switch (signal) {
      TradingSignal.buy => AppColors.positive,
      TradingSignal.sell => AppColors.negative,
      TradingSignal.hold => AppColors.glowCyan,
    };
  }

  static Color _executionTypeColor(String label) {
    switch (label.toLowerCase()) {
      case 'market':
        return AppColors.negative;
      case 'limit':
        return AppColors.glowCyan;
      case 'post only':
        return AppColors.positive;
      case 'scaled':
        return AppColors.glowAmber;
      default:
        return AppColors.textSecondary;
    }
  }

  static String _marketLabel(ConnectionStatus? status) {
    if (status == null) {
      return 'Market: Checking';
    }
    return switch (status.state) {
      MarketConnectionState.connected =>
        'Market: Live ${status.latencyMs == null ? '' : '| ${status.latencyMs}ms'}'
            .trim(),
      MarketConnectionState.stale =>
        'Market: Slow ${status.lastMessageAt == null ? '' : '| ${DateTime.now().difference(status.lastMessageAt!).inSeconds}s'}'
            .trim(),
      MarketConnectionState.reconnecting => 'Market: Reconnecting',
      MarketConnectionState.connecting => 'Market: Connecting',
      MarketConnectionState.disconnected => 'Market: Offline',
    };
  }

  static Color _marketColor(MarketConnectionState? state) {
    return switch (state) {
      MarketConnectionState.connected => AppColors.glowCyan,
      MarketConnectionState.stale => AppColors.warning,
      MarketConnectionState.reconnecting => AppColors.warning,
      MarketConnectionState.connecting => AppColors.glowAmber,
      MarketConnectionState.disconnected => AppColors.negative,
      null => AppColors.glowAmber,
    };
  }

  static _TradingState _resolveTradingState({
    required bool isRunning,
    required TradingStrategy? strategy,
    required ProtectionStatus protection,
    required StrategyTradePlan? plan,
    required dynamic position,
    required bool engineReady,
  }) {
    if (strategy is ManualStrategy) {
      return const _TradingState('Trading: Manual Desk', AppColors.glowAmber);
    }
    if (!engineReady) {
      return const _TradingState('Trading: Loading', AppColors.glowAmber);
    }
    if (!isRunning) {
      return const _TradingState('Trading: Stopped', AppColors.negative);
    }
    if (protection.state == ProtectionState.locked) {
      return const _TradingState('Trading: Protected', AppColors.warning);
    }
    if (protection.state == ProtectionState.cooldown) {
      return const _TradingState('Trading: Cooldown', AppColors.glowAmber);
    }
    if (position != null) {
      return _TradingState(
        'Trading: In ${position.isLong ? 'Long' : 'Short'}',
        AppColors.positive,
      );
    }
    if (plan == null || plan.signal == TradingSignal.hold) {
      return const _TradingState('Trading: Waiting', AppColors.glowCyan);
    }
    return _TradingState(
      'Trading: Ready ${plan.signal == TradingSignal.buy ? 'Long' : 'Short'}',
      plan.signal == TradingSignal.buy
          ? AppColors.positive
          : AppColors.negative,
    );
  }

  static String _formatPrice(double? value) {
    if (value == null || value <= 0) {
      return '--';
    }
    return value.toStringAsFixed(value >= 100 ? 2 : 6);
  }

  static String _formatUsdt(double? value) {
    if (value == null || value <= 0) {
      return '--';
    }
    final digits = value >= 100
        ? 2
        : value >= 1
        ? 3
        : 6;
    return '${value.toStringAsFixed(digits)} USDT';
  }

  static String _formatQuantity(double? value) {
    if (value == null || value <= 0) {
      return '--';
    }
    if (value >= 1000) {
      return value.toStringAsFixed(2);
    }
    if (value >= 1) {
      return value.toStringAsFixed(4);
    }
    return value.toStringAsFixed(6);
  }

  static double? _resolveLiveTakeProfit({
    required dynamic position,
    required StrategyTradePlan? plan,
    required RiskSettings? risk,
  }) {
    if (position == null) {
      return null;
    }
    final planMatchesSide =
        plan != null &&
        plan.isActionable &&
        ((position.isLong && plan.signal == TradingSignal.buy) ||
            (!position.isLong && plan.signal == TradingSignal.sell));
    if (risk != null &&
        (risk.hasTakeProfit ||
            (planMatchesSide && plan.takeProfitPercent > 0))) {
      final percent = risk.resolveTakeProfitPercent(
        position.entryPrice,
        quantity: position.quantity,
        fallbackPercent: planMatchesSide ? plan.takeProfitPercent : null,
      );
      return percent > 0 ? position.takeProfitPrice(percent) : null;
    }
    return null;
  }

  static double? _resolveLiveStopLoss({
    required dynamic position,
    required StrategyTradePlan? plan,
    required RiskSettings? risk,
  }) {
    if (position == null) {
      return null;
    }
    final planMatchesSide =
        plan != null &&
        plan.isActionable &&
        ((position.isLong && plan.signal == TradingSignal.buy) ||
            (!position.isLong && plan.signal == TradingSignal.sell));
    if (risk != null &&
        (risk.hasStopLoss || (planMatchesSide && plan.stopLossPercent > 0))) {
      final percent = risk.resolveStopLossPercent(
        position.entryPrice,
        quantity: position.quantity,
        fallbackPercent: planMatchesSide ? plan.stopLossPercent : null,
      );
      return percent > 0 ? position.stopLossPrice(percent) : null;
    }
    return null;
  }
}

class _DeskField extends StatelessWidget {
  final String label;
  final String helper;
  final TextEditingController controller;
  final TextInputType keyboardType;

  const _DeskField({
    required this.label,
    required this.helper,
    required this.controller,
    required this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(labelText: label),
        ),
        const SizedBox(height: 4),
        Text(
          helper,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
        ),
      ],
    );
  }
}

class _DeskStat extends StatelessWidget {
  final String label;
  final String value;
  final String helper;
  final Color color;

  const _DeskStat({
    required this.label,
    required this.value,
    required this.helper,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            helper,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _TradingState {
  final String label;
  final Color color;

  const _TradingState(this.label, this.color);
}
