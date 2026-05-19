import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import '../../bloc/scan_bloc.dart';
import '../../bloc/scan_event.dart';
import '../../bloc/scan_state.dart';
import '../theme/app_theme.dart';
import '../widgets/scan_overlay_painter.dart';
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
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.black,
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
              // ── Camera Feed ─────────────────────────────────────────
              _buildCameraFeed(state),

              // ── Mesh overlay ────────────────────────────────────────
              if (state.isScanning || state.isProcessing)
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Opacity(
                    opacity: _pulseAnim.value,
                    child: CustomPaint(
                      painter: ScanOverlayPainter(
                        coveragePercent: state.coveragePercent,
                      ),
                    ),
                  ),
                ),

              // ── Instruction text ────────────────────────────────────
              Positioned(
                top: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    state.isProcessing
                        ? 'Processing mesh, please wait...'
                        : 'Point the camera at the other side...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      shadows: const [
                        Shadow(blurRadius: 8, color: Colors.black)
                      ],
                    ),
                  ),
                ),
              ),

              // ── Top-right progress ring ─────────────────────────────
              if (state.isScanning)
                Positioned(
                  top: 12,
                  right: 16,
                  child: ScanProgressRing(
                    percent: state.coveragePercent,
                    pointCount: state.pointCount,
                  ),
                ),

              // ── Bottom stop/render button ───────────────────────────
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildStopButton(context, state),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCameraFeed(ScanState state) {
    final controller = context.read<ScanBloc>().cameraController;
    if (state.isCameraReady &&
        controller != null &&
        controller.value.isInitialized) {
      return CameraPreview(controller);
    }

    // Loading / camera not ready yet
    return Container(
      color: Colors.black,
      child: Center(
        child: state.status == ScanStatus.error
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.camera_alt,
                      color: AppTheme.textDarkGrey, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    state.errorMessage ?? 'Camera unavailable',
                    style: TextStyle(color: AppTheme.textGrey),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryRed),
                  SizedBox(height: 12),
                  Text('Initializing camera...',
                      style: TextStyle(color: AppTheme.textGrey)),
                ],
              ),
      ),
    );
  }

  Widget _buildStopButton(BuildContext context, ScanState state) {
    if (state.isProcessing) {
      return Container(
        width: 72,
        height: 72,
        decoration: const BoxDecoration(
          color: AppTheme.primaryRed,
          shape: BoxShape.circle,
        ),
        child: const CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 3,
        ),
      );
    }

    return GestureDetector(
      onTap: () =>
          context.read<ScanBloc>().add(const ScanMeshGenerationRequested()),
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, child) => Transform.scale(
          scale: _pulseAnim.value,
          child: child,
        ),
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
