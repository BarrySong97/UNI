import 'package:flutter/material.dart';

import '../../services/ai/ai_settings_service.dart';
import '../../shared/constants/common-design-tokens.dart';
import '../../shared/constants/form-design-tokens.dart';
import '../../shared/constants/settings-design-tokens.dart';

class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key, required this.aiSettings});

  final AiSettingsService aiSettings;

  static void push(BuildContext context, AiSettingsService aiSettings) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AiSettingsPage(aiSettings: aiSettings),
      ),
    );
  }

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  late final TextEditingController _promptController;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(
      text: widget.aiSettings.baseUrl,
    );
    _apiKeyController = TextEditingController(
      text: widget.aiSettings.apiKey,
    );
    _modelController = TextEditingController(
      text: widget.aiSettings.model,
    );
    _promptController = TextEditingController(
      text: widget.aiSettings.prompt,
    );
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommonDesignTokens.pageBackground,
      appBar: AppBar(
        backgroundColor: CommonDesignTokens.pageBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: CommonDesignTokens.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'AI Settings',
          style: TextStyle(
            fontSize: CommonDesignTokens.bookTitleSize,
            fontWeight: FontWeight.w700,
            color: CommonDesignTokens.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CONNECTION section
            const _SectionLabel(label: 'CONNECTION'),
            const SizedBox(height: 12),
            _buildCard(
              children: [
                _buildFieldRow(
                  icon: Icons.link_outlined,
                  label: 'Base URL',
                  controller: _baseUrlController,
                  hintText: 'https://api.openai.com/v1',
                  keyboardType: TextInputType.url,
                ),
                _buildDivider(),
                _buildFieldRow(
                  icon: Icons.key_outlined,
                  label: 'API Key',
                  controller: _apiKeyController,
                  hintText: 'sk-...',
                  obscureText: _obscureApiKey,
                  trailing: GestureDetector(
                    onTap: () =>
                        setState(() => _obscureApiKey = !_obscureApiKey),
                    child: Icon(
                      _obscureApiKey
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: CommonDesignTokens.textSecondary,
                    ),
                  ),
                ),
                _buildDivider(),
                _buildFieldRow(
                  icon: Icons.smart_toy_outlined,
                  label: 'Model',
                  controller: _modelController,
                  hintText: 'gpt-4o-mini',
                ),
              ],
            ),
            const SizedBox(height: 28),

            // PROMPT section
            const _SectionLabel(label: 'PROMPT'),
            const SizedBox(height: 12),
            _buildCard(
              children: [
                Padding(
                  padding: const EdgeInsets.all(
                    FormDesignTokens.textareaPadding,
                  ),
                  child: TextField(
                    controller: _promptController,
                    maxLines: FormDesignTokens.textareaMaxLines,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                      fontSize: FormDesignTokens.textareaSize,
                      color: CommonDesignTokens.textPrimary,
                      height: FormDesignTokens.textareaLineHeight,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter your custom prompt...',
                      hintStyle: TextStyle(
                        fontSize: FormDesignTokens.textareaSize,
                        color: CommonDesignTokens.textSecondary.withValues(
                          alpha: FormDesignTokens.textareaHintOpacity,
                        ),
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: FormDesignTokens.helperHorizontalPadding,
              ),
              child: Text(
                'This prompt is sent as the system message when you tap '
                '"Explain" in the reader. Use {bookTitle} for the book title, '
                '{selectedText} for the selected text, and {context} for the '
                'surrounding context.',
                style: TextStyle(
                  fontSize: FormDesignTokens.helperSize,
                  color: CommonDesignTokens.textSecondary,
                  height: FormDesignTokens.helperLineHeight,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              height: FormDesignTokens.buttonHeight,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: FormDesignTokens.buttonBg,
                  foregroundColor: FormDesignTokens.buttonText,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      CommonDesignTokens.cardRadius,
                    ),
                  ),
                  textStyle: const TextStyle(
                    fontSize: FormDesignTokens.buttonFontSize,
                    fontWeight: FormDesignTokens.buttonFontWeight,
                  ),
                ),
                child: const Text('Save'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: CommonDesignTokens.cardBg,
        borderRadius: BorderRadius.circular(CommonDesignTokens.cardRadius),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildFieldRow({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    String? hintText,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: FormDesignTokens.fieldRowHeight,
        child: Row(
          children: [
            Container(
              width: SettingsDesignTokens.settingsRowIconContainerSize,
              height: SettingsDesignTokens.settingsRowIconContainerSize,
              decoration: BoxDecoration(
                color: SettingsDesignTokens.settingsRowIconContainerBg,
                borderRadius: BorderRadius.circular(
                  SettingsDesignTokens.settingsRowIconContainerRadius,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 20,
                color: CommonDesignTokens.headerLabelColor,
              ),
            ),
            const SizedBox(width: FormDesignTokens.fieldIconGap),
            SizedBox(
              width: FormDesignTokens.fieldLabelWidth,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: FormDesignTokens.fieldLabelSize,
                  fontWeight: FontWeight.w500,
                  color: CommonDesignTokens.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: FormDesignTokens.fieldLabelGap),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                obscureText: obscureText,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: FormDesignTokens.fieldValueSize,
                  color: CommonDesignTokens.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(
                    fontSize: FormDesignTokens.fieldValueSize,
                    color: CommonDesignTokens.textSecondary.withValues(
                      alpha: FormDesignTokens.fieldHintOpacity,
                    ),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: FormDesignTokens.dividerIndent),
      child: Container(
        height: FormDesignTokens.dividerThickness,
        color: FormDesignTokens.dividerColor,
      ),
    );
  }

  Future<void> _save() async {
    await widget.aiSettings.update(
      baseUrl: _baseUrlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      model: _modelController.text.trim(),
      prompt: _promptController.text.trim(),
    );
    if (mounted) Navigator.of(context).pop();
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: CommonDesignTokens.headerLabelSize,
        fontWeight: FontWeight.w600,
        color: CommonDesignTokens.headerLabelColor,
        letterSpacing: 0.5,
      ),
    );
  }
}
