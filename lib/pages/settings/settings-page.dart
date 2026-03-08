import 'package:flutter/material.dart';

import '../../shared/constants/common-design-tokens.dart';
import '../../components/library/library-header.dart';
import '../../components/settings/settings-account-card.dart';
import '../../components/settings/settings-row.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
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

              // AI
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SettingsSectionLabel(label: 'AI'),
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
                        icon: Icons.tune_outlined,
                        label: 'Explanation Detail',
                        value: 'Balanced',
                      ),
                      SettingsRow(
                        icon: Icons.language_outlined,
                        label: 'Explanation Language',
                        value: 'English',
                      ),
                      SettingsRow(
                        icon: Icons.key_outlined,
                        label: 'API Key',
                        value: 'Not Set',
                        showDivider: false,
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
                  child: const Column(
                    children: <Widget>[
                      SettingsRow(
                        icon: Icons.chat_bubble_outline,
                        label: 'Feedback',
                      ),
                      SettingsRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                      ),
                      SettingsRow(
                        icon: Icons.share_outlined,
                        label: 'Social Media',
                      ),
                      SettingsRow(
                        icon: Icons.help_outline,
                        label: 'Help',
                      ),
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
