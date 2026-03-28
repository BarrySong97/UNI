import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/providers/app-providers.dart';
import '../../shared/constants/common-design-tokens.dart';
import 'onboarding_ai_step.dart';
import 'onboarding_voice_step.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({required this.onComplete, super.key});

  final VoidCallback onComplete;

  static const String _keyCompleted = 'onboarding_completed';

  /// Returns true if onboarding has been completed or skipped before.
  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyCompleted) ?? false;
  }

  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCompleted, true);
  }

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNext() {
    if (_currentPage < 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _goBack() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finish() async {
    await OnboardingFlow.markCompleted();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final ttsService = AppProvidersScope.of(context).ttsService;
    return Scaffold(
      backgroundColor: CommonDesignTokens.pageBackground,
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: [
                OnboardingAiStep(onContinue: _goToNext, onSkip: _goToNext),
                OnboardingVoiceStep(
                  modelManager: ttsService.modelManager,
                  onVoiceSelected: (languageCode, voiceKey) =>
                      ttsService.setVoiceForLanguage(languageCode, voiceKey),
                  onContinue: _finish,
                  onSkip: _finish,
                  onBack: _goBack,
                ),
              ],
            ),
          ),
          // Page indicator
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(2, (i) {
                final active = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? CommonDesignTokens.textPrimary
                        : CommonDesignTokens.borderColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
