import 'package:flutter_test/flutter_test.dart';
import 'package:ifutures/models/risk_settings.dart';

void main() {
  group('RiskSettings absolute USDT guards', () {
    const risk = RiskSettings(
      stopLossPercent: 1,
      takeProfitPercent: 2,
      tradeQuantity: 1,
      targetProfitUsdt: 5,
      maxLossUsdt: 5,
    );

    test(r'converts $5 target and loss to percentages from entry notional', () {
      const entryPrice = 100.0;
      const quantity = 10.0;

      expect(
        risk.resolveTakeProfitPercent(entryPrice, quantity: quantity),
        closeTo(0.5, 1e-12),
      );
      expect(
        risk.resolveStopLossPercent(entryPrice, quantity: quantity),
        closeTo(0.5, 1e-12),
      );
    });

    test(
      'absolute guards override configured and plan fallback percentages',
      () {
        expect(
          risk.resolveTakeProfitPercent(100, quantity: 10, fallbackPercent: 12),
          closeTo(0.5, 1e-12),
        );
        expect(
          risk.resolveStopLossPercent(100, quantity: 10, fallbackPercent: 8),
          closeTo(0.5, 1e-12),
        );
      },
    );

    test(r'reports the configured $5 gross estimates', () {
      expect(risk.resolveEstimatedTakeProfitUsdt(100, 10), 5);
      expect(risk.resolveEstimatedMaxLossUsdt(100, 10), 5);
    });

    test('uses percentage fallbacks when absolute guards are disabled', () {
      const percentageRisk = RiskSettings(
        stopLossPercent: 1,
        takeProfitPercent: 2,
        tradeQuantity: 1,
      );

      expect(percentageRisk.resolveTakeProfitPercent(100, quantity: 10), 2);
      expect(percentageRisk.resolveStopLossPercent(100, quantity: 10), 1);
      expect(percentageRisk.resolveEstimatedTakeProfitUsdt(100, 10), 20);
      expect(percentageRisk.resolveEstimatedMaxLossUsdt(100, 10), 10);
    });

    test('zero plan values do not disable configured percentage guards', () {
      const percentageRisk = RiskSettings(
        stopLossPercent: 1.5,
        takeProfitPercent: 2,
        tradeQuantity: 1,
      );

      expect(
        percentageRisk.resolveStopLossPercent(
          100,
          quantity: 1,
          fallbackPercent: 0,
        ),
        1.5,
      );
      expect(
        percentageRisk.resolveTakeProfitPercent(
          100,
          quantity: 1,
          fallbackPercent: 0,
        ),
        2,
      );
    });
  });
}
