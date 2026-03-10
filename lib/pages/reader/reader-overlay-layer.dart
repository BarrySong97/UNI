import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flureadium/flureadium.dart';

import '../../app/providers/app-providers.dart';
import '../../components/reader/reader-overlay-controls.dart';
import '../../services/reader/reader-overlay-controller.dart';
import '../../services/reader/reader-performance-tracker.dart';
import '../../stores/reader/reader-store.dart';
import 'reader-channel-mixin.dart';

/// A persistent overlay layer with background-preloaded reader widgets.
///
/// Each slot keeps a single resident Readium widget instance.
/// Showing/hiding switches position only, without rebuilding platform view.
class ReaderOverlayLayer extends StatefulWidget {
  const ReaderOverlayLayer({super.key});

  @override
  State<ReaderOverlayLayer> createState() => _ReaderOverlayLayerState();
}

class _ReaderOverlayLayerState extends State<ReaderOverlayLayer>
    with ReaderChannelMixin {
  @override
  final Flureadium flureadium = Flureadium();

  @override
  ReaderStore? readerStore;

  String? _activeBookId;
  String? _activeSessionId;
  Publication? _activePublication;
  String? _activatingSessionId;
  bool _channelsSubscribed = false;
  final Set<String> _readySessions = <String>{};
  final Set<String> _activatedSessions = <String>{};
  int _activationEpoch = 0;
  String? _visibleBookId;
  String? _controlsBookId;
  bool _controlsVisible = false;

  @override
  String? get activeSessionId => _activeSessionId;

  @override
  Publication? get activePublication => _activePublication;

  @override
  void dispose() {
    cancelChannels();
    super.dispose();
  }

  Future<void> _activateVisibleSlot(ReaderOverlaySlot slot, int epoch) async {
    final sameSession =
        _activeBookId == slot.bookId && _activeSessionId == slot.sessionId;
    if (sameSession && _activatedSessions.contains(slot.sessionId)) {
      return;
    }
    _activeBookId = slot.bookId;
    _activeSessionId = slot.sessionId;
    _activePublication = slot.publication;
    _channelsSubscribed = false;
    cancelChannels();
    final providers = AppProvidersScope.of(context);
    readerStore = providers.readerStore;
    _activatingSessionId = slot.sessionId;
    try {
      // 切到可见书时只切 store 上下文，不重建该 slot 的原生 reader widget。
      await readerStore!.openBook(slot.bookId);
      if (!mounted ||
          epoch != _activationEpoch ||
          _activeSessionId != slot.sessionId) {
        return;
      }
      _activatedSessions.add(slot.sessionId);
      _trySubscribeForSession(slot.sessionId);
    } finally {
      if (_activatingSessionId == slot.sessionId) {
        _activatingSessionId = null;
      }
    }
  }

  void _onReaderReady(ReaderOverlaySlot slot) {
    // 隐藏态也会触发 onReady：这正是“后台预热成功”的关键证据。
    _readySessions.add(slot.sessionId);
    AppProvidersScope.of(
      context,
    ).readerOverlayController.markContentReady(slot.bookId);

    if (_activeSessionId == slot.sessionId) {
      _trySubscribeForSession(slot.sessionId);
    }
  }

  @override
  void onFirstReaderSignal() {
    final bookId = _activeBookId;
    if (bookId == null) {
      return;
    }
    AppProvidersScope.of(
      context,
    ).readerOverlayController.markContentReady(bookId);
  }

  void _handleBack() {
    _hideControls();
    final providers = AppProvidersScope.of(context);
    unawaited(
      (readerStore?.flushProgress() ?? Future<void>.value()).then((_) {
        return providers.libraryStore.refreshProgress();
      }),
    );
    providers.readerOverlayController.hide();
  }

  void _ensureVisibleSlotActivated(ReaderOverlaySlot slot) {
    final sameSession =
        _activeBookId == slot.bookId && _activeSessionId == slot.sessionId;
    final activated = _activatedSessions.contains(slot.sessionId);
    if (sameSession && activated) {
      _trySubscribeForSession(slot.sessionId);
      return;
    }
    if (_activatingSessionId == slot.sessionId) {
      return;
    }
    final epoch = ++_activationEpoch;
    unawaited(_activateVisibleSlot(slot, epoch));
  }

  void _trySubscribeForSession(String sessionId) {
    if (_channelsSubscribed) {
      return;
    }
    if (_activeSessionId != sessionId) {
      return;
    }
    if (!_readySessions.contains(sessionId) ||
        !_activatedSessions.contains(sessionId)) {
      return;
    }
    _channelsSubscribed = true;
    ReaderPerf.mark('overlay.reader_widget_ready', bookId: _activeBookId);
    unawaited(subscribeToChannels());
  }

  void _pruneSessionFlags(List<ReaderOverlaySlot> slots) {
    final activeIds = slots.map((slot) => slot.sessionId).toSet();
    _readySessions.removeWhere((id) => !activeIds.contains(id));
    _activatedSessions.removeWhere((id) => !activeIds.contains(id));
    if (_activatingSessionId != null &&
        !activeIds.contains(_activatingSessionId)) {
      _activatingSessionId = null;
    }
  }

  void _toggleControls(String bookId) {
    setState(() {
      if (_controlsVisible && _controlsBookId == bookId) {
        _controlsVisible = false;
        _controlsBookId = null;
        return;
      }
      _controlsVisible = true;
      _controlsBookId = bookId;
    });
  }

  void _hideControls() {
    if (!_controlsVisible && _controlsBookId == null) {
      return;
    }
    setState(() {
      _controlsVisible = false;
      _controlsBookId = null;
    });
  }

  void _showPlaceholderFeedback(String label) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('$label is not implemented yet.')),
    );
  }

  bool _shouldShowControlsFor(String bookId) {
    return _controlsVisible && _controlsBookId == bookId;
  }

  Widget _buildSlot(
    ReaderOverlaySlot slot, {
    required bool isVisible,
    required bool showControls,
  }) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    const readingBackgroundColor = Color(0xFFFFFFFF);
    Locator? initialLocator;
    final initialLocatorJson = slot.initialLocatorJson;
    if (initialLocatorJson != null && initialLocatorJson.isNotEmpty) {
      try {
        final raw = jsonDecode(initialLocatorJson);
        if (raw is Map<String, dynamic>) {
          initialLocator = Locator.fromJson(raw);
        } else if (raw is Map) {
          initialLocator = Locator.fromJson(raw.cast<String, dynamic>());
        }
      } catch (_) {
        initialLocator = null;
      }
    }
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !isVisible,
        child: AnimatedSlide(
          // 只做位置切换来显示/隐藏，避免点击时新建 platform view 导致失去秒开。
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          offset: isVisible ? Offset.zero : const Offset(1.05, 0),
          child: Opacity(
            opacity: isVisible ? 1 : 0,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: ColoredBox(
                    color: readingBackgroundColor,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: viewPadding.top,
                        bottom: viewPadding.bottom,
                      ),
                      child: ReadiumReaderWidget(
                        key: ValueKey<String>(
                          'overlay_slot_${slot.bookId}_${slot.sessionId}',
                        ),
                        publication: slot.publication,
                        sessionId: slot.sessionId,
                        initialLocator: initialLocator,
                        onTap: isVisible
                            ? () => _toggleControls(slot.bookId)
                            : null,
                        onReady: () => _onReaderReady(slot),
                      ),
                    ),
                  ),
                ),
                if (isVisible)
                  ReaderOverlayControls(
                    isVisible: showControls,
                    onBack: _handleBack,
                    onSettings: () => _showPlaceholderFeedback('Settings'),
                    onActionTap: (actionId) {
                      final label = switch (actionId) {
                        'contents' => 'Contents',
                        'notes' => 'Notes',
                        'progress' => 'Progress',
                        'brightness' => 'Brightness',
                        'font' => 'Font',
                        _ => 'Action',
                      };
                      _showPlaceholderFeedback(label);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final providers = AppProvidersScope.of(context);
    final ctrl = providers.readerOverlayController;
    readerStore = providers.readerStore;

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[ctrl, providers.readerStore]),
      builder: (context, _) {
        final slots = ctrl.slots;
        if (slots.isEmpty) {
          cancelChannels();
          _activeBookId = null;
          _activeSessionId = null;
          _activePublication = null;
          _visibleBookId = null;
          _controlsBookId = null;
          _controlsVisible = false;
          _activatingSessionId = null;
          _channelsSubscribed = false;
          _readySessions.clear();
          _activatedSessions.clear();
          return const SizedBox.shrink();
        }
        _pruneSessionFlags(slots);

        final visibleBookId = ctrl.visibleBookId;
        if (visibleBookId == null) {
          _visibleBookId = null;
          _controlsBookId = null;
          _controlsVisible = false;
          return Stack(
            children: slots
                .map(
                  (slot) =>
                      _buildSlot(slot, isVisible: false, showControls: false),
                )
                .toList(growable: false),
          );
        }
        if (_visibleBookId != visibleBookId) {
          _visibleBookId = visibleBookId;
          _controlsBookId = null;
          _controlsVisible = false;
        }

        final visibleSlot = ctrl.slotForBook(visibleBookId);
        if (visibleSlot != null) {
          _ensureVisibleSlotActivated(visibleSlot);
        }

        return Stack(
          children: slots
              .map((slot) {
                final isVisible = slot.bookId == visibleBookId;
                return _buildSlot(
                  slot,
                  isVisible: isVisible,
                  showControls:
                      isVisible && _shouldShowControlsFor(slot.bookId),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }
}
