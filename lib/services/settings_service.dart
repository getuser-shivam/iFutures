import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_provider.dart';

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
  static const _isTestnet = 'is_testnet';
  static const _riskStopLoss = 'risk_stop_loss_percent';
  static const _riskTakeProfit = 'risk_take_profit_percent';
  static const _riskTradeQuantity = 'risk_trade_quantity';
  static const _riskLeverage = 'risk_trade_leverage';
  static const _rsiPeriod = 'strategy_rsi_period';
  static const _rsiOverbought = 'strategy_rsi_overbought';
  static const _rsiOversold = 'strategy_rsi_oversold';
  static const _lastSelectedSymbol = 'last_selected_symbol';
  static const _symbolList = 'symbol_list';
  static const defaultAutomationPath = r'I:\Path\Projects\automation';

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
  double? getAiLongBiasPrice() => _prefs?.getDouble(_aiLongBiasPrice);
  Future<void> setAiLongBiasPrice(double? value) async {
    await init();
    if (value == null) {
      await _prefs?.remove(_aiLongBiasPrice);
      return;
    }
    await _prefs?.setDouble(_aiLongBiasPrice, value);
  }

  double? getAiShortBiasPrice() => _prefs?.getDouble(_aiShortBiasPrice);
  Future<void> setAiShortBiasPrice(double? value) async {
    await init();
    if (value == null) {
      await _prefs?.remove(_aiShortBiasPrice);
      return;
    }
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

  double getRiskTakeProfitPercent() =>
      _prefs?.getDouble(_riskTakeProfit) ?? 2.0;
  Future<void> setRiskTakeProfitPercent(double value) async {
    await init();
    await _prefs?.setDouble(_riskTakeProfit, value);
  }

  double getRiskTradeQuantity() =>
      _prefs?.getDouble(_riskTradeQuantity) ?? 0.01;
  Future<void> setRiskTradeQuantity(double value) async {
    await init();
    await _prefs?.setDouble(_riskTradeQuantity, value);
  }

  int getRiskLeverage() => _prefs?.getInt(_riskLeverage) ?? 1;
  Future<void> setRiskLeverage(int value) async {
    await init();
    await _prefs?.setInt(_riskLeverage, value);
  }

  // RSI strategy tuning
  int getRsiPeriod() => _prefs?.getInt(_rsiPeriod) ?? 14;
  Future<void> setRsiPeriod(int value) async {
    await init();
    await _prefs?.setInt(_rsiPeriod, value);
  }

  double getRsiOverbought() => _prefs?.getDouble(_rsiOverbought) ?? 70.0;
  Future<void> setRsiOverbought(double value) async {
    await init();
    await _prefs?.setDouble(_rsiOverbought, value);
  }

  double getRsiOversold() => _prefs?.getDouble(_rsiOversold) ?? 30.0;
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

  // Symbol list
  List<String>? getSymbolList() => _prefs?.getStringList(_symbolList);
  Future<void> setSymbolList(List<String> values) async {
    await init();
    await _prefs?.setStringList(_symbolList, values);
  }

  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    await init();
    await _prefs?.clear();
  }

  Future<String> importAiConfigFromAutomation({
    String automationPath = defaultAutomationPath,
  }) async {
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
