import 'package:flutter/material.dart';

import '../../shared/constants/common-design-tokens.dart';

class HelpFaqPage extends StatelessWidget {
  const HelpFaqPage({super.key});

  static void push(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const HelpFaqPage()),
    );
  }

  static const List<_FaqEntry> _entries = <_FaqEntry>[
    _FaqEntry(
      question: 'How do I import a book?',
      answer: 'Go to the Library tab, tap the import button in the top right, '
          'and select an EPUB file from your device.',
    ),
    _FaqEntry(
      question: 'What file formats are supported?',
      answer: 'Currently only EPUB format is supported.',
    ),
    _FaqEntry(
      question: 'How does reading time tracking work?',
      answer:
          'Reading time is tracked automatically while you are actively reading. '
          'It pauses when the app is in the background or when you stop interacting.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommonDesignTokens.pageBackground,
      appBar: AppBar(
        backgroundColor: CommonDesignTokens.pageBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(
            Icons.arrow_back,
            color: CommonDesignTokens.textPrimary,
          ),
        ),
        title: const Text(
          'Help & FAQ',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: CommonDesignTokens.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: _entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final entry = _entries[index];
          return Container(
            decoration: BoxDecoration(
              color: CommonDesignTokens.cardBg,
              borderRadius: BorderRadius.circular(CommonDesignTokens.cardRadius),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 18),
                childrenPadding:
                    const EdgeInsets.fromLTRB(18, 0, 18, 16),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(CommonDesignTokens.cardRadius),
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(CommonDesignTokens.cardRadius),
                ),
                title: Text(
                  entry.question,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: CommonDesignTokens.textPrimary,
                  ),
                ),
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      entry.answer,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: CommonDesignTokens.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FaqEntry {
  const _FaqEntry({required this.question, required this.answer});

  final String question;
  final String answer;
}
