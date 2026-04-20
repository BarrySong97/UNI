import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../entities/explain-history-entity.dart';
import '../../../services/ai/explain_prompt_builder.dart';
import '../../../services/ai/ai_settings_service.dart';
import '../../../services/search/image_search_service.dart';
import '../../../services/reader/selection/reader_selection_text_sanitizer.dart';
import '../../../shared/constants/common-design-tokens.dart';
import '../../../shared/widgets/pronunciation_selection_toolbar.dart';
import '../../../services/ai/openai_llm_provider.dart';
import '../../../services/db/app-database.dart';
import '../../../services/phonetics/phonetics_service.dart';
import '../../../services/tts/tts_service.dart';

class ReaderExplainSheet extends StatefulWidget {
  const ReaderExplainSheet({
    super.key,
    required this.selectedText,
    required this.rawSelectedText,
    required this.pageContext,
    required this.paragraphContext,
    required this.aiSettings,
    required this.languageConfig,
    required this.bookTitle,
    required this.phoneticsService,
    required this.ttsService,
    required this.database,
    required this.bookId,
    required this.chapterIndex,
    this.bookLanguage,
  });

  final String selectedText;
  final String rawSelectedText;
  final String pageContext;

  /// The plain text of the source paragraph(s) containing the selection,
  /// extracted directly from the original [RenderNode] tree.  Used for
  /// sentence extraction so that `indexOf` works reliably regardless of
  /// whether the K-P or greedy layout path was used.
  final String paragraphContext;
  final AiSettingsService aiSettings;
  final AiLanguageConfig languageConfig;
  final String bookTitle;
  final PhoneticsService phoneticsService;
  final TtsService ttsService;
  final AppDatabase database;
  final String bookId;
  final int chapterIndex;
  final String? bookLanguage;

  static Future<void> show({
    required BuildContext context,
    required String selectedText,
    required String rawSelectedText,
    required String pageContext,
    required String paragraphContext,
    required AiSettingsService aiSettings,
    required AiLanguageConfig languageConfig,
    required String bookTitle,
    required PhoneticsService phoneticsService,
    required TtsService ttsService,
    required AppDatabase database,
    required String bookId,
    required int chapterIndex,
    String? bookLanguage,
    bool isTablet = false,
    bool selectionOnRightPage = false,
  }) {
    final sheet = ReaderExplainSheet(
      selectedText: selectedText,
      rawSelectedText: rawSelectedText,
      pageContext: pageContext,
      paragraphContext: paragraphContext,
      aiSettings: aiSettings,
      languageConfig: languageConfig,
      bookTitle: bookTitle,
      phoneticsService: phoneticsService,
      ttsService: ttsService,
      database: database,
      bookId: bookId,
      chapterIndex: chapterIndex,
      bookLanguage: bookLanguage,
    );

    if (!isTablet) {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => sheet,
      );
    }

    // Tablet mode: floating panel on the opposite side of the selection.
    // Text on right page → panel slides in from the left.
    // Text on left page → panel slides in from the right.
    final showOnLeft = selectionOnRightPage;
    const panelMargin = 20.0;

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss explain sheet',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, _, __) {
        final mq = MediaQuery.of(dialogContext);
        final screenWidth = mq.size.width;
        final screenHeight = mq.size.height;
        final panelWidth = screenWidth / 2 - panelMargin * 2;
        final panelHeight = screenHeight * 0.85;

        return Align(
          alignment: showOnLeft ? Alignment.centerLeft : Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(
              left: showOnLeft ? panelMargin : 0,
              right: showOnLeft ? 0 : panelMargin,
              bottom: panelMargin,
              top: panelMargin,
            ),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              elevation: 12,
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: panelWidth,
                height: panelHeight,
                child: sheet,
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        // Slide horizontally from the corresponding edge.
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(showOnLeft ? -1 : 1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  @override
  State<ReaderExplainSheet> createState() => _ReaderExplainSheetState();
}

class _ReaderExplainSheetState extends State<ReaderExplainSheet>
    with SingleTickerProviderStateMixin {
  late final ExplainAiService _aiService;
  late final AnimationController _shimmerController;
  final ScrollController _scrollController = ScrollController();
  String _aiResponse = '';
  bool _isStreaming = false;
  String? _error;

  late final bool _isWordOrPhrase;
  late final bool _isSingleWord;
  late final String _containingSentence;
  late final bool _customPromptModeEnabled;
  ExplainStructuredData? _structuredData;

  // Phonetics state (word mode only).
  PhoneticsResult? _phonetics;
  PhoneticsLookupOutcome? _phoneticsOutcome;
  String? _playingAccent;
  bool _isPhoneticsAiLoading = false;

  // Image search state (word/phrase mode only).
  List<ImageSearchResult>? _imageSearchResults;
  bool _isImageSearching = false;

  // Explain text inline selection state.
  final Map<String, PhoneticsLookupOutcome> _inlineSelectionPhoneticsCache =
      <String, PhoneticsLookupOutcome>{};
  String _inlineSelectionRawText = '';
  String _inlineSelectionText = '';
  String? _inlineSelectionLookupKey;
  bool _isInlineSelectionPhoneticsLoading = false;
  bool _isInlineSelectionAiLoading = false;

  static final _sentenceEndPattern = RegExp(r'[.!?。！？\n]');

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    widget.ttsService.addListener(_onTtsChanged);

    final selectedText = widget.selectedText;
    final text = selectedText.length > 4000
        ? '${selectedText.substring(0, 4000)}\n(text truncated)'
        : selectedText;

    _isWordOrPhrase = isReaderWordOrPhraseSelection(
      rawSelectedText: widget.rawSelectedText,
      normalizedSelectedText: selectedText,
    );
    _isSingleWord =
        _isWordOrPhrase && isReaderSingleWordSelection(selectedText);

    _containingSentence = _isWordOrPhrase
        ? _extractContainingSentence(widget.paragraphContext, selectedText)
        : '';

    final surroundingContext = _isWordOrPhrase
        ? _containingSentence
        : widget.pageContext;

    final config = widget.languageConfig;
    _customPromptModeEnabled = config.customPromptModeEnabled;
    final resolvedLanguageCode = widget.aiSettings.resolveBookLanguage(
      widget.bookLanguage,
    );
    final systemPrompt = buildExplainSystemPrompt(
      bookTitle: widget.bookTitle,
      selectedText: text,
      context: surroundingContext,
      languageCode: resolvedLanguageCode,
      config: config,
      includePartOfSpeech: _isSingleWord,
    );

    _aiService = ExplainAiService(
      settings: widget.aiSettings,
      systemPrompt: systemPrompt,
      model: config.model,
    );

    if (_isWordOrPhrase) {
      _lookupPhonetics();
      _fetchImageSearchResults();
    }
    _loadOrFetch();

    // Auto read-aloud selected text when sheet opens (if enabled).
    if (widget.aiSettings.autoReadAloud) {
      widget.ttsService.speakForBookLanguage(
        widget.selectedText,
        widget.bookLanguage,
      );
    }
  }

  void _onTtsChanged() {
    if (!widget.ttsService.isSpeaking && _playingAccent != null) {
      if (mounted) setState(() => _playingAccent = null);
    }
  }

  Future<void> _lookupPhonetics() async {
    try {
      final outcome = await widget.phoneticsService.lookupWithOutcome(
        widget.selectedText,
      );
      if (mounted) {
        setState(() {
          _phoneticsOutcome = outcome;
          _phonetics = outcome.result;
        });
      }
    } catch (_) {}
  }

  Future<void> _lookupPhoneticsWithAi() async {
    if (_isPhoneticsAiLoading) {
      return;
    }

    setState(() => _isPhoneticsAiLoading = true);
    try {
      final result = await widget.phoneticsService.fetchWithAiAndCache(
        widget.selectedText,
      );
      if (mounted) {
        setState(() {
          _phonetics = result;
          _phoneticsOutcome = PhoneticsLookupOutcome(
            result: result,
            foundLocally: false,
            foundInAiCache: true,
            canTryAi: widget.phoneticsService.supportsAiLookup,
          );
        });
      }
    } on PhoneticsAiNotConfiguredException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'AI phonetics is not configured. Set it up in Settings.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI phonetics lookup failed.')),
        );
      }
    }
    if (mounted) {
      setState(() => _isPhoneticsAiLoading = false);
    }
  }

  Future<void> _fetchImageSearchResults() async {
    setState(() => _isImageSearching = true);
    try {
      final results = await ImageSearchService.search(
        widget.aiSettings.imageSearchEngine,
        widget.selectedText,
      );
      if (mounted) {
        setState(() {
          _imageSearchResults = results;
          _isImageSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isImageSearching = false);
    }
  }

  Future<void> _openImageSearchInBrowser() async {
    final url = ImageSearchService.webSearchUrl(
      widget.aiSettings.imageSearchEngine,
      widget.selectedText,
    );
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // Silently ignore — image search browser launch is non-critical.
    }
  }

  Future<void> _playPronunciation(String accent) async {
    final languageCode = accent == 'uk' ? 'en_GB' : 'en_US';
    final model = widget.ttsService.modelInfoForLanguage(languageCode);
    if (model == null || !widget.ttsService.modelManager.isReady(model)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'TTS model not downloaded. Please download it in Settings.',
            ),
          ),
        );
      }
      return;
    }
    if (_playingAccent == accent && widget.ttsService.isSpeaking) {
      await widget.ttsService.stop();
      return;
    }
    setState(() => _playingAccent = accent);
    await widget.ttsService.speakWithLanguage(
      widget.selectedText,
      languageCode,
    );
  }

  Future<void> _playInlineSelectionPronunciation(String text) async {
    final languageCode = widget.ttsService.resolveBookLanguage(
      widget.bookLanguage,
    );
    final model = widget.ttsService.modelInfoForLanguage(languageCode);
    if (model == null || !widget.ttsService.modelManager.isReady(model)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'TTS model not downloaded. Please download it in Settings.',
            ),
          ),
        );
      }
      return;
    }
    await widget.ttsService.speakWithLanguage(text, languageCode);
  }

  void _onInlineSelectionChanged(SelectedContent? content) {
    final rawText = content?.plainText ?? '';
    final normalizedText = sanitizeReaderSelectionText(rawText);
    if (rawText == _inlineSelectionRawText &&
        normalizedText == _inlineSelectionText) {
      return;
    }

    final isWordOrPhrase = _isInlineSelectionWordOrPhrase(
      rawText,
      normalizedText,
    );

    setState(() {
      _inlineSelectionRawText = rawText;
      _inlineSelectionText = normalizedText;
      if (!isWordOrPhrase) {
        _inlineSelectionLookupKey = null;
        _isInlineSelectionPhoneticsLoading = false;
      }
    });

    if (isWordOrPhrase) {
      _lookupInlineSelectionPhonetics(normalizedText);
    }
  }

  bool _isInlineSelectionWordOrPhrase(String rawText, String normalizedText) {
    if (normalizedText.isEmpty) return false;
    return isReaderWordOrPhraseSelection(
      rawSelectedText: rawText,
      normalizedSelectedText: normalizedText,
    );
  }

  Future<void> _lookupInlineSelectionPhonetics(String text) async {
    if (_inlineSelectionPhoneticsCache.containsKey(text)) {
      if (mounted && _isInlineSelectionPhoneticsLoading) {
        setState(() => _isInlineSelectionPhoneticsLoading = false);
      }
      return;
    }

    _inlineSelectionLookupKey = text;
    setState(() => _isInlineSelectionPhoneticsLoading = true);

    try {
      final result = await widget.phoneticsService.lookupWithOutcome(text);
      _inlineSelectionPhoneticsCache[text] = result;
    } catch (_) {
      _inlineSelectionPhoneticsCache[text] = PhoneticsLookupOutcome.empty(
        canTryAi: widget.phoneticsService.supportsAiLookup,
      );
    }

    if (!mounted || _inlineSelectionLookupKey != text) {
      return;
    }

    setState(() => _isInlineSelectionPhoneticsLoading = false);
  }

  Future<void> _lookupInlineSelectionPhoneticsWithAi() async {
    final text = _inlineSelectionText;
    if (text.isEmpty || _isInlineSelectionAiLoading) {
      return;
    }

    setState(() => _isInlineSelectionAiLoading = true);
    try {
      final result = await widget.phoneticsService.fetchWithAiAndCache(text);
      _inlineSelectionPhoneticsCache[text] = PhoneticsLookupOutcome(
        result: result,
        foundLocally: false,
        foundInAiCache: true,
        canTryAi: widget.phoneticsService.supportsAiLookup,
      );
    } on PhoneticsAiNotConfiguredException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'AI phonetics is not configured. Set it up in Settings.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI phonetics lookup failed.')),
        );
      }
    }

    if (!mounted || _inlineSelectionText != text) {
      return;
    }
    setState(() => _isInlineSelectionAiLoading = false);
  }

  Widget _buildInlineSelectionContextMenu(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    if (!_isInlineSelectionWordOrPhrase(
      _inlineSelectionRawText,
      _inlineSelectionText,
    )) {
      return AdaptiveTextSelectionToolbar.selectableRegion(
        selectableRegionState: selectableRegionState,
      );
    }

    ContextMenuButtonItem? copyItem;
    for (final item in selectableRegionState.contextMenuButtonItems) {
      if (item.type == ContextMenuButtonType.copy) {
        copyItem = item;
        break;
      }
    }

    return PronunciationSelectionToolbar(
      anchors: selectableRegionState.contextMenuAnchors,
      ipaLabel: _inlineSelectionIpaLabel,
      aiButtonLabel: _showInlineSelectionAiButton ? 'AI' : null,
      onAiPressed: _showInlineSelectionAiButton
          ? _lookupInlineSelectionPhoneticsWithAi
          : null,
      isAiLoading: _isInlineSelectionAiLoading,
      buttonItems: [
        ContextMenuButtonItem(
          label: 'Pronounce',
          onPressed: () {
            selectableRegionState.hideToolbar();
            _playInlineSelectionPronunciation(_inlineSelectionText);
          },
        ),
        ContextMenuButtonItem(
          type: ContextMenuButtonType.copy,
          onPressed:
              copyItem?.onPressed ??
              () {
                Clipboard.setData(ClipboardData(text: _inlineSelectionText));
                selectableRegionState.hideToolbar();
              },
        ),
      ],
    );
  }

  String? get _inlineSelectionIpaLabel {
    if (_inlineSelectionText.isEmpty) {
      return null;
    }

    final outcome = _inlineSelectionPhoneticsCache[_inlineSelectionText];
    final phonetics = outcome?.result;
    if (phonetics == null) {
      return null;
    }

    final languageCode = widget.ttsService.resolveBookLanguage(
      widget.bookLanguage,
    );
    final preferredIpa = switch (languageCode) {
      'en_GB' => phonetics.uk,
      'en_US' => phonetics.us,
      _ => phonetics.us.isNotEmpty ? phonetics.us : phonetics.uk,
    };

    if (preferredIpa.isNotEmpty) {
      return '/$preferredIpa/';
    }

    final fallbackIpa = phonetics.us.isNotEmpty ? phonetics.us : phonetics.uk;
    if (fallbackIpa.isNotEmpty) {
      return '/$fallbackIpa/';
    }

    return null;
  }

  bool get _showInlineSelectionAiButton {
    if (_inlineSelectionText.isEmpty || _isInlineSelectionPhoneticsLoading) {
      return false;
    }
    final outcome = _inlineSelectionPhoneticsCache[_inlineSelectionText];
    if (outcome == null) {
      return false;
    }
    return !outcome.result.hasAny && outcome.canTryAi;
  }

  static String _extractContainingSentence(String fullText, String target) {
    final index = fullText.indexOf(target);
    if (index < 0) return fullText;

    var sentenceStart = 0;
    for (var i = index - 1; i >= 0; i--) {
      if (_sentenceEndPattern.hasMatch(fullText[i])) {
        sentenceStart = i + 1;
        break;
      }
    }

    var sentenceEnd = fullText.length;
    for (var i = index + target.length; i < fullText.length; i++) {
      if (_sentenceEndPattern.hasMatch(fullText[i])) {
        sentenceEnd = i + 1;
        break;
      }
    }

    var result = fullText.substring(sentenceStart, sentenceEnd).trim();

    // Safety net: if the extracted "sentence" is unreasonably long (no
    // punctuation boundary found), truncate to a window around the target.
    if (result.length > 300) {
      final targetInResult = result.indexOf(target);
      if (targetInResult >= 0) {
        final windowStart = (targetInResult - 100).clamp(0, result.length);
        final windowEnd = (targetInResult + target.length + 100).clamp(
          0,
          result.length,
        );
        result = result.substring(windowStart, windowEnd).trim();
      }
    }

    return result;
  }

  @override
  void dispose() {
    widget.ttsService.removeListener(_onTtsChanged);
    _shimmerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Try cache first, fall back to AI.
  Future<void> _loadOrFetch() async {
    setState(() {
      _isStreaming = true;
      _error = null;
      _aiResponse = '';
      _structuredData = null;
    });

    try {
      final cached = await widget.database.getExplainCache(
        bookId: widget.bookId,
        chapterIndex: widget.chapterIndex,
        selectedText: widget.selectedText,
        contextSentence: _containingSentence,
      );
      if (cached != null && mounted) {
        setState(() {
          _aiResponse = cached;
          _structuredData = _customPromptModeEnabled
              ? null
              : ExplainStructuredData.tryParse(cached);
          _isStreaming = false;
        });
        return;
      }
    } catch (_) {}

    await _fetchFromAi();
  }

  /// Force re-fetch from AI, ignoring cache.
  Future<void> _refresh() async {
    if (_isStreaming) return;
    setState(() {
      _isStreaming = true;
      _error = null;
      _aiResponse = '';
      _structuredData = null;
    });
    await _fetchFromAi();
  }

  Future<void> _fetchFromAi() async {
    try {
      await for (final chunk in _aiService.sendMessage(
        'Explain this passage',
      )) {
        if (!mounted) return;
        setState(() {
          _aiResponse += chunk;
        });
        if (_customPromptModeEnabled) _scrollToBottom();
      }
      final parsed = _customPromptModeEnabled
          ? null
          : ExplainStructuredData.tryParse(_aiResponse);
      // Save to cache after successful completion.
      if (_aiResponse.isNotEmpty) {
        widget.database.upsertExplainCache(
          bookId: widget.bookId,
          chapterIndex: widget.chapterIndex,
          selectedText: widget.selectedText,
          contextSentence: _containingSentence,
          response: _aiResponse,
        );
      }
      if (!mounted) return;
      setState(() {
        _structuredData = parsed;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isStreaming = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: CommonDesignTokens.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Header: word + sentence, or text preview
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _isWordOrPhrase ? _buildWordHeader() : _buildTextPreview(),
          ),
          const SizedBox(height: 20),
          // AI response
          Expanded(child: _buildResponseArea()),
          // Error
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 13,
                  decoration: TextDecoration.none,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildWordHeader() {
    final partOfSpeech = _isSingleWord
        ? _structuredData?.partOfSpeech.trim() ?? ''
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Word + refresh button on the same line
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                widget.selectedText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: CommonDesignTokens.textPrimary,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            if (!_isStreaming)
              GestureDetector(
                onTap: _refresh,
                child: const Icon(
                  Icons.sync,
                  size: 22,
                  color: CommonDesignTokens.textSecondary,
                ),
              ),
          ],
        ),
        if (partOfSpeech.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildPartOfSpeechChip(partOfSpeech),
        ],
        // Phonetics row: IPA + play button (hidden when no IPA available).
        if (_phonetics != null &&
            (_phonetics!.us.isNotEmpty || _phonetics!.uk.isNotEmpty)) ...[
          const SizedBox(height: 12),
          _buildPhoneticsRow(),
        ] else if (_phoneticsOutcome?.canTryAi == true) ...[
          const SizedBox(height: 12),
          _buildAiPhoneticsButton(),
        ],
        if (_containingSentence.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSentenceWithBoldWord(_containingSentence, widget.selectedText),
        ],
      ],
    );
  }

  Widget _buildPartOfSpeechChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: CommonDesignTokens.pageBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: CommonDesignTokens.textSecondary,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  Widget _buildPhoneticsRow() {
    final ph = _phonetics!;
    final usChip = ph.us.isNotEmpty
        ? _buildAccentChip('US', ph.us, 'us')
        : null;
    final ukChip = ph.uk.isNotEmpty
        ? _buildAccentChip('UK', ph.uk, 'uk')
        : null;

    final chips = [if (usChip != null) usChip, if (ukChip != null) ukChip];

    if (chips.isEmpty) return const SizedBox.shrink();
    if (chips.length == 1) return chips.first;

    // Try horizontal first; fall back to vertical when too wide.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Rough threshold: if both IPAs together are likely to overflow,
        // stack vertically.  Each IPA char ≈ 8px at fontSize 14; add
        // label (22px) + icon (20px) + gaps (10px) ≈ 52px per chip.
        final estimatedWidth =
            (ph.us.length + ph.uk.length) * 8.0 + 52 * 2 + 16;
        if (estimatedWidth > constraints.maxWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [chips[0], const SizedBox(height: 4), chips[1]],
          );
        }
        return Row(children: [chips[0], const SizedBox(width: 16), chips[1]]);
      },
    );
  }

  Widget _buildAiPhoneticsButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: _isPhoneticsAiLoading ? null : _lookupPhoneticsWithAi,
        icon: _isPhoneticsAiLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome, size: 18),
        label: const Text('AI'),
      ),
    );
  }

  Widget _buildAccentChip(String label, String ipa, String accent) {
    final isPlaying = _playingAccent == accent && widget.ttsService.isSpeaking;

    return GestureDetector(
      onTap: () => _playPronunciation(accent),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: CommonDesignTokens.pageBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: CommonDesignTokens.textSecondary,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '/$ipa/',
                style: const TextStyle(
                  fontSize: 14,
                  color: CommonDesignTokens.textPrimary,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              isPlaying ? Icons.stop_circle_outlined : Icons.volume_up,
              size: 18,
              color: isPlaying
                  ? CommonDesignTokens.textPrimary
                  : CommonDesignTokens.headerLabelColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentenceWithBoldWord(String sentence, String word) {
    final index = sentence.indexOf(word);

    Widget textContent;
    if (index < 0) {
      textContent = Text(
        '"$sentence"',
        style: const TextStyle(
          fontSize: 14,
          color: CommonDesignTokens.textSecondary,
          fontStyle: FontStyle.italic,
          height: 1.5,
          decoration: TextDecoration.none,
        ),
      );
    } else {
      final before = sentence.substring(0, index);
      final after = sentence.substring(index + word.length);
      textContent = RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 14,
            color: CommonDesignTokens.textSecondary,
            fontStyle: FontStyle.italic,
            height: 1.5,
          ),
          children: [
            TextSpan(text: '"$before'),
            TextSpan(
              text: word,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: CommonDesignTokens.textPrimary,
              ),
            ),
            TextSpan(text: '$after"'),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CommonDesignTokens.pageBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: textContent,
    );
  }

  Widget _buildTextPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Spacer(),
            if (!_isStreaming)
              GestureDetector(
                onTap: _refresh,
                child: const Icon(
                  Icons.sync,
                  size: 22,
                  color: CommonDesignTokens.textSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CommonDesignTokens.pageBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            widget.selectedText.length > 200
                ? '${widget.selectedText.substring(0, 200)}...'
                : widget.selectedText,
            style: const TextStyle(
              fontSize: 13,
              color: CommonDesignTokens.textSecondary,
              fontStyle: FontStyle.italic,
              decoration: TextDecoration.none,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildResponseArea() {
    // AI content part: skeleton while loading, structured or markdown once
    // available. Explain text is wrapped in a SelectionArea so long-pressing
    // a word or phrase can surface IPA / Pronounce / Copy actions.
    Widget aiContent;
    if (_aiResponse.isEmpty && _isStreaming) {
      aiContent = _buildSkeleton();
    } else if (!_customPromptModeEnabled) {
      aiContent = _buildStructuredContent();
    } else {
      aiContent = MarkdownBody(
        data: _aiResponse,
        selectable: false,
        styleSheet: MarkdownStyleSheet(
          p: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: CommonDesignTokens.textPrimary,
            decoration: TextDecoration.none,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectionArea(
            onSelectionChanged: _onInlineSelectionChanged,
            contextMenuBuilder: _buildInlineSelectionContextMenu,
            child: aiContent,
          ),
          if (_isWordOrPhrase) _buildVisualReferenceSection(),
        ],
      ),
    );
  }

  Widget _buildStructuredContent() {
    final data = _structuredData;
    if (data == null) {
      return MarkdownBody(
        data: _aiResponse,
        selectable: false,
        styleSheet: MarkdownStyleSheet(
          p: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: CommonDesignTokens.textPrimary,
            decoration: TextDecoration.none,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Meaning section header
        _buildSectionHeader(Icons.menu_book_outlined, 'Meaning'),
        const SizedBox(height: 10),
        // Meaning body
        Text(
          data.meaningExplain,
          style: const TextStyle(
            fontSize: 17,
            height: 1.55,
            fontWeight: FontWeight.w500,
            color: CommonDesignTokens.textPrimary,
            decoration: TextDecoration.none,
          ),
        ),
        // Divider
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Divider(
            height: 1,
            thickness: 1,
            color: CommonDesignTokens.pageBackground,
          ),
        ),
        // Details & Usage section header
        _buildSectionHeader(Icons.format_list_bulleted, 'Details & Usage'),
        const SizedBox(height: 12),
        // Detail bullets
        for (final detail in data.detailExplain)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '• $detail',
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: CommonDesignTokens.textPrimary,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        if (data.detailExplain.isEmpty)
          const Text(
            'No extra detail.',
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: CommonDesignTokens.textSecondary,
              decoration: TextDecoration.none,
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSectionHeader(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 18, color: CommonDesignTokens.headerLabelColor),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: CommonDesignTokens.headerLabelColor,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Visual Reference (image search)
  // ---------------------------------------------------------------------------

  Widget _buildVisualReferenceSection() {
    // Hide entirely when there is nothing to show and not loading.
    final hasResults =
        _imageSearchResults != null && _imageSearchResults!.isNotEmpty;
    if (!_isImageSearching && !hasResults) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Divider
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Divider(
            height: 1,
            thickness: 1,
            color: CommonDesignTokens.pageBackground,
          ),
        ),
        // Section header: icon + label on left, pill button on right.
        Row(
          children: [
            const Icon(
              Icons.image_outlined,
              size: 18,
              color: CommonDesignTokens.headerLabelColor,
            ),
            const SizedBox(width: 6),
            const Text(
              'Visual Reference',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: CommonDesignTokens.headerLabelColor,
                decoration: TextDecoration.none,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _openImageSearchInBrowser,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: CommonDesignTokens.pageBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search,
                      size: 14,
                      color: CommonDesignTokens.textSecondary,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'More Images on Internet',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: CommonDesignTokens.textSecondary,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Content: loading skeleton or image row.
        if (_isImageSearching)
          _buildImageSearchSkeleton()
        else if (hasResults)
          _buildImageRow(),
      ],
    );
  }

  Widget _buildImageRow() {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _imageSearchResults!.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final result = _imageSearchResults![index];
          return GestureDetector(
            onTap: () => _showImagePreview(result.sourceUrl),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                result.thumbnailUrl,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 120,
                    height: 120,
                    color: CommonDesignTokens.pageBackground,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                        color: CommonDesignTokens.headerLabelColor,
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  width: 120,
                  height: 120,
                  color: CommonDesignTokens.pageBackground,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    size: 24,
                    color: CommonDesignTokens.textSecondary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showImagePreview(String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return GestureDetector(
          onTap: () => Navigator.of(dialogContext).pop(),
          child: Scaffold(
            backgroundColor: Colors.black87,
            body: Stack(
              children: [
                // Zoomable / pannable full image.
                Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        size: 48,
                        color: Colors.white38,
                      ),
                    ),
                  ),
                ),
                // Close button.
                Positioned(
                  top: MediaQuery.of(dialogContext).padding.top + 8,
                  right: 12,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 28,
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageSearchSkeleton() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final offset = _shimmerController.value * 2 - 0.5;
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFFEBEBEB),
                Color(0xFFF5F5F5),
                Color(0xFFEBEBEB),
              ],
              stops: [
                (offset - 0.3).clamp(0.0, 1.0),
                offset.clamp(0.0, 1.0),
                (offset + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: Row(
        children: List.generate(
          3,
          (index) => Padding(
            padding: EdgeInsets.only(right: index < 2 ? 8.0 : 0),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: CommonDesignTokens.pageBackground,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            final offset = _shimmerController.value * 2 - 0.5;
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFFEBEBEB),
                Color(0xFFF5F5F5),
                Color(0xFFEBEBEB),
              ],
              stops: [
                (offset - 0.3).clamp(0.0, 1.0),
                offset.clamp(0.0, 1.0),
                (offset + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _skeletonLine(1.0),
          const SizedBox(height: 10),
          _skeletonLine(0.92),
          const SizedBox(height: 10),
          _skeletonLine(0.85),
          const SizedBox(height: 10),
          _skeletonLine(0.6),
        ],
      ),
    );
  }

  Widget _skeletonLine(double widthFraction) {
    return FractionallySizedBox(
      widthFactor: widthFraction,
      child: Container(
        height: 14,
        decoration: BoxDecoration(
          color: CommonDesignTokens.pageBackground,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
