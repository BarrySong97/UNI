import 'package:flutter_test/flutter_test.dart';
import 'package:uni/services/db/app-database.dart';

void main() {
  test(
    'upsertPhoneticsCache stores and replaces cached IPA by normalized text',
    () async {
      final database = AppDatabase();

      await database.upsertPhoneticsCache(
        normalizedText: 'openai',
        usIpa: 'old-us',
        ukIpa: '',
        source: 'ai',
      );
      await database.upsertPhoneticsCache(
        normalizedText: 'openai',
        usIpa: 'new-us',
        ukIpa: 'new-uk',
        source: 'ai',
      );

      final cached = await database.getPhoneticsCache(normalizedText: 'openai');

      expect(cached, isNotNull);
      expect(cached!.us, 'new-us');
      expect(cached.uk, 'new-uk');
    },
  );
}
