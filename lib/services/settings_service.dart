import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _apiKey = 'binance_api_key';
  static const _apiSecret = 'binance_api_secret';
  static const _aiUrl = 'ai_strategy_url';
  static const _isTestnet = 'is_testnet';
  static const _riskStopLoss = 'risk_stop_loss_percent';
  static const _riskTakeProfit = 'risk_take_profit_percent';
  static const _riskTradeQuantity = 'risk_trade_quantity';
  static const _lastSelectedSymbol = 'last_selected_symbol';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  SharedPreferences? _prefs;

  SettingsService();

  Future<void> init() async {
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
  }

  bool get isInitialized => _prefs != null;

  // API Key
  Future<String?> getApiKey() => _secureStorage.read(key: _apiKey);
  Future<void> setApiKey(String value) => _secureStorage.write(key: _apiKey, value: value);

  // API Secret
  Future<String?> getApiSecret() => _secureStorage.read(key: _apiSecret);
  Future<void> setApiSecret(String value) => _secureStorage.write(key: _apiSecret, value: value);

  // AI URL
  String getAiUrl() => _prefs?.getString(_aiUrl) ?? 'https://your-ai-api.com/analyze';
  Future<void> setAiUrl(String value) async {
    await init();
    await _prefs?.setString(_aiUrl, value);
  }

  // Testnet
  bool getIsTestnet() => _prefs?.getBool(_isTestnet) ?? true;
  Future<void> setIsTestnet(bool value) async {
    await init();
    await _prefs?.setBool(_isTestnet, value);
  }

  // Risk settings
  double getRiskStopLossPercent() => _prefs?.getDouble(_riskStopLoss) ?? 1.0;
  Future<void> setRiskStopLossPercent(double value) async {
    await init();
    await _prefs?.setDouble(_riskStopLoss, value);
  }

  double getRiskTakeProfitPercent() => _prefs?.getDouble(_riskTakeProfit) ?? 2.0;
  Future<void> setRiskTakeProfitPercent(double value) async {
    await init();
    await _prefs?.setDouble(_riskTakeProfit, value);
  }

  double getRiskTradeQuantity() => _prefs?.getDouble(_riskTradeQuantity) ?? 0.01;
  Future<void> setRiskTradeQuantity(double value) async {
    await init();
    await _prefs?.setDouble(_riskTradeQuantity, value);
  }

  // Last selected symbol
  String? getLastSelectedSymbol() => _prefs?.getString(_lastSelectedSymbol);
  Future<void> setLastSelectedSymbol(String value) async {
    await init();
    await _prefs?.setString(_lastSelectedSymbol, value);
  }

  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    await init();
    await _prefs?.clear();
  }
}
