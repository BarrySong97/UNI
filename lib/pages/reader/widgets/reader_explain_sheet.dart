import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../services/ai/ai_settings_service.dart';
import '../../../services/ai/openai_llm_provider.dart';
import '../../../services/db/app-database.dart';
import '../../../services/phonetics/phonetics_service.dart';
import '../../../services/tts/tts_service.dart';

class ReaderExplainSheet extends StatefulWidget {
  const ReaderExplainSheet({
    super.key,
    required this.selectedText,
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
  });

  final String selectedText;
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

  static Future<void> show({
    required BuildContext context,
    required String selectedText,
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
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ReaderExplainSheet(
        selectedText: selectedText,
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
      ),
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
  late final String _containingSentence;
  late final bool _customPromptModeEnabled;
  _StructuredExplainData? _structuredData;

  // Phonetics state (word mode only).
  PhoneticsResult? _phonetics;
  String? _playingAccent;

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

    _isWordOrPhrase =
        selectedText.length <= 80 &&
        !_sentenceEndPattern.hasMatch(selectedText);

    _containingSentence = _isWordOrPhrase
        ? _extractContainingSentence(widget.paragraphContext, selectedText)
        : '';

    final surroundingContext = _isWordOrPhrase
        ? _containingSentence
        : widget.pageContext;

    final config = widget.languageConfig;
    _customPromptModeEnabled = config.customPromptModeEnabled;
    final detailLine = AiSettingsService.detailInstruction(config.detail);
    final langLine = AiSettingsService.languageInstruction(
      config.explanationLanguage,
    );

    final promptTemplate =
        _customPromptModeEnabled && config.customPrompt.isNotEmpty
        ? config.customPrompt
        : AiSettingsService.defaultPrompt;
    final defaultPrompt = promptTemplate
        .replaceAll('{bookTitle}', widget.bookTitle)
        .replaceAll('{selectedText}', text)
        .replaceAll('{context}', surroundingContext);

    final structuredPrompt = _buildStructuredPrompt(
      bookTitle: widget.bookTitle,
      selectedText: text,
      context: surroundingContext,
      detailLine: detailLine,
      languageLine: langLine,
    );
    final customPromptSystem =
        '$defaultPrompt\n\n$detailLine'
        '${langLine.isNotEmpty ? '\n$langLine' : ''}';
    final systemPrompt = _customPromptModeEnabled
        ? customPromptSystem
        : structuredPrompt;

    _aiService = ExplainAiService(
      settings: widget.aiSettings,
      systemPrompt: systemPrompt,
      model: config.model,
    );

    if (_isWordOrPhrase) _lookupPhonetics();
    _loadOrFetch();
  }

  void _onTtsChanged() {
    if (!widget.ttsService.isSpeaking && _playingAccent != null) {
      if (mounted) setState(() => _playingAccent = null);
    }
  }

  Future<void> _lookupPhonetics() async {
    try {
      final result = await widget.phoneticsService.lookup(widget.selectedText);
      if (mounted) setState(() => _phonetics = result);
    } catch (_) {}
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

  String _buildStructuredPrompt({
    required String bookTitle,
    required String selectedText,
    required String context,
    required String detailLine,
    required String languageLine,
  }) {
    final languageInstruction = languageLine.isNotEmpty
        ? '\n- $languageLine'
        : '';
    return 'You are a reading assistant for "$bookTitle".\n'
        'The user selected text: "$selectedText"\n'
        'Context:\n---\n$context\n---\n\n'
        'Goal: help the reader quickly understand the selected text in context.\n'
        'Return ONLY a JSON object (no markdown, no code fence, no extra text) '
        'with this exact schema:\n'
        '{\n'
        '  "meaningExplain": "string",\n'
        '  "detailExplain": ["string", "string"]\n'
        '}\n\n'
        'Constraints:\n'
        '- Keep each string concise and practical.\n'
        '- Focus on this exact context, not generic dictionary entries.\n'
        '- Use plain language for intermediate English learners.\n'
        '- Keep detailExplain to 2-3 short bullets.\n'
        '- $detailLine'
        '$languageInstruction';
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
              : _StructuredExplainData.tryParse(cached);
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
          : _StructuredExplainData.tryParse(_aiResponse);
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
                  color: Colors.grey.shade300,
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 24),
          ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Word + refresh button on the same line
        Row(
          children: [
            Expanded(
              child: Text(
                widget.selectedText,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            if (!_isStreaming)
              GestureDetector(
                onTap: _refresh,
                child: Icon(
                  Icons.refresh,
                  size: 20,
                  color: Colors.grey.shade500,
                ),
              ),
          ],
        ),
        // Phonetics row: IPA + play button (hidden when no IPA available).
        if (_phonetics != null &&
            (_phonetics!.us.isNotEmpty || _phonetics!.uk.isNotEmpty)) ...[
          const SizedBox(height: 6),
          _buildPhoneticsRow(),
        ],
        if (_containingSentence.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildSentenceWithBoldWord(_containingSentence, widget.selectedText),
        ],
      ],
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

  Widget _buildAccentChip(String label, String ipa, String accent) {
    final isPlaying = _playingAccent == accent && widget.ttsService.isSpeaking;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade500,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '/$ipa/',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        const SizedBox(width: 2),
        GestureDetector(
          onTap: () => _playPronunciation(accent),
          child: Icon(
            isPlaying ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
            size: 18,
            color: isPlaying ? Colors.black87 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildSentenceWithBoldWord(String sentence, String word) {
    final index = sentence.indexOf(word);
    if (index < 0) {
      return Text(
        sentence,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade700,
          height: 1.4,
          decoration: TextDecoration.none,
        ),
      );
    }

    final before = sentence.substring(0, index);
    final after = sentence.substring(index + word.length);

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade700,
          height: 1.4,
        ),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: word,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: after),
        ],
      ),
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
                child: Icon(
                  Icons.refresh,
                  size: 20,
                  color: Colors.grey.shade500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.selectedText.length > 200
                ? '${widget.selectedText.substring(0, 200)}...'
                : widget.selectedText,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
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
    if (_aiResponse.isEmpty && _isStreaming) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _buildSkeleton(),
      );
    }

    if (!_customPromptModeEnabled) {
      return SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _buildStructuredContent(),
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: MarkdownBody(
        data: _aiResponse,
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          p: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: Colors.black87,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Widget _buildStructuredContent() {
    final data = _structuredData;
    if (data == null) {
      return MarkdownBody(
        data: _aiResponse,
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          p: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: Colors.black87,
            decoration: TextDecoration.none,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStructuredCard(
          title: 'Meaning Explain',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.meaningExplain,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildStructuredCard(
          title: 'Detail Explain',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final detail in data.detailExplain)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '• $detail',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Colors.black87,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              if (data.detailExplain.isEmpty)
                const Text(
                  'No extra detail.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Colors.black54,
                    decoration: TextDecoration.none,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildStructuredCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE6DCCF)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.45,
              color: Colors.grey.shade600,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
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
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _StructuredExplainData {
  const _StructuredExplainData({
    required this.meaningExplain,
    required this.detailExplain,
  });

  final String meaningExplain;
  final List<String> detailExplain;

  static _StructuredExplainData? tryParse(String raw) {
    final jsonText = _extractJson(raw);
    if (jsonText == null) return null;
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map<String, dynamic>) return null;
      final meaningExplain = _readString(decoded['meaningExplain']).isNotEmpty
          ? _readString(decoded['meaningExplain'])
          : _readString(decoded['inThisSentence']);
      if (meaningExplain.isEmpty) return null;

      var detailExplain = _readStringList(decoded['detailExplain']);
      if (detailExplain.isEmpty) {
        final legacyWhy = _readStringList(decoded['whyThisMeaning']);
        final legacyNotHere = _readString(decoded['notHere']);
        final legacyAlternatives = _readStringList(
          decoded['nearbyAlternatives'],
        );
        detailExplain = [
          ...legacyWhy,
          if (legacyNotHere.isNotEmpty) 'Not here: $legacyNotHere',
          ...legacyAlternatives.map((item) => 'Alternative: $item'),
        ];
      }

      return _StructuredExplainData(
        meaningExplain: meaningExplain,
        detailExplain: detailExplain,
      );
    } catch (_) {
      return null;
    }
  }

  static String? _extractJson(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) return trimmed;

    final fenced = RegExp(
      r'```(?:json)?\s*([\s\S]*?)\s*```',
      multiLine: true,
    ).firstMatch(trimmed);
    if (fenced == null) return null;
    return fenced.group(1)?.trim();
  }

  static String _readString(Object? value) {
    if (value is String) return value.trim();
    return '';
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
