import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/price_alert.dart';
import '../../providers/trading_provider.dart';
import '../../theme/app_theme.dart';
import '../common/app_toast.dart';

class PriceAlertListener extends ConsumerWidget {
  final String symbol;

  const PriceAlertListener({super.key, required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(tickerStreamProvider(symbol), (previous, next) {
      unawaited(_handleTickerUpdate(context, ref, next));
    });
    return const SizedBox.shrink();
  }

  Future<void> _handleTickerUpdate(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<dynamic> ticker,
  ) async {
    final price = ticker.maybeWhen(
      data: (data) => double.tryParse(data['c']?.toString() ?? ''),
      orElse: () => null,
    );

    if (price == null) return;

    final service = ref.read(priceAlertServiceProvider);
    final triggeredAlerts = await service.evaluateAlerts(symbol, price);

    if (!context.mounted || triggeredAlerts.isEmpty) {
      return;
    }

    ref.invalidate(priceAlertsProvider(symbol));

    final summary = triggeredAlerts
        .map((alert) {
          final direction = alert.direction == PriceAlertDirection.above
              ? 'above'
              : 'below';
          return '${alert.symbol} $direction ${formatPriceValue(alert.threshold)}';
        })
        .join(', ');

    showAppToast(
      context,
      triggeredAlerts.length == 1
          ? 'Price alert triggered: $summary'
          : 'Price alerts triggered: $summary',
      backgroundColor: AppColors.warning.withOpacity(0.95),
      foregroundColor: Colors.white,
      icon: Icons.notifications_active_outlined,
      duration: const Duration(seconds: 3),
    );
  }
}
