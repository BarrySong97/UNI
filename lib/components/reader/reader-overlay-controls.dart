import 'package:flutter/material.dart';

class ReaderOverlayControls extends StatelessWidget {
  const ReaderOverlayControls({
    required this.isVisible,
    required this.onBack,
    required this.onSettings,
    required this.onActionTap,
    super.key,
  });

  final bool isVisible;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final ValueChanged<String> onActionTap;

  static const List<_ReaderOverlayAction> _actions = <_ReaderOverlayAction>[
    _ReaderOverlayAction(id: 'contents', icon: Icons.menu),
    _ReaderOverlayAction(id: 'notes', icon: Icons.explore_outlined),
    _ReaderOverlayAction(id: 'progress', icon: Icons.brightness_1_outlined),
    _ReaderOverlayAction(id: 'brightness', icon: Icons.light_mode_outlined),
    _ReaderOverlayAction(id: 'font', icon: Icons.format_size),
  ];

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.viewPaddingOf(context);
    const background = Color(0xFFFFFFFF);
    const divider = Color(0xFFECEEF2);
    const iconColor = Color(0xFF5F6672);
    const duration = Duration(milliseconds: 240);
    const curve = Curves.easeOutCubic;
    final topBarHeight = padding.top + 56;
    final bottomBarHeight = padding.bottom + 64;

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !isVisible,
        child: Stack(
          children: <Widget>[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedSlide(
                duration: duration,
                curve: curve,
                offset: isVisible ? Offset.zero : const Offset(0, -1),
                child: DecoratedBox(
                  key: const Key('reader_overlay_top_surface'),
                  decoration: const BoxDecoration(
                    color: background,
                    border: Border(
                      bottom: BorderSide(color: divider, width: 0.5),
                    ),
                  ),
                  child: SizedBox(
                    key: const Key('reader_overlay_top_bar'),
                    height: topBarHeight,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: padding.top,
                        left: 10,
                        right: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          IconButton(
                            key: const Key('reader_overlay_back'),
                            onPressed: onBack,
                            splashRadius: 20,
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              size: 22,
                              color: iconColor,
                            ),
                          ),
                          IconButton(
                            key: const Key('reader_overlay_settings'),
                            onPressed: onSettings,
                            splashRadius: 20,
                            icon: const Icon(
                              Icons.tune,
                              size: 21,
                              color: iconColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedSlide(
                duration: duration,
                curve: curve,
                offset: isVisible ? Offset.zero : const Offset(0, 1),
                child: DecoratedBox(
                  key: const Key('reader_overlay_bottom_surface'),
                  decoration: const BoxDecoration(
                    color: background,
                    border: Border(top: BorderSide(color: divider, width: 0.5)),
                  ),
                  child: SizedBox(
                    key: const Key('reader_overlay_bottom_bar'),
                    height: bottomBarHeight,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: padding.bottom),
                      child: Row(
                        children: _actions
                            .map(
                              (action) => Expanded(
                                child: _ActionButton(
                                  action: action,
                                  onTap: () => onActionTap(action.id),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, required this.onTap});

  final _ReaderOverlayAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: Key('reader_overlay_action_${action.id}'),
      onPressed: onTap,
      splashRadius: 20,
      iconSize: 26,
      color: const Color(0xFF5F6672),
      icon: Icon(action.icon),
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _ReaderOverlayAction {
  const _ReaderOverlayAction({required this.id, required this.icon});

  final String id;
  final IconData icon;
}
