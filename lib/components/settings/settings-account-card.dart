import 'package:flutter/material.dart';

import '../../shared/constants/common-design-tokens.dart';
import '../../shared/constants/settings-design-tokens.dart';

class SettingsAccountCard extends StatelessWidget {
  const SettingsAccountCard({
    required this.initials,
    required this.name,
    required this.subtitle,
    super.key,
  });

  final String initials;
  final String name;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CommonDesignTokens.cardBg,
        borderRadius: BorderRadius.circular(CommonDesignTokens.cardRadius),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: SettingsDesignTokens.settingsAccountAvatarSize,
            height: SettingsDesignTokens.settingsAccountAvatarSize,
            decoration: BoxDecoration(
              color: CommonDesignTokens.avatarBg,
              borderRadius: BorderRadius.circular(
                SettingsDesignTokens.settingsAccountAvatarSize / 2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: CommonDesignTokens.bookTitleSize,
                fontWeight: FontWeight.w600,
                color: CommonDesignTokens.avatarTextColor,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: CommonDesignTokens.bookTitleSize,
                    fontWeight: FontWeight.w600,
                    color: CommonDesignTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: CommonDesignTokens.bookAuthorSize,
                    fontWeight: FontWeight.w500,
                    color: CommonDesignTokens.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.edit_outlined,
            size: 20,
            color: CommonDesignTokens.textSecondary,
          ),
        ],
      ),
    );
  }
}
