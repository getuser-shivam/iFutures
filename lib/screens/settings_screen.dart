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

  @override
  void initState() {
    super.initState();
    // In a real app, load these from secure storage
    _apiKeyController = TextEditingController(text: 'YOUR_API_KEY');
    _apiSecretController = TextEditingController(text: 'YOUR_API_SECRET');
    _aiUrlController = TextEditingController(text: 'https://your-ai-api.com/analyze');
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiSecretController.dispose();
    _aiUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 32),
          const Text('AI Strategy Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _aiUrlController,
            decoration: const InputDecoration(labelText: 'AI Analysis URL', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              // Update providers or save to storage
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings saved (locally for session)')),
              );
            },
            child: const Text('SAVE SETTINGS'),
          ),
        ],
      ),
    );
  }
}
