import 'dart:async';

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
  bool _channelsSubscribed = false;
  final Set<String> _readySessions = <String>{};

  @override
  String? get activeSessionId => _activeSessionId;

  @override
  void dispose() {
    cancelChannels();
    super.dispose();
  }

  Future<void> _activateVisibleSlot(ReaderOverlaySlot slot) async {
    if (_activeBookId == slot.bookId && _activeSessionId == slot.sessionId) {
      return;
    }
    _activeBookId = slot.bookId;
    _activeSessionId = slot.sessionId;
    _channelsSubscribed = false;
    cancelChannels();
    final providers = AppProvidersScope.of(context);
    readerStore = providers.readerStore;
    await readerStore!.openBook(slot.bookId);
  }

  void _onReaderReady(ReaderOverlaySlot slot) {
    _readySessions.add(slot.sessionId);
    AppProvidersScope.of(
      context,
    ).readerOverlayController.markContentReady(slot.bookId);

    if (_activeSessionId == slot.sessionId && !_channelsSubscribed) {
      _channelsSubscribed = true;
      ReaderPerf.mark('overlay.reader_widget_ready', bookId: _activeBookId);
      subscribeToChannels();
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
    unawaited(readerStore?.flushProgress());
    AppProvidersScope.of(context).readerOverlayController.hide();
  }

  Widget _buildSlot(ReaderOverlaySlot slot, {required bool isVisible}) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !isVisible,
        child: AnimatedSlide(
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
          _channelsSubscribed = false;
          _readySessions.clear();
          return const SizedBox.shrink();
        }

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
          unawaited(_activateVisibleSlot(visibleSlot));
          if (_readySessions.contains(visibleSlot.sessionId) &&
              !_channelsSubscribed) {
            _channelsSubscribed = true;
            ReaderPerf.mark(
              'overlay.reader_widget_ready',
              bookId: _activeBookId,
            );
            subscribeToChannels();
          }
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
