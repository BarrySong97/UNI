import 'package:flutter/material.dart';

import '../../shared/constants/common-design-tokens.dart';
import '../../shared/constants/shelf-design-tokens.dart';
import '../../shared/layout/responsive_layout.dart';

class LibraryEmptyState extends StatelessWidget {
  const LibraryEmptyState({required this.onImportTap, super.key});

  final VoidCallback onImportTap;

  // Max content width on tablet so the button doesn't stretch across the screen.
  static const double _tabletContentWidth = 480;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= kTabletBreakpoint;
        return Padding(
          padding: const EdgeInsets.only(top: 80),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isTablet ? _tabletContentWidth : double.infinity,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
            _buildIconBadge(),
            const SizedBox(height: 28),
            const Text(
              'Start your library',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: CommonDesignTokens.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 15,
                  color: CommonDesignTokens.textSecondary,
                  height: 1.45,
                ),
                children: const <InlineSpan>[
                  TextSpan(text: 'Import an '),
                  TextSpan(
                    text: 'ePub',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: CommonDesignTokens.textPrimary,
                    ),
                  ),
                  TextSpan(text: ' to start\ntracking your reading journey.'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onImportTap,
                icon: const Icon(Icons.add, size: 20),
                label: const Text(
                  'Add Your First Book',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ShelfDesignTokens.continueButtonBg,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.search,
                  size: 16,
                  color: CommonDesignTokens.textSecondary.withValues(
                    alpha: 0.45,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Browse recommendations',
                  style: TextStyle(
                    fontSize: 14,
                    color: CommonDesignTokens.textSecondary.withValues(
                      alpha: 0.45,
                    ),
                  ),
                ),
              ],
            ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIconBadge() {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        children: <Widget>[
          Center(
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: CommonDesignTokens.borderColor.withValues(alpha: 0.4),
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.menu_book_rounded,
                size: 48,
                color: CommonDesignTokens.textSecondary.withValues(alpha: 0.35),
              ),
            ),
          ),
          Positioned(
            right: 4,
            bottom: 8,
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: ShelfDesignTokens.continueButtonBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.add, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
