import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiSettingsService extends ChangeNotifier {
  static const String _keyBaseUrl = 'ai_base_url';
  static const String _keyApiKey = 'ai_api_key';
  static const String _keyModel = 'ai_model';

  static const String defaultBaseUrl = 'https://api.openai.com/v1';
  static const String defaultModel = 'gpt-4o-mini';

  String _baseUrl = defaultBaseUrl;
  String _apiKey = '';
  String _model = defaultModel;

  String get baseUrl => _baseUrl;
  String get apiKey => _apiKey;
  String get model => _model;
  bool get isConfigured => _apiKey.isNotEmpty;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_keyBaseUrl) ?? defaultBaseUrl;
    _apiKey = prefs.getString(_keyApiKey) ?? '';
    _model = prefs.getString(_keyModel) ?? defaultModel;
    notifyListeners();
  }

  Future<void> update({
    required String baseUrl,
    required String apiKey,
    required String model,
  }) async {
    _baseUrl = baseUrl;
    _apiKey = apiKey;
    _model = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseUrl, baseUrl);
    await prefs.setString(_keyApiKey, apiKey);
    await prefs.setString(_keyModel, model);
    notifyListeners();
  }
}
