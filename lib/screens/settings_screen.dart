import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trading_provider.dart';
import '../models/ai_provider.dart';
import '../models/ai_service_status.dart';
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
import '../trading/algo_strategy.dart';
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
  bool _isTestnet = true;
  String _savedApiKey = '';
  String _savedApiSecret = '';
  bool _savedIsTestnet = true;
  String _savedAiApiKey = '';
  String _savedAiUrl = '';
  String _savedAiModel = '';
  String _savedAiLongBias = '';
  String _savedAiShortBias = '';
  AiProvider _savedAiProvider = AiProvider.groqChat;
  ManualOrderType _savedAiLongOrderType = ManualOrderType.limit;
  ManualOrderType _savedAiShortOrderType = ManualOrderType.limit;
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

    final apiKey = await settings.getApiKey();
    final apiSecret = await settings.getApiSecret();
    final aiApiKey = await settings.getAiApiKey();
    final storedSymbols = settings.getSymbolList();
    final symbolText = normalizeSymbolList(
      storedSymbols == null || storedSymbols.isEmpty
          ? defaultSymbols
          : storedSymbols,
      requiredSymbols: [triausdtSymbol],
    ).join(', ');

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
      _symbolListController.text = symbolText;
      _isTestnet = settings.getIsTestnet();
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
    return double.tryParse(normalized);
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
      requiredSymbols: [triausdtSymbol],
    );
  }

  ManualOrderType _parseOrderType(String value) {
    return ManualOrderType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => ManualOrderType.limit,
    );
  }

  Future<void> _importAutomationAiConfig() async {
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
    final stopLoss = _parseDouble(_stopLossController.text);
    final takeProfit = _parseDouble(_takeProfitController.text);
    final tradeQuantity = _parseDouble(_tradeQuantityController.text);
    final leverage = _parseInt(_leverageController.text);
    final cooldownMinutes = _parseInt(_cooldownMinutesController.text);
    final protectionPauseMinutes = _parseInt(
      _protectionPauseMinutesController.text,
    );
    final maxConsecutiveLosses = _parseInt(
      _maxConsecutiveLossesController.text,
    );
    final maxDrawdownPercent = _parseDouble(_maxDrawdownController.text);
    final symbols = _parseSymbolList(_symbolListController.text);
    final rsiPeriod = _parseInt(_rsiPeriodController.text);
    final rsiOverbought = _parseDouble(_rsiOverboughtController.text);
    final rsiOversold = _parseDouble(_rsiOversoldController.text);
    final aiLongBias = _parseDouble(_aiLongBiasController.text);
    final aiShortBias = _parseDouble(_aiShortBiasController.text);

    if (stopLoss == null || stopLoss < 0) {
      showAppToast(
        context,
        'Stop loss must be a valid number (0 or greater).',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
      return;
    }

    if (takeProfit == null || takeProfit < 0) {
      showAppToast(
        context,
        'Take profit must be a valid number (0 or greater).',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
      return;
    }

    if (tradeQuantity == null || tradeQuantity <= 0) {
      showAppToast(
        context,
        'Trade quantity must be greater than 0.',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
      return;
    }

    if (leverage == null || leverage < 1 || leverage > 125) {
      showAppToast(
        context,
        'Leverage must be an integer between 1 and 125.',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
      return;
    }

    if (cooldownMinutes == null || cooldownMinutes < 0) {
      showAppToast(
        context,
        'Cooldown must be 0 or a positive whole number of minutes.',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
      return;
    }

    if (protectionPauseMinutes == null || protectionPauseMinutes < 0) {
      showAppToast(
        context,
        'Protection pause must be 0 or a positive whole number of minutes.',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
      return;
    }

    if (maxConsecutiveLosses == null || maxConsecutiveLosses < 0) {
      showAppToast(
        context,
        'Max consecutive losses must be 0 or a positive whole number.',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
      return;
    }

    if (maxDrawdownPercent == null || maxDrawdownPercent < 0) {
      showAppToast(
        context,
        'Max drawdown must be 0 or a positive percentage.',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
      return;
    }

    if ((maxConsecutiveLosses > 0 || maxDrawdownPercent > 0) &&
        protectionPauseMinutes == 0) {
      showAppToast(
        context,
        'Set a protection pause above 0 minutes when loss-streak or drawdown locks are enabled.',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
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

    await _persistBinanceSettings(settings);
    await _persistAiSettings(settings);
    await settings.setSymbolList(symbols);
    await settings.setRiskStopLossPercent(stopLoss);
    await settings.setRiskTakeProfitPercent(takeProfit);
    await settings.setRiskTradeQuantity(tradeQuantity);
    await settings.setRiskLeverage(leverage);
    await settings.setRiskCooldownMinutes(cooldownMinutes);
    await settings.setRiskProtectionPauseMinutes(protectionPauseMinutes);
    await settings.setRiskMaxConsecutiveLosses(maxConsecutiveLosses);
    await settings.setRiskMaxDrawdownPercent(maxDrawdownPercent);
    await settings.setRsiPeriod(rsiPeriod);
    await settings.setRsiOverbought(rsiOverbought);
    await settings.setRsiOversold(rsiOversold);

    final currentStrategy = ref.read(currentStrategyProvider);
    if (currentStrategy is RsiStrategy) {
      await ref
          .read(currentStrategyProvider.notifier)
          .setMode(StrategyMode.algo, symbol: ref.read(selectedSymbolProvider));
    } else if (currentStrategy is AiStrategy) {
      final symbol = ref.read(selectedSymbolProvider);
      await ref
          .read(currentStrategyProvider.notifier)
          .setMode(StrategyMode.ai, symbol: symbol);
    }

    if (mounted) {
      showAppToast(
        context,
        'Settings saved successfully',
        backgroundColor: AppColors.positive.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.check_circle_outline,
      );
      _invalidateRuntimeProviders();
    }
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

    _savedAiApiKey = aiApiKey;
    _savedAiUrl = aiUrl;
    _savedAiModel = aiModel;
    _savedAiLongBias = _aiLongBiasController.text.trim();
    _savedAiShortBias = _aiShortBiasController.text.trim();
    _savedAiProvider = _selectedAiProvider;
    _savedAiLongOrderType = _selectedAiLongOrderType;
    _savedAiShortOrderType = _selectedAiShortOrderType;
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
        _selectedAiProvider != _savedAiProvider ||
        _selectedAiLongOrderType != _savedAiLongOrderType ||
        _selectedAiShortOrderType != _savedAiShortOrderType;
  }

  void _invalidateRuntimeProviders() {
    final symbol = ref.read(selectedSymbolProvider);
    ref.invalidate(binanceApiProvider);
    ref.invalidate(binanceWsProvider);
    ref.invalidate(aiStrategyProvider);
    ref.invalidate(riskSettingsProvider);
    ref.invalidate(symbolListProvider);
    ref.invalidate(tradingEngineProvider(symbol));
    ref.invalidate(connectionStatusProvider(symbol));
    ref.invalidate(binanceAccountStatusProvider(symbol));
    ref.invalidate(aiServiceStatusProvider(symbol));
  }

  Future<void> _saveBinanceSettingsOnly() async {
    final settings = ref.read(settingsServiceProvider);
    await _persistBinanceSettings(settings);
    _invalidateRuntimeProviders();
    if (!mounted) return;
    showAppToast(
      context,
      'API keys saved locally. The running app will now use this ${_isTestnet ? 'demo' : 'live'} connection and key pair.',
      backgroundColor: AppColors.positive.withValues(alpha: 0.95),
      foregroundColor: Colors.white,
      icon: Icons.verified_user_outlined,
    );
  }

  Future<void> _saveAiSettingsOnly() async {
    final settings = ref.read(settingsServiceProvider);
    await _persistAiSettings(settings);
    _invalidateRuntimeProviders();
    if (!mounted) return;
    showAppToast(
      context,
      'AI API settings saved locally. The running app will now use this AI provider configuration.',
      backgroundColor: AppColors.positive.withValues(alpha: 0.95),
      foregroundColor: Colors.white,
      icon: Icons.psychology_alt_outlined,
    );
  }

  Future<void> _testBinanceConnection() async {
    final apiKey = _apiKeyController.text.trim();
    final apiSecret = _apiSecretController.text.trim();
    final symbol = ref.read(selectedSymbolProvider);

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

      String spotSummary = '';
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
        if (_isTestnet) {
          spotSummary = 'Spot access is skipped in Demo Connection mode.';
        } else {
          rethrow;
        }
      }

      try {
        await api.syncServerTime();
        final accountInfo = await api.getAccountInfo();
        final positions = await api.getPositionRisk(symbol: symbol);
        final trades = await api.getUserTrades(symbol: symbol, limit: 1);
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

        final spotStatusPrefix = _isTestnet
            ? 'Spot access check bypassed.'
            : 'Spot read access verified.';
        final message =
            '$spotStatusPrefix $spotSummary '
            '${_isTestnet ? 'Demo Futures connection' : 'Live Futures connection'} is active. '
            '${totalWalletBalance != null ? 'Wallet ${totalWalletBalance.toStringAsFixed(2)} USDT. ' : ''}'
            '${availableBalance != null ? 'Available ${availableBalance.toStringAsFixed(2)} USDT. ' : ''}'
            '${openPositionCount > 0 ? 'Open positions: $openPositionCount. ' : 'No open position for $symbol. '}'
            '$lastTradeNote';

        await _persistBinanceSettings(settings);
        _invalidateRuntimeProviders();

        setState(() {
          _isTestingBinance = false;
          _binanceCheckState = _BinanceCheckState.success;
          _binanceCheckMessage = message;
          _binanceCheckRawDetails = null;
          _binanceCheckAt = DateTime.now();
        });

        if (!mounted) return;
        showAppToast(
          context,
          '${_isTestnet ? 'Demo Spot skipped. ' : 'Spot read access passed. '}${_isTestnet ? 'Demo Futures access passed.' : 'Live Futures access passed.'} The verified Binance settings have been saved and applied.',
          backgroundColor: AppColors.positive.withValues(alpha: 0.95),
          foregroundColor: Colors.white,
          icon: Icons.check_circle_outline,
        );
      } catch (error) {
        final spotStatusPrefix = _isTestnet
            ? 'Spot access check bypassed.'
            : 'Spot read access verified.';
        final message =
            '$spotStatusPrefix $spotSummary ${_friendlyFuturesCapabilityError(error)}';
        final settings = ref.read(settingsServiceProvider);
        await _persistBinanceSettings(settings);
        _invalidateRuntimeProviders();
        setState(() {
          _isTestingBinance = false;
          _binanceCheckState = _BinanceCheckState.limited;
          _binanceCheckMessage = message;
          _binanceCheckRawDetails = _binanceRawDetails(error);
          _binanceCheckAt = DateTime.now();
        });

        if (!mounted) return;
        showAppToast(
          context,
          '${_isTestnet ? 'Demo Spot skipped. ' : 'Spot read access passed, but '}${_isTestnet ? 'Demo Futures access' : 'Live Futures access'} is still unavailable for this key. The current values were saved and applied for read-only monitoring.',
          backgroundColor: AppColors.warning.withValues(alpha: 0.95),
          foregroundColor: Colors.white,
          icon: Icons.info_outline,
        );
      }
    } catch (error) {
      final message = _friendlyBinanceConnectionError(
        error,
        capabilityLabel: 'spot read access',
      );
      setState(() {
        _isTestingBinance = false;
        _binanceCheckState = _BinanceCheckState.failure;
        _binanceCheckMessage = message;
        _binanceCheckRawDetails = _binanceRawDetails(error);
        _binanceCheckAt = DateTime.now();
      });

      if (!mounted) return;
      showAppToast(
        context,
        message,
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
    }
  }

  Future<void> _testAiConnection() async {
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
      leverage: _parseInt(_leverageController.text) ?? 1,
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

    try {
      final result = await strategy.verifyConnection();
      final checkedAt = result.checkedAt ?? DateTime.now();

      if (result.state == AiServiceState.active) {
        final settings = ref.read(settingsServiceProvider);
        await _persistAiSettings(settings);
        _invalidateRuntimeProviders();
        setState(() {
          _isTestingAi = false;
          _aiCheckState = _AiCheckState.success;
          _aiCheckMessage = result.message;
          _aiCheckRawDetails = null;
          _aiCheckAt = checkedAt;
        });
        if (!mounted) return;
        showAppToast(
          context,
          'AI API connection verified and applied.',
          backgroundColor: AppColors.positive.withValues(alpha: 0.95),
          foregroundColor: Colors.white,
          icon: Icons.check_circle_outline,
        );
        return;
      }

      final failedState = result.state == AiServiceState.notConfigured
          ? _AiCheckState.failure
          : _AiCheckState.failure;
      setState(() {
        _isTestingAi = false;
        _aiCheckState = failedState;
        _aiCheckMessage = result.message;
        _aiCheckRawDetails = result.message;
        _aiCheckAt = checkedAt;
      });
      if (!mounted) return;
      showAppToast(
        context,
        result.message ?? 'AI API verification failed.',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
    } catch (error) {
      setState(() {
        _isTestingAi = false;
        _aiCheckState = _AiCheckState.failure;
        _aiCheckMessage = 'AI API verification failed: $error';
        _aiCheckRawDetails = '$error';
        _aiCheckAt = DateTime.now();
      });
      if (!mounted) return;
      showAppToast(
        context,
        'AI API verification failed: $error',
        backgroundColor: AppColors.negative.withValues(alpha: 0.95),
        foregroundColor: Colors.white,
        icon: Icons.error_outline,
      );
    }
  }

  double? _asDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
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
                      ? 'Demo Connection uses Binance Futures testnet on testnet.binancefuture.com.'
                      : 'Live Connection uses Binance Futures live on fapi.binance.com and checks Spot read access first.',
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
                      label: const Text('Live Connection'),
                      selected: !_isTestnet,
                      onSelected: (_) => setState(() => _isTestnet = false),
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
                        : 'Live Connection uses your real Binance account. It changes the target only; access still needs to be verified below.',
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
                'Choose the AI provider, import local automation credentials, and define the price zones AI should respect.',
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
                      '${_selectedAiProvider.label} is the active AI provider. Verify & Apply sends a small live request so the app can confirm the URL, model, and API key before using AI mode.',
                  accentColor: AppColors.glowCyan,
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
                        onPressed: _importAutomationAiConfig,
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('IMPORT AUTOMATION'),
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
                  'AI mode uses these zones as guidance. Stop loss, take profit, and leverage come from the Risk Management section below, and AI can scale the configured max quantity down when the setup looks weaker.',
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
                'Comma-separated list of tradable symbols. TRIAUSDT is included by default.',
            child: TextField(
              controller: _symbolListController,
              decoration: const InputDecoration(
                labelText: 'Symbols (e.g., BTCUSDT, ETHUSDT, TRIAUSDT)',
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'Risk Management',
            subtitle:
                'Percent-based stops, fixed position sizing, and auto-entry protections. The dashboard converts this quantity into estimated USDT exposure and margin.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _stopLossController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Stop Loss (%)'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _takeProfitController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Take Profit (%)',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _tradeQuantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Trade Quantity (base units)',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _leverageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Leverage (x)'),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            color: AppColors.glowAmber,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Protection Engine',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Set any field to 0 to disable it. Cooldown pauses new auto entries after an exit. Loss-streak and drawdown locks pause auto entries for the configured protection window.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _cooldownMinutesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cooldown After Exit (minutes)',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _protectionPauseMinutesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Protection Pause Window (minutes)',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _maxConsecutiveLossesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max Consecutive Losses',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _maxDrawdownController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Max Realized Drawdown (%)',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppPanel(
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveSettings,
                    child: const Text('SAVE ALL SETTINGS'),
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
