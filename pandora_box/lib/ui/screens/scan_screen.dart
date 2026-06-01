import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';

import '../../bloc/scan_bloc.dart';
import '../theme/app_theme.dart';
import 'preview_3d_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({Key? key}) : super(key: key);

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Start the camera session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScanBloc>().add(const ScanStarted());
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ScanBloc, ScanState>(
      listener: (context, state) {
        if (state.status == ScanStatus.meshReady) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const Preview3DScreen()),
          );
        } else if (state.status == ScanStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? 'Scan error'),
              backgroundColor: AppTheme.primaryRed,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.black,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.chevron_left,
                  color: AppTheme.primaryRed, size: 30),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            title: _buildStepIndicator(state),
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              // ── Layer 1: Camera Feed ──────────────────────────────────────
              _buildCameraFeed(state),

              // ── Layer 2: Viewfinder Target (Only when scanning) ───────────
              if (state.isScanning) _buildAlignmentTarget(),

              // ── Layer 3: Processing Overlay ───────────────────────────────
              if (state.isProcessing) _buildProcessingOverlay(state),

              // ── Layer 4: Instructions & Shutter (Only when scanning) ──────
              if (state.isScanning) ...[
                _buildInstructionText(state),
                _buildShutterButton(context, state),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── UI Components ─────────────────────────────────────────────────────────

  Widget _buildStepIndicator(ScanState state) {
    // We will add capturedCount (0 to 4) to your ScanState next.
    final count = state.capturedCount ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        border: Border.all(color: AppTheme.primaryRed, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        state.isProcessing ? 'AI Processing' : 'Angle ${count + 1} of 4',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildAlignmentTarget() {
    return Center(
      child: Container(
        width: 280,
        height: 380,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            // Center crosshair
            Center(
              child: Icon(Icons.add,
                  color: Colors.white.withOpacity(0.3), size: 40),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionText(ScanState state) {
    final count = state.capturedCount ?? 0;
    String instruction = "";

    switch (count) {
      case 0:
        instruction = "Frame the FRONT of the object";
        break;
      case 1:
        instruction = "Rotate object 90° to the RIGHT";
        break;
      case 2:
        instruction = "Rotate object 90° to the BACK";
        break;
      case 3:
        instruction = "Rotate object 90° to the LEFT";
        break;
      default:
        instruction = "Preparing AI...";
        break;
    }

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              instruction,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShutterButton(BuildContext context, ScanState state) {
    final isCapturing = state.isCapturingFrame ?? false;

    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: isCapturing
              ? null
              : () => context.read<ScanBloc>().add(const ScanPhotoCaptured()),
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: isCapturing ? Colors.grey : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primaryRed, width: 4),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryRed.withOpacity(0.4),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: isCapturing
                  ? const CircularProgressIndicator(color: AppTheme.primaryRed)
                  : Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Standard Camera & Processing Views ────────────────────────────────────

  Widget _buildCameraFeed(ScanState state) {
    if (state.isProcessing || !state.isCameraReady) {
      return Container(color: Colors.black);
    }
    final controller = context.read<ScanBloc>().cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return Container(color: Colors.black);
    }
    try {
      final size = MediaQuery.of(context).size;
      var scale = size.aspectRatio * controller.value.aspectRatio;
      if (scale < 1) scale = 1 / scale;
      return Transform.scale(
        scale: scale,
        child: Center(child: CameraPreview(controller)),
      );
    } catch (e) {
      return Container(color: Colors.black);
    }
  }

  Widget _buildProcessingOverlay(ScanState state) {
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.processingStep.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: state.processingProgress,
                  minHeight: 8,
                  backgroundColor: AppTheme.cardBackground,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.primaryRed),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Aligning Point Clouds...',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.7), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
