import 'package:flutter/material.dart';

import '../../services/ai/ai_settings_service.dart';

class AiSettingsDialog extends StatefulWidget {
  const AiSettingsDialog({super.key, required this.aiSettings});

  final AiSettingsService aiSettings;

  static Future<void> show(
    BuildContext context,
    AiSettingsService aiSettings,
  ) {
    return showDialog<void>(
      context: context,
      builder: (_) => AiSettingsDialog(aiSettings: aiSettings),
    );
  }

  @override
  State<AiSettingsDialog> createState() => _AiSettingsDialogState();
}

class _AiSettingsDialogState extends State<AiSettingsDialog> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;

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
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('AI Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _baseUrlController,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                hintText: 'https://api.openai.com/v1',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key',
                hintText: 'sk-...',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: 'Model',
                hintText: 'gpt-4o-mini',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    await widget.aiSettings.update(
      baseUrl: _baseUrlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      model: _modelController.text.trim(),
    );
    if (mounted) Navigator.of(context).pop();
  }
}
