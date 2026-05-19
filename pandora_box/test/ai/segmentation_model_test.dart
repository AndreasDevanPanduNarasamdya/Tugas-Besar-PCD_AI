import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MediaPipe Segmentation - device only test', () {
    // tflite_flutter only runs on Android device
    // Tested via Python: input [1,256,256,3] output [1,256,256,6] ✅
    // Tested via Flutter device: run flutter run and use test screen
  }, skip: 'TFLite requires Android device to run');
}
