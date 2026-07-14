import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_provider.dart';
import '../models/strategy_mode.dart';

class SettingsService {
  static const _apiKey = 'binance_api_key';
  static const _apiSecret = 'binance_api_secret';
  static const _aiUrl = 'ai_strategy_url';
  static const _aiApiKey = 'ai_strategy_api_key';
  static const _aiProvider = 'ai_strategy_provider';
  static const _aiModel = 'ai_strategy_model';
  static const _aiLongBiasPrice = 'ai_long_bias_price';
  static const _aiShortBiasPrice = 'ai_short_bias_price';
  static const _aiLongOrderType = 'ai_long_order_type';
  static const _aiShortOrderType = 'ai_short_order_type';
  static const _aiTradeDirectionMode = 'ai_trade_direction_mode';
  static const _aiLeverage = 'ai_trade_leverage';
  static const _aiInvestmentUsdt = 'ai_investment_usdt';
  static const _isTestnet = 'is_testnet';
  static const _riskStopLoss = 'risk_stop_loss_percent';
  static const _riskTakeProfit = 'risk_take_profit_percent';
  static const _riskTradeQuantity = 'risk_trade_quantity';
  static const _riskInvestmentUsdt = 'risk_investment_usdt';
  static const _riskTargetProfitUsdt = 'risk_target_profit_usdt';
  static const _riskMaxLossUsdt = 'risk_max_loss_usdt';
  static const _riskLeverage = 'risk_trade_leverage';
  static const _riskCooldownMinutes = 'risk_cooldown_minutes';
  static const _riskProtectionPauseMinutes = 'risk_protection_pause_minutes';
  static const _riskMaxConsecutiveLosses = 'risk_max_consecutive_losses';
  static const _riskMaxDrawdownPercent = 'risk_max_drawdown_percent';
  static const _rsiPeriod = 'strategy_rsi_period';
  static const _rsiOverbought = 'strategy_rsi_overbought';
  static const _rsiOversold = 'strategy_rsi_oversold';
  static const _lastSelectedSymbol = 'last_selected_symbol';
  static const _lastStrategyMode = 'last_strategy_mode';
  static const _symbolList = 'symbol_list';
  static const _tradingClientOwnerId = 'trading_client_owner_id';
  static const _tradingClientOwnerIdLength = 8;
  static const _tradingClientOwnerIdAlphabet =
      '0123456789abcdefghijklmnopqrstuvwxyz';
  static final RegExp _tradingClientOwnerIdPattern = RegExp(r'^[a-z0-9]{8}$');
  static const defaultAutomationPath = r'I:\Path\Projects\automation';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  SharedPreferences? _prefs;
  String? _cachedTradingClientOwnerId;
  Future<String>? _tradingClientOwnerIdRequest;

  SettingsService();

  static double _finiteRange(
    double? value, {
    required double fallback,
    required double min,
    required double max,
  }) {
    return value != null && value.isFinite && value >= min && value <= max
        ? value
        : fallback;
  }

  static double? _finitePositive(double? value, {required double max}) {
    return value != null && value.isFinite && value > 0 && value <= max
        ? value
        : null;
  }

  static void _requireFiniteRange(
    double value, {
    required String name,
    required double min,
    required double max,
  }) {
    if (!value.isFinite || value < min || value > max) {
      throw ArgumentError.value(value, name, 'Must be finite in [$min, $max].');
    }
  }

  Future<void> init() async {
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
  }

  bool get isInitialized => _prefs != null;

  /// Returns the durable identifier used to scope Binance client-order IDs to
  /// this app installation.
  ///
  /// The identifier is eight lowercase base-36 characters, so it is safe to
  /// embed in Binance client-order IDs while leaving room for role and nonce
  /// segments within Binance's 36-character limit. Concurrent callers on this
  /// service instance share the same creation request.
  Future<String> getOrCreateTradingClientOwnerId() {
    final cached = _cachedTradingClientOwnerId;
    if (cached != null) return Future<String>.value(cached);

    final pending = _tradingClientOwnerIdRequest;
    if (pending != null) return pending;

    final request = _loadOrCreateTradingClientOwnerId();
    _tradingClientOwnerIdRequest = request;
    return request;
  }

  Future<String> _loadOrCreateTradingClientOwnerId() async {
    try {
      await init();
      final stored = _prefs!.get(_tradingClientOwnerId);
      if (stored is String && _tradingClientOwnerIdPattern.hasMatch(stored)) {
        _cachedTradingClientOwnerId = stored;
        return stored;
      }

      final random = Random.secure();
      final ownerId = List<String>.generate(
        _tradingClientOwnerIdLength,
        (_) =>
            _tradingClientOwnerIdAlphabet[random.nextInt(
              _tradingClientOwnerIdAlphabet.length,
            )],
        growable: false,
      ).join();
      final persisted = await _prefs!.setString(_tradingClientOwnerId, ownerId);
      if (!persisted) {
        throw StateError('Could not persist the trading client owner ID.');
      }
      _cachedTradingClientOwnerId = ownerId;
      return ownerId;
    } finally {
      _tradingClientOwnerIdRequest = null;
    }
  }

  // API Key
  Future<String?> getApiKey() => _secureStorage.read(key: _apiKey);
  Future<void> setApiKey(String value) =>
      _secureStorage.write(key: _apiKey, value: value);

  // API Secret
  Future<String?> getApiSecret() => _secureStorage.read(key: _apiSecret);
  Future<void> setApiSecret(String value) =>
      _secureStorage.write(key: _apiSecret, value: value);

  // AI URL
  String getAiUrl() =>
      _prefs?.getString(_aiUrl) ?? 'https://your-ai-api.com/analyze';
  Future<void> setAiUrl(String value) async {
    await init();
    await _prefs?.setString(_aiUrl, value);
  }

  // AI API Key
  Future<String?> getAiApiKey() => _secureStorage.read(key: _aiApiKey);
  Future<void> setAiApiKey(String value) =>
      _secureStorage.write(key: _aiApiKey, value: value);

  // AI Provider
  String getAiProvider() =>
      _prefs?.getString(_aiProvider) ?? AiProvider.groqChat.key;
  Future<void> setAiProvider(String value) async {
    await init();
    await _prefs?.setString(_aiProvider, value);
  }

  // AI Model
  String getAiModel() => _prefs?.getString(_aiModel) ?? '';
  Future<void> setAiModel(String value) async {
    await init();
    await _prefs?.setString(_aiModel, value);
  }

  // AI Zone Bias
  double? getAiLongBiasPrice() =>
      _finitePositive(_prefs?.getDouble(_aiLongBiasPrice), max: 1e12);
  Future<void> setAiLongBiasPrice(double? value) async {
    await init();
    if (value == null) {
      await _prefs?.remove(_aiLongBiasPrice);
      return;
    }
    _requireFiniteRange(
      value,
      name: 'AI long bias',
      min: 0.00000001,
      max: 1e12,
    );
    await _prefs?.setDouble(_aiLongBiasPrice, value);
  }

  double? getAiShortBiasPrice() =>
      _finitePositive(_prefs?.getDouble(_aiShortBiasPrice), max: 1e12);
  Future<void> setAiShortBiasPrice(double? value) async {
    await init();
    if (value == null) {
      await _prefs?.remove(_aiShortBiasPrice);
      return;
    }
    _requireFiniteRange(
      value,
      name: 'AI short bias',
      min: 0.00000001,
      max: 1e12,
    );
    await _prefs?.setDouble(_aiShortBiasPrice, value);
  }

  String getAiLongOrderType() => _prefs?.getString(_aiLongOrderType) ?? 'limit';
  Future<void> setAiLongOrderType(String value) async {
    await init();
    await _prefs?.setString(_aiLongOrderType, value);
  }

  String getAiShortOrderType() =>
      _prefs?.getString(_aiShortOrderType) ?? 'limit';
  Future<void> setAiShortOrderType(String value) async {
    await init();
    await _prefs?.setString(_aiShortOrderType, value);
  }

  String getAiTradeDirectionMode() =>
      _prefs?.getString(_aiTradeDirectionMode) ?? 'auto';
  Future<void> setAiTradeDirectionMode(String value) async {
    await init();
    await _prefs?.setString(_aiTradeDirectionMode, value);
  }

  int? getAiLeverage() {
    final value = _prefs?.getInt(_aiLeverage);
    return value != null && value >= 1 && value <= 125 ? value : null;
  }

  Future<void> setAiLeverage(int? value) async {
    await init();
    if (value == null) {
      await _prefs?.remove(_aiLeverage);
      return;
    }
    if (value < 1 || value > 125) {
      throw ArgumentError.value(value, 'AI leverage', 'Must be from 1 to 125.');
    }
    await _prefs?.setInt(_aiLeverage, value);
  }

  double? getAiInvestmentUsdt() =>
      _finitePositive(_prefs?.getDouble(_aiInvestmentUsdt), max: 1000000);
  Future<void> setAiInvestmentUsdt(double? value) async {
    await init();
    if (value == null) {
      await _prefs?.remove(_aiInvestmentUsdt);
      return;
    }
    _requireFiniteRange(value, name: 'AI investment', min: 0.01, max: 1000000);
    await _prefs?.setDouble(_aiInvestmentUsdt, value);
  }

  // Testnet
  bool getIsTestnet() => _prefs?.getBool(_isTestnet) ?? true;
  Future<void> setIsTestnet(bool value) async {
    await init();
    await _prefs?.setBool(_isTestnet, value);
  }

  // Risk settings
  double getRiskStopLossPercent() => _finiteRange(
    _prefs?.getDouble(_riskStopLoss),
    fallback: 1,
    min: 0,
    max: 100,
  );
  Future<void> setRiskStopLossPercent(double value) async {
    await init();
    _requireFiniteRange(value, name: 'stop loss', min: 0, max: 100);
    await _prefs?.setDouble(_riskStopLoss, value);
  }

  double getRiskTakeProfitPercent() => _finiteRange(
    _prefs?.getDouble(_riskTakeProfit),
    fallback: 2,
    min: 0,
    max: 100,
  );
  Future<void> setRiskTakeProfitPercent(double value) async {
    await init();
    _requireFiniteRange(value, name: 'take profit', min: 0, max: 100);
    await _prefs?.setDouble(_riskTakeProfit, value);
  }

  double getRiskTradeQuantity() => _finiteRange(
    _prefs?.getDouble(_riskTradeQuantity),
    fallback: 0.01,
    min: 0.00000001,
    max: 1000000000,
  );
  Future<void> setRiskTradeQuantity(double value) async {
    await init();
    _requireFiniteRange(
      value,
      name: 'trade quantity',
      min: 0.00000001,
      max: 1000000000,
    );
    await _prefs?.setDouble(_riskTradeQuantity, value);
  }

  double? getRiskInvestmentUsdt() => _finiteRange(
    _prefs?.getDouble(_riskInvestmentUsdt),
    fallback: 5,
    min: 0.01,
    max: 1000000,
  );
  Future<void> setRiskInvestmentUsdt(double? value) async {
    await init();
    if (value == null) {
      await _prefs?.remove(_riskInvestmentUsdt);
      return;
    }
    _requireFiniteRange(
      value,
      name: 'risk investment',
      min: 0.01,
      max: 1000000,
    );
    await _prefs?.setDouble(_riskInvestmentUsdt, value);
  }

  double? getRiskTargetProfitUsdt() =>
      _finitePositive(_prefs?.getDouble(_riskTargetProfitUsdt), max: 1000000);
  Future<void> setRiskTargetProfitUsdt(double? value) async {
    await init();
    if (value == null) {
      await _prefs?.remove(_riskTargetProfitUsdt);
      return;
    }
    _requireFiniteRange(
      value,
      name: 'target profit',
      min: 0.00000001,
      max: 1000000,
    );
    await _prefs?.setDouble(_riskTargetProfitUsdt, value);
  }

  double? getRiskMaxLossUsdt() =>
      _finitePositive(_prefs?.getDouble(_riskMaxLossUsdt), max: 1000000);
  Future<void> setRiskMaxLossUsdt(double? value) async {
    await init();
    if (value == null) {
      await _prefs?.remove(_riskMaxLossUsdt);
      return;
    }
    _requireFiniteRange(value, name: 'max loss', min: 0.00000001, max: 1000000);
    await _prefs?.setDouble(_riskMaxLossUsdt, value);
  }

  int getRiskLeverage() {
    final value = _prefs?.getInt(_riskLeverage) ?? 1;
    return value >= 1 && value <= 125 ? value : 1;
  }

  Future<void> setRiskLeverage(int value) async {
    await init();
    if (value < 1 || value > 125) {
      throw ArgumentError.value(value, 'risk leverage', 'Must be 1 to 125.');
    }
    await _prefs?.setInt(_riskLeverage, value);
  }

  int getRiskCooldownMinutes() {
    final value = _prefs?.getInt(_riskCooldownMinutes) ?? 0;
    return value >= 0 && value <= 525600 ? value : 0;
  }

  Future<void> setRiskCooldownMinutes(int value) async {
    await init();
    if (value < 0 || value > 525600) {
      throw ArgumentError.value(value, 'cooldown', 'Must be 0 to 525600.');
    }
    await _prefs?.setInt(_riskCooldownMinutes, value);
  }

  int getRiskProtectionPauseMinutes() {
    final value = _prefs?.getInt(_riskProtectionPauseMinutes) ?? 30;
    return value >= 0 && value <= 525600 ? value : 30;
  }

  Future<void> setRiskProtectionPauseMinutes(int value) async {
    await init();
    if (value < 0 || value > 525600) {
      throw ArgumentError.value(
        value,
        'protection pause',
        'Must be 0 to 525600.',
      );
    }
    await _prefs?.setInt(_riskProtectionPauseMinutes, value);
  }

  int getRiskMaxConsecutiveLosses() {
    final value = _prefs?.getInt(_riskMaxConsecutiveLosses) ?? 0;
    return value >= 0 && value <= 10000 ? value : 0;
  }

  Future<void> setRiskMaxConsecutiveLosses(int value) async {
    await init();
    if (value < 0 || value > 10000) {
      throw ArgumentError.value(
        value,
        'max consecutive losses',
        'Must be 0 to 10000.',
      );
    }
    await _prefs?.setInt(_riskMaxConsecutiveLosses, value);
  }

  double getRiskMaxDrawdownPercent() => _finiteRange(
    _prefs?.getDouble(_riskMaxDrawdownPercent),
    fallback: 0,
    min: 0,
    max: 100,
  );
  Future<void> setRiskMaxDrawdownPercent(double value) async {
    await init();
    _requireFiniteRange(value, name: 'max drawdown', min: 0, max: 100);
    await _prefs?.setDouble(_riskMaxDrawdownPercent, value);
  }

  // RSI strategy tuning
  int getRsiPeriod() {
    final value = _prefs?.getInt(_rsiPeriod) ?? 14;
    return value >= 2 && value <= 1000 ? value : 14;
  }

  Future<void> setRsiPeriod(int value) async {
    await init();
    await _prefs?.setInt(_rsiPeriod, value);
  }

  double getRsiOverbought() => _finiteRange(
    _prefs?.getDouble(_rsiOverbought),
    fallback: 70,
    min: 0.00000001,
    max: 99.99999999,
  );
  Future<void> setRsiOverbought(double value) async {
    await init();
    await _prefs?.setDouble(_rsiOverbought, value);
  }

  double getRsiOversold() => _finiteRange(
    _prefs?.getDouble(_rsiOversold),
    fallback: 30,
    min: 0,
    max: 99.99999999,
  );
  Future<void> setRsiOversold(double value) async {
    await init();
    await _prefs?.setDouble(_rsiOversold, value);
  }

  // Last selected symbol
  String? getLastSelectedSymbol() => _prefs?.getString(_lastSelectedSymbol);
  Future<void> setLastSelectedSymbol(String value) async {
    await init();
    await _prefs?.setString(_lastSelectedSymbol, value);
  }

  StrategyMode getLastStrategyMode() =>
      strategyModeFromKey(_prefs?.getString(_lastStrategyMode));
  Future<void> setLastStrategyMode(StrategyMode value) async {
    await init();
    await _prefs?.setString(_lastStrategyMode, value.key);
  }

  // Symbol list
  List<String>? getSymbolList() => _prefs?.getStringList(_symbolList);
  Future<void> setSymbolList(List<String> values) async {
    await init();
    await _prefs?.setStringList(_symbolList, values);
  }

  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    await init();
    final tradingClientOwnerId = await getOrCreateTradingClientOwnerId();
    await _prefs?.clear();
    final ownerIdRestored = await _prefs!.setString(
      _tradingClientOwnerId,
      tradingClientOwnerId,
    );
    if (!ownerIdRestored) {
      _cachedTradingClientOwnerId = null;
      throw StateError('Could not preserve the trading client owner ID.');
    }
  }

  Future<String> importAiConfigFromAutomation({
    String automationPath = defaultAutomationPath,
  }) async {
    if (kIsWeb) {
      return 'Automation file import is available in the desktop app.';
    }
    await init();

    String? importedKey;
    String? importedProvider;
    String? importedModel;
    String? importedUrl;
    var importedAnything = false;

    final guiSettingsFile = File('$automationPath\\gui_settings.json');
    if (await guiSettingsFile.exists()) {
      try {
        final jsonMap =
            jsonDecode(await guiSettingsFile.readAsString())
                as Map<String, dynamic>;
        final providerText = jsonMap['provider']?.toString().toLowerCase();
        if (providerText != null) {
          if (providerText.contains('groq')) {
            importedProvider = AiProvider.groqChat.key;
            importedUrl = AiProvider.groqChat.defaultUrl;
          } else if (providerText.contains('pollinations')) {
            importedProvider = AiProvider.pollinationsText.key;
            importedUrl = AiProvider.pollinationsText.defaultUrl;
          }
        }

        final rawModel = jsonMap['model']?.toString().trim();
        if (rawModel != null && rawModel.isNotEmpty) {
          importedModel = rawModel;
        }

        final rawKey = jsonMap['api_key']?.toString().trim();
        if (rawKey != null && rawKey.isNotEmpty) {
          importedKey = rawKey;
        }
      } catch (_) {
        // Ignore malformed automation GUI config and continue to .env.
      }
    }

    final envFile = File('$automationPath\\.env');
    if (await envFile.exists()) {
      final envVars = <String, String>{};
      final lines = await envFile.readAsLines();
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty ||
            trimmed.startsWith('#') ||
            !trimmed.contains('=')) {
          continue;
        }
        final separator = trimmed.indexOf('=');
        final key = trimmed.substring(0, separator).trim();
        final value = trimmed.substring(separator + 1).trim();
        envVars[key] = value;
      }

      importedKey ??=
          envVars['GROQ_API_KEY'] ??
          envVars['OPENAI_API_KEY'] ??
          envVars['POLLINATIONS_API_KEY'];

      if (importedProvider == null) {
        if ((envVars['GROQ_API_KEY'] ?? '').isNotEmpty) {
          importedProvider = AiProvider.groqChat.key;
          importedUrl = AiProvider.groqChat.defaultUrl;
        } else if ((envVars['POLLINATIONS_API_KEY'] ?? '').isNotEmpty) {
          importedProvider = AiProvider.pollinationsText.key;
          importedUrl = AiProvider.pollinationsText.defaultUrl;
        }
      }
    }

    if (importedProvider != null && importedProvider.isNotEmpty) {
      await setAiProvider(importedProvider);
      importedAnything = true;
    }

    if (importedKey != null && importedKey.isNotEmpty) {
      await setAiApiKey(importedKey);
      importedAnything = true;
    }

    if (importedUrl != null && importedUrl.isNotEmpty) {
      await setAiUrl(importedUrl);
      importedAnything = true;
    }

    if (importedModel != null && importedModel.isNotEmpty) {
      await setAiModel(importedModel);
      importedAnything = true;
    }

    if (!importedAnything) {
      return 'No compatible AI config was found in automation.';
    }

    final provider = aiProviderFromKey(getAiProvider());
    if (getAiModel().trim().isEmpty ||
        (provider == AiProvider.groqChat && getAiModel().trim() == 'openai')) {
      await setAiModel(provider.defaultModel);
    }

    return 'Imported AI config from automation.';
  }
}
