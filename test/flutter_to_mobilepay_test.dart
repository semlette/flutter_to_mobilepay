import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_to_mobilepay/flutter_to_mobilepay.dart';

void main() {
  const MethodChannel channel = MethodChannel('flutter_to_mobilepay');

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  /*test('getPlatformVersion', () async {
    expect(await MobilePay.platformVersion, '42');
  });*/
}
