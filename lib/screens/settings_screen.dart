import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trading_provider.dart';
import '../models/ai_provider.dart';
import '../models/ai_service_status.dart';
import '../models/ai_trade_direction_mode.dart';
import '../models/binance_account_status.dart';
import '../models/manual_order.dart';
import '../constants/symbols.dart';
import '../models/rsi_strategy_preset.dart';
import '../models/strategy_mode.dart';
import '../services/binance_api.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common/app_panel.dart';
import '../widgets/common/app_toast.dart';
import '../widgets/common/status_pill.dart';
import '../widgets/dashboard/backtest_card.dart';
import '../widgets/dashboard/manual_order_ticket.dart';
import '../widgets/dashboard/mode_selector.dart';
import '../trading/ai_strategy.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _apiKeyController;
  late TextEditingController _apiSecretController;
  late TextEditingController _aiUrlController;
  late TextEditingController _aiApiKeyController;
  late TextEditingController _aiModelController;
  late TextEditingController _aiLongBiasController;
  late TextEditingController _aiShortBiasController;
  late TextEditingController _aiInvestmentUsdtController;
  late TextEditingController _aiLeverageController;
  late TextEditingController _symbolListController;
  late TextEditingController _stopLossController;
  late TextEditingController _takeProfitController;
  late TextEditingController _tradeQuantityController;
  late TextEditingController _leverageController;
  late TextEditingController _cooldownMinutesController;
  late TextEditingController _protectionPauseMinutesController;
  late TextEditingController _maxConsecutiveLossesController;
  late TextEditingController _maxDrawdownController;
  late TextEditingController _rsiPeriodController;
  late TextEditingController _rsiOverboughtController;
  late TextEditingController _rsiOversoldController;
  AiProvider _selectedAiProvider = AiProvider.groqChat;
  ManualOrderType _selectedAiLongOrderType = ManualOrderType.limit;
  ManualOrderType _selectedAiShortOrderType = ManualOrderType.limit;
  AiTradeDirectionMode _selectedAiTradeDirectionMode =
      AiTradeDirectionMode.auto;
  bool _isTestnet = true;
  String _savedApiKey = '';
  String _savedApiSecret = '';
  bool _savedIsTestnet = true;
  String _savedAiApiKey = '';
  String _savedAiUrl = '';
  String _savedAiModel = '';
  String _savedAiLongBias = '';
  String _savedAiShortBias = '';
  String _savedAiInvestmentUsdt = '';
  String _savedAiLeverage = '';
  AiProvider _savedAiProvider = AiProvider.groqChat;
  ManualOrderType _savedAiLongOrderType = ManualOrderType.limit;
  ManualOrderType _savedAiShortOrderType = ManualOrderType.limit;
  AiTradeDirectionMode _savedAiTradeDirectionMode = AiTradeDirectionMode.auto;
  bool _isLoading = true;
  bool _isTestingBinance = false;
  bool _isTestingAi = false;
  _BinanceCheckState _binanceCheckState = _BinanceCheckState.idle;
  String? _binanceCheckMessage;
  String? _binanceCheckRawDetails;
  DateTime? _binanceCheckAt;
  _AiCheckState _aiCheckState = _AiCheckState.idle;
  String? _aiCheckMessage;
  String? _aiCheckRawDetails;
  DateTime? _aiCheckAt;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    _apiSecretController = TextEditingController();
    _aiUrlController = TextEditingController();
    _aiApiKeyController = TextEditingController();
    _aiModelController = TextEditingController();
    _aiLongBiasController = TextEditingController();
    _aiShortBiasController = TextEditingController();
    _aiInvestmentUsdtController = TextEditingController();
    _aiLeverageController = TextEditingController();
    _symbolListController = TextEditingController();
    _stopLossController = TextEditingController();
    _takeProfitController = TextEditingController();
    _tradeQuantityController = TextEditingController();
    _leverageController = TextEditingController();
    _cooldownMinutesController = TextEditingController();
    _protectionPauseMinutesController = TextEditingController();
    _maxConsecutiveLossesController = TextEditingController();
    _maxDrawdownController = TextEditingController();
    _rsiPeriodController = TextEditingController();
    _rsiOverboughtController = TextEditingController();
    _rsiOversoldController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = ref.read(settingsServiceProvider);
    await settings.init();

    final isTestnet = settings.getIsTestnet();
    var apiKey = await settings.getApiKey();
    var apiSecret = await settings.getApiSecret();
    if (kIsWeb &&
        !isTestnet &&
        ((apiKey ?? '').isNotEmpty || (apiSecret ?? '').isNotEmpty)) {
      await settings.setApiKey('');
      await settings.setApiSecret('');
      apiKey = null;
      apiSecret = null;
    }
    final aiApiKey = await settings.getAiApiKey();
    final storedSymbols = settings.getSymbolList();
    final symbolText = normalizeSymbolList(
      storedSymbols == null || storedSymbols.isEmpty
          ? defaultSymbols
          : storedSymbols,
      requiredSymbols: [...coreTradingSymbols, truusdtSymbol],
    ).join(', ');

    if (!mounted) return;
    setState(() {
      _apiKeyController.text = apiKey ?? '';
      _apiSecretController.text = apiSecret ?? '';
      _savedApiKey = apiKey ?? '';
      _savedApiSecret = apiSecret ?? '';
      _aiUrlController.text = settings.getAiUrl();
      _aiApiKeyController.text = aiApiKey ?? '';
      _aiModelController.text = settings.getAiModel();
      _savedAiApiKey = aiApiKey ?? '';
      _savedAiUrl = settings.getAiUrl();
      _savedAiModel = settings.getAiModel();
      _aiLongBiasController.text =
          settings.getAiLongBiasPrice()?.toString() ?? '';
      _aiShortBiasController.text =
          settings.getAiShortBiasPrice()?.toString() ?? '';
      _savedAiLongBias = settings.getAiLongBiasPrice()?.toString() ?? '';
      _savedAiShortBias = settings.getAiShortBiasPrice()?.toString() ?? '';
      _aiInvestmentUsdtController.text =
          settings.getAiInvestmentUsdt()?.toString() ?? '';
      _savedAiInvestmentUsdt = _aiInvestmentUsdtController.text;
      _aiLeverageController.text = settings.getAiLeverage()?.toString() ?? '';
      _savedAiLeverage = _aiLeverageController.text;
      _selectedAiProvider = aiProviderFromKey(settings.getAiProvider());
      _savedAiProvider = _selectedAiProvider;
      _selectedAiLongOrderType = ManualOrderType.values.byName(
        settings.getAiLongOrderType(),
      );
      _savedAiLongOrderType = _selectedAiLongOrderType;
      _selectedAiShortOrderType = ManualOrderType.values.byName(
        settings.getAiShortOrderType(),
      );
      _savedAiShortOrderType = _selectedAiShortOrderType;
      _selectedAiTradeDirectionMode = aiTradeDirectionModeFromKey(
        settings.getAiTradeDirectionMode(),
      );
      _savedAiTradeDirectionMode = _selectedAiTradeDirectionMode;
      _symbolListController.text = symbolText;
      _isTestnet = isTestnet;
      _savedIsTestnet = _isTestnet;
      _stopLossController.text = settings.getRiskStopLossPercent().toString();
      _takeProfitController.text = settings
          .getRiskTakeProfitPercent()
          .toString();
      _tradeQuantityController.text = settings
          .getRiskTradeQuantity()
          .toString();
      _leverageController.text = settings.getRiskLeverage().toString();
      _cooldownMinutesController.text = settings
          .getRiskCooldownMinutes()
          .toString();
      _protectionPauseMinutesController.text = settings
          .getRiskProtectionPauseMinutes()
          .toString();
      _maxConsecutiveLossesController.text = settings
          .getRiskMaxConsecutiveLosses()
          .toString();
      _maxDrawdownController.text = settings
          .getRiskMaxDrawdownPercent()
          .toString();
      _rsiPeriodController.text = settings.getRsiPeriod().toString();
      _rsiOverboughtController.text = settings.getRsiOverbought().toString();
      _rsiOversoldController.text = settings.getRsiOversold().toString();
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiSecretController.dispose();
    _aiUrlController.dispose();
    _aiApiKeyController.dispose();
    _aiModelController.dispose();
    _aiLongBiasController.dispose();
    _aiShortBiasController.dispose();
    _aiInvestmentUsdtController.dispose();
    _aiLeverageController.dispose();
    _symbolListController.dispose();
    _stopLossController.dispose();
    _takeProfitController.dispose();
    _tradeQuantityController.dispose();
    _leverageController.dispose();
    _cooldownMinutesController.dispose();
    _protectionPauseMinutesController.dispose();
    _maxConsecutiveLossesController.dispose();
    _maxDrawdownController.dispose();
    _rsiPeriodController.dispose();
    _rsiOverboughtController.dispose();
    _rsiOversoldController.dispose();
    super.dispose();
  }

  int? _parseInt(String value) {
    final normalized = value.trim();
    return int.tryParse(normalized);
  }

  double? _parseDouble(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    final parsed = double.tryParse(normalized);
    return parsed?.isFinite == true ? parsed : null;
  }

  bool _validateAiConstraintFields() {
    final investmentText = _aiInvestmentUsdtController.text.trim();
    final leverageText = _aiLeverageController.text.trim();
    final longBiasText = _aiLongBiasController.text.trim();
    final shortBiasText = _aiShortBiasController.text.trim();
    final aiInvestmentUsdt = investmentText.isEmpty
        ? null
        : _parseDouble(investmentText);
    final aiLeverage = leverageText.isEmpty ? null : _parseInt(leverageText);
    final longBias = longBiasText.isEmpty ? null : _parseDouble(longBiasText);
    final shortBias = shortBiasText.isEmpty
        ? null
        : _parseDouble(shortBiasText);

    if (investmentText.isNotEmpty &&
        (aiInvestmentUsdt == null ||
            aiInvestmentUsdt <= 0 ||
            aiInvestmentUsdt > 1000000)) {
      showAppToast(
        context,
        'AI max margin budget must be a finite value up to 1,000,000 USDT.',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
      return false;
    }

    if (leverageText.isNotEmpty &&
        (aiLeverage == null || aiLeverage < 1 || aiLeverage > 125)) {
      showAppToast(
        context,
        'AI leverage must be an integer between 1 and 125.',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
      return false;
    }

    if (longBiasText.isNotEmpty &&
        (longBias == null || longBias <= 0 || longBias > 1e12)) {
      showAppToast(
        context,
        'AI long-zone price must be a finite positive number.',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
      return false;
    }

    if (shortBiasText.isNotEmpty &&
        (shortBias == null || shortBias <= 0 || shortBias > 1e12)) {
      showAppToast(
        context,
        'AI short-zone price must be a finite positive number.',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
      return false;
    }

    return true;
  }

  RsiStrategyPreset? get _selectedRsiPreset {
    final period = _parseInt(_rsiPeriodController.text);
    final overbought = _parseDouble(_rsiOverboughtController.text);
    final oversold = _parseDouble(_rsiOversoldController.text);

    if (period == null || overbought == null || oversold == null) {
      return null;
    }

    return findRsiStrategyPreset(
      period: period,
      overbought: overbought,
      oversold: oversold,
    );
  }

  void _applyRsiPreset(RsiStrategyPreset preset) {
    setState(() {
      _rsiPeriodController.text = preset.period.toString();
      _rsiOverboughtController.text = preset.overbought.toString();
      _rsiOversoldController.text = preset.oversold.toString();
    });
  }

  List<String> _parseSymbolList(String value) {
    return normalizeSymbolList(
      value.split(','),
      requiredSymbols: [...coreTradingSymbols, truusdtSymbol],
    );
  }

  Future<void> _importAutomationAiConfig() async {
    if (kIsWeb) {
      if (!mounted) return;
      showAppToast(
        context,
        'Automation file import is available in the desktop app.',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
      return;
    }
    final settings = ref.read(settingsServiceProvider);
    final message = await settings.importAiConfigFromAutomation();
    await _loadSettings();
    if (!mounted) return;
    showAppToast(
      context,
      message,
      backgroundColor: AppColors.glowCyan.withValues(alpha: 0.95),
      foregroundColor: Colors.white,
      icon: Icons.auto_awesome_outlined,
    );
  }

  Future<void> _saveSettings() async {
    final settings = ref.read(settingsServiceProvider);
    final symbols = _parseSymbolList(_symbolListController.text);
    final rsiPeriod = _parseInt(_rsiPeriodController.text);
    final rsiOverbought = _parseDouble(_rsiOverboughtController.text);
    final rsiOversold = _parseDouble(_rsiOversoldController.text);
    if (!_validateAiConstraintFields()) {
      return;
    }
    if (_blockUnsafeWebLiveCredentials()) {
      return;
    }

    if (symbols.isEmpty) {
      showAppToast(
        context,
        'Add at least one symbol (comma-separated).',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
      return;
    }

    if (rsiPeriod == null || rsiPeriod < 2) {
      showAppToast(
        context,
        'RSI period must be an integer of at least 2.',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
      return;
    }

    if (rsiOverbought == null || rsiOverbought <= 0 || rsiOverbought >= 100) {
      showAppToast(
        context,
        'RSI overbought must be between 0 and 100.',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
      return;
    }

    if (rsiOversold == null || rsiOversold < 0 || rsiOversold >= 100) {
      showAppToast(
        context,
        'RSI oversold must be between 0 and 100.',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
      return;
    }

    if (rsiOversold >= rsiOverbought) {
      showAppToast(
        context,
        'RSI oversold must be below the overbought threshold.',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
      return;
    }

    final symbol = ref.read(selectedSymbolProvider);
    await ref.read(currentStrategyReadyProvider.future);
    final mode = ref.read(currentStrategyModeProvider);
    if (!await _disarmRuntimeBeforeSettingsChange(
      symbol: symbol,
      reason: 'settings_changed',
    )) {
      return;
    }

    try {
      await _persistBinanceSettings(settings);
      await _persistAiSettings(settings);
      await settings.setSymbolList(symbols);
      await settings.setRsiPeriod(rsiPeriod);
      await settings.setRsiOverbought(rsiOverbought);
      await settings.setRsiOversold(rsiOversold);
      await _refreshRuntimeProviders(symbol: symbol, mode: mode);
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        'Settings could not be applied safely: $error',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
      return;
    }

    if (!mounted) return;
    showAppToast(
      context,
      'Settings saved. Automation is disarmed; review the new configuration before starting again.',
      backgroundColor: AppColors.positive.withValues(alpha: 0.95),
      foregroundColor: Colors.white,
      icon: Icons.check_circle_outline,
    );
  }

  Future<void> _persistBinanceSettings(SettingsService settings) async {
    final apiKey = _apiKeyController.text.trim();
    final apiSecret = _apiSecretController.text.trim();
    await settings.setApiKey(apiKey);
    await settings.setApiSecret(apiSecret);
    await settings.setIsTestnet(_isTestnet);
    _savedApiKey = apiKey;
    _savedApiSecret = apiSecret;
    _savedIsTestnet = _isTestnet;
  }

  Future<void> _persistAiSettings(SettingsService settings) async {
    final aiLongBias = _parseDouble(_aiLongBiasController.text);
    final aiShortBias = _parseDouble(_aiShortBiasController.text);
    final aiInvestmentUsdt = _aiInvestmentUsdtController.text.trim().isEmpty
        ? null
        : _parseDouble(_aiInvestmentUsdtController.text);
    final aiLeverage = _aiLeverageController.text.trim().isEmpty
        ? null
        : _parseInt(_aiLeverageController.text);
    final aiApiKey = _aiApiKeyController.text.trim();
    final aiUrl = _aiUrlController.text.trim();
    final aiModel = _aiModelController.text.trim();

    await settings.setAiApiKey(aiApiKey);
    await settings.setAiUrl(aiUrl);
    await settings.setAiProvider(_selectedAiProvider.key);
    await settings.setAiModel(aiModel);
    await settings.setAiLongBiasPrice(aiLongBias);
    await settings.setAiShortBiasPrice(aiShortBias);
    await settings.setAiLongOrderType(_selectedAiLongOrderType.name);
    await settings.setAiShortOrderType(_selectedAiShortOrderType.name);
    await settings.setAiTradeDirectionMode(_selectedAiTradeDirectionMode.key);
    await settings.setAiInvestmentUsdt(aiInvestmentUsdt);
    await settings.setAiLeverage(aiLeverage);

    _savedAiApiKey = aiApiKey;
    _savedAiUrl = aiUrl;
    _savedAiModel = aiModel;
    _savedAiLongBias = _aiLongBiasController.text.trim();
    _savedAiShortBias = _aiShortBiasController.text.trim();
    _savedAiInvestmentUsdt = _aiInvestmentUsdtController.text.trim();
    _savedAiLeverage = _aiLeverageController.text.trim();
    _savedAiProvider = _selectedAiProvider;
    _savedAiLongOrderType = _selectedAiLongOrderType;
    _savedAiShortOrderType = _selectedAiShortOrderType;
    _savedAiTradeDirectionMode = _selectedAiTradeDirectionMode;
  }

  bool get _hasUnsavedBinanceChanges {
    return _apiKeyController.text.trim() != _savedApiKey ||
        _apiSecretController.text.trim() != _savedApiSecret ||
        _isTestnet != _savedIsTestnet;
  }

  bool get _hasUnsavedAiChanges {
    return _aiApiKeyController.text.trim() != _savedAiApiKey ||
        _aiUrlController.text.trim() != _savedAiUrl ||
        _aiModelController.text.trim() != _savedAiModel ||
        _aiLongBiasController.text.trim() != _savedAiLongBias ||
        _aiShortBiasController.text.trim() != _savedAiShortBias ||
        _aiInvestmentUsdtController.text.trim() != _savedAiInvestmentUsdt ||
        _aiLeverageController.text.trim() != _savedAiLeverage ||
        _selectedAiProvider != _savedAiProvider ||
        _selectedAiLongOrderType != _savedAiLongOrderType ||
        _selectedAiShortOrderType != _savedAiShortOrderType ||
        _selectedAiTradeDirectionMode != _savedAiTradeDirectionMode;
  }

  Future<bool> _disarmRuntimeBeforeSettingsChange({
    required String symbol,
    required String reason,
  }) async {
    final result = await ref
        .read(tradingRuntimeSafetyProvider)
        .disarmBeforeRuntimeChange(symbol: symbol, reason: reason);
    if (!result.canProceed) {
      if (!mounted) return false;
      showAppToast(
        context,
        'Settings were not applied because working iFutures entries could not be cancelled and reconciled: ${result.error}',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.security_outlined,
        duration: const Duration(seconds: 6),
      );
      return false;
    }
    ref.read(isBotRunningProvider(symbol).notifier).state = false;
    return mounted;
  }

  Future<void> _refreshRuntimeProviders({
    required String symbol,
    required StrategyMode mode,
  }) async {
    ref.invalidate(binanceApiProvider);
    ref.invalidate(binanceWsProvider);
    ref.invalidate(aiStrategyProvider(symbol));
    ref.invalidate(riskSettingsProvider);
    ref.invalidate(symbolListProvider);
    await ref
        .read(currentStrategyProvider.notifier)
        .setMode(mode, symbol: symbol, persist: false);
    ref.invalidate(tradingEngineProvider(symbol));
    ref.invalidate(connectionStatusProvider(symbol));
    ref.invalidate(binanceAccountStatusProvider(symbol));
    ref.invalidate(aiServiceStatusProvider(symbol));
  }

  Future<void> _saveBinanceSettingsOnly() async {
    if (_blockUnsafeWebLiveCredentials()) {
      return;
    }
    final symbol = ref.read(selectedSymbolProvider);
    await ref.read(currentStrategyReadyProvider.future);
    final mode = ref.read(currentStrategyModeProvider);
    if (!await _disarmRuntimeBeforeSettingsChange(
      symbol: symbol,
      reason: 'binance_settings_changed',
    )) {
      return;
    }
    final settings = ref.read(settingsServiceProvider);
    try {
      await _persistBinanceSettings(settings);
      await _refreshRuntimeProviders(symbol: symbol, mode: mode);
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        'Binance settings could not be applied safely: $error',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
      return;
    }
    if (!mounted) return;
    showAppToast(
      context,
      'API keys saved locally for this ${_isTestnet ? 'demo' : 'live'} connection. Automation is disarmed for review.',
      backgroundColor: AppColors.positive.withValues(alpha: 0.95),
      foregroundColor: Colors.white,
      icon: Icons.verified_user_outlined,
    );
  }

  Future<void> _saveAiSettingsOnly() async {
    if (!_validateAiConstraintFields()) {
      return;
    }
    final symbol = ref.read(selectedSymbolProvider);
    await ref.read(currentStrategyReadyProvider.future);
    final mode = ref.read(currentStrategyModeProvider);
    if (!await _disarmRuntimeBeforeSettingsChange(
      symbol: symbol,
      reason: 'ai_settings_changed',
    )) {
      return;
    }
    final settings = ref.read(settingsServiceProvider);
    try {
      await _persistAiSettings(settings);
      await _refreshRuntimeProviders(symbol: symbol, mode: mode);
    } catch (error) {
      if (!mounted) return;
      showAppToast(
        context,
        'AI settings could not be applied safely: $error',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
      return;
    }
    if (!mounted) return;
    showAppToast(
      context,
      'AI API settings saved locally and the active strategy was rebuilt. Automation is disarmed for review.',
      backgroundColor: AppColors.positive.withValues(alpha: 0.95),
      foregroundColor: Colors.white,
      icon: Icons.psychology_alt_outlined,
    );
  }

  Future<void> _testBinanceConnection() async {
    final apiKey = _apiKeyController.text.trim();
    final apiSecret = _apiSecretController.text.trim();
    final symbol = ref.read(selectedSymbolProvider);

    if (_blockUnsafeWebLiveCredentials(updateCheckState: true)) {
      return;
    }

    if (apiKey.isEmpty || apiSecret.isEmpty) {
      setState(() {
        _binanceCheckState = _BinanceCheckState.failure;
        _binanceCheckMessage =
            'Enter both the Binance API key and secret before testing.';
        _binanceCheckAt = DateTime.now();
      });
      showAppToast(
        context,
        'Enter both the Binance API key and secret before testing.',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
      return;
    }

    setState(() {
      _isTestingBinance = true;
      _binanceCheckState = _BinanceCheckState.testing;
      _binanceCheckMessage = null;
      _binanceCheckRawDetails = null;
    });

    try {
      final api = BinanceApiService(
        apiKey: apiKey,
        apiSecret: apiSecret,
        isTestnet: _isTestnet,
      );

      Object? spotError;
      String spotSummary;
      if (_isTestnet) {
        spotSummary = 'Spot access is not checked in Demo Connection mode.';
      } else {
        try {
          await api.syncServerTime(scope: BinanceApiScope.spot);
          final spotAccountInfo = await api.getSpotAccountInfo();
          Map<String, dynamic>? spotRestrictions;
          try {
            spotRestrictions = await api.getSpotApiRestrictions();
          } catch (_) {}
          spotSummary = _buildSpotAccessSummary(
            spotAccountInfo,
            spotRestrictions,
          );
        } catch (error) {
          spotError = error;
          spotSummary = _friendlyBinanceConnectionError(
            error,
            capabilityLabel: 'optional Spot read access',
          );
        }
      }

      var futuresAccessVerified = false;
      try {
        await api.syncServerTime();
        final accountInfo = await api.getAccountInfo();
        final positions = await api.getPositionRisk(symbol: symbol);
        final trades = await api.getUserTrades(symbol: symbol, limit: 1);
        futuresAccessVerified = true;
        final settings = ref.read(settingsServiceProvider);

        final totalWalletBalance = _asDouble(accountInfo['totalWalletBalance']);
        final availableBalance = _asDouble(accountInfo['availableBalance']);
        final openPositionCount = positions.where((item) {
          if (item is! Map) return false;
          final amount = _asDouble(item['positionAmt']);
          return amount != null && amount != 0;
        }).length;
        final lastTradeNote = trades.isEmpty
            ? 'No recent $symbol fills were returned.'
            : 'Recent $symbol fills are accessible.';

        final spotAccessNote = _isTestnet
            ? spotSummary
            : spotError == null
            ? 'Optional Spot read access also passed. $spotSummary'
            : 'Optional Spot read access was unavailable, but it is not required for Futures. $spotSummary';
        final message =
            '${_isTestnet ? 'Demo Futures connection' : 'Live Futures connection'} is active. '
            '${totalWalletBalance != null ? 'Wallet ${totalWalletBalance.toStringAsFixed(2)} USDT. ' : ''}'
            '${availableBalance != null ? 'Available ${availableBalance.toStringAsFixed(2)} USDT. ' : ''}'
            '${openPositionCount > 0 ? 'Open positions: $openPositionCount. ' : 'No open position for $symbol. '}'
            '$lastTradeNote $spotAccessNote';

        await ref.read(currentStrategyReadyProvider.future);
        final mode = ref.read(currentStrategyModeProvider);
        if (!await _disarmRuntimeBeforeSettingsChange(
          symbol: symbol,
          reason: 'verified_binance_settings_changed',
        )) {
          if (!mounted) return;
          setState(() {
            _isTestingBinance = false;
            _binanceCheckState = _BinanceCheckState.failure;
            _binanceCheckMessage =
                '$message Connection verified, but the settings were not applied because working orders could not be reconciled.';
            _binanceCheckAt = DateTime.now();
          });
          return;
        }
        await _persistBinanceSettings(settings);
        await _refreshRuntimeProviders(symbol: symbol, mode: mode);

        if (!mounted) return;
        setState(() {
          _isTestingBinance = false;
          _binanceCheckState = _BinanceCheckState.success;
          _binanceCheckMessage = message;
          _binanceCheckRawDetails = spotError == null
              ? null
              : _binanceRawDetails(spotError);
          _binanceCheckAt = DateTime.now();
        });

        showAppToast(
          context,
          '${_isTestnet
              ? 'Demo Futures access passed. Spot is not required in Demo Connection. '
              : spotError == null
              ? 'Live Futures access passed. Optional Spot read access also passed. '
              : 'Live Futures access passed. Optional Spot read access was unavailable and is not required. '}The verified Futures settings were saved; automation is disarmed for review.',
          backgroundColor: AppColors.positive.withValues(alpha: 0.95),
          foregroundColor: Colors.white,
          icon: Icons.check_circle_outline,
        );
      } catch (error) {
        if (futuresAccessVerified) {
          if (!mounted) return;
          final message =
              'Futures access passed, but the verified settings could not be applied safely: $error';
          setState(() {
            _isTestingBinance = false;
            _binanceCheckState = _BinanceCheckState.failure;
            _binanceCheckMessage = message;
            _binanceCheckRawDetails = _binanceRawDetails(error);
            _binanceCheckAt = DateTime.now();
          });
          showAppToast(
            context,
            message,
            backgroundColor: AppColors.negative.withValues(alpha: 0.95),
            foregroundColor: Colors.white,
            icon: Icons.error_outline,
          );
          return;
        }
        final hasSpotReadOnlyAccess = !_isTestnet && spotError == null;
        final spotAccessNote = _isTestnet
            ? spotSummary
            : hasSpotReadOnlyAccess
            ? 'Optional Spot read access passed. $spotSummary'
            : 'Optional Spot read access was also unavailable. $spotSummary';
        final message =
            '${_friendlyFuturesCapabilityError(error)} $spotAccessNote';
        if (!mounted) return;
        setState(() {
          _isTestingBinance = false;
          _binanceCheckState = hasSpotReadOnlyAccess
              ? _BinanceCheckState.limited
              : _BinanceCheckState.failure;
          _binanceCheckMessage = message;
          _binanceCheckRawDetails = _binanceRawDetails(error);
          _binanceCheckAt = DateTime.now();
        });

        showAppToast(
          context,
          hasSpotReadOnlyAccess
              ? 'Optional Spot read access passed, but Live Futures access is unavailable for this key. The current values were not saved or applied.'
              : '${_isTestnet ? 'Demo Futures access is unavailable. Spot is not required in Demo Connection.' : 'Live Futures access is unavailable, and optional Spot read access was also unavailable.'} The values were not saved or applied.',
          backgroundColor:
              (hasSpotReadOnlyAccess ? AppColors.warning : AppColors.negative)
                  .withValues(alpha: 0.95),
          foregroundColor: Colors.white,
          icon: hasSpotReadOnlyAccess
              ? Icons.info_outline
              : Icons.error_outline,
        );
      }
    } catch (error) {
      final message = _friendlyBinanceConnectionError(
        error,
        capabilityLabel: 'the Binance access check',
      );
      if (!mounted) return;
      setState(() {
        _isTestingBinance = false;
        _binanceCheckState = _BinanceCheckState.failure;
        _binanceCheckMessage = message;
        _binanceCheckRawDetails = _binanceRawDetails(error);
        _binanceCheckAt = DateTime.now();
      });
      showAppToast(
        context,
        message,
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
    }
  }

  bool _blockUnsafeWebLiveCredentials({bool updateCheckState = false}) {
    final hasCredentials =
        _apiKeyController.text.trim().isNotEmpty ||
        _apiSecretController.text.trim().isNotEmpty;
    if (!kIsWeb || _isTestnet || !hasCredentials) {
      return false;
    }
    const message =
        'Live Binance credentials are blocked in the public web app because a browser cannot safely hold your API secret. Use Binance Demo here or configure Live Connection in the Windows desktop app.';
    if (updateCheckState) {
      setState(() {
        _binanceCheckState = _BinanceCheckState.failure;
        _binanceCheckMessage = message;
        _binanceCheckAt = DateTime.now();
      });
    }
    showAppToast(
      context,
      message,
      backgroundColor: AppColors.negative.withValues(alpha: 0.95),
      foregroundColor: Colors.white,
      icon: Icons.security_outlined,
      duration: const Duration(seconds: 6),
    );
    return true;
  }

  Future<void> _testAiConnection() async {
    if (!_validateAiConstraintFields()) {
      return;
    }
    final symbol = ref.read(selectedSymbolProvider);
    final strategy = AiStrategy(
      apiUrl: _aiUrlController.text.trim(),
      apiKey: _aiApiKeyController.text.trim(),
      provider: _selectedAiProvider,
      model: _aiModelController.text.trim(),
      symbolLabel: symbol,
      longBiasPrice: _parseDouble(_aiLongBiasController.text),
      shortBiasPrice: _parseDouble(_aiShortBiasController.text),
      longOrderType: _selectedAiLongOrderType,
      shortOrderType: _selectedAiShortOrderType,
      tradeDirectionMode: _selectedAiTradeDirectionMode,
      leverage:
          (_aiLeverageController.text.trim().isEmpty
              ? null
              : _parseInt(_aiLeverageController.text)) ??
          (_parseInt(_leverageController.text) ?? 1),
      maxInvestmentUsdt: _aiInvestmentUsdtController.text.trim().isEmpty
          ? null
          : _parseDouble(_aiInvestmentUsdtController.text),
      takeProfitPercent: _parseDouble(_takeProfitController.text) ?? 0,
      stopLossPercent: _parseDouble(_stopLossController.text) ?? 0,
    );

    setState(() {
      _isTestingAi = true;
      _aiCheckState = _AiCheckState.testing;
      _aiCheckMessage = null;
      _aiCheckRawDetails = null;
      _aiCheckAt = null;
    });

    var aiAccessVerified = false;
    try {
      final result = await strategy.verifyConnection();
      final checkedAt = result.checkedAt ?? DateTime.now();
      if (!mounted) return;

      if (result.state == AiServiceState.active) {
        aiAccessVerified = true;
        await ref.read(currentStrategyReadyProvider.future);
        final mode = ref.read(currentStrategyModeProvider);
        if (!await _disarmRuntimeBeforeSettingsChange(
          symbol: symbol,
          reason: 'verified_ai_settings_changed',
        )) {
          if (!mounted) return;
          setState(() {
            _isTestingAi = false;
            _aiCheckState = _AiCheckState.failure;
            _aiCheckMessage =
                'AI access passed, but the settings were not applied because working orders could not be reconciled.';
            _aiCheckRawDetails = null;
            _aiCheckAt = checkedAt;
          });
          return;
        }
        final settings = ref.read(settingsServiceProvider);
        await _persistAiSettings(settings);
        await _refreshRuntimeProviders(symbol: symbol, mode: mode);
        if (!mounted) return;
        setState(() {
          _isTestingAi = false;
          _aiCheckState = _AiCheckState.success;
          _aiCheckMessage = result.message;
          _aiCheckRawDetails = null;
          _aiCheckAt = checkedAt;
        });
        showAppToast(
          context,
          'AI API connection verified and applied. The active strategy was rebuilt and automation is disarmed for review.',
          backgroundColor: AppColors.positive.withValues(alpha: 0.95),
          foregroundColor: Colors.white,
          icon: Icons.check_circle_outline,
        );
        return;
      }

      setState(() {
        _isTestingAi = false;
        _aiCheckState = _AiCheckState.failure;
        _aiCheckMessage = result.message;
        _aiCheckRawDetails = result.message;
        _aiCheckAt = checkedAt;
      });
      showAppToast(
        context,
        result.message ?? 'AI API verification failed.',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
    } catch (error) {
      if (!mounted) return;
      final message = aiAccessVerified
          ? 'AI access passed, but the verified settings could not be applied safely: $error'
          : 'AI API verification failed: $error';
      setState(() {
        _isTestingAi = false;
        _aiCheckState = _AiCheckState.failure;
        _aiCheckMessage = message;
        _aiCheckRawDetails = '$error';
        _aiCheckAt = DateTime.now();
      });
      showAppToast(
        context,
        message,
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
    }
  }

  double? _asDouble(Object? value) {
    if (value == null) return null;
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value.toString());
    return parsed?.isFinite == true ? parsed : null;
  }

  int _countFundedSpotAssets(Map<String, dynamic> spotAccountInfo) {
    final balances = spotAccountInfo['balances'];
    if (balances is! List) {
      return 0;
    }

    return balances.where((item) {
      if (item is! Map) return false;
      final free = _asDouble(item['free']) ?? 0;
      final locked = _asDouble(item['locked']) ?? 0;
      return free != 0 || locked != 0;
    }).length;
  }

  String _buildSpotAccessSummary(
    Map<String, dynamic> spotAccountInfo,
    Map<String, dynamic>? spotRestrictions,
  ) {
    final fundedAssetCount = _countFundedSpotAssets(spotAccountInfo);
    final parts = <String>[
      fundedAssetCount > 0
          ? 'Spot returned $fundedAssetCount funded asset${fundedAssetCount == 1 ? '' : 's'}.'
          : 'Spot returned no funded assets.',
    ];

    final readingEnabled = spotRestrictions?['enableReading'];
    if (readingEnabled is bool) {
      parts.add(
        readingEnabled
            ? 'Read permission is enabled.'
            : 'Read permission is disabled.',
      );
    }

    final spotTradingEnabled = spotRestrictions?['enableSpotAndMarginTrading'];
    if (spotTradingEnabled is bool) {
      parts.add(
        spotTradingEnabled
            ? 'Spot trading is enabled.'
            : 'Spot trading is disabled.',
      );
    }

    final futuresEnabled = spotRestrictions?['enableFutures'];
    if (futuresEnabled is bool) {
      parts.add(
        futuresEnabled
            ? 'Futures permission is enabled on this key.'
            : 'Futures permission is disabled on this key.',
      );
    }

    return parts.join(' ');
  }

  String _friendlyBinanceConnectionError(
    Object error, {
    String capabilityLabel = 'the key',
  }) {
    if (error is BinanceApiException) {
      if (error.errorCode == -1022 || error.body.contains('-1022')) {
        return 'Binance rejected the signature. The API secret in Settings does not match the API key.';
      }
      if (error.errorCode == -1021 || error.body.contains('-1021')) {
        return 'Binance rejected the timestamp. The app retried with server time, but the request still failed.';
      }
      if (error.errorCode == -2015 ||
          error.errorCode == -2014 ||
          error.body.contains('-2015') ||
          error.body.contains('-2014')) {
        final requestIp = _extractRequestIp(error.body);
        final requestIpText = requestIp == null
            ? ''
            : ' Binance says the request is coming from $requestIp.';
        return 'Binance rejected $capabilityLabel. Check the API key and secret, whether the key is active, and whether it was pasted exactly.$requestIpText';
      }
      if (error.body.contains('-1003')) {
        return 'Binance rate-limited the request. Wait a moment and test again.';
      }
      return 'Binance returned an error: ${error.body}';
    }

    final text = error.toString().toLowerCase();
    if (text.contains('failed host lookup') ||
        text.contains('socketexception')) {
      return 'The app could not reach Binance. Check DNS, VPN/Tailscale, firewall rules, and whether Live Connection or Demo Connection is the correct target.';
    }
    if (text.contains('handshake') || text.contains('certificate')) {
      return 'TLS handshake failed while contacting Binance. Check network interception, antivirus HTTPS inspection, or system certificates.';
    }

    return 'Binance connection test failed: $error';
  }

  String _friendlyFuturesCapabilityError(Object error) {
    if (error is BinanceApiException &&
        (error.errorCode == -2015 ||
            error.errorCode == -2014 ||
            error.body.contains('-2015') ||
            error.body.contains('-2014'))) {
      final requestIp = _extractRequestIp(error.body);
      final requestIpText = requestIp == null
          ? ''
          : ' Binance says the futures request is coming from $requestIp.';
      return 'Futures endpoints still rejected this key. Check Futures permission, the selected connection mode, and whether this exact key is allowed for Futures.$requestIpText';
    }

    return _friendlyBinanceConnectionError(
      error,
      capabilityLabel: 'futures access',
    );
  }

  String? _binanceRawDetails(Object error) {
    if (error is! BinanceApiException) {
      return null;
    }

    final parts = <String>[
      'HTTP ${error.statusCode}',
      error.method,
      error.requestUri.toString(),
    ];
    if (error.errorCode != null) {
      parts.add('code ${error.errorCode}');
    }
    if (error.errorMessage != null && error.errorMessage!.trim().isNotEmpty) {
      parts.add(error.errorMessage!.trim());
    }
    return parts.join(' | ');
  }

  String? _extractRequestIp(String body) {
    final match = RegExp(r'request ip:\s*([0-9a-fA-F\.:]+)').firstMatch(body);
    return match?.group(1);
  }

  @override
  Widget build(BuildContext context) {
    final currentMode = ref.watch(currentStrategyModeProvider);
    final currentStrategy = ref.watch(currentStrategyProvider);
    final symbol = ref.watch(selectedSymbolProvider);
    final binanceStatus = ref.watch(binanceAccountStatusProvider(symbol));
    final aiStatus = ref.watch(aiServiceStatusProvider(symbol));

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bot Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Bot Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SettingsSection(
            title: 'Strategy Workspace',
            subtitle:
                'Choose the active mode here. Configuration, manual tickets, and backtesting live in Settings, while the live strategy terminal stays on the dashboard.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: ModeSelector(),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusPill(
                      label: 'Active: ${currentMode.label}',
                      color: _modeColor(currentMode),
                    ),
                    if (currentStrategy != null)
                      StatusPill(
                        label: currentStrategy.name,
                        color: AppColors.glowCyan,
                      ),
                    StatusPill(
                      label: 'Symbol: $symbol',
                      color: AppColors.glowAmber,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _strategyWorkspaceDescription(currentMode),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _WorkspaceBlock(
            title: 'Manual Workspace',
            subtitle:
                'Open, close, and override positions from here. Manual controls stay available even when AI or ALGO is the active mode.',
            child: ManualOrderTicket(symbol: symbol),
          ),
          const SizedBox(height: 16),
          if (currentMode == StrategyMode.algo) ...[
            _WorkspaceBlock(
              title: 'Algorithm Lab',
              subtitle:
                  'Run backtests here so RSI experiments and tuning stay grouped away from the live dashboard.',
              child: BacktestCard(symbol: symbol),
            ),
            const SizedBox(height: 16),
          ],
          _SettingsSection(
            title: 'Binance API Configuration',
            subtitle:
                'Choose whether this app talks to your real Binance account or the demo futures environment, then verify access below.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusPill(
                      label: _isTestnet
                          ? 'Connection: Demo'
                          : 'Connection: Live',
                      color: _isTestnet
                          ? AppColors.glowAmber
                          : AppColors.glowCyan,
                    ),
                    _buildSavedBinanceStatusPill(binanceStatus),
                    if (_hasUnsavedBinanceChanges)
                      const StatusPill(
                        label: 'Form: Unsaved',
                        color: AppColors.warning,
                      ),
                    if (_binanceCheckState != _BinanceCheckState.idle)
                      StatusPill(
                        label: switch (_binanceCheckState) {
                          _BinanceCheckState.testing => 'Access Check: Running',
                          _BinanceCheckState.success => 'Access Check: Passed',
                          _BinanceCheckState.limited =>
                            'Access Check: Read Only',
                          _BinanceCheckState.failure => 'Access Check: Failed',
                          _BinanceCheckState.idle => 'Access Check: Idle',
                        },
                        color: switch (_binanceCheckState) {
                          _BinanceCheckState.testing => AppColors.glowAmber,
                          _BinanceCheckState.success => AppColors.positive,
                          _BinanceCheckState.limited => AppColors.warning,
                          _BinanceCheckState.failure => AppColors.negative,
                          _BinanceCheckState.idle => AppColors.textMuted,
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoCallout(
                  title: 'Connection Target',
                  body: _isTestnet
                      ? 'Demo Connection uses Binance Futures demo on demo-fapi.binance.com.'
                      : 'Live Connection uses Binance Futures live on fapi.binance.com. Futures access is required; Spot read access is checked separately and is optional.',
                  accentColor: _isTestnet
                      ? AppColors.glowAmber
                      : AppColors.glowCyan,
                ),
                const SizedBox(height: 12),
                const _InfoCallout(
                  title: 'Save Behavior',
                  body:
                      'Verify & Apply now saves the API key, secret, and connection mode automatically when Binance accepts the credentials. Use Save Without Verify only if you want to store the values locally first.',
                  accentColor: AppColors.glowCyan,
                ),
                const SizedBox(height: 12),
                const _InfoCallout(
                  title: 'Trusted IP Tip',
                  body:
                      'If your ISP changes this PC public IP after a reboot or router reconnect, Binance trusted-IP keys can stop working even though the key is still valid. The stable fix is a static IP, a VPS, or a separate unrestricted read-only key for monitoring.',
                  accentColor: AppColors.warning,
                ),
                if (binanceStatus.hasValue &&
                    binanceStatus.valueOrNull?.message != null) ...[
                  const SizedBox(height: 12),
                  _InfoCallout(
                    title: 'Running App Status',
                    body: binanceStatus.valueOrNull!.message!,
                    accentColor: _binanceStatusColor(
                      binanceStatus.valueOrNull!.state,
                    ),
                  ),
                ],
                if (_hasUnsavedBinanceChanges) ...[
                  const SizedBox(height: 12),
                  const _InfoCallout(
                    title: 'Unsaved Binance Changes',
                    body:
                        'The form values on this screen differ from what the running app is using. Verify & Apply will save a working key automatically, while Save Without Verify stores the values locally right away.',
                    accentColor: AppColors.warning,
                  ),
                ],
                if (_binanceCheckMessage != null) ...[
                  const SizedBox(height: 12),
                  _InfoCallout(
                    title: switch (_binanceCheckState) {
                      _BinanceCheckState.success => 'Latest Access Check',
                      _BinanceCheckState.limited => 'Latest Access Summary',
                      _BinanceCheckState.failure => 'Latest Access Error',
                      _BinanceCheckState.testing => 'Latest Access Check',
                      _BinanceCheckState.idle => 'Latest Access Check',
                    },
                    body: _binanceCheckAt == null
                        ? _binanceCheckMessage!
                        : '${_binanceCheckMessage!}\nChecked at ${_formatTimestamp(_binanceCheckAt!)}',
                    accentColor: switch (_binanceCheckState) {
                      _BinanceCheckState.success => AppColors.positive,
                      _BinanceCheckState.limited => AppColors.warning,
                      _BinanceCheckState.failure => AppColors.negative,
                      _BinanceCheckState.testing => AppColors.glowAmber,
                      _BinanceCheckState.idle => AppColors.border,
                    },
                  ),
                ],
                if (_binanceCheckRawDetails != null) ...[
                  const SizedBox(height: 12),
                  _InfoCallout(
                    title: 'Raw Binance Response',
                    body: _binanceCheckAt == null
                        ? _binanceCheckRawDetails!
                        : '${_binanceCheckRawDetails!}\nChecked at ${_formatTimestamp(_binanceCheckAt!)}',
                    accentColor: AppColors.textSecondary,
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _apiKeyController,
                  decoration: const InputDecoration(labelText: 'API Key'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _apiSecretController,
                  decoration: const InputDecoration(labelText: 'API Secret'),
                  obscureText: true,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Connection Mode',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ChoiceChip(
                      label: Text(
                        kIsWeb ? 'Live: Desktop Only' : 'Live Connection',
                      ),
                      selected: !_isTestnet,
                      onSelected: kIsWeb
                          ? null
                          : (_) => setState(() => _isTestnet = false),
                    ),
                    ChoiceChip(
                      label: const Text('Demo Connection'),
                      selected: _isTestnet,
                      onSelected: (_) => setState(() => _isTestnet = true),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _isTestnet
                        ? 'Demo Connection uses Binance Futures testnet. It changes the target only; access still needs to be verified below.'
                        : (kIsWeb
                              ? 'Public web safety mode will not use or verify live Binance credentials, and live credential changes cannot be saved here. Use the Windows desktop app for authenticated live access.'
                              : 'Live Connection uses your real Binance account. It changes the target only; access still needs to be verified below.'),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 220,
                      child: OutlinedButton.icon(
                        onPressed: _saveBinanceSettingsOnly,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('SAVE WITHOUT VERIFY'),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: ElevatedButton.icon(
                        onPressed: _isTestingBinance
                            ? null
                            : _testBinanceConnection,
                        icon: Icon(
                          _isTestingBinance
                              ? Icons.hourglass_top
                              : Icons.verified_outlined,
                        ),
                        label: Text(
                          _isTestingBinance ? 'VERIFYING...' : 'VERIFY & APPLY',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'AI Strategy Configuration',
            subtitle:
                'Connect the AI provider here. Live trader rules like side, leverage, and margin budget are now controlled from the dashboard desk.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusPill(
                      label: 'Provider: ${_selectedAiProvider.label}',
                      color: AppColors.glowCyan,
                    ),
                    _buildSavedAiStatusPill(aiStatus),
                    if (_hasUnsavedAiChanges)
                      const StatusPill(
                        label: 'AI Form: Unsaved',
                        color: AppColors.warning,
                      ),
                    if (_aiCheckState != _AiCheckState.idle)
                      StatusPill(
                        label: switch (_aiCheckState) {
                          _AiCheckState.testing => 'AI Check: Running',
                          _AiCheckState.success => 'AI Check: Passed',
                          _AiCheckState.failure => 'AI Check: Failed',
                          _AiCheckState.idle => 'AI Check: Idle',
                        },
                        color: switch (_aiCheckState) {
                          _AiCheckState.testing => AppColors.glowAmber,
                          _AiCheckState.success => AppColors.positive,
                          _AiCheckState.failure => AppColors.negative,
                          _AiCheckState.idle => AppColors.textMuted,
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoCallout(
                  title: 'AI Target',
                  body:
                      '${_selectedAiProvider.label} is the active AI provider. Verify & Apply sends a small live request so the app can confirm the URL, model, API key, and trader constraints before using AI mode.',
                  accentColor: AppColors.glowCyan,
                ),
                if (kIsWeb) ...[
                  const SizedBox(height: 12),
                  const _InfoCallout(
                    title: 'Browser API-Key Warning',
                    body:
                        'AI provider keys entered in this public web app are sent from and stored on this browser. They cannot be kept like a server-side secret. Prefer the desktop app; otherwise use a restricted, revocable key with a strict spend limit.',
                    accentColor: AppColors.negative,
                  ),
                ],
                const SizedBox(height: 12),
                const _InfoCallout(
                  title: 'Dashboard Rules',
                  body:
                      'Use the AI Trade Rules strip at the top of the dashboard to set Long Only, Short Only, leverage, and USDT margin budget. Settings now focuses on provider connectivity and advanced behavior.',
                  accentColor: AppColors.warning,
                ),
                if (aiStatus.hasValue &&
                    aiStatus.valueOrNull?.message != null) ...[
                  const SizedBox(height: 12),
                  _InfoCallout(
                    title: 'Running AI Status',
                    body: aiStatus.valueOrNull!.message!,
                    accentColor: _aiStatusColor(aiStatus.valueOrNull!.state),
                  ),
                ],
                if (_hasUnsavedAiChanges) ...[
                  const SizedBox(height: 12),
                  const _InfoCallout(
                    title: 'Unsaved AI Changes',
                    body:
                        'The AI values on this screen differ from what the running app is using. Verify & Apply saves a working AI setup automatically, while Save Without Verify stores the values locally right away.',
                    accentColor: AppColors.warning,
                  ),
                ],
                if (_aiCheckMessage != null) ...[
                  const SizedBox(height: 12),
                  _InfoCallout(
                    title: switch (_aiCheckState) {
                      _AiCheckState.success => 'Latest AI Check',
                      _AiCheckState.failure => 'Latest AI Error',
                      _AiCheckState.testing => 'Latest AI Check',
                      _AiCheckState.idle => 'Latest AI Check',
                    },
                    body: _aiCheckAt == null
                        ? _aiCheckMessage!
                        : '${_aiCheckMessage!}\nChecked at ${_formatTimestamp(_aiCheckAt!)}',
                    accentColor: switch (_aiCheckState) {
                      _AiCheckState.success => AppColors.positive,
                      _AiCheckState.failure => AppColors.negative,
                      _AiCheckState.testing => AppColors.glowAmber,
                      _AiCheckState.idle => AppColors.border,
                    },
                  ),
                ],
                if (_aiCheckRawDetails != null) ...[
                  const SizedBox(height: 12),
                  _InfoCallout(
                    title: 'Raw AI Response',
                    body: _aiCheckAt == null
                        ? _aiCheckRawDetails!
                        : '${_aiCheckRawDetails!}\nChecked at ${_formatTimestamp(_aiCheckAt!)}',
                    accentColor: AppColors.textSecondary,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<AiProvider>(
                        value: _selectedAiProvider,
                        decoration: const InputDecoration(
                          labelText: 'AI Provider',
                        ),
                        items: AiProvider.values
                            .map(
                              (provider) => DropdownMenuItem(
                                value: provider,
                                child: Text(provider.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedAiProvider = value;
                            if (_aiUrlController.text.trim().isEmpty ||
                                _aiUrlController.text.contains(
                                  'your-ai-api.com',
                                )) {
                              _aiUrlController.text = value.defaultUrl;
                            }
                            if (_aiModelController.text.trim().isEmpty) {
                              _aiModelController.text = value.defaultModel;
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: kIsWeb ? null : _importAutomationAiConfig,
                        icon: const Icon(Icons.download_outlined),
                        label: Text(
                          kIsWeb ? 'DESKTOP ONLY' : 'IMPORT AUTOMATION',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _aiApiKeyController,
                  decoration: const InputDecoration(labelText: 'AI API Key'),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _aiUrlController,
                  decoration: const InputDecoration(
                    labelText: 'AI Analysis URL',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _aiModelController,
                  decoration: const InputDecoration(labelText: 'AI Model'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _aiLongBiasController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Long Bias At Or Below',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _aiShortBiasController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Short Bias At Or Above',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<ManualOrderType>(
                        value: _selectedAiLongOrderType,
                        decoration: const InputDecoration(
                          labelText: 'Preferred Long Order Type',
                        ),
                        items: ManualOrderType.values
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedAiLongOrderType = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<ManualOrderType>(
                        value: _selectedAiShortOrderType,
                        decoration: const InputDecoration(
                          labelText: 'Preferred Short Order Type',
                        ),
                        items: ManualOrderType.values
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedAiShortOrderType = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Provider keys and advanced AI behavior live here. Trading side, leverage, and budget now live on the dashboard so the trader can change them without leaving the market view.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 220,
                      child: OutlinedButton.icon(
                        onPressed: _saveAiSettingsOnly,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('SAVE AI WITHOUT VERIFY'),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: ElevatedButton.icon(
                        onPressed: _isTestingAi ? null : _testAiConnection,
                        icon: Icon(
                          _isTestingAi
                              ? Icons.hourglass_top
                              : Icons.psychology_alt_outlined,
                        ),
                        label: Text(
                          _isTestingAi ? 'VERIFYING...' : 'VERIFY AI & APPLY',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'RSI Strategy Tuning',
            subtitle: 'Choose a preset or fine-tune the algorithm manually.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in rsiStrategyPresets)
                      ChoiceChip(
                        label: Text(preset.label),
                        selected: _selectedRsiPreset?.key == preset.key,
                        onSelected: (_) => _applyRsiPreset(preset),
                      ),
                    Chip(
                      label: Text(_selectedRsiPreset?.label ?? 'Custom'),
                      backgroundColor: AppColors.surfaceAlt,
                      side: BorderSide(
                        color: _selectedRsiPreset != null
                            ? AppColors.glowCyan
                            : AppColors.warning,
                      ),
                      labelStyle: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedRsiPreset?.description ??
                      'Custom RSI values are active. Save to apply them to ALGO mode and backtests.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _rsiPeriodController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'RSI Period'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _rsiOverboughtController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'RSI Overbought',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _rsiOversoldController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'RSI Oversold'),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'Symbols',
            subtitle:
                'Comma-separated Futures symbols. ARIAUSDT, TRIAUSDT, SIRENUSDT, BTCUSDT, and TRUUSDT are always included.',
            child: TextField(
              controller: _symbolListController,
              decoration: const InputDecoration(
                labelText:
                    'Symbols (e.g., ARIAUSDT, TRIAUSDT, SIRENUSDT, BTCUSDT)',
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'Trading Controls',
            subtitle:
                'Risk, leverage, sizing, and protection rules now live on the dashboard trading desk beside the live chart.',
            child: const _InfoCallout(
              title: 'Moved To Dashboard',
              body:
                  'Open the dashboard to control stop loss, take profit, quantity, leverage, cooldown, and protection rules. Keeping them on the desk makes START AUTO, waiting states, and live chart decisions easier to read together.',
              accentColor: AppColors.glowAmber,
            ),
          ),
          const SizedBox(height: 20),
          AppPanel(
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveSettings,
                    child: const Text('SAVE SETTINGS'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _modeColor(StrategyMode mode) {
    return switch (mode) {
      StrategyMode.manual => AppColors.glowAmber,
      StrategyMode.algo => AppColors.positive,
      StrategyMode.ai => AppColors.glowCyan,
    };
  }

  String _strategyWorkspaceDescription(StrategyMode mode) {
    return switch (mode) {
      StrategyMode.manual =>
        'Manual mode keeps the order desk here in Settings. Use it to override AI or ALGO cleanly while the dashboard continues to show live activity.',
      StrategyMode.algo =>
        'ALGO mode keeps RSI tuning and backtests here, while the dashboard shows the live strategy terminal and market/account context.',
      StrategyMode.ai =>
        'AI mode keeps provider setup and bias zones here, while the dashboard shows the live strategy terminal and account activity.',
    };
  }

  Widget _buildSavedBinanceStatusPill(AsyncValue<BinanceAccountStatus> status) {
    return status.when(
      data: (data) => StatusPill(
        label: switch (data.state) {
          BinanceAccountState.notConfigured => 'App Status: Not Configured',
          BinanceAccountState.checking => 'App Status: Checking',
          BinanceAccountState.active => 'App Status: Active',
          BinanceAccountState.limited => 'App Status: Read Only',
          BinanceAccountState.attentionRequired => 'App Status: Attention',
        },
        color: _binanceStatusColor(data.state),
      ),
      loading: () => const StatusPill(
        label: 'App Status: Checking',
        color: AppColors.glowAmber,
      ),
      error: (error, stack) => const StatusPill(
        label: 'App Status: Error',
        color: AppColors.negative,
      ),
    );
  }

  Widget _buildSavedAiStatusPill(AsyncValue<AiServiceStatus> status) {
    return status.when(
      data: (data) => StatusPill(
        label: switch (data.state) {
          AiServiceState.notConfigured => 'AI API: Not Configured',
          AiServiceState.checking => 'AI API: Checking',
          AiServiceState.active => 'AI API: Active',
          AiServiceState.attentionRequired => 'AI API: Attention',
        },
        color: _aiStatusColor(data.state),
      ),
      loading: () => const StatusPill(
        label: 'AI API: Checking',
        color: AppColors.glowAmber,
      ),
      error: (error, stack) =>
          const StatusPill(label: 'AI API: Error', color: AppColors.negative),
    );
  }

  Color _binanceStatusColor(BinanceAccountState state) {
    return switch (state) {
      BinanceAccountState.notConfigured => AppColors.warning,
      BinanceAccountState.checking => AppColors.glowAmber,
      BinanceAccountState.active => AppColors.positive,
      BinanceAccountState.limited => AppColors.warning,
      BinanceAccountState.attentionRequired => AppColors.negative,
    };
  }

  Color _aiStatusColor(AiServiceState state) {
    return switch (state) {
      AiServiceState.notConfigured => AppColors.warning,
      AiServiceState.checking => AppColors.glowAmber,
      AiServiceState.active => AppColors.positive,
      AiServiceState.attentionRequired => AppColors.negative,
    };
  }

  String _formatTimestamp(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} $hour:$minute $suffix';
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _WorkspaceBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _WorkspaceBlock({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

enum _BinanceCheckState { idle, testing, success, limited, failure }

enum _AiCheckState { idle, testing, success, failure }

class _InfoCallout extends StatelessWidget {
  final String title;
  final String body;
  final Color accentColor;

  const _InfoCallout({
    required this.title,
    required this.body,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: accentColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
