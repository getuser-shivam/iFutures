import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/price_alert.dart';
import '../../providers/trading_provider.dart';
import '../../theme/app_theme.dart';
import '../common/action_button.dart';
import '../common/app_panel.dart';
import '../common/app_toast.dart';
import '../common/status_pill.dart';

class PriceAlertsCard extends ConsumerStatefulWidget {
  final String symbol;

  const PriceAlertsCard({
    super.key,
    required this.symbol,
  });

  @override
  ConsumerState<PriceAlertsCard> createState() => _PriceAlertsCardState();
}

class _PriceAlertsCardState extends ConsumerState<PriceAlertsCard> {
  late final TextEditingController _thresholdController;
  PriceAlertDirection _direction = PriceAlertDirection.above;

  @override
  void initState() {
    super.initState();
    _thresholdController = TextEditingController();
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }

  double? _parseDouble(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  Future<void> _addAlert() async {
    final threshold = _parseDouble(_thresholdController.text);
    if (threshold == null || threshold <= 0) {
      showAppToast(
        context,
        'Enter a valid alert threshold greater than zero.',
        backgroundColor: AppColors.negative.withOpacity(0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
      return;
    }

    final service = ref.read(priceAlertServiceProvider);
    await service.addAlert(
      symbol: widget.symbol,
      threshold: threshold,
      direction: _direction,
    );

    if (!mounted) return;

    _thresholdController.clear();
    ref.invalidate(priceAlertsProvider(widget.symbol));
    showAppToast(
      context,
      '${widget.symbol} alert added',
      backgroundColor: AppColors.positive.withOpacity(0.95),
      foregroundColor: Colors.white,
      icon: Icons.notifications_active_outlined,
    );
  }

  Future<void> _removeAlert(String alertId) async {
    final service = ref.read(priceAlertServiceProvider);
    await service.removeAlert(widget.symbol, alertId);
    ref.invalidate(priceAlertsProvider(widget.symbol));
    if (!mounted) return;
    showAppToast(
      context,
      'Alert removed',
      backgroundColor: AppColors.surfaceAlt,
      icon: Icons.delete_outline,
    );
  }

  Future<void> _rearmAlert(String alertId) async {
    final service = ref.read(priceAlertServiceProvider);
    await service.rearmAlert(widget.symbol, alertId);
    ref.invalidate(priceAlertsProvider(widget.symbol));
    if (!mounted) return;
    showAppToast(
      context,
      'Alert rearmed',
      backgroundColor: AppColors.glowCyan.withOpacity(0.95),
      foregroundColor: Colors.white,
      icon: Icons.restart_alt,
    );
  }

  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(priceAlertsProvider(widget.symbol));
    final tickerAsync = ref.watch(tickerStreamProvider(widget.symbol));
    final latestPrice = tickerAsync.maybeWhen(
      data: (data) => double.tryParse(data['c']?.toString() ?? ''),
      orElse: () => null,
    );

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active_outlined, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Price Alerts',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              alertsAsync.when(
                data: (alerts) {
                  final activeCount = alerts.where((alert) => alert.isActive).length;
                  return StatusPill(
                    label: '$activeCount active',
                    color: activeCount > 0 ? AppColors.glowCyan : AppColors.textMuted,
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Toast notifications fire when the market crosses your threshold. Alerts are one-shot until you rearm them.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          if (latestPrice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  StatusPill(
                    label: 'Live: \$${formatPriceValue(latestPrice)}',
                    color: AppColors.glowCyan,
                  ),
                  const SizedBox(width: 8),
                  StatusPill(
                    label: 'Symbol: ${widget.symbol}',
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          Column(
            children: [
              TextField(
                controller: _thresholdController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Alert threshold',
                  hintText: 'e.g. 0.7425',
                ),
              ),
              const SizedBox(height: 12),
              ToggleButtons(
                isSelected: [
                  _direction == PriceAlertDirection.above,
                  _direction == PriceAlertDirection.below,
                ],
                onPressed: (index) {
                  setState(() {
                    _direction = index == 0 ? PriceAlertDirection.above : PriceAlertDirection.below;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                constraints: const BoxConstraints(minHeight: 44, minWidth: 118),
                color: AppColors.textSecondary,
                selectedColor: Colors.white,
                fillColor: AppColors.glowCyan,
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('Above'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('Below'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ActionButton(
                  label: 'ADD ALERT',
                  icon: Icons.add_alert_outlined,
                  color: AppColors.glowAmber,
                  onPressed: _addAlert,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          alertsAsync.when(
            data: (alerts) {
              if (alerts.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'No alerts yet. Add one to get a toast when price crosses your level.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }

              return ListView.separated(
                itemCount: alerts.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final alert = alerts[index];
                  return _buildAlertTile(alert);
                },
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stack) => Text(
              'Error loading alerts: $error',
              style: const TextStyle(color: AppColors.negative),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertTile(PriceAlert alert) {
    final color = alert.isTriggered
        ? AppColors.textMuted
        : alert.direction == PriceAlertDirection.above
            ? AppColors.positive
            : AppColors.warning;

    final statusLabel = alert.isTriggered
        ? 'TRIGGERED'
        : alert.enabled
            ? 'ACTIVE'
            : 'PAUSED';

    final detailText = alert.isTriggered
        ? 'Triggered at ${TimeOfDay.fromDateTime(alert.triggeredAt!).format(context)}'
        : '${alert.direction.label} \$${formatPriceValue(alert.threshold)}';
    final createdText = 'Created ${TimeOfDay.fromDateTime(alert.createdAt).format(context)}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(
            alert.direction == PriceAlertDirection.above ? Icons.trending_up : Icons.trending_down,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detailText,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  createdText,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusPill(
                label: statusLabel,
                color: color,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (alert.isTriggered)
                    TextButton(
                      onPressed: () => _rearmAlert(alert.id),
                      child: const Text('REARM'),
                    ),
                  IconButton(
                    tooltip: 'Remove alert',
                    onPressed: () => _removeAlert(alert.id),
                    icon: const Icon(Icons.delete_outline),
                    color: AppColors.negative,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
