import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/pages/reader/quote_card/models/quote_card_draft.dart';
import 'package:uni/pages/reader/quote_card/models/reader_quote_card_payload.dart';
import 'package:uni/pages/reader/quote_card/reader_quote_card_page.dart';
import 'package:uni/pages/reader/quote_card/widgets/quote_card_preview.dart';

void main() {
  ReaderQuoteCardPayload buildPayload() {
    return const ReaderQuoteCardPayload(
      bookId: 'book-1',
      bookTitle: 'The Overstory',
      bookAuthor: 'Richard Powers',
      selectedText: 'The best time to plant a tree was ten years ago.',
      readerFontFamily: 'Georgia',
      readerThemeName: 'Paper',
    );
  }

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ReaderQuoteCardPage(payload: buildPayload())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders selected text and metadata', (tester) async {
    await pumpPage(tester);

    expect(
      find.text('The best time to plant a tree was ten years ago.'),
      findsOneWidget,
    );
    expect(find.text('Richard Powers'), findsOneWidget);
    expect(find.text('The Overstory'), findsOneWidget);
  });

  testWidgets('updates template, background, layout and font selections', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('quote-card-option-template-spotlight'),
      ),
    );
    await tester.pumpAndSettle();
    var preview = tester.widget<QuoteCardPreview>(
      find.byType(QuoteCardPreview),
    );
    expect(preview.draft.template, QuoteCardTemplate.spotlight);

    await tester.tap(
      find.byKey(const ValueKey<String>('quote-card-tab-background')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('quote-card-option-background-night')),
    );
    await tester.pumpAndSettle();
    preview = tester.widget<QuoteCardPreview>(find.byType(QuoteCardPreview));
    expect(preview.draft.background, QuoteCardBackgroundPreset.night);

    await tester.tap(
      find.byKey(const ValueKey<String>('quote-card-tab-layout')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('quote-card-option-layout-top')),
    );
    await tester.pumpAndSettle();
    preview = tester.widget<QuoteCardPreview>(find.byType(QuoteCardPreview));
    expect(preview.draft.layout, QuoteCardLayoutPreset.top);

    await tester.tap(find.byKey(const ValueKey<String>('quote-card-tab-font')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('quote-card-option-font-serif')),
    );
    await tester.pumpAndSettle();
    preview = tester.widget<QuoteCardPreview>(find.byType(QuoteCardPreview));
    expect(preview.draft.fontPreset, QuoteCardFontPreset.serif);
  });

  testWidgets('visibility toggles hide metadata fields', (tester) async {
    await pumpPage(tester);

    await tester.tap(
      find.byKey(const ValueKey<String>('quote-card-tab-visibility')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('quote-card-visibility-book-title'),
        ),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('quote-card-book-title-text')),
      findsNothing,
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey<String>('quote-card-visibility-author')),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('quote-card-author-text')),
      findsNothing,
    );
  });

  testWidgets('toggle button collapses and expands controls', (tester) async {
    await pumpPage(tester);

    expect(
      find.byKey(const ValueKey<String>('quote-card-editor-panel')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('quote-card-toggle-controls')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('quote-card-editor-panel')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('quote-card-toggle-controls')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('quote-card-editor-panel')),
      findsOneWidget,
    );
  });
}
