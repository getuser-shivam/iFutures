import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/binance_account_status.dart';
import '../../models/manual_order.dart';
import '../../providers/trading_provider.dart';
import '../../theme/app_theme.dart';
import '../common/app_panel.dart';
import '../common/app_toast.dart';
import '../common/status_pill.dart';

class OneClickTradeCard extends ConsumerStatefulWidget {
  final String symbol;

  const OneClickTradeCard({super.key, required this.symbol});

  @override
  ConsumerState<OneClickTradeCard> createState() => _OneClickTradeCardState();
}

class _OneClickTradeCardState extends ConsumerState<OneClickTradeCard> {
  bool _armed = false;
  bool _isSubmitting = false;
  ManualOrderType _entryType = ManualOrderType.postOnly;
  Timer? _armTimer;

  @override
  void dispose() {
    _armTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OneClickTradeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol) {
      _armTimer?.cancel();
      _armed = false;
      _isSubmitting = false;
    }
  }

  void _setArmed(bool value) {
    _armTimer?.cancel();
    setState(() {
      _armed = value;
    });
    if (value) {
      _armTimer = Timer(const Duration(seconds: 30), () {
        if (mounted) {
          setState(() {
            _armed = false;
          });
        }
      });
    }
  }

  Future<void> _applyFiveDollarGuard() async {
    final position = ref
        .read(positionStreamProvider(widget.symbol))
        .valueOrNull;
    if (position != null) {
      _toast(
        'Close the current position before changing its global TP/SL guard.',
        accepted: false,
      );
      return;
    }
    try {
      final disarm = await ref
          .read(tradingRuntimeSafetyProvider)
          .disarmBeforeRuntimeChange(
            symbol: widget.symbol,
            reason: 'risk_preset_changed',
          );
      if (!disarm.canProceed) {
        throw disarm.error ?? 'unknown order-reconciliation failure';
      }
      ref.read(isBotRunningProvider(widget.symbol).notifier).state = false;

      final settings = ref.read(settingsServiceProvider);
      await settings.init();
      final currentBudget = settings.getRiskInvestmentUsdt() ?? 0;
      final safeBudget = currentBudget < 10 ? 10.0 : currentBudget;
      await settings.setRiskInvestmentUsdt(safeBudget);
      await settings.setRiskTradeQuantity(safeBudget);
      await settings.setRiskTargetProfitUsdt(5);
      await settings.setRiskMaxLossUsdt(5);

      final currentMode = ref.read(currentStrategyModeProvider);
      ref.invalidate(riskSettingsProvider);
      ref.invalidate(aiStrategyProvider(widget.symbol));
      await ref
          .read(currentStrategyProvider.notifier)
          .setMode(currentMode, symbol: widget.symbol, persist: false);
      ref.invalidate(tradingEngineProvider(widget.symbol));
      ref.invalidate(symbolRulesProvider(widget.symbol));
    } catch (error) {
      if (!mounted) return;
      _toast('The preset was not applied safely: $error', accepted: false);
      return;
    }
    if (!mounted) return;
    _setArmed(false);
    _toast(
      r'Estimated $5 take-profit / $5 max-loss guard applied with at least a $10 margin budget. Fees, funding, tick rounding, and slippage can change realized PnL.',
      accepted: true,
    );
  }

  Future<void> _submit(
    ManualOrderAction action, {
    required ManualOrderRoutingExpectation routingExpectation,
  }) async {
    if (!_armed || _isSubmitting) return;
    setState(() {
      _isSubmitting = true;
    });
    try {
      final engineAsync = ref.read(tradingEngineProvider(widget.symbol));
      if (engineAsync is! AsyncData) {
        _toast('Trading engine is still loading.', accepted: false);
        return;
      }
      final engine = engineAsync.requireValue;
      final risk = await ref.read(riskSettingsProvider.future);
      final ticker = ref.read(tickerStreamProvider(widget.symbol)).valueOrNull;
      final livePrice = double.tryParse('${ticker?['c'] ?? ''}');
      final quantity = risk.resolveQuantity(livePrice);
      if (livePrice == null ||
          livePrice <= 0 ||
          quantity == null ||
          quantity <= 0) {
        _toast(
          'A live price and valid risk budget are required before one-click entry.',
          accepted: false,
        );
        return;
      }

      double? price;
      if (_entryType == ManualOrderType.postOnly) {
        final book = await engine.refreshOrderBook();
        final isFresh =
            book != null &&
            DateTime.now().difference(book.capturedAt) <=
                const Duration(seconds: 3);
        price = action == ManualOrderAction.openLong
            ? book?.bestBid
            : book?.bestAsk;
        if (!isFresh || price == null || price <= 0) {
          _toast(
            'Smart Maker is waiting for a fresh best bid/ask. It will not silently fall back to a market order.',
            accepted: false,
          );
          return;
        }
      }

      final result = await engine.submitManualOrder(
        ManualOrderRequest(
          action: action,
          orderType: _entryType,
          quantity: quantity,
          price: price,
          routingExpectation: routingExpectation,
        ),
      );
      if (result.accepted && engine.isManualOverrideActive) {
        ref.read(isBotRunningProvider(widget.symbol).notifier).state = false;
      }
      _toast(result.message, accepted: result.accepted);
    } finally {
      _setArmed(false);
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _toast(String message, {required bool accepted}) {
    if (!mounted) return;
    showAppToast(
      context,
      message,
      backgroundColor: (accepted ? AppColors.positive : AppColors.negative)
          .withValues(alpha: 0.96),
      foregroundColor: Colors.white,
      icon: accepted ? Icons.check_circle_outline : Icons.error_outline,
      duration: const Duration(seconds: 5),
    );
  }

  @override
  Widget build(BuildContext context) {
    final risk = ref.watch(riskSettingsProvider).valueOrNull;
    final rulesAsync = ref.watch(symbolRulesProvider(widget.symbol));
    final accountAsync = ref.watch(binanceAccountStatusProvider(widget.symbol));
    final account = accountAsync.valueOrNull;
    final engine = ref.watch(tradingEngineProvider(widget.symbol)).valueOrNull;
    final ticker = ref.watch(tickerStreamProvider(widget.symbol)).valueOrNull;
    final livePrice = double.tryParse('${ticker?['c'] ?? ''}');
    final quantity = risk?.resolveQuantity(livePrice);
    final target = risk?.resolveEstimatedTakeProfitUsdt(livePrice, quantity);
    final loss = risk?.resolveEstimatedMaxLossUsdt(livePrice, quantity);
    final stopDistancePercent =
        risk != null &&
            livePrice != null &&
            livePrice > 0 &&
            quantity != null &&
            quantity > 0
        ? risk.resolveStopLossPercent(livePrice, quantity: quantity)
        : null;
    final conservativeStopLimit = risk == null || risk.leverage <= 0
        ? null
        : 80 / risk.leverage;
    final riskGuardReady =
        stopDistancePercent != null &&
        stopDistancePercent > 0 &&
        conservativeStopLimit != null &&
        stopDistancePercent < conservativeStopLimit;
    final isRealMoney =
        account?.state == BinanceAccountState.active &&
        account?.isTestnet == false;
    final isDemo =
        account?.state == BinanceAccountState.active &&
        account?.isTestnet == true;
    final exchangeConfigured = engine?.hasExchangeCredentials == true;
    final exchangeRoutingActive =
        account?.state == BinanceAccountState.active && exchangeConfigured;
    final exchangeRoutingBlocked = exchangeConfigured && !exchangeRoutingActive;
    final routingExpectation = exchangeRoutingActive
        ? isDemo
              ? ManualOrderRoutingExpectation.binanceDemo
              : ManualOrderRoutingExpectation.binanceLive
        : ManualOrderRoutingExpectation.paper;
    final browserLiveBlocked = kIsWeb && isRealMoney;
    final rules = rulesAsync.valueOrNull;
    final symbolReady = rules?.isTradablePerpetual == true;
    final canSubmit =
        _armed &&
        !_isSubmitting &&
        symbolReady &&
        !browserLiveBlocked &&
        !exchangeRoutingBlocked &&
        riskGuardReady;

    return AppPanel(
      accent: isRealMoney ? AppColors.negative : AppColors.glowCyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'One-Click Guarded Entry',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              StatusPill(
                label: isRealMoney
                    ? 'REAL MONEY'
                    : isDemo
                    ? 'BINANCE DEMO'
                    : exchangeRoutingBlocked
                    ? 'BINANCE CHECKING'
                    : 'PAPER / MONITOR',
                color: isRealMoney
                    ? AppColors.negative
                    : isDemo || exchangeRoutingBlocked
                    ? AppColors.glowAmber
                    : AppColors.glowCyan,
              ),
              StatusPill(
                label: rulesAsync.isLoading
                    ? '${widget.symbol}: CHECKING'
                    : symbolReady
                    ? '${widget.symbol}: TRADING'
                    : '${widget.symbol}: BLOCKED',
                color: symbolReady ? AppColors.positive : AppColors.negative,
              ),
              StatusPill(
                label: _armed ? 'ARMED: 30s' : 'DISARMED',
                color: _armed ? AppColors.negative : AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            browserLiveBlocked
                ? 'Public web safety mode blocks real-money order mutations. Use the desktop app or Binance demo.'
                : exchangeRoutingBlocked
                ? 'Binance credentials are configured, but Futures routing is not active yet. Entry is disabled so a control labeled PAPER can never turn into a live order during account sync.'
                : 'Arm once, then choose LONG or SHORT. Smart Maker posts at the best book price to avoid taker execution; it may not fill. Keep the desktop app open until any working entry fills or is cancelled and protection is confirmed. No strategy can guarantee profit.',
            style: TextStyle(
              color: browserLiveBlocked
                  ? AppColors.negative
                  : AppColors.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('SMART MAKER (POST-ONLY)'),
                selected: _entryType == ManualOrderType.postOnly,
                onSelected: (_) {
                  setState(() {
                    _entryType = ManualOrderType.postOnly;
                  });
                  _setArmed(false);
                },
              ),
              ChoiceChip(
                label: const Text('MARKET (TAKER)'),
                selected: _entryType == ManualOrderType.market,
                onSelected: (_) {
                  setState(() {
                    _entryType = ManualOrderType.market;
                  });
                  _setArmed(false);
                },
              ),
              OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _applyFiveDollarGuard,
                icon: const Icon(Icons.shield_outlined),
                label: const Text(r'EST. $5 TP / $5 SL'),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: _armed,
                    onChanged:
                        symbolReady &&
                            !browserLiveBlocked &&
                            riskGuardReady &&
                            !exchangeRoutingBlocked
                        ? _setArmed
                        : null,
                  ),
                  Text(
                    isRealMoney ? 'ARM REAL MONEY' : 'ARM ONE-CLICK',
                    style: TextStyle(
                      color: isRealMoney
                          ? AppColors.negative
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _GuardMetric(
                label: 'Margin',
                value: _formatUsdt(risk?.investmentUsdt),
                color: AppColors.glowCyan,
              ),
              _GuardMetric(
                label: 'Leverage',
                value: '${risk?.leverage ?? 1}x',
                color: AppColors.glowAmber,
              ),
              _GuardMetric(
                label: 'Quantity',
                value: _formatQuantity(quantity),
                color: AppColors.textPrimary,
              ),
              _GuardMetric(
                label: 'TP (gross est.)',
                value: target == null ? 'OFF' : '+${_formatUsdt(target)}',
                color: AppColors.positive,
              ),
              _GuardMetric(
                label: 'SL (gross est.)',
                value: loss == null ? 'OFF' : '-${_formatUsdt(loss)}',
                color: AppColors.negative,
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 560;
              Widget entryButton({
                required ManualOrderAction action,
                required Color color,
                required IconData icon,
                required String label,
              }) {
                return FilledButton.icon(
                  onPressed: canSubmit
                      ? () => _submit(
                          action,
                          routingExpectation: routingExpectation,
                        )
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                  ),
                  icon: Icon(icon),
                  label: Text(_isSubmitting ? 'SENDING...' : label),
                );
              }

              final longButton = entryButton(
                action: ManualOrderAction.openLong,
                color: AppColors.positive,
                icon: Icons.trending_up,
                label: 'ONE-CLICK LONG',
              );
              final shortButton = entryButton(
                action: ManualOrderAction.openShort,
                color: AppColors.negative,
                icon: Icons.trending_down,
                label: 'ONE-CLICK SHORT',
              );
              if (narrow) {
                return Column(
                  children: [
                    SizedBox(width: double.infinity, child: longButton),
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: shortButton),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: longButton),
                  const SizedBox(width: 12),
                  Expanded(child: shortButton),
                ],
              );
            },
          ),
          if (risk?.hasStopLoss != true) ...[
            const SizedBox(height: 10),
            const Text(
              'One-click is disabled until a stop-loss guard is configured.',
              style: TextStyle(color: AppColors.negative, fontSize: 12),
            ),
          ] else if (!riskGuardReady) ...[
            const SizedBox(height: 10),
            const Text(
              r'One-click is disabled because the configured loss guard is too near the estimated liquidation zone. Increase margin, lower max loss, or reduce leverage.',
              style: TextStyle(color: AppColors.negative, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatUsdt(double? value) {
    if (value == null || value <= 0) return '--';
    return '${value.toStringAsFixed(value >= 100 ? 2 : 3)} USDT';
  }

  static String _formatQuantity(double? value) {
    if (value == null || value <= 0) return '--';
    if (value >= 1) return value.toStringAsFixed(2);
    return value.toStringAsFixed(6);
  }
}

class _GuardMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _GuardMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
