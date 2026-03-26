enum AiProvider { customPromptApi, groqChat, pollinationsText }

extension AiProviderX on AiProvider {
  String get key => switch (this) {
    AiProvider.customPromptApi => 'custom',
    AiProvider.groqChat => 'groq',
    AiProvider.pollinationsText => 'pollinations',
  };

  String get label => switch (this) {
    AiProvider.customPromptApi => 'Custom AI API',
    AiProvider.groqChat => 'Groq Chat',
    AiProvider.pollinationsText => 'Pollinations',
  };

  String get defaultUrl => switch (this) {
    AiProvider.customPromptApi => 'https://your-ai-api.com/analyze',
    AiProvider.groqChat => 'https://api.groq.com/openai/v1/chat/completions',
    AiProvider.pollinationsText => 'https://text.pollinations.ai/',
  };

  String get defaultModel => switch (this) {
    AiProvider.customPromptApi => '',
    AiProvider.groqChat => 'llama-3.1-8b-instant',
    AiProvider.pollinationsText => 'openai',
  };
}

AiProvider aiProviderFromKey(String? value) {
  return AiProvider.values.firstWhere(
    (provider) => provider.key == value,
    orElse: () => AiProvider.groqChat,
  );
}
