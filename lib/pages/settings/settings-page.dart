import 'package:flutter/material.dart';

import '../../app/providers/app-providers.dart';
import '../../components/settings/ai_settings_dialog.dart' show AiSettingsPage;
import '../../components/settings/tts_settings_page.dart' show TtsSettingsPage;
import '../../shared/constants/common-design-tokens.dart';
import '../../components/library/library-header.dart';
import '../../components/settings/settings-account-card.dart';
import '../../components/settings/settings-row.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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

              // ACCOUNT
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SettingsSectionLabel(label: 'ACCOUNT'),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SettingsAccountCard(
                  initials: 'JD',
                  name: 'James D.',
                  subtitle: 'MEMBER SINCE 2024',
                ),
              ),
              const SizedBox(height: 28),

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
                  child: Column(
                    children: <Widget>[
                      const SettingsRow(
                        icon: Icons.tune_outlined,
                        label: 'Explanation Detail',
                        value: 'Balanced',
                      ),
                      const SettingsRow(
                        icon: Icons.language_outlined,
                        label: 'Explanation Language',
                        value: 'English',
                      ),
                      ListenableBuilder(
                        listenable: aiSettings,
                        builder: (context, _) => SettingsRow(
                          icon: Icons.key_outlined,
                          label: 'API Key',
                          value: aiSettings.isConfigured
                              ? 'Configured'
                              : 'Not Set',
                          showDivider: false,
                          onTap: () => AiSettingsPage.push(context, aiSettings),
                        ),
                      ),
                    ],
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
                  child: ListenableBuilder(
                    listenable: ttsService,
                    builder: (context, _) => SettingsRow(
                      icon: Icons.record_voice_over_outlined,
                      label: 'TTS',
                      value: ttsService.currentModelDisplayName,
                      showDivider: false,
                      onTap: () => TtsSettingsPage.push(context, ttsService),
                    ),
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
                  child: const Column(
                    children: <Widget>[
                      SettingsRow(
                        icon: Icons.chat_bubble_outline,
                        label: 'Feedback',
                      ),
                      SettingsRow(icon: Icons.email_outlined, label: 'Email'),
                      SettingsRow(
                        icon: Icons.share_outlined,
                        label: 'Social Media',
                      ),
                      SettingsRow(icon: Icons.help_outline, label: 'Help'),
                      SettingsRow(
                        icon: Icons.quiz_outlined,
                        label: 'FAQ',
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
