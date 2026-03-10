import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flureadium/flureadium.dart';

import '../../app/providers/app-providers.dart';
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

  Widget _buildSlot(ReaderOverlaySlot slot, {required bool isVisible}) {
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
                  child: ReadiumReaderWidget(
                    key: ValueKey<String>(
                      'overlay_slot_${slot.bookId}_${slot.sessionId}',
                    ),
                    publication: slot.publication,
                    sessionId: slot.sessionId,
                    initialLocator: initialLocator,
                    onReady: () => _onReaderReady(slot),
                  ),
                ),
                if (isVisible)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: _handleBack,
                          icon: const Icon(Icons.arrow_back_ios_new),
                        ),
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

  @override
  Widget build(BuildContext context) {
    final ctrl = AppProvidersScope.of(context).readerOverlayController;

    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        final slots = ctrl.slots;
        if (slots.isEmpty) {
          cancelChannels();
          _activeBookId = null;
          _activeSessionId = null;
          _activePublication = null;
          _activatingSessionId = null;
          _channelsSubscribed = false;
          _readySessions.clear();
          _activatedSessions.clear();
          return const SizedBox.shrink();
        }
        _pruneSessionFlags(slots);

        final visibleBookId = ctrl.visibleBookId;
        if (visibleBookId == null) {
          return Stack(
            children: slots
                .map((slot) => _buildSlot(slot, isVisible: false))
                .toList(growable: false),
          );
        }

        final visibleSlot = ctrl.slotForBook(visibleBookId);
        if (visibleSlot != null) {
          _ensureVisibleSlotActivated(visibleSlot);
        }

        return Stack(
          children: slots
              .map(
                (slot) =>
                    _buildSlot(slot, isVisible: slot.bookId == visibleBookId),
              )
              .toList(growable: false),
        );
      },
    );
  }
}
