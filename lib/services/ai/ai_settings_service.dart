import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../search/image_search_service.dart';

/// Detail level controls how verbose the AI explanation is.
enum ExplanationDetail { brief, balanced, detailed }

/// Wire format expected by the configured AI endpoint.
enum AiProviderKind {
  /// OpenAI Chat Completions / `/v1/chat/completions` style API.
  openAiCompatible,

  /// Anthropic Messages API style.
  anthropicCompatible,
}

class VocabularyLevelOption {
  const VocabularyLevelOption({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;
}

/// Per-language AI configuration.
class AiLanguageConfig {
  const AiLanguageConfig({
    this.detail = ExplanationDetail.balanced,
    this.explanationLanguage = '',
    this.customPrompt = '',
    this.customPromptModeEnabled = false,
    this.vocabularyLevel = '',
  });

  final ExplanationDetail detail;

  /// Language for AI responses (e.g. "Chinese", "English"). Empty = auto.
  final String explanationLanguage;

  /// Custom prompt template. Empty = use default.
  final String customPrompt;

  /// When true, explanation uses user-defined prompt + free-form markdown.
  /// When false, reader explain uses built-in structured UI format.
  final bool customPromptModeEnabled;

  /// Source-language vocabulary difficulty guidance for built-in prompts.
  final String vocabularyLevel;

  Map<String, dynamic> toJson() => {
    'detail': detail.name,
    'explanationLanguage': explanationLanguage,
    'customPrompt': customPrompt,
    'customPromptModeEnabled': customPromptModeEnabled,
    'vocabularyLevel': vocabularyLevel,
  };

  factory AiLanguageConfig.fromJson(Map<String, dynamic> json) {
    return AiLanguageConfig(
      detail: ExplanationDetail.values.firstWhere(
        (e) => e.name == json['detail'],
        orElse: () => ExplanationDetail.balanced,
      ),
      explanationLanguage: json['explanationLanguage'] as String? ?? '',
      customPrompt: json['customPrompt'] as String? ?? '',
      customPromptModeEnabled:
          json['customPromptModeEnabled'] as bool? ?? false,
      vocabularyLevel: json['vocabularyLevel'] as String? ?? '',
    );
  }

  AiLanguageConfig copyWith({
    ExplanationDetail? detail,
    String? explanationLanguage,
    String? customPrompt,
    bool? customPromptModeEnabled,
    String? vocabularyLevel,
  }) {
    return AiLanguageConfig(
      detail: detail ?? this.detail,
      explanationLanguage: explanationLanguage ?? this.explanationLanguage,
      customPrompt: customPrompt ?? this.customPrompt,
      customPromptModeEnabled:
          customPromptModeEnabled ?? this.customPromptModeEnabled,
      vocabularyLevel: vocabularyLevel ?? this.vocabularyLevel,
    );
  }
}

class AiSettingsService extends ChangeNotifier {
  // Global keys.
  static const String _keyBaseUrl = 'ai_base_url';
  static const String _keyApiKey = 'ai_api_key';
  static const String _keyModel = 'ai_model_global';
  static const String _keyProvider = 'ai_provider';
  static const String _keyConfigMap = 'ai_config_map';
  static const String _keyImageSearchEngine = 'ai_image_search_engine';

  // Legacy keys (for migration).
  static const String _keyLegacyModel = 'ai_model';
  static const String _keyLegacyPrompt = 'ai_prompt';

  static const String defaultBaseUrl = 'https://api.openai.com/v1';
  static const String defaultModel = 'gpt-4o-mini';
  static const AiProviderKind defaultProvider = AiProviderKind.openAiCompatible;
  static const String defaultLanguage = 'en_US';
  static const String defaultEnglishVocabularyLevel = 'cet6';

  static const String defaultPrompt =
      'You are a reading assistant for the book "{bookTitle}".\n\n'
      'The user selected: "{selectedText}"\n\n'
      'Context:\n---\n{context}\n---\n\n'
      'Give a clear, concise explanation of the selected text. '
      'Focus on what it means in this context. '
      'If it is a single word or short phrase, explain its meaning and usage here.';

  // Global settings.
  String _baseUrl = defaultBaseUrl;
  String _apiKey = '';
  String _model = defaultModel;
  AiProviderKind _provider = defaultProvider;
  ImageSearchEngine _imageSearchEngine = ImageSearchEngine.bing;

  /// Per-language AI config: languageCode -> AiLanguageConfig.
  final Map<String, AiLanguageConfig> _configMap = {};

  String get baseUrl => _baseUrl;
  String get apiKey => _apiKey;
  String get model => _model;
  AiProviderKind get provider => _provider;
  bool get isConfigured => _apiKey.isNotEmpty;
  ImageSearchEngine get imageSearchEngine => _imageSearchEngine;
  Map<String, AiLanguageConfig> get configMap => Map.unmodifiable(_configMap);

  /// Get config for a specific language code (returns default if not set).
  AiLanguageConfig configForLanguage(String languageCode) {
    final normalized = normalizeLanguageCode(languageCode);
    final config = _configMap[normalized] ?? const AiLanguageConfig();
    return _withLanguageDefaults(normalized, config);
  }

  static String normalizeLanguageCode(String? languageCode) {
    if (languageCode == null) return '';
    return languageCode.trim().replaceAll('-', '_');
  }

  static bool isEnglishLanguageCode(String? languageCode) {
    final normalized = normalizeLanguageCode(languageCode);
    if (normalized.isEmpty) {
      return false;
    }
    return normalized.split('_').first.toLowerCase() == 'en';
  }

  static String defaultVocabularyLevelFor(String languageCode) {
    return isEnglishLanguageCode(languageCode)
        ? defaultEnglishVocabularyLevel
        : '';
  }

  static List<VocabularyLevelOption> vocabularyOptionsFor(String languageCode) {
    if (!isEnglishLanguageCode(languageCode)) {
      return const <VocabularyLevelOption>[];
    }
    return const <VocabularyLevelOption>[
      VocabularyLevelOption(
        id: 'cet4',
        label: 'CET4',
        description:
            'Use simple, everyday English with quick clarifications for harder terms.',
      ),
      VocabularyLevelOption(
        id: 'cet6',
        label: 'CET6',
        description:
            'Use moderately advanced English while keeping academic jargon explained.',
      ),
      VocabularyLevelOption(
        id: 'ielts',
        label: 'IELTS',
        description:
            'Use upper-intermediate academic English with concise support for rare terms.',
      ),
      VocabularyLevelOption(
        id: 'toefl',
        label: 'TOEFL',
        description:
            'Use advanced academic English, but briefly gloss specialized vocabulary when needed.',
      ),
      VocabularyLevelOption(
        id: 'gre',
        label: 'GRE',
        description:
            'Use precise, high-level English and preserve nuance with minimal simplification.',
      ),
    ];
  }

  static String vocabularyInstruction({
    required String languageCode,
    required String levelId,
  }) {
    if (!isEnglishLanguageCode(languageCode) || levelId.isEmpty) {
      return '';
    }

    switch (levelId) {
      case 'cet4':
        return 'The selected text is English. Assume the reader has CET-4 level English comprehension. Keep any English terminology simple and high-frequency; if you must use English above CET-4 level, briefly clarify it inline. Even if you respond in another language, keep the English vocabulary load appropriate for a CET-4 learner.';
      case 'cet6':
        return 'The selected text is English. Assume the reader has CET-6 level English comprehension. You may use moderately advanced English terminology, but briefly clarify rarer English words inline when they go beyond CET-6 level. Even if you respond in another language, keep the English vocabulary load appropriate for a CET-6 learner.';
      case 'ielts':
        return 'The selected text is English. Assume the reader has IELTS-level English comprehension. You may use upper-intermediate academic English, but briefly clarify less common English terms inline. Even if you respond in another language, keep the English vocabulary load appropriate for an IELTS learner.';
      case 'toefl':
        return 'The selected text is English. Assume the reader has TOEFL-level English comprehension. You may use advanced academic English, but briefly clarify specialized English vocabulary inline when needed. Even if you respond in another language, keep the English vocabulary load appropriate for a TOEFL learner.';
      case 'gre':
        return 'The selected text is English. Assume the reader has GRE-level English comprehension. Preserve precision and nuance, but briefly clarify unusually rare English terms inline when they are likely above GRE level. Even if you respond in another language, keep the English vocabulary load appropriate for a GRE learner.';
      default:
        return '';
    }
  }

  /// Resolve a book's language tag to a configured AI language code.
  String resolveBookLanguage(String? bookLanguage) {
    if (bookLanguage == null || bookLanguage.isEmpty) return defaultLanguage;

    final normalized = normalizeLanguageCode(bookLanguage);
    if (normalized.isEmpty) return defaultLanguage;

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
        return 'Be extremely brief. Explain in 1-2 sentences only.';
      case ExplanationDetail.balanced:
        return 'Keep your explanation concise — a short paragraph at most.';
      case ExplanationDetail.detailed:
        return 'Provide a thorough explanation. Include nuances, background, '
            'and any relevant context, but stay focused and avoid unnecessary '
            'filler.';
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
    _model = prefs.getString(_keyModel) ?? defaultModel;
    final providerName = prefs.getString(_keyProvider);
    if (providerName != null) {
      _provider = AiProviderKind.values.firstWhere(
        (p) => p.name == providerName,
        orElse: () => defaultProvider,
      );
    }
    final engineName = prefs.getString(_keyImageSearchEngine);
    if (engineName != null) {
      _imageSearchEngine = ImageSearchEngine.values.firstWhere(
        (e) => e.name == engineName,
        orElse: () => ImageSearchEngine.bing,
      );
    }

    final configMapJson = prefs.getString(_keyConfigMap);
    if (configMapJson != null) {
      final liftedModel = _loadConfigMap(configMapJson);
      if (prefs.getString(_keyModel) == null && liftedModel != null) {
        _model = liftedModel;
        await prefs.setString(_keyModel, liftedModel);
      }
    } else {
      await _migrateLegacySettings(prefs);
    }

    notifyListeners();
  }

  /// Returns the first non-default `model` value found in legacy per-language
  /// JSON entries, or null. Used to lift the old per-language model into the
  /// new global model setting.
  String? _loadConfigMap(String json) {
    String? liftedModel;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      _configMap.clear();
      for (final entry in map.entries) {
        final normalizedKey = normalizeLanguageCode(entry.key);
        final raw = entry.value as Map<String, dynamic>;
        final legacyModel = raw['model'] as String?;
        if (liftedModel == null &&
            legacyModel != null &&
            legacyModel.isNotEmpty) {
          liftedModel = legacyModel;
        }
        _configMap[normalizedKey] = AiLanguageConfig.fromJson(raw);
      }
    } catch (e) {
      debugPrint('[AiSettingsService] Error loading config map: $e');
    }
    return liftedModel;
  }

  Future<void> _migrateLegacySettings(SharedPreferences prefs) async {
    final legacyModel = prefs.getString(_keyLegacyModel);
    final legacyPrompt = prefs.getString(_keyLegacyPrompt);

    if (legacyModel != null) {
      _model = legacyModel;
      await prefs.setString(_keyModel, legacyModel);
      await prefs.remove(_keyLegacyModel);
    }
    if (legacyPrompt != null) {
      _configMap[defaultLanguage] = AiLanguageConfig(
        customPrompt: legacyPrompt,
      );
      await _saveConfigMap(prefs);
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
    String? model,
    AiProviderKind? provider,
  }) async {
    _baseUrl = baseUrl;
    _apiKey = apiKey;
    if (model != null) _model = model.isEmpty ? defaultModel : model;
    if (provider != null) _provider = provider;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseUrl, baseUrl);
    await prefs.setString(_keyApiKey, apiKey);
    if (model != null) await prefs.setString(_keyModel, _model);
    if (provider != null) {
      await prefs.setString(_keyProvider, provider.name);
    }
    notifyListeners();
  }

  /// Set the image search engine.
  Future<void> setImageSearchEngine(ImageSearchEngine engine) async {
    _imageSearchEngine = engine;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyImageSearchEngine, engine.name);
    notifyListeners();
  }

  /// Set per-language AI config.
  Future<void> setConfigForLanguage(
    String languageCode,
    AiLanguageConfig config,
  ) async {
    final normalized = normalizeLanguageCode(languageCode);
    _configMap[normalized] = config;
    final prefs = await SharedPreferences.getInstance();
    await _saveConfigMap(prefs);
    notifyListeners();
  }

  /// Remove per-language AI config (falls back to default).
  Future<void> removeConfigForLanguage(String languageCode) async {
    _configMap.remove(normalizeLanguageCode(languageCode));
    final prefs = await SharedPreferences.getInstance();
    await _saveConfigMap(prefs);
    notifyListeners();
  }

  static AiLanguageConfig _withLanguageDefaults(
    String languageCode,
    AiLanguageConfig config,
  ) {
    final vocabularyLevel = config.vocabularyLevel.isNotEmpty
        ? config.vocabularyLevel
        : defaultVocabularyLevelFor(languageCode);
    if (vocabularyLevel == config.vocabularyLevel) {
      return config;
    }
    return config.copyWith(vocabularyLevel: vocabularyLevel);
  }
}
