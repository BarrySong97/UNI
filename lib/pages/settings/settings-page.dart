import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/providers/app-providers.dart';
import '../../components/settings/ai_settings_dialog.dart' show AiSettingsPage;
import '../../components/settings/tts_settings_page.dart' show TtsSettingsPage;
import '../../components/settings/tts_test_page.dart' show TtsTestPage;
import '../../shared/constants/common-design-tokens.dart';
import '../../shared/layout/responsive_layout.dart';
import '../../components/library/library-header.dart';
import '../../components/settings/settings-row.dart';
import 'help-faq-page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const String _contactEmail = 'contact@example.com';

  static const List<_SocialMediaEntry> _socialMediaEntries =
      <_SocialMediaEntry>[
        _SocialMediaEntry(platform: 'Twitter / X', handle: '@example'),
        _SocialMediaEntry(platform: 'Instagram', handle: '@example'),
      ];

  @override
  Widget build(BuildContext context) {
    final aiSettings = AppProvidersScope.of(context).aiSettingsService;
    final ttsService = AppProvidersScope.of(context).ttsService;

    return Container(
      color: CommonDesignTokens.pageBackground,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 12, bottom: 120),
          child: ResponsiveContentWrapper(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Header
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: LibraryHeader(
                    headerTitle: 'Settings',
                    showImportButton: false,
                  ),
                ),
                const SizedBox(height: 24),

                // AI SETTINGS
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SettingsSectionLabel(label: 'AI SETTINGS'),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: CommonDesignTokens.cardBg,
                      borderRadius: BorderRadius.circular(
                        CommonDesignTokens.cardRadius,
                      ),
                    ),
                    child: ListenableBuilder(
                      listenable: aiSettings,
                      builder: (context, _) {
                        final summary = aiSettings.isConfigured
                            ? 'Configured'
                            : 'Not Set';
                        return SettingsRow(
                          icon: Icons.smart_toy_outlined,
                          label: 'AI Explain',
                          value: summary,
                          showDivider: false,
                          onTap: () => AiSettingsPage.push(
                            context,
                            aiSettings,
                            ttsService,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // TTS SETTINGS
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SettingsSectionLabel(label: 'TTS SETTINGS'),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: CommonDesignTokens.cardBg,
                      borderRadius: BorderRadius.circular(
                        CommonDesignTokens.cardRadius,
                      ),
                    ),
                    child: Column(
                      children: <Widget>[
                        ListenableBuilder(
                          listenable: ttsService,
                          builder: (context, _) {
                            final langCount =
                                ttsService.configuredLanguages.length;
                            final summary = langCount == 0
                                ? 'Not configured'
                                : '$langCount language${langCount > 1 ? 's' : ''}';
                            return SettingsRow(
                              icon: Icons.record_voice_over_outlined,
                              label: 'TTS',
                              value: summary,
                              onTap: () =>
                                  TtsSettingsPage.push(context, ttsService),
                            );
                          },
                        ),
                        SettingsRow(
                          icon: Icons.science_outlined,
                          label: 'TTS Test',
                          value: 'Quick checks',
                          showDivider: false,
                          onTap: () => TtsTestPage.push(context, ttsService),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ABOUT
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SettingsSectionLabel(label: 'ABOUT'),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: CommonDesignTokens.cardBg,
                      borderRadius: BorderRadius.circular(
                        CommonDesignTokens.cardRadius,
                      ),
                    ),
                    child: Column(
                      children: <Widget>[
                        SettingsRow(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          onTap: () => _showEmailSheet(context),
                        ),
                        SettingsRow(
                          icon: Icons.share_outlined,
                          label: 'Social Media',
                          onTap: () => _showSocialMediaSheet(context),
                        ),
                        SettingsRow(
                          icon: Icons.help_outline,
                          label: 'Help & FAQ',
                          showDivider: false,
                          onTap: () => HelpFaqPage.push(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEmailSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        decoration: const BoxDecoration(
          color: CommonDesignTokens.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: CommonDesignTokens.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Contact Email',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: CommonDesignTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              _contactEmail,
              style: TextStyle(
                fontSize: 15,
                color: CommonDesignTokens.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: _contactEmail));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Email copied'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: CommonDesignTokens.textPrimary,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Copy Email',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSocialMediaSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        decoration: const BoxDecoration(
          color: CommonDesignTokens.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: CommonDesignTokens.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Social Media',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: CommonDesignTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            for (final entry in _socialMediaEntries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: entry.handle));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${entry.platform} handle copied'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: CommonDesignTokens.pageBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                entry.platform,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: CommonDesignTokens.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                entry.handle,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: CommonDesignTokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.copy,
                          size: 18,
                          color: CommonDesignTokens.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SocialMediaEntry {
  const _SocialMediaEntry({required this.platform, required this.handle});

  final String platform;
  final String handle;
}
