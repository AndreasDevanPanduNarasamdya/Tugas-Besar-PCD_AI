import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class ImuData {
  final double tiltAngle; // degrees — lean angle for bike
  final bool isShaking; // true if too much vibration
  final bool impactDetected; // sudden G-force spike
  final double accelerationMagnitude;

  const ImuData({
    required this.tiltAngle,
    required this.isShaking,
    required this.impactDetected,
    required this.accelerationMagnitude,
  });
}

typedef ImuCallback = void Function(ImuData data);

class ImuService {
  StreamSubscription? _accelSubscription;
  StreamSubscription? _gyroSubscription;

  double _tiltAngle = 0.0;
  bool _isRunning = false;

  static const double _shakeThreshold = 15.0;
  static const double _impactThreshold = 25.0;

  bool get isRunning => _isRunning;

  void start({required ImuCallback onData}) {
    _accelSubscription = accelerometerEventStream().listen((event) {
      final magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      // Calculate tilt angle from gravity vector
      _tiltAngle = atan2(event.x, event.z) * (180 / pi);

      final isShaking = magnitude > _shakeThreshold;
      final impactDetected = magnitude > _impactThreshold;

      onData(ImuData(
        tiltAngle: _tiltAngle,
        isShaking: isShaking,
        impactDetected: impactDetected,
        accelerationMagnitude: magnitude,
      ));
    });

    _isRunning = true;
    print('[ImuService] Started');
  }

  void stop() {
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _isRunning = false;
    print('[ImuService] Stopped');
  }

  void dispose() {
    stop();
  }
}
