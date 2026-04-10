import 'package:flutter_test/flutter_test.dart';
import 'package:uni/pages/reader/quote_card/models/quote_card_draft.dart';
import 'package:uni/pages/reader/quote_card/quote_card_style_resolver.dart';

void main() {
  test('every template resolves to the correct family', () {
    expect(
      QuoteCardTemplate.auroraMist.family,
      QuoteCardTemplateFamily.gradient,
    );
    expect(
      QuoteCardTemplate.editorialBloom.family,
      QuoteCardTemplateFamily.gradient,
    );
    expect(
      QuoteCardTemplate.nightGlow.family,
      QuoteCardTemplateFamily.gradient,
    );
    expect(QuoteCardTemplate.coverColumn.family, QuoteCardTemplateFamily.image);
    expect(
      QuoteCardTemplate.galleryFrame.family,
      QuoteCardTemplateFamily.image,
    );
    expect(QuoteCardTemplate.archiveNote.family, QuoteCardTemplateFamily.image);
  });

  test('gradient templates do not resolve an image height factor', () {
    final style = resolveQuoteCardStyle(
      draft: const QuoteCardDraft(template: QuoteCardTemplate.auroraMist),
    );

    expect(style.family, QuoteCardTemplateFamily.gradient);
    expect(style.imageHeightFactor, isNull);
  });

  test('image templates resolve expected height ratios per layout', () {
    final balanced = resolveQuoteCardStyle(
      draft: const QuoteCardDraft(
        template: QuoteCardTemplate.coverColumn,
        layout: QuoteCardLayoutPreset.center,
      ),
    );
    final imageFocus = resolveQuoteCardStyle(
      draft: const QuoteCardDraft(
        template: QuoteCardTemplate.coverColumn,
        layout: QuoteCardLayoutPreset.top,
      ),
    );
    final textFocus = resolveQuoteCardStyle(
      draft: const QuoteCardDraft(
        template: QuoteCardTemplate.coverColumn,
        layout: QuoteCardLayoutPreset.bottom,
      ),
    );

    expect(balanced.imageHeightFactor, 0.52);
    expect(imageFocus.imageHeightFactor, 0.58);
    expect(textFocus.imageHeightFactor, 0.46);
  });

  test(
    'archive note enables metadata grid while gallery frame keeps simple metadata',
    () {
      final archive = resolveQuoteCardStyle(
        draft: const QuoteCardDraft(template: QuoteCardTemplate.archiveNote),
      );
      final gallery = resolveQuoteCardStyle(
        draft: const QuoteCardDraft(template: QuoteCardTemplate.galleryFrame),
      );

      expect(archive.showMetadataGrid, isTrue);
      expect(archive.metadataLayout, QuoteCardMetadataLayout.grid);
      expect(gallery.showMetadataGrid, isFalse);
      expect(gallery.metadataLayout, QuoteCardMetadataLayout.bottomCenter);
    },
  );
}
