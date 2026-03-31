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

  // Phonetics state (word mode only).
  PhoneticsResult? _phonetics;
  String? _playingAccent;

  static final _sentenceEndPattern = RegExp(r'[.!?。！？]');

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

    _isWordOrPhrase = selectedText.length <= 80 &&
        !_sentenceEndPattern.hasMatch(selectedText);

    _containingSentence = _isWordOrPhrase
        ? _extractContainingSentence(widget.pageContext, selectedText)
        : '';

    final surroundingContext =
        _isWordOrPhrase ? _containingSentence : widget.pageContext;

    final config = widget.languageConfig;
    final promptTemplate = config.customPrompt.isNotEmpty
        ? config.customPrompt
        : AiSettingsService.defaultPrompt;
    final basePrompt = promptTemplate
        .replaceAll('{bookTitle}', widget.bookTitle)
        .replaceAll('{selectedText}', text)
        .replaceAll('{context}', surroundingContext);

    final detailLine = AiSettingsService.detailInstruction(config.detail);
    final langLine = AiSettingsService.languageInstruction(
      config.explanationLanguage,
    );
    final systemPrompt = '$basePrompt\n\n$detailLine'
        '${langLine.isNotEmpty ? '\n$langLine' : ''}';

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
      final result =
          await widget.phoneticsService.lookup(widget.selectedText);
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
        final windowEnd =
            (targetInResult + target.length + 100).clamp(0, result.length);
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
    });
    await _fetchFromAi();
  }

  Future<void> _fetchFromAi() async {
    try {
      await for (final chunk
          in _aiService.sendMessage('Explain this passage')) {
        if (!mounted) return;
        setState(() {
          _aiResponse += chunk;
        });
        _scrollToBottom();
      }
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
            child: _isWordOrPhrase
                ? _buildWordHeader()
                : _buildTextPreview(),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 24),
          ),
          // AI response
          Expanded(
            child: _buildResponseArea(),
          ),
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
        // Phonetics row: IPA + play button
        if (_phonetics != null) ...[
          const SizedBox(height: 6),
          _buildPhoneticsRow(),
        ],
        if (_containingSentence.isNotEmpty) ...[
          const SizedBox(height: 8),
          // The sentence with the word bolded
          _buildSentenceWithBoldWord(
            _containingSentence,
            widget.selectedText,
          ),
        ],
      ],
    );
  }

  Widget _buildPhoneticsRow() {
    final ph = _phonetics!;
    return Row(
      children: [
        _buildAccentChip('US', ph.us, 'us'),
        const SizedBox(width: 16),
        _buildAccentChip('UK', ph.uk, 'uk'),
      ],
    );
  }

  Widget _buildAccentChip(String label, String ipa, String accent) {
    final isPlaying =
        _playingAccent == accent && widget.ttsService.isSpeaking;

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
        Text(
          '/$ipa/',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(width: 2),
        GestureDetector(
          onTap: () => _playPronunciation(accent),
          child: Icon(
            isPlaying
                ? Icons.stop_circle_outlined
                : Icons.volume_up_outlined,
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
