class ReaderTooltipActionSpec {
  const ReaderTooltipActionSpec({
    required this.actionLabel,
    required this.showPrimaryAction,
    required this.showAuxiliaryActions,
    required this.showNoteAction,
    required this.showUnmarkAction,
  });

  final String actionLabel;
  final bool showPrimaryAction;
  final bool showAuxiliaryActions;
  final bool showNoteAction;
  final bool showUnmarkAction;

  factory ReaderTooltipActionSpec.forSelection({
    required bool canEditSingle,
    required bool canOnlyUnmark,
  }) {
    final actionLabel = canOnlyUnmark
        ? 'Unmark'
        : canEditSingle
        ? 'Edit'
        : 'Mark';
    return ReaderTooltipActionSpec(
      actionLabel: actionLabel,
      showPrimaryAction: true,
      showAuxiliaryActions: true,
      showNoteAction: !canOnlyUnmark,
      showUnmarkAction: false,
    );
  }

  factory ReaderTooltipActionSpec.forFocused({required int annotationCount}) {
    if (annotationCount <= 1) {
      return const ReaderTooltipActionSpec(
        actionLabel: '',
        showPrimaryAction: false,
        showAuxiliaryActions: true,
        showNoteAction: true,
        showUnmarkAction: true,
      );
    }
    return const ReaderTooltipActionSpec(
      actionLabel: 'Unmark',
      showPrimaryAction: true,
      showAuxiliaryActions: false,
      showNoteAction: false,
      showUnmarkAction: false,
    );
  }
}
