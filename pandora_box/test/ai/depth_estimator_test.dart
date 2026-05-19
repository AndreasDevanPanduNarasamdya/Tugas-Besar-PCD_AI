import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Depth Anything V2 - device only test', () {
    // tflite_flutter only runs on Android device
    // Tested via Python: input [1,518,518,3] output [1,518,518,1] ✅
    // Tested via Flutter device: run flutter run and use test screen
  }, skip: 'TFLite requires Android device to run');
}
