import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ifutures/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('non-finite persisted trading values fall back safely', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'risk_stop_loss_percent': double.nan,
      'risk_take_profit_percent': double.infinity,
      'risk_trade_quantity': double.nan,
      'risk_investment_usdt': double.negativeInfinity,
      'risk_target_profit_usdt': double.nan,
      'risk_max_loss_usdt': double.infinity,
      'risk_max_drawdown_percent': double.nan,
      'ai_long_bias_price': double.nan,
      'ai_short_bias_price': double.infinity,
      'ai_investment_usdt': double.nan,
    });
    final settings = SettingsService();
    await settings.init();

    expect(settings.getRiskStopLossPercent(), 1);
    expect(settings.getRiskTakeProfitPercent(), 2);
    expect(settings.getRiskTradeQuantity(), 0.01);
    expect(settings.getRiskInvestmentUsdt(), 5);
    expect(settings.getRiskTargetProfitUsdt(), isNull);
    expect(settings.getRiskMaxLossUsdt(), isNull);
    expect(settings.getRiskMaxDrawdownPercent(), 0);
    expect(settings.getAiLongBiasPrice(), isNull);
    expect(settings.getAiShortBiasPrice(), isNull);
    expect(settings.getAiInvestmentUsdt(), isNull);
  });

  test('non-finite trading values cannot be persisted', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = SettingsService();
    await settings.init();

    await expectLater(
      settings.setRiskStopLossPercent(double.nan),
      throwsArgumentError,
    );
    await expectLater(
      settings.setRiskInvestmentUsdt(double.infinity),
      throwsArgumentError,
    );
    await expectLater(
      settings.setAiInvestmentUsdt(double.nan),
      throwsArgumentError,
    );
  });

  test('trading client owner ID is Binance-safe and stable', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = SettingsService();

    final concurrentIds = await Future.wait(
      List<Future<String>>.generate(
        16,
        (_) => settings.getOrCreateTradingClientOwnerId(),
      ),
    );
    final ownerId = concurrentIds.first;

    expect(concurrentIds.toSet(), <String>{ownerId});
    expect(ownerId, matches(RegExp(r'^[a-z0-9]{8}$')));

    final reloadedSettings = SettingsService();
    expect(await reloadedSettings.getOrCreateTradingClientOwnerId(), ownerId);
  });

  test('malformed trading client owner ID is replaced and persisted', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'trading_client_owner_id': 'NOT-BINANCE-SAFE',
    });
    final settings = SettingsService();

    final repairedOwnerId = await settings.getOrCreateTradingClientOwnerId();

    expect(repairedOwnerId, isNot('NOT-BINANCE-SAFE'));
    expect(repairedOwnerId, matches(RegExp(r'^[a-z0-9]{8}$')));
    final reloadedSettings = SettingsService();
    expect(
      await reloadedSettings.getOrCreateTradingClientOwnerId(),
      repairedOwnerId,
    );
  });

  test('clearing user settings preserves the installation owner ID', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    final settings = SettingsService();
    final ownerId = await settings.getOrCreateTradingClientOwnerId();
    await settings.setAiUrl('https://example.com/ai');

    await settings.clearAll();

    expect(settings.getAiUrl(), 'https://your-ai-api.com/analyze');
    final reloadedSettings = SettingsService();
    expect(await reloadedSettings.getOrCreateTradingClientOwnerId(), ownerId);
  });
}
