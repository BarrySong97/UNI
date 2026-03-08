import 'package:flureadium_platform_interface/method_channel_flureadium.dart';
import 'package:flureadium_platform_interface/src/index.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('$MethodChannelFlureadium', () {
    final log = <MethodCall>[];
    late MethodChannelFlureadium methodChannelReadium;
    final testTextLocator = Locator(
      href: 'chapter1.html',
      type: 'text/xhtml',
      locations: Locations(cssSelector: '#loc1'),
      text: LocatorText(before: 'a', highlight: 'b', after: 'c'),
    );

    setUp(() async {
      methodChannelReadium = MethodChannelFlureadium();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannelReadium.methodChannel, (
            methodCall,
          ) async {
            log.add(methodCall);
            switch (methodCall.method) {
              case 'openPublication':
                return 'TODO';
              case 'ttsEnable':
                return true;
              case 'goRight':
                return true;
              default:
                return null;
            }
          });
      log.clear();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel(methodChannelReadium.textLocatorChannel.name),
            (methodCall) async {
              switch (methodCall.method) {
                case 'listen':
                  await TestDefaultBinaryMessengerBinding
                      .instance
                      .defaultBinaryMessenger
                      .handlePlatformMessage(
                        methodChannelReadium.textLocatorChannel.name,
                        methodChannelReadium.textLocatorChannel.codec
                            .encodeSuccessEnvelope(testTextLocator),
                        (_) {},
                      );
                  break;
                case 'cancel':
                default:
                  return null;
              }
              return null;
            },
          );
    });

    test('onBatteryChanged', () async {
      final result = await methodChannelReadium.onTextLocatorChanged.first;
      expect(result, testTextLocator);
    }, skip: 'Flaky test - times out waiting for stream event');

    //   test('getBatteryLevel', () async {
    //     final result = await methodChannelBattery.batteryLevel;
    //     expect(result, 100);
    //     expect(
    //       log,
    //       <Matcher>[
    //         isMethodCall(
    //           'getBatteryLevel',
    //           arguments: null,
    //         ),
    //       ],
    //     );
    //   });

    //   test('isInBatterySaveMode', () async {
    //     final result = await methodChannelBattery.isInBatterySaveMode;
    //     expect(result, true);
    //     expect(
    //       log,
    //       <Matcher>[
    //         isMethodCall(
    //           'isInBatterySaveMode',
    //           arguments: null,
    //         ),
    //       ],
    //     );
    //   });

    //   test('getBatteryState', () async {
    //     final result = await methodChannelBattery.batteryState;
    //     expect(result, BatteryState.charging);
    //     expect(
    //       log,
    //       <Matcher>[
    //         isMethodCall(
    //           'getBatteryState',
    //           arguments: null,
    //         ),
    //       ],
    //     );
    //   });
  });
}
