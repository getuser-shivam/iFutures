import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trading_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _apiKeyController;
  late TextEditingController _apiSecretController;
  late TextEditingController _aiUrlController;
  bool _isTestnet = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    _apiSecretController = TextEditingController();
    _aiUrlController = TextEditingController();
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
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiSecretController.dispose();
    _aiUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final settings = ref.read(settingsServiceProvider);
    await settings.setApiKey(_apiKeyController.text);
    await settings.setApiSecret(_apiSecretController.text);
    await settings.setAiUrl(_aiUrlController.text);
    await settings.setIsTestnet(_isTestnet);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
      // Invalidate providers to force refresh with new settings
      ref.invalidate(binanceApiProvider);
      ref.invalidate(binanceWsProvider);
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
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Binance API Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _apiKeyController,
            decoration: const InputDecoration(labelText: 'API Key', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _apiSecretController,
            decoration: const InputDecoration(labelText: 'API Secret', border: OutlineInputBorder()),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Use Testnet'),
            value: _isTestnet,
            onChanged: (val) => setState(() => _isTestnet = val),
          ),
          const SizedBox(height: 32),
          const Text('AI Strategy Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _aiUrlController,
            decoration: const InputDecoration(labelText: 'AI Analysis URL', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: _saveSettings,
            child: const Text('SAVE SETTINGS', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
