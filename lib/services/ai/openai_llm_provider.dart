import 'dart:async';

import 'package:genkit/genkit.dart';
import 'package:genkit_openai/genkit_openai.dart';

import 'ai_settings_service.dart';

/// Chat message for the explain UI.
class ExplainChatMessage {
  ExplainChatMessage({required this.isUser, required this.text});

  final bool isUser;
  String text;
}

/// Wraps Genkit to provide streaming AI responses for the explain feature.
class ExplainAiService {
  ExplainAiService({
    required AiSettingsService settings,
    required String systemPrompt,
    required String model,
  }) : _model = model,
       _systemPrompt = systemPrompt {
    _ai = Genkit(
      plugins: [
        openAI(
          apiKey: settings.apiKey,
          baseUrl: settings.baseUrl,
        ),
      ],
    );
  }

  final String _model;
  final String _systemPrompt;
  late final Genkit _ai;
  final List<Message> _history = [];

  /// Sends a user message and streams the response text chunk by chunk.
  Stream<String> sendMessage(String userPrompt) async* {
    _history.add(
      Message(
        role: Role.user,
        content: [TextPart(text: userPrompt)],
      ),
    );

    final allMessages = [
      Message(
        role: Role.system,
        content: [TextPart(text: _systemPrompt)],
      ),
      ..._history,
    ];

    final responseBuffer = StringBuffer();

    final stream = _ai.generateStream(
      model: openAI.model(_model),
      messages: allMessages,
    );

    await for (final chunk in stream) {
      final text = chunk.text;
      if (text.isNotEmpty) {
        responseBuffer.write(text);
        yield text;
      }
    }

    _history.add(
      Message(
        role: Role.model,
        content: [TextPart(text: responseBuffer.toString())],
      ),
    );
  }
}
