import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin_engine/ar_flutter_plugin.dart';

void main() {
  runApp(const MaterialApp(home: ARHome()));
}

class ARHome extends StatefulWidget {
  const ARHome({super.key});

  @override
  State<ARHome> createState() => _ARHomeState();
}

class _ARHomeState extends State<ARHome> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: ARView(onARViewCreated: onARViewCreated));
  }

  void onARViewCreated(
    dynamic arSessionManager,
    dynamic arObjectManager,
    dynamic arAnchorManager,
    dynamic arLocationManager,
  ) {
    arSessionManager.onInitialize(
      showFeaturePoints: true,
      showPlanes: true,
      showWorldOrigin: true,
    );

    arObjectManager.onInitialize();
  }
}
