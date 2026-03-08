import 'package:flutter_test/flutter_test.dart';
import 'package:flureadium_platform_interface/flureadium_platform_interface.dart';

void main() {
  group('ReaderNavigationConfig', () {
    test('creates instance with all fields null', () {
      final config = ReaderNavigationConfig();
      expect(config.enableEdgeTapNavigation, isNull);
      expect(config.enableSwipeNavigation, isNull);
      expect(config.edgeTapAreaPoints, isNull);
      expect(config.disableDoubleTapZoom, isNull);
      expect(config.disableTextSelection, isNull);
      expect(config.disableDragGestures, isNull);
      expect(config.disableDoubleTapTextSelection, isNull);
    });

    test('can be constructed with all fields', () {
      final config = ReaderNavigationConfig(
        enableEdgeTapNavigation: true,
        enableSwipeNavigation: false,
        edgeTapAreaPoints: 60.0,
        disableDoubleTapZoom: true,
        disableTextSelection: false,
        disableDragGestures: true,
        disableDoubleTapTextSelection: false,
      );
      expect(config.enableEdgeTapNavigation, isTrue);
      expect(config.enableSwipeNavigation, isFalse);
      expect(config.edgeTapAreaPoints, equals(60.0));
      expect(config.disableDoubleTapZoom, isTrue);
      expect(config.disableTextSelection, isFalse);
      expect(config.disableDragGestures, isTrue);
      expect(config.disableDoubleTapTextSelection, isFalse);
    });

    test('toJson includes only non-null fields', () {
      final config = ReaderNavigationConfig(
        enableEdgeTapNavigation: true,
        edgeTapAreaPoints: 60.0,
      );
      final json = config.toJson();
      expect(json['enableEdgeTapNavigation'], isTrue);
      expect(json['edgeTapAreaPoints'], equals(60.0));
      expect(json.containsKey('enableSwipeNavigation'), isFalse);
      expect(json.containsKey('disableDoubleTapZoom'), isFalse);
      expect(json.containsKey('disableTextSelection'), isFalse);
      expect(json.containsKey('disableDragGestures'), isFalse);
      expect(json.containsKey('disableDoubleTapTextSelection'), isFalse);
    });

    test('toJson returns empty map when all null', () {
      expect(ReaderNavigationConfig().toJson(), isEmpty);
    });

    test('toJson serializes booleans as booleans, not strings', () {
      final config = ReaderNavigationConfig(enableEdgeTapNavigation: true);
      final json = config.toJson();
      expect(json['enableEdgeTapNavigation'], isA<bool>());
      expect(json['enableEdgeTapNavigation'], isTrue);
    });

    test('toJson serializes edgeTapAreaPoints as double', () {
      final config = ReaderNavigationConfig(edgeTapAreaPoints: 80.0);
      final json = config.toJson();
      expect(json['edgeTapAreaPoints'], isA<double>());
      expect(json['edgeTapAreaPoints'], equals(80.0));
    });

    test('fields are mutable', () {
      final config = ReaderNavigationConfig()
        ..enableEdgeTapNavigation = false
        ..disableDoubleTapZoom = true
        ..edgeTapAreaPoints = 44.0;
      expect(config.enableEdgeTapNavigation, isFalse);
      expect(config.disableDoubleTapZoom, isTrue);
      expect(config.edgeTapAreaPoints, equals(44.0));
    });

    test('toJson with all fields set', () {
      final config = ReaderNavigationConfig(
        enableEdgeTapNavigation: true,
        enableSwipeNavigation: false,
        edgeTapAreaPoints: 100.0,
        disableDoubleTapZoom: true,
        disableTextSelection: false,
        disableDragGestures: true,
        disableDoubleTapTextSelection: false,
      );
      final json = config.toJson();
      expect(json['enableEdgeTapNavigation'], isTrue);
      expect(json['enableSwipeNavigation'], isFalse);
      expect(json['edgeTapAreaPoints'], equals(100.0));
      expect(json['disableDoubleTapZoom'], isTrue);
      expect(json['disableTextSelection'], isFalse);
      expect(json['disableDragGestures'], isTrue);
      expect(json['disableDoubleTapTextSelection'], isFalse);
    });
  });
}
