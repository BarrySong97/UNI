import 'package:flutter/material.dart';

import '../../../services/ai/ai_settings_service.dart';
import '../../../services/ai/openai_llm_provider.dart';

class ReaderExplainSheet extends StatefulWidget {
  const ReaderExplainSheet({
    super.key,
    required this.selectedText,
    required this.aiSettings,
    required this.bookTitle,
  });

  final String selectedText;
  final AiSettingsService aiSettings;
  final String bookTitle;

  static Future<void> show({
    required BuildContext context,
    required String selectedText,
    required AiSettingsService aiSettings,
    required String bookTitle,
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
        aiSettings: aiSettings,
        bookTitle: bookTitle,
      ),
    );
  }

  @override
  State<ReaderExplainSheet> createState() => _ReaderExplainSheetState();
}

class _ReaderExplainSheetState extends State<ReaderExplainSheet> {
  late final ExplainAiService _aiService;
  final List<ExplainChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isStreaming = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final text = widget.selectedText.length > 4000
        ? '${widget.selectedText.substring(0, 4000)}\n(text truncated)'
        : widget.selectedText;

    _aiService = ExplainAiService(
      settings: widget.aiSettings,
      systemPrompt: 'You are a reading assistant helping the user understand a '
          'passage from the book "${widget.bookTitle}".\n\n'
          'The user selected the following text:\n---\n$text\n---\n\n'
          'Explain this passage clearly and concisely. Cover:\n'
          '1. The meaning of the text in plain language\n'
          '2. Any difficult vocabulary or phrases\n'
          '3. The context or significance if apparent\n\n'
          'Keep explanations helpful but not overly long. '
          'If the user asks follow-up questions, answer based on the passage.',
    );

    // Auto-send the first explanation request.
    _sendMessage('Explain this passage');
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isStreaming) return;

    setState(() {
      _messages.add(ExplainChatMessage(isUser: true, text: text));
      _messages.add(ExplainChatMessage(isUser: false, text: ''));
      _isStreaming = true;
      _error = null;
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      await for (final chunk in _aiService.sendMessage(text)) {
        if (!mounted) return;
        setState(() {
          _messages.last.text += chunk;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        // Remove the empty AI message on error.
        if (_messages.isNotEmpty && !_messages.last.isUser &&
            _messages.last.text.isEmpty) {
          _messages.removeLast();
        }
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
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Padding(
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
            // Title
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Explain',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Selected text preview
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
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
            ),
            const SizedBox(height: 8),
            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  // Hide the auto-sent first user message.
                  if (index == 0 && msg.isUser) {
                    return const SizedBox.shrink();
                  }
                  return _buildMessageBubble(msg);
                },
              ),
            ),
            // Error
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
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
            // Input
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ExplainChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment:
            msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: msg.isUser ? Colors.blue.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: msg.text.isEmpty && !msg.isUser
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : SelectableText(
                  msg.text,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Colors.black87,
                    decoration: TextDecoration.none,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              enabled: !_isStreaming,
              decoration: const InputDecoration(
                hintText: 'Ask a follow-up question...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                isDense: true,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: _sendMessage,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isStreaming
                ? null
                : () => _sendMessage(_inputController.text),
            icon: const Icon(Icons.send),
            color: Colors.blue,
          ),
        ],
      ),
    );
  }
}
