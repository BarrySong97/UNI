import 'package:flutter/material.dart';

import '../../shared/constants/common-design-tokens.dart';
import '../../shared/constants/library-design-tokens.dart';
import '../../shared/constants/settings-design-tokens.dart';
import '../../shared/constants/shelf-design-tokens.dart';

class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel({required this.label, super.key});

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

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.showDivider = true,
    super.key,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            height: SettingsDesignTokens.settingsRowHeight,
            child: Row(
              children: <Widget>[
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
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: LibraryDesignTokens.bookProfileActionSize,
                      fontWeight: FontWeight.w500,
                      color: CommonDesignTokens.textPrimary,
                    ),
                  ),
                ),
                if (value != null) ...[
                  Text(
                    value!,
                    style: const TextStyle(
                      fontSize: LibraryDesignTokens.bookProfileMetaSize,
                      color: CommonDesignTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                const Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: CommonDesignTokens.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 54),
            child: Container(
              height: 1,
              color: ShelfDesignTokens.nowReadingCoverPlaceholderBg,
            ),
          ),
      ],
    );
  }
}
