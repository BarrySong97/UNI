import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Detail level controls how verbose the AI explanation is.
enum ExplanationDetail { brief, balanced, detailed }

/// Per-language AI configuration.
class AiLanguageConfig {
  const AiLanguageConfig({
    this.model = AiSettingsService.defaultModel,
    this.detail = ExplanationDetail.balanced,
    this.explanationLanguage = '',
    this.customPrompt = '',
  });

  final String model;
  final ExplanationDetail detail;

  /// Language for AI responses (e.g. "Chinese", "English"). Empty = auto.
  final String explanationLanguage;

  /// Custom prompt template. Empty = use default.
  final String customPrompt;

  Map<String, dynamic> toJson() => {
        'model': model,
        'detail': detail.name,
        'explanationLanguage': explanationLanguage,
        'customPrompt': customPrompt,
      };

  factory AiLanguageConfig.fromJson(Map<String, dynamic> json) {
    return AiLanguageConfig(
      model: json['model'] as String? ?? AiSettingsService.defaultModel,
      detail: ExplanationDetail.values.firstWhere(
        (e) => e.name == json['detail'],
        orElse: () => ExplanationDetail.balanced,
      ),
      explanationLanguage: json['explanationLanguage'] as String? ?? '',
      customPrompt: json['customPrompt'] as String? ?? '',
    );
  }

  AiLanguageConfig copyWith({
    String? model,
    ExplanationDetail? detail,
    String? explanationLanguage,
    String? customPrompt,
  }) {
    return AiLanguageConfig(
      model: model ?? this.model,
      detail: detail ?? this.detail,
      explanationLanguage: explanationLanguage ?? this.explanationLanguage,
      customPrompt: customPrompt ?? this.customPrompt,
    );
  }
}

class AiSettingsService extends ChangeNotifier {
  // Global keys.
  static const String _keyBaseUrl = 'ai_base_url';
  static const String _keyApiKey = 'ai_api_key';
  static const String _keyConfigMap = 'ai_config_map';

  // Legacy keys (for migration).
  static const String _keyLegacyModel = 'ai_model';
  static const String _keyLegacyPrompt = 'ai_prompt';

  static const String defaultBaseUrl = 'https://api.openai.com/v1';
  static const String defaultModel = 'gpt-4o-mini';
  static const String defaultLanguage = 'en_US';

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

  // Global settings.
  String _baseUrl = defaultBaseUrl;
  String _apiKey = '';

  /// Per-language AI config: languageCode -> AiLanguageConfig.
  final Map<String, AiLanguageConfig> _configMap = {};

  String get baseUrl => _baseUrl;
  String get apiKey => _apiKey;
  bool get isConfigured => _apiKey.isNotEmpty;
  Map<String, AiLanguageConfig> get configMap => Map.unmodifiable(_configMap);

  /// Get config for a specific language code (returns default if not set).
  AiLanguageConfig configForLanguage(String languageCode) {
    return _configMap[languageCode] ?? const AiLanguageConfig();
  }

  /// Resolve a book's language tag to a configured AI language code.
  String resolveBookLanguage(String? bookLanguage) {
    if (bookLanguage == null || bookLanguage.isEmpty) return defaultLanguage;

    final normalized = bookLanguage.replaceAll('-', '_');

    // Exact match.
    if (_configMap.containsKey(normalized)) return normalized;

    // Family match: "en" matches "en_US" or "en_GB".
    final family = normalized.split('_').first;
    for (final lang in _configMap.keys) {
      if (lang.startsWith('${family}_')) return lang;
    }

    return defaultLanguage;
  }

  /// Resolve book language and return the matching per-language config.
  AiLanguageConfig resolveConfig(String? bookLanguage) {
    final langCode = resolveBookLanguage(bookLanguage);
    return configForLanguage(langCode);
  }

  /// Detail instruction text appended to the system prompt.
  static String detailInstruction(ExplanationDetail detail) {
    switch (detail) {
      case ExplanationDetail.brief:
        return 'Be very brief and concise. Give a short, direct explanation '
            'in 2-3 sentences.';
      case ExplanationDetail.balanced:
        return 'Provide a balanced explanation that is thorough but not '
            'overly long.';
      case ExplanationDetail.detailed:
        return 'Provide a detailed, in-depth analysis. Cover nuances, '
            'literary devices, cultural context, and any relevant '
            'background information.';
    }
  }

  /// Language instruction text appended to the system prompt.
  static String languageInstruction(String explanationLanguage) {
    if (explanationLanguage.isEmpty) return '';
    return 'Respond in $explanationLanguage.';
  }

  // ---------------------------------------------------------------------------
  // Initialization & persistence
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_keyBaseUrl) ?? defaultBaseUrl;
    _apiKey = prefs.getString(_keyApiKey) ?? '';

    final configMapJson = prefs.getString(_keyConfigMap);
    if (configMapJson != null) {
      _loadConfigMap(configMapJson);
    } else {
      await _migrateLegacySettings(prefs);
    }

    notifyListeners();
  }

  void _loadConfigMap(String json) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      _configMap.clear();
      for (final entry in map.entries) {
        _configMap[entry.key] = AiLanguageConfig.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    } catch (e) {
      debugPrint('[AiSettingsService] Error loading config map: $e');
    }
  }

  Future<void> _migrateLegacySettings(SharedPreferences prefs) async {
    final legacyModel = prefs.getString(_keyLegacyModel);
    final legacyPrompt = prefs.getString(_keyLegacyPrompt);

    if (legacyModel != null || legacyPrompt != null) {
      _configMap[defaultLanguage] = AiLanguageConfig(
        model: legacyModel ?? defaultModel,
        customPrompt: legacyPrompt ?? '',
      );
      await _saveConfigMap(prefs);
      await prefs.remove(_keyLegacyModel);
      await prefs.remove(_keyLegacyPrompt);
    }
  }

  Future<void> _saveConfigMap(SharedPreferences prefs) async {
    final map = <String, dynamic>{};
    for (final entry in _configMap.entries) {
      map[entry.key] = entry.value.toJson();
    }
    await prefs.setString(_keyConfigMap, jsonEncode(map));
  }

  // ---------------------------------------------------------------------------
  // Update methods
  // ---------------------------------------------------------------------------

  /// Update global connection settings (shared across all languages).
  Future<void> updateGlobal({
    required String baseUrl,
    required String apiKey,
  }) async {
    _baseUrl = baseUrl;
    _apiKey = apiKey;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseUrl, baseUrl);
    await prefs.setString(_keyApiKey, apiKey);
    notifyListeners();
  }

  /// Set per-language AI config.
  Future<void> setConfigForLanguage(
    String languageCode,
    AiLanguageConfig config,
  ) async {
    _configMap[languageCode] = config;
    final prefs = await SharedPreferences.getInstance();
    await _saveConfigMap(prefs);
    notifyListeners();
  }

  /// Remove per-language AI config (falls back to default).
  Future<void> removeConfigForLanguage(String languageCode) async {
    _configMap.remove(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await _saveConfigMap(prefs);
    notifyListeners();
  }
}
