import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trading_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/dashboard/app_panel.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _apiKeyController;
  late TextEditingController _apiSecretController;
  late TextEditingController _aiUrlController;
  late TextEditingController _stopLossController;
  late TextEditingController _takeProfitController;
  late TextEditingController _tradeQuantityController;
  bool _isTestnet = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    _apiSecretController = TextEditingController();
    _aiUrlController = TextEditingController();
    _stopLossController = TextEditingController();
    _takeProfitController = TextEditingController();
    _tradeQuantityController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = ref.read(settingsServiceProvider);
    await settings.init();

    final apiKey = await settings.getApiKey();
    final apiSecret = await settings.getApiSecret();

    setState(() {
      _apiKeyController.text = apiKey ?? '';
      _apiSecretController.text = apiSecret ?? '';
      _aiUrlController.text = settings.getAiUrl();
      _isTestnet = settings.getIsTestnet();
      _stopLossController.text = settings.getRiskStopLossPercent().toString();
      _takeProfitController.text = settings.getRiskTakeProfitPercent().toString();
      _tradeQuantityController.text = settings.getRiskTradeQuantity().toString();
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiSecretController.dispose();
    _aiUrlController.dispose();
    _stopLossController.dispose();
    _takeProfitController.dispose();
    _tradeQuantityController.dispose();
    super.dispose();
  }

  double? _parseDouble(String value) {
    final normalized = value.trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  Future<void> _saveSettings() async {
    final settings = ref.read(settingsServiceProvider);
    final stopLoss = _parseDouble(_stopLossController.text);
    final takeProfit = _parseDouble(_takeProfitController.text);
    final tradeQuantity = _parseDouble(_tradeQuantityController.text);

    if (stopLoss == null || stopLoss < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stop loss must be a valid number (0 or greater).')),
      );
      return;
    }

    if (takeProfit == null || takeProfit < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Take profit must be a valid number (0 or greater).')),
      );
      return;
    }

    if (tradeQuantity == null || tradeQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trade quantity must be greater than 0.')),
      );
      return;
    }

    await settings.setApiKey(_apiKeyController.text);
    await settings.setApiSecret(_apiSecretController.text);
    await settings.setAiUrl(_aiUrlController.text);
    await settings.setIsTestnet(_isTestnet);
    await settings.setRiskStopLossPercent(stopLoss);
    await settings.setRiskTakeProfitPercent(takeProfit);
    await settings.setRiskTradeQuantity(tradeQuantity);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
      ref.invalidate(binanceApiProvider);
      ref.invalidate(binanceWsProvider);
      ref.invalidate(riskSettingsProvider);
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
                  activeColor: AppColors.glowCyan,
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
            title: 'Risk Management',
            subtitle: 'Percent-based stops and fixed position sizing.',
            child: Column(
              children: [
                TextField(
                  controller: _stopLossController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Stop Loss (%)'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _takeProfitController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Take Profit (%)'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _tradeQuantityController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Trade Quantity'),
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
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
