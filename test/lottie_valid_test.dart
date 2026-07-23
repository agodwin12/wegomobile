import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

// Validates that the hand-generated ride Lottie assets parse and build a real
// composition in the lottie engine (not merely valid JSON).
void main() {
  const names = [
    'ride_searching',
    'ride_success',
    'ride_locating',
    'ride_no_drivers',
  ];

  for (final name in names) {
    test('lottie $name parses and has a duration', () async {
      final bytes = File('assets/lottie/$name.json').readAsBytesSync();
      final comp = await LottieComposition.fromBytes(bytes);
      expect(comp.duration.inMilliseconds, greaterThan(0),
          reason: '$name produced a zero-length composition');
      expect(comp.startFrame, lessThan(comp.endFrame));
    });
  }
}
