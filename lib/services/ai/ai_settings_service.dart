import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiSettingsService extends ChangeNotifier {
  static const String _keyBaseUrl = 'ai_base_url';
  static const String _keyApiKey = 'ai_api_key';
  static const String _keyModel = 'ai_model';
  static const String _keyPrompt = 'ai_prompt';

  static const String defaultBaseUrl = 'https://api.openai.com/v1';
  static const String defaultModel = 'gpt-4o-mini';
  static const String defaultPrompt =
      'You are a reading assistant helping the user understand a passage '
      'from the book "{bookTitle}".\n\n'
      'The user selected: "{selectedText}"\n\n'
      'Surrounding context:\n---\n{context}\n---\n\n'
      'Explain this passage clearly and concisely. Cover:\n'
      '1. The meaning of the text in plain language\n'
      '2. Any difficult vocabulary or phrases\n'
      '3. The context or significance if apparent\n\n'
      'Keep explanations helpful but not overly long. '
      'If the user asks follow-up questions, answer based on the passage.';

  String _baseUrl = defaultBaseUrl;
  String _apiKey = '';
  String _model = defaultModel;
  String _prompt = defaultPrompt;

  String get baseUrl => _baseUrl;
  String get apiKey => _apiKey;
  String get model => _model;
  String get prompt => _prompt;
  bool get isConfigured => _apiKey.isNotEmpty;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_keyBaseUrl) ?? defaultBaseUrl;
    _apiKey = prefs.getString(_keyApiKey) ?? '';
    _model = prefs.getString(_keyModel) ?? defaultModel;
    _prompt = prefs.getString(_keyPrompt) ?? defaultPrompt;
    notifyListeners();
  }

  Future<void> update({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String prompt,
  }) async {
    _baseUrl = baseUrl;
    _apiKey = apiKey;
    _model = model;
    _prompt = prompt;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseUrl, baseUrl);
    await prefs.setString(_keyApiKey, apiKey);
    await prefs.setString(_keyModel, model);
    await prefs.setString(_keyPrompt, prompt);
    notifyListeners();
  }
}
