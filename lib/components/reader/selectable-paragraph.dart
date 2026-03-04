import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../entities/highlight-entity.dart';
import 'highlighted-text-span.dart';

class SelectableParagraph extends StatelessWidget {
  SelectableParagraph({
    required this.text,
    required this.highlights,
    required this.highlightActionLabel,
    required this.focusNode,
    this.textStyle,
    this.contentPadding = const EdgeInsets.all(16),
    required this.onSelectionChanged,
    required this.onHighlightRequested,
    super.key,
  }) : _builder = HighlightedTextSpanBuilder();

  final String text;
  final List<HighlightEntity> highlights;
  final String highlightActionLabel;
  final FocusNode focusNode;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry contentPadding;
  final void Function(TextSelection selection) onSelectionChanged;
  final void Function(TextSelection selection) onHighlightRequested;
  final HighlightedTextSpanBuilder _builder;

  @override
  Widget build(BuildContext context) {
    final baseStyle = textStyle ?? Theme.of(context).textTheme.bodyLarge;
    final spans = _builder.build(
      text: text,
      highlights: highlights,
      baseStyle: baseStyle,
    );

    return Padding(
      padding: contentPadding,
      child: SelectableText.rich(
        TextSpan(children: spans, style: baseStyle),
        focusNode: focusNode,
        onSelectionChanged: (selection, _) {
          onSelectionChanged(selection);
        },
        contextMenuBuilder: (context, editableTextState) {
          final selection = editableTextState.textEditingValue.selection;
          if (selection.isCollapsed) {
            return const SizedBox.shrink();
          }

          final selectedText = selection.textInside(
            editableTextState.textEditingValue.text,
          );
          final localizations = MaterialLocalizations.of(context);
          final canCopy = selectedText.isNotEmpty;

          return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: editableTextState.contextMenuAnchors,
            buttonItems: <ContextMenuButtonItem>[
              ContextMenuButtonItem(
                label: localizations.copyButtonLabel,
                onPressed: canCopy
                    ? () {
                        Clipboard.setData(ClipboardData(text: selectedText));
                        editableTextState.hideToolbar();
                      }
                    : null,
              ),
              ContextMenuButtonItem(
                label: highlightActionLabel,
                onPressed: () {
                  onHighlightRequested(selection);
                  editableTextState.hideToolbar();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
