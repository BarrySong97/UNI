class PhoneticsResult {
  final String us;
  final String uk;

  const PhoneticsResult({required this.us, required this.uk});

  static const empty = PhoneticsResult(us: '', uk: '');

  bool get hasAny => us.trim().isNotEmpty || uk.trim().isNotEmpty;
}

class PhoneticsLookupOutcome {
  final PhoneticsResult result;
  final bool foundLocally;
  final bool foundInAiCache;
  final bool canTryAi;

  const PhoneticsLookupOutcome({
    required this.result,
    required this.foundLocally,
    required this.foundInAiCache,
    required this.canTryAi,
  });

  const PhoneticsLookupOutcome.empty({required this.canTryAi})
    : result = PhoneticsResult.empty,
      foundLocally = false,
      foundInAiCache = false;
}

class PhoneticsAiNotConfiguredException implements Exception {
  const PhoneticsAiNotConfiguredException();

  @override
  String toString() => 'AI phonetics lookup is not configured.';
}

class PhoneticsAiLookupException implements Exception {
  const PhoneticsAiLookupException(this.message);

  final String message;

  @override
  String toString() => message;
}
