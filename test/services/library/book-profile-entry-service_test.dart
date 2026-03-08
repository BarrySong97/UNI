import 'package:flutter_test/flutter_test.dart';
import 'package:uni/services/library/book-profile-entry-service.dart';

void main() {
  test('returns profile when no reading progress exists', () {
    const service = BookProfileEntryService();

    final target = service.resolveEntry('book-1', <String, double>{});

    expect(target, BookProfileEntryTarget.profile);
  });

  test('returns reader when reading progress exists', () {
    const service = BookProfileEntryService();
    final progressMap = <String, double>{'book-1': 0.4};

    final target = service.resolveEntry('book-1', progressMap);

    expect(target, BookProfileEntryTarget.reader);
  });
}
