import 'package:flutter_test/flutter_test.dart';
import 'package:uni/pages/reader/models/reader_tooltip_action_spec.dart';

void main() {
  test('selection spec for unmarked selection uses Mark and keeps note', () {
    final spec = ReaderTooltipActionSpec.forSelection(
      canEditSingle: false,
      canOnlyUnmark: false,
    );

    expect(spec.actionLabel, 'Mark');
    expect(spec.showPrimaryAction, isTrue);
    expect(spec.showAuxiliaryActions, isTrue);
    expect(spec.showNoteAction, isTrue);
    expect(spec.showUnmarkAction, isFalse);
  });

  test('selection spec for exact single mark uses Edit', () {
    final spec = ReaderTooltipActionSpec.forSelection(
      canEditSingle: true,
      canOnlyUnmark: false,
    );

    expect(spec.actionLabel, 'Edit');
    expect(spec.showPrimaryAction, isTrue);
    expect(spec.showAuxiliaryActions, isTrue);
    expect(spec.showNoteAction, isTrue);
    expect(spec.showUnmarkAction, isFalse);
  });

  test('selection spec for overlap-only uses Unmark and hides note', () {
    final spec = ReaderTooltipActionSpec.forSelection(
      canEditSingle: false,
      canOnlyUnmark: true,
    );

    expect(spec.actionLabel, 'Unmark');
    expect(spec.showPrimaryAction, isTrue);
    expect(spec.showAuxiliaryActions, isTrue);
    expect(spec.showNoteAction, isFalse);
    expect(spec.showUnmarkAction, isFalse);
  });

  test('focused single mark hides primary action and keeps direct mark actions', () {
    final spec = ReaderTooltipActionSpec.forFocused(annotationCount: 1);

    expect(spec.actionLabel, isEmpty);
    expect(spec.showPrimaryAction, isFalse);
    expect(spec.showAuxiliaryActions, isTrue);
    expect(spec.showNoteAction, isTrue);
    expect(spec.showUnmarkAction, isTrue);
  });

  test('focused multi-mark tap only keeps primary unmark', () {
    final spec = ReaderTooltipActionSpec.forFocused(annotationCount: 2);

    expect(spec.actionLabel, 'Unmark');
    expect(spec.showPrimaryAction, isTrue);
    expect(spec.showAuxiliaryActions, isFalse);
    expect(spec.showNoteAction, isFalse);
    expect(spec.showUnmarkAction, isFalse);
  });
}
