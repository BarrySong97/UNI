export 'phonetics_models.dart';

import 'package:malsami/malsami.dart';

import '../ai/ai_settings_service.dart';
import '../db/app-database.dart';
import 'ai_phonetics_service.dart';
import 'phonetics_candidate_builder.dart';
import 'phonetics_models.dart';

typedef LocalPhoneticsLookup =
    Future<PhoneticsResult> Function(String candidate);

class PhoneticsService {
  PhoneticsService({
    AppDatabase? database,
    AiPhoneticsService? aiPhoneticsService,
    AiSettingsService? aiSettingsService,
    LocalPhoneticsLookup? localLookupOverride,
  }) : _database = database,
       _aiPhoneticsService = aiPhoneticsService,
       _aiSettingsService = aiSettingsService,
       _localLookupOverride = localLookupOverride;

  final AppDatabase? _database;
  final AiPhoneticsService? _aiPhoneticsService;
  final AiSettingsService? _aiSettingsService;
  final LocalPhoneticsLookup? _localLookupOverride;

  late final EnglishG2P _usG2p;
  late final EnglishG2P _ukG2p;
  bool _initialized = false;

  bool get supportsAiLookup => _aiPhoneticsService != null;

  bool get isAiConfigured =>
      _aiPhoneticsService?.isConfigured ??
      (_aiSettingsService?.isConfigured == true);

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _usG2p = EnglishG2P();
    await _usG2p.initialize();
    _ukG2p = EnglishG2P(british: true);
    await _ukG2p.initialize();
    _initialized = true;
  }

  Future<PhoneticsResult> lookup(String text) async {
    final outcome = await lookupWithOutcome(text);
    return outcome.result;
  }

  Future<PhoneticsLookupOutcome> lookupWithOutcome(String text) async {
    final localResult = await _lookupLocally(text);
    if (localResult.hasAny) {
      return PhoneticsLookupOutcome(
        result: localResult,
        foundLocally: true,
        foundInAiCache: false,
        canTryAi: supportsAiLookup,
      );
    }

    final cachedResult = await _lookupAiCache(text);
    if (cachedResult.hasAny) {
      return PhoneticsLookupOutcome(
        result: cachedResult,
        foundLocally: false,
        foundInAiCache: true,
        canTryAi: supportsAiLookup,
      );
    }

    return PhoneticsLookupOutcome.empty(canTryAi: supportsAiLookup);
  }

  Future<PhoneticsResult> fetchWithAiAndCache(String text) async {
    if (!supportsAiLookup) {
      throw const PhoneticsAiLookupException(
        'AI phonetics lookup is unavailable.',
      );
    }
    if (!isAiConfigured) {
      throw const PhoneticsAiNotConfiguredException();
    }

    final cached = await _lookupAiCache(text);
    if (cached.hasAny) {
      return cached;
    }

    final result = await _aiPhoneticsService!.lookupIpa(text);
    if (!result.hasAny) {
      throw const PhoneticsAiLookupException('AI did not return IPA.');
    }

    final normalizedText = normalizePhoneticsCacheKey(text);
    if (normalizedText.isNotEmpty && _database != null) {
      await _database.upsertPhoneticsCache(
        normalizedText: normalizedText,
        usIpa: result.us,
        ukIpa: result.uk,
        source: 'ai',
      );
    }
    return result;
  }

  Future<PhoneticsResult> _lookupLocally(String text) async {
    if (_localLookupOverride == null) {
      await initialize();
    }

    for (final candidate in buildPhoneticsFallbackCandidates(text)) {
      final result = await _lookupCandidate(candidate);
      if (result.hasAny) {
        return result;
      }
    }
    return PhoneticsResult.empty;
  }

  Future<PhoneticsResult> _lookupAiCache(String text) async {
    final normalizedText = normalizePhoneticsCacheKey(text);
    if (normalizedText.isEmpty || _database == null) {
      return PhoneticsResult.empty;
    }
    return await _database.getPhoneticsCache(normalizedText: normalizedText) ??
        PhoneticsResult.empty;
  }

  Future<PhoneticsResult> _lookupCandidate(String text) async {
    if (_localLookupOverride != null) {
      return _localLookupOverride(text);
    }
    final (usPhonemes, _) = await _usG2p.convert(text);
    final (ukPhonemes, _) = await _ukG2p.convert(text);
    return PhoneticsResult(
      us: _normalizePhonemes(usPhonemes),
      uk: _normalizePhonemes(ukPhonemes),
    );
  }

  String _normalizePhonemes(String phonemes) {
    final trimmed = phonemes.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final withoutUnknowns = trimmed.replaceAll('❓', '').replaceAll(' ', '');
    if (withoutUnknowns.isEmpty) {
      return '';
    }

    return trimmed;
  }
}
