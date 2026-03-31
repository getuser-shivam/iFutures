import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trading_provider.dart';
import '../models/ai_provider.dart';
import '../models/manual_order.dart';
import '../constants/symbols.dart';
import '../models/rsi_strategy_preset.dart';
import '../models/strategy_mode.dart';
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
  late TextEditingController _rsiPeriodController;
  late TextEditingController _rsiOverboughtController;
  late TextEditingController _rsiOversoldController;
  AiProvider _selectedAiProvider = AiProvider.groqChat;
  ManualOrderType _selectedAiLongOrderType = ManualOrderType.limit;
  ManualOrderType _selectedAiShortOrderType = ManualOrderType.limit;
  bool _isTestnet = true;
  bool _isLoading = true;

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
      _aiUrlController.text = settings.getAiUrl();
      _aiApiKeyController.text = aiApiKey ?? '';
      _aiModelController.text = settings.getAiModel();
      _aiLongBiasController.text =
          settings.getAiLongBiasPrice()?.toString() ?? '';
      _aiShortBiasController.text =
          settings.getAiShortBiasPrice()?.toString() ?? '';
      _selectedAiProvider = aiProviderFromKey(settings.getAiProvider());
      _selectedAiLongOrderType = ManualOrderType.values.byName(
        settings.getAiLongOrderType(),
      );
      _selectedAiShortOrderType = ManualOrderType.values.byName(
        settings.getAiShortOrderType(),
      );
      _symbolListController.text = symbolText;
      _isTestnet = settings.getIsTestnet();
      _stopLossController.text = settings.getRiskStopLossPercent().toString();
      _takeProfitController.text = settings
          .getRiskTakeProfitPercent()
          .toString();
      _tradeQuantityController.text = settings
          .getRiskTradeQuantity()
          .toString();
      _leverageController.text = settings.getRiskLeverage().toString();
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

    await settings.setApiKey(_apiKeyController.text);
    await settings.setApiSecret(_apiSecretController.text);
    await settings.setAiUrl(_aiUrlController.text);
    await settings.setAiApiKey(_aiApiKeyController.text);
    await settings.setAiProvider(_selectedAiProvider.key);
    await settings.setAiModel(_aiModelController.text.trim());
    await settings.setAiLongBiasPrice(aiLongBias);
    await settings.setAiShortBiasPrice(aiShortBias);
    await settings.setAiLongOrderType(_selectedAiLongOrderType.name);
    await settings.setAiShortOrderType(_selectedAiShortOrderType.name);
    await settings.setIsTestnet(_isTestnet);
    await settings.setSymbolList(symbols);
    await settings.setRiskStopLossPercent(stopLoss);
    await settings.setRiskTakeProfitPercent(takeProfit);
    await settings.setRiskTradeQuantity(tradeQuantity);
    await settings.setRiskLeverage(leverage);
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
      ref.invalidate(binanceApiProvider);
      ref.invalidate(binanceWsProvider);
      ref.invalidate(aiStrategyProvider);
      ref.invalidate(riskSettingsProvider);
      ref.invalidate(symbolListProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentMode = ref.watch(currentStrategyModeProvider);
    final currentStrategy = ref.watch(currentStrategyProvider);
    final symbol = ref.watch(selectedSymbolProvider);

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
            subtitle: 'Connect securely to your exchange account.',
            child: Column(
              children: [
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
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Use Testnet'),
                  value: _isTestnet,
                  activeThumbColor: AppColors.glowCyan,
                  onChanged: (val) => setState(() => _isTestnet = val),
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
                  'AI mode uses these zones as guidance. Stop loss, take profit, and leverage come from the Risk Management section below.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
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
                'Percent-based stops and fixed position sizing. The dashboard converts this quantity into estimated USDT exposure and margin.',
            child: Column(
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
