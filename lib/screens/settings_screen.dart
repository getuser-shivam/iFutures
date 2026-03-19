import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trading_provider.dart';
import '../constants/symbols.dart';
import '../models/rsi_strategy_preset.dart';
import '../theme/app_theme.dart';
import '../widgets/common/app_panel.dart';
import '../widgets/common/app_toast.dart';
import '../trading/algo_strategy.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _apiKeyController;
  late TextEditingController _apiSecretController;
  late TextEditingController _aiUrlController;
  late TextEditingController _symbolListController;
  late TextEditingController _stopLossController;
  late TextEditingController _takeProfitController;
  late TextEditingController _tradeQuantityController;
  late TextEditingController _rsiPeriodController;
  late TextEditingController _rsiOverboughtController;
  late TextEditingController _rsiOversoldController;
  bool _isTestnet = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    _apiSecretController = TextEditingController();
    _aiUrlController = TextEditingController();
    _symbolListController = TextEditingController();
    _stopLossController = TextEditingController();
    _takeProfitController = TextEditingController();
    _tradeQuantityController = TextEditingController();
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
    final storedSymbols = settings.getSymbolList();
    final symbolText = (storedSymbols == null || storedSymbols.isEmpty)
        ? defaultSymbols.join(', ')
        : storedSymbols.join(', ');

    setState(() {
      _apiKeyController.text = apiKey ?? '';
      _apiSecretController.text = apiSecret ?? '';
      _aiUrlController.text = settings.getAiUrl();
      _symbolListController.text = symbolText;
      _isTestnet = settings.getIsTestnet();
      _stopLossController.text = settings.getRiskStopLossPercent().toString();
      _takeProfitController.text = settings
          .getRiskTakeProfitPercent()
          .toString();
      _tradeQuantityController.text = settings
          .getRiskTradeQuantity()
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
    _symbolListController.dispose();
    _stopLossController.dispose();
    _takeProfitController.dispose();
    _tradeQuantityController.dispose();
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
    final parts = value.split(',');
    final seen = <String>{};
    final result = <String>[];
    for (final part in parts) {
      final symbol = part.trim().toUpperCase();
      if (symbol.isEmpty) continue;
      if (seen.add(symbol)) {
        result.add(symbol);
      }
    }
    return result;
  }

  Future<void> _saveSettings() async {
    final settings = ref.read(settingsServiceProvider);
    final stopLoss = _parseDouble(_stopLossController.text);
    final takeProfit = _parseDouble(_takeProfitController.text);
    final tradeQuantity = _parseDouble(_tradeQuantityController.text);
    final symbols = _parseSymbolList(_symbolListController.text);
    final rsiPeriod = _parseInt(_rsiPeriodController.text);
    final rsiOverbought = _parseDouble(_rsiOverboughtController.text);
    final rsiOversold = _parseDouble(_rsiOversoldController.text);

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
    await settings.setIsTestnet(_isTestnet);
    await settings.setSymbolList(symbols);
    await settings.setRiskStopLossPercent(stopLoss);
    await settings.setRiskTakeProfitPercent(takeProfit);
    await settings.setRiskTradeQuantity(tradeQuantity);
    await settings.setRsiPeriod(rsiPeriod);
    await settings.setRsiOverbought(rsiOverbought);
    await settings.setRsiOversold(rsiOversold);

    final currentStrategy = ref.read(currentStrategyProvider);
    if (currentStrategy is RsiStrategy) {
      ref.read(currentStrategyProvider.notifier).state = RsiStrategy(
        period: rsiPeriod,
        overbought: rsiOverbought,
        oversold: rsiOversold,
      );
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
      ref.invalidate(riskSettingsProvider);
      ref.invalidate(symbolListProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            subtitle: 'Provide the endpoint used for AI signal analysis.',
            child: TextField(
              controller: _aiUrlController,
              decoration: const InputDecoration(labelText: 'AI Analysis URL'),
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
            subtitle: 'Comma-separated list of tradable symbols.',
            child: TextField(
              controller: _symbolListController,
              decoration: const InputDecoration(
                labelText: 'Symbols (e.g., BTCUSDT, ETHUSDT)',
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'Risk Management',
            subtitle: 'Percent-based stops and fixed position sizing.',
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
                    labelText: 'Trade Quantity',
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
