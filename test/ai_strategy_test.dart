import 'package:flutter_test/flutter_test.dart';
import 'package:ifutures/models/ai_provider.dart';
import 'package:ifutures/models/ai_service_status.dart';
import 'package:ifutures/trading/ai_strategy.dart';

void main() {
  test(
    'verifyConnection reports not configured when API key is missing',
    () async {
      final strategy = AiStrategy(
        apiUrl: AiProvider.groqChat.defaultUrl,
        apiKey: '',
        provider: AiProvider.groqChat,
        model: AiProvider.groqChat.defaultModel,
      );

      final result = await strategy.verifyConnection();

      expect(result.state, AiServiceState.notConfigured);
      expect(result.message, contains('API key is missing'));
    },
  );
}
