import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import '../../bloc/scan_bloc.dart';
import '../theme/app_theme.dart';
import '../widgets/progress_ring.dart';
import 'preview_3d_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({Key? key}) : super(key: key);

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(_pulseController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScanBloc>().add(const ScanStarted());
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

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
                context.read<ScanBloc>().add(const ScanStopped());
                Navigator.pop(context);
              },
            ),
            title: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                border: Border.all(color: AppTheme.primaryRed, width: 1.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                state.isProcessing ? 'Rendering' : 'Scanning',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              // ── Camera feed ──────────────────────────────────────────
              _buildCameraFeed(state),

              // ── Scan overlay (mesh grid) — only while scanning ────────
              // NOTE: wire up ScanOverlayPainter here if needed
              // if (state.isScanning) CustomPaint(painter: ScanOverlayPainter(...)),

              // ── Processing overlay — replaces camera view ─────────────
              if (state.isProcessing) _buildProcessingOverlay(state),

              // ── Instruction text (scanning only) ──────────────────────
              if (state.isScanning)
                SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'Point the camera at the object...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          shadows: const [
                            Shadow(blurRadius: 8, color: Colors.black)
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Progress ring top-right ───────────────────────────────
              if (state.isScanning)
                SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12, right: 16),
                      child: ScanProgressRing(
                        percent: state.coveragePercent,
                        pointCount: state.pointCount,
                      ),
                    ),
                  ),
                ),

              // ── Stop button ───────────────────────────────────────────
              if (!state.isProcessing)
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(child: _buildStopButton(context, state)),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── Camera feed ───────────────────────────────────────────────────────────
  // IMPORTANT: Never render CameraPreview once processing starts.
  // The controller is disposed inside _onMeshGenerationRequested, but Flutter
  // fires one more build() frame after the state change, causing:
  //   "buildPreview() was called on a disposed CameraController"
  // The fix: bail out on isProcessing || !isCameraReady BEFORE touching controller.

  Widget _buildCameraFeed(ScanState state) {
    if (state.isProcessing || !state.isCameraReady) {
      // Processing overlay covers the screen anyway — return empty
      return Container(color: Colors.black);
    }

    if (state.status == ScanStatus.error) {
      return _buildErrorState(state.errorMessage);
    }

    final controller = context.read<ScanBloc>().cameraController;

    // Guard: controller may be disposed between state change and this build frame
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
    } on CameraException catch (e) {
      // Disposed between the null-check above and buildPreview() — safe to ignore
      print(
          '[ScanScreen] CameraPreview build skipped (disposed): ${e.description}');
      return Container(color: Colors.black);
    } catch (e) {
      print('[ScanScreen] CameraPreview unexpected error: $e');
      return Container(color: Colors.black);
    }
  }

  Widget _buildErrorState(String? message) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt,
                color: AppTheme.textDarkGrey, size: 48),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                message ?? 'Camera unavailable',
                style: const TextStyle(color: AppTheme.textGrey),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Processing overlay ────────────────────────────────────────────────────

  Widget _buildProcessingOverlay(ScanState state) {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Step label
              Text(
                state.processingStep.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 20),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: state.processingProgress,
                  minHeight: 6,
                  backgroundColor: AppTheme.cardBackground,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.primaryRed),
                ),
              ),
              const SizedBox(height: 10),

              // Percentage
              Text(
                '${(state.processingProgress * 100).toInt()}%',
                style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
              ),

              const SizedBox(height: 24),

              // Frame + point stats for context
              Text(
                '${state.frameCount} frames  ·  ${state.pointCount} points',
                style:
                    const TextStyle(color: AppTheme.textDarkGrey, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Stop / render button ──────────────────────────────────────────────────

  Widget _buildStopButton(BuildContext context, ScanState state) {
    return GestureDetector(
      onTap: state.isScanning
          ? () =>
              context.read<ScanBloc>().add(const ScanMeshGenerationRequested())
          : null,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, child) =>
            Transform.scale(scale: _pulseAnim.value, child: child),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppTheme.primaryRed,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryRed.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(Icons.stop_rounded, color: Colors.white, size: 36),
        ),
      ),
    );
  }
}
