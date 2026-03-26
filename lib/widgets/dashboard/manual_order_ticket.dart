import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/manual_order.dart';
import '../../models/rsi_strategy_preset.dart';
import '../../providers/trading_provider.dart';
import '../../theme/app_theme.dart';
import '../../trading/algo_strategy.dart';
import '../../trading/manual_strategy.dart';
import '../../trading/strategy.dart';
import '../common/action_button.dart';
import '../common/app_panel.dart';
import '../common/app_toast.dart';
import '../common/status_pill.dart';

class ManualOrderTicket extends ConsumerStatefulWidget {
  final String symbol;

  const ManualOrderTicket({super.key, required this.symbol});

  @override
  ConsumerState<ManualOrderTicket> createState() => _ManualOrderTicketState();
}

class _ManualOrderTicketState extends ConsumerState<ManualOrderTicket> {
  late TextEditingController _priceController;
  late TextEditingController _scaleEndController;
  late TextEditingController _scaleStepsController;

  ManualOrderAction _selectedAction = ManualOrderAction.openLong;
  ManualOrderType _selectedOrderType = ManualOrderType.market;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController();
    _scaleEndController = TextEditingController();
    _scaleStepsController = TextEditingController(text: '3');
  }

  @override
  void dispose() {
    _priceController.dispose();
    _scaleEndController.dispose();
    _scaleStepsController.dispose();
    super.dispose();
  }

  double? _parseDouble(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  int? _parseInt(String value) {
    return int.tryParse(value.trim());
  }

  Future<void> _submitOrder() async {
    final engineAsync = ref.read(tradingEngineProvider(widget.symbol));
    if (engineAsync is! AsyncData) {
      if (!mounted) return;
      showAppToast(
        context,
        'Trading engine is still loading.',
        backgroundColor: AppColors.warning.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.hourglass_bottom_outlined,
      );
      return;
    }

    final engine = engineAsync.requireValue;
    final riskSettings = await ref.read(riskSettingsProvider.future);
    final position = ref
        .read(positionStreamProvider(widget.symbol))
        .valueOrNull;
    final quantity =
        _selectedAction.isCloseAction &&
            position != null &&
            position.side == _selectedAction.positionSide
        ? position.quantity
        : riskSettings.tradeQuantity;

    final request = ManualOrderRequest(
      action: _selectedAction,
      orderType: _selectedOrderType,
      quantity: quantity,
      price: switch (_selectedOrderType) {
        ManualOrderType.market => null,
        _ => _parseDouble(_priceController.text),
      },
      scaleEndPrice: _selectedOrderType == ManualOrderType.scaled
          ? _parseDouble(_scaleEndController.text)
          : null,
      scaleSteps: _selectedOrderType == ManualOrderType.scaled
          ? (_parseInt(_scaleStepsController.text) ?? 0)
          : 1,
    );

    final result = await engine.submitManualOrder(request);
    if (!mounted) return;

    if (result.accepted && engine.isManualOverrideActive) {
      ref.read(isBotRunningProvider(widget.symbol).notifier).state = false;
    }

    showAppToast(
      context,
      result.message,
      backgroundColor: result.accepted
          ? AppColors.glowCyan.withValues(alpha: 0.95)
          : AppColors.negative.withValues(alpha: 0.95),
      foregroundColor: Colors.white,
      icon: result.accepted ? Icons.check_circle_outline : Icons.error_outline,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = ref.watch(isBotRunningProvider(widget.symbol));
    final engineAsync = ref.watch(tradingEngineProvider(widget.symbol));
    final engine = engineAsync.valueOrNull;
    final currentStrategy = ref.watch(currentStrategyProvider);
    final signalAsync = ref.watch(signalStreamProvider(widget.symbol));
    final riskAsync = ref.watch(riskSettingsProvider);
    final positionAsync = ref.watch(positionStreamProvider(widget.symbol));
    final pendingOrdersAsync = ref.watch(
      pendingManualOrderStreamProvider(widget.symbol),
    );

    final risk = riskAsync.valueOrNull;
    final position = positionAsync.valueOrNull;
    final pendingOrders = pendingOrdersAsync.maybeWhen(
      data: (orders) => orders,
      orElse: () => const <PendingManualOrder>[],
    );
    final ticketQuantity =
        _selectedAction.isCloseAction &&
            position != null &&
            position.side == _selectedAction.positionSide
        ? position.quantity
        : risk?.tradeQuantity;

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Manual Order Ticket',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose exactly how to open or close the position. If AI or ALGO is active, submitting a manual ticket stops auto execution and gives control back to you.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSignalPill(signalAsync),
              if (currentStrategy != null)
                StatusPill(
                  label: 'Source: ${_strategyLabel(currentStrategy)}',
                  color: AppColors.glowCyan,
                ),
              StatusPill(
                label: _executionControlLabel(
                  currentStrategy,
                  isRunning,
                  engine?.isManualOverrideActive ?? false,
                ),
                color: _executionControlColor(
                  currentStrategy,
                  isRunning,
                  engine?.isManualOverrideActive ?? false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TicketSection(
            label: 'Action',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ManualOrderAction.values.map((action) {
                return ChoiceChip(
                  label: Text(action.label),
                  selected: _selectedAction == action,
                  onSelected: (_) {
                    setState(() {
                      _selectedAction = action;
                    });
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          _TicketSection(
            label: 'Order Type',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ManualOrderType.values.map((orderType) {
                return ChoiceChip(
                  label: Text(orderType.label),
                  selected: _selectedOrderType == orderType,
                  onSelected: (_) {
                    setState(() {
                      _selectedOrderType = orderType;
                    });
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          if (_selectedOrderType == ManualOrderType.limit ||
              _selectedOrderType == ManualOrderType.postOnly)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText:
                          '${_selectedOrderType.label} Price (${widget.symbol})',
                    ),
                  ),
                ),
              ],
            ),
          if (_selectedOrderType == ManualOrderType.scaled)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(labelText: 'Scale Start Price'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _scaleEndController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Scale End Price',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _scaleStepsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Steps'),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Text(
            _selectedAction.isCloseAction
                ? 'Close tickets use the currently open matching position and its live quantity.'
                : 'Open tickets use your saved trade quantity, and any manual execution overrides bot decisions immediately.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _TicketMeta(
                    label: 'Ticket Qty',
                    value: ticketQuantity?.toStringAsFixed(4) ?? '--',
                  ),
                ),
                Expanded(
                  child: _TicketMeta(
                    label: 'Position',
                    value: position == null
                        ? 'NONE'
                        : (position.isLong ? 'LONG' : 'SHORT'),
                  ),
                ),
                Expanded(
                  child: _TicketMeta(
                    label: 'Queued',
                    value: '${pendingOrders.length}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ActionButton(
            label:
                '${_selectedOrderType.label.toUpperCase()} ${_selectedAction.label.toUpperCase()}',
            icon: _actionIcon(_selectedAction),
            color: _actionColor(_selectedAction),
            onPressed: engineAsync.isLoading ? null : _submitOrder,
          ),
          if (pendingOrders.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Queued Orders',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final order in pendingOrders.take(6))
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.summary,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      'Qty ${order.quantity.toStringAsFixed(4)}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignalPill(AsyncValue<TradingSignal?> signalAsync) {
    return signalAsync.when(
      data: (signal) {
        final label = switch (signal) {
          TradingSignal.buy => 'BUY',
          TradingSignal.sell => 'SELL',
          TradingSignal.hold => 'HOLD',
          null => '--',
        };
        final color = switch (signal) {
          TradingSignal.buy => AppColors.positive,
          TradingSignal.sell => AppColors.negative,
          TradingSignal.hold => AppColors.textSecondary,
          null => AppColors.textMuted,
        };
        return StatusPill(label: 'Signal: $label', color: color);
      },
      loading: () => const StatusPill(
        label: 'Signal: ...',
        color: AppColors.textSecondary,
      ),
      error: (_, __) =>
          const StatusPill(label: 'Signal: Error', color: AppColors.warning),
    );
  }

  String _strategyLabel(TradingStrategy strategy) {
    if (strategy is RsiStrategy) {
      final settings = ref.read(settingsServiceProvider);
      final preset = findRsiStrategyPreset(
        period: settings.getRsiPeriod(),
        overbought: settings.getRsiOverbought(),
        oversold: settings.getRsiOversold(),
      );
      if (preset != null) {
        return '${strategy.name} (${preset.label})';
      }
      return '${strategy.name} (Custom)';
    }
    return strategy.name;
  }

  String _executionControlLabel(
    TradingStrategy? strategy,
    bool isRunning,
    bool isManualOverrideActive,
  ) {
    if (isManualOverrideActive) {
      return 'Control: Manual override';
    }
    if (strategy is ManualStrategy) {
      return 'Control: Manual';
    }
    if (isRunning) {
      return 'Control: Auto execution';
    }
    return 'Control: Manual takeover ready';
  }

  Color _executionControlColor(
    TradingStrategy? strategy,
    bool isRunning,
    bool isManualOverrideActive,
  ) {
    if (isManualOverrideActive) {
      return AppColors.glowAmber;
    }
    if (strategy is ManualStrategy) {
      return AppColors.glowAmber;
    }
    if (isRunning) {
      return AppColors.positive;
    }
    return AppColors.glowAmber;
  }

  Color _actionColor(ManualOrderAction action) {
    return switch (action) {
      ManualOrderAction.openLong => AppColors.positive,
      ManualOrderAction.openShort => AppColors.negative,
      ManualOrderAction.closeLong ||
      ManualOrderAction.closeShort => AppColors.glowAmber,
    };
  }

  IconData _actionIcon(ManualOrderAction action) {
    return switch (action) {
      ManualOrderAction.openLong => Icons.arrow_upward,
      ManualOrderAction.openShort => Icons.arrow_downward,
      ManualOrderAction.closeLong ||
      ManualOrderAction.closeShort => Icons.close,
    };
  }
}

class _TicketSection extends StatelessWidget {
  final String label;
  final Widget child;

  const _TicketSection({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _TicketMeta extends StatelessWidget {
  final String label;
  final String value;

  const _TicketMeta({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
