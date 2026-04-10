import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uni/pages/reader/quote_card/models/quote_card_draft.dart';
import 'package:uni/pages/reader/quote_card/models/reader_quote_card_payload.dart';
import 'package:uni/pages/reader/quote_card/reader_quote_card_page.dart';
import 'package:uni/pages/reader/quote_card/widgets/quote_card_preview.dart';

void main() {
  ReaderQuoteCardPayload buildPayload({String? coverDataUrl}) {
    return ReaderQuoteCardPayload(
      bookId: 'book-1',
      bookTitle: 'The Overstory',
      bookAuthor: 'Richard Powers',
      selectedText: 'The best time to plant a tree was ten years ago.',
      readerFontFamily: 'Georgia',
      readerThemeName: 'Paper',
      coverDataUrl: coverDataUrl,
      chapterTitle: 'Roots',
      pageLabel: 'Page 18',
      collectionLabel: 'Spring Notes',
    );
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    ReaderQuoteCardPayload? payload,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ReaderQuoteCardPage(payload: payload ?? buildPayload()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapOption(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(ValueKey<String>(key)));
    await tester.pumpAndSettle();
  }

  Future<void> revealTemplateOption(
    WidgetTester tester,
    String optionKey,
  ) async {
    final listFinder = find.byKey(
      const ValueKey<String>('quote-card-options-template'),
    );
    await tester.drag(listFinder, const Offset(1600, 0));
    await tester.pumpAndSettle();

    for (var index = 0; index < 8; index += 1) {
      final optionFinder = find.byKey(ValueKey<String>(optionKey));
      if (optionFinder.evaluate().isNotEmpty) {
        return;
      }
      await tester.drag(listFinder, const Offset(-240, 0));
      await tester.pumpAndSettle();
    }
  }

  QuoteCardPreview previewOf(WidgetTester tester) {
    return tester.widget<QuoteCardPreview>(find.byType(QuoteCardPreview));
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

  testWidgets('template list contains all six V2 templates', (tester) async {
    await pumpPage(tester);

    expect(find.text('Aurora'), findsOneWidget);
    expect(find.text('Editorial'), findsOneWidget);
    expect(find.text('Night Glow'), findsOneWidget);

    await revealTemplateOption(tester, 'quote-card-option-template-cover');
    expect(find.text('Cover'), findsOneWidget);
    await revealTemplateOption(tester, 'quote-card-option-template-gallery');
    expect(find.text('Gallery'), findsOneWidget);
    await revealTemplateOption(tester, 'quote-card-option-template-archive');
    expect(find.text('Archive'), findsOneWidget);
  });

  testWidgets('uses split layout on tablet widths', (tester) async {
    await pumpPage(tester, size: const Size(1180, 900));

    expect(
      find.byKey(const ValueKey<String>('quote-card-tablet-layout')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('quote-card-side-editor')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('quote-card-bottom-editor')),
      findsNothing,
    );
  });

  testWidgets('background panel adapts between gradient and image families', (
    tester,
  ) async {
    await pumpPage(tester);

    await tapOption(tester, 'quote-card-tab-background');
    expect(
      find.byKey(
        const ValueKey<String>('quote-card-option-background-intensity-subtle'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('quote-card-option-image-source-cover'),
      ),
      findsNothing,
    );

    await tapOption(tester, 'quote-card-tab-template');
    await revealTemplateOption(tester, 'quote-card-option-template-cover');
    await tapOption(tester, 'quote-card-option-template-cover');
    await tapOption(tester, 'quote-card-tab-background');

    expect(
      find.byKey(
        const ValueKey<String>('quote-card-option-image-source-cover'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('quote-card-option-background-intensity-subtle'),
      ),
      findsNothing,
    );
  });

  testWidgets('layout labels adapt between gradient and image families', (
    tester,
  ) async {
    await pumpPage(tester);

    await tapOption(tester, 'quote-card-tab-layout');
    expect(find.text('Top'), findsOneWidget);
    expect(find.text('Center'), findsOneWidget);
    expect(find.text('Bottom'), findsOneWidget);

    await tapOption(tester, 'quote-card-tab-template');
    await revealTemplateOption(tester, 'quote-card-option-template-cover');
    await tapOption(tester, 'quote-card-option-template-cover');
    await tapOption(tester, 'quote-card-tab-layout');

    expect(find.text('Image Focus'), findsOneWidget);
    expect(find.text('Balanced'), findsOneWidget);
    expect(find.text('Text Focus'), findsOneWidget);
  });

  testWidgets('collection visibility is only shown for image templates', (
    tester,
  ) async {
    await pumpPage(tester);

    await tapOption(tester, 'quote-card-tab-visibility');
    expect(
      find.byKey(const ValueKey<String>('quote-card-visibility-collection')),
      findsNothing,
    );

    await tapOption(tester, 'quote-card-tab-template');
    await revealTemplateOption(tester, 'quote-card-option-template-archive');
    await tapOption(tester, 'quote-card-option-template-archive');
    await tapOption(tester, 'quote-card-tab-visibility');

    expect(
      find.byKey(const ValueKey<String>('quote-card-visibility-collection')),
      findsOneWidget,
    );
  });

  testWidgets('selecting templates switches family and applies defaults', (
    tester,
  ) async {
    await pumpPage(tester);

    await revealTemplateOption(tester, 'quote-card-option-template-cover');
    await tapOption(tester, 'quote-card-option-template-cover');
    var preview = previewOf(tester);
    expect(preview.draft.template.family, QuoteCardTemplateFamily.image);
    expect(preview.draft.background, QuoteCardBackgroundPreset.archivePaper);

    await revealTemplateOption(tester, 'quote-card-option-template-aurora');
    await tapOption(tester, 'quote-card-option-template-aurora');
    preview = previewOf(tester);
    expect(preview.draft.template.family, QuoteCardTemplateFamily.gradient);
    expect(preview.draft.background, QuoteCardBackgroundPreset.mist);

    await revealTemplateOption(tester, 'quote-card-option-template-night-glow');
    await tapOption(tester, 'quote-card-option-template-night-glow');
    preview = previewOf(tester);
    expect(preview.draft.background, QuoteCardBackgroundPreset.night);
    expect(preview.draft.fontPreset, QuoteCardFontPreset.displaySerif);
  });

  testWidgets('gradient template renders no hero image', (tester) async {
    await pumpPage(tester);

    expect(
      find.byKey(const ValueKey<String>('quote-card-hero-image')),
      findsNothing,
    );
  });

  testWidgets('image template renders hero image and falls back to artwork', (
    tester,
  ) async {
    await pumpPage(tester, payload: buildPayload(coverDataUrl: null));

    await revealTemplateOption(tester, 'quote-card-option-template-cover');
    await tapOption(tester, 'quote-card-option-template-cover');

    final image = tester.widget<Image>(
      find.byKey(const ValueKey<String>('quote-card-hero-image')),
    );
    expect(image.image, isA<AssetImage>());
  });

  testWidgets(
    'archive template shows metadata grid and hides collection cleanly',
    (tester) async {
      await pumpPage(tester);

      await revealTemplateOption(tester, 'quote-card-option-template-archive');
      await tapOption(tester, 'quote-card-option-template-archive');
      expect(
        find.byKey(const ValueKey<String>('quote-card-metadata-grid')),
        findsOneWidget,
      );
      expect(find.text('COLLECTION'), findsNothing);

      await tapOption(tester, 'quote-card-tab-visibility');
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('quote-card-visibility-collection')),
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('quote-card-visibility-collection'),
          ),
          matching: find.byType(Switch),
        ),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.text('COLLECTION'), findsOneWidget);
      expect(find.text('Spring Notes'), findsOneWidget);
    },
  );

  testWidgets('visibility toggles hide title and author metadata', (
    tester,
  ) async {
    await pumpPage(tester);

    await tapOption(tester, 'quote-card-tab-visibility');

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

    await tapOption(tester, 'quote-card-toggle-controls');
    expect(
      find.byKey(const ValueKey<String>('quote-card-editor-panel')),
      findsNothing,
    );

    await tapOption(tester, 'quote-card-toggle-controls');
    expect(
      find.byKey(const ValueKey<String>('quote-card-editor-panel')),
      findsOneWidget,
    );
  });
}
