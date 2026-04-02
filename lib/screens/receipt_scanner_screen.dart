import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';
import '../utils/ui_helper.dart';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitializing = true;
  bool _isFlashOn = false;
  bool _isProcessing = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  late AnimationController _animationController;
  late Animation<double> _scanLineAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _fadeAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeCamera() async {
    try {
      // Small delay helps with native channel connection on some devices
      await Future.delayed(const Duration(milliseconds: 500));

      _cameras = await availableCameras();
      if (_cameras.isEmpty) throw 'Kamera tidak ditemukan';

      _controller = CameraController(
        _cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      if (mounted) setState(() => _isInitializing = false);
    } catch (e) {
      debugPrint('Camera Error: $e');
      if (mounted) {
        String msg = e.toString();
        if (msg.contains('channel-error')) {
          msg = "Koneksi kamera terputus. Coba restart aplikasi ya!";
        }
        UIHelper.showErrorSnackBar(context, msg);
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _animationController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized)
      return;

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _controller!.value.isTakingPicture ||
        _isProcessing) return;

    try {
      setState(() => _isProcessing = true);
      HapticFeedback.mediumImpact();

      final image = await _controller!.takePicture();
      if (mounted) Navigator.pop(context, image);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        UIHelper.showErrorSnackBar(context, 'Gagal mengambil foto: $e');
      }
    }
  }

  void _toggleFlash() async {
    if (_controller == null) return;
    try {
      _isFlashOn = !_isFlashOn;
      await _controller!
          .setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
      setState(() {});
    } catch (e) {
      debugPrint('Flash Error: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        Navigator.pop(context, image);
      }
    } catch (e) {
      if (mounted) {
        UIHelper.showErrorSnackBar(context, 'Gagal mengambil gambar: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Preview
          CameraPreview(_controller!),

          // 2. The Custom Overlay (Scanner Lens)
          _buildScannerOverlay(context),

          // 3. UI Controls
          _buildControls(context),

          // 4. Processing Overlay
          if (_isProcessing)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text("Memproses Gambar...",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay(BuildContext context) {
    return Stack(
      children: [
        // Pulsing Lens Effect around the cutout area
        Center(
          child: Transform.translate(
            offset: const Offset(0, -70), // ALIGNED with -70 offset
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.72,
                height: MediaQuery.of(context).size.height * 0.42,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.08), width: 10),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ),

        // Dark mask with cutout
        CustomPaint(
          painter: ScannerMaskPainter(),
          size: Size.infinite,
        ),

        // Scanning Line Animation
        AnimatedBuilder(
          animation: _scanLineAnimation,
          builder: (context, child) {
            final size = MediaQuery.of(context).size;
            final rectWidth = size.width * 0.72;
            final rectHeight = size.height * 0.42;
            final rectLeft = (size.width - rectWidth) / 2;
            final rectTop = (size.height - rectHeight) / 2 - 70;

            return Positioned(
              top: rectTop + (rectHeight * _scanLineAnimation.value),
              left: rectLeft + 5, // Narrower to stay inside border
              right: rectLeft + 5, // Narrower to stay inside border
              child: Column(
                children: [
                  Container(
                    height: 2,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary,
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0),
                          AppColors.primary,
                          AppColors.primary.withOpacity(0),
                        ],
                      ),
                    ),
                  ),
                  // Light flare below the line
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary.withOpacity(0.15),
                          AppColors.primary.withOpacity(0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // Futuristic HUD Elements (Corners)
        AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) => Opacity(
            opacity: _fadeAnimation.value,
            child: _buildHUDelements(context),
          ),
        ),

        // Flash (Top Left)
        Positioned(
          top: MediaQuery.of(context).padding.top + 20,
          left: 20,
          child: _buildCircleAction(
            icon: _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            onTap: _toggleFlash,
            color: _isFlashOn
                ? const Color.fromARGB(255, 234, 234, 234).withOpacity(0.3)
                : Colors.black38,
            iconColor: _isFlashOn
                ? const Color.fromARGB(255, 255, 255, 255)
                : Colors.white,
            tooltip: "Flash",
          ),
        ),

        // Close (Top Right)
        Positioned(
          top: MediaQuery.of(context).padding.top + 20,
          right: 20,
          child: _buildCircleAction(
            icon: Icons.close_rounded,
            onTap: () => Navigator.pop(context),
            color: Colors.black38,
            tooltip: "Tutup",
          ),
        ),

        // Hint Text
        Positioned(
          top: (MediaQuery.of(context).size.height / 2) +
              (MediaQuery.of(context).size.height * 0.42 / 2) -
              40, // Recalculated for shorter border
          left: 0,
          right: 0,
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.center_focus_strong_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 10),
                      Text(
                        "Posisikan struk di dalam kotak",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHUDelements(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final rectWidth = size.width * 0.72;
    final rectHeight = size.height * 0.42;
    final rectLeft = (size.width - rectWidth) / 2;
    final rectTop = (size.height - rectHeight) / 2 - 70;

    return Stack(
      children: [
        // Target corner markers (HUD style)
        Positioned(
          left: rectLeft,
          top: rectTop,
          child: _buildHUDcorner(0), // Top Left
        ),
        Positioned(
          right: rectLeft,
          top: rectTop,
          child: _buildHUDcorner(1), // Top Right
        ),
        Positioned(
          right: rectLeft,
          bottom: size.height - (rectTop + rectHeight),
          child: _buildHUDcorner(2), // Bottom Right
        ),
        Positioned(
          left: rectLeft,
          bottom: size.height - (rectTop + rectHeight),
          child: _buildHUDcorner(3), // Bottom Left
        ),

        // Small target crosshair in center
        Center(
          child: Transform.translate(
            offset: const Offset(0, -70), // Match the -70 rectTop offset
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white12, width: 0.5),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(width: 4, height: 4, color: Colors.white24),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHUDcorner(int quadrant) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        border: Border(
          top: (quadrant == 0 || quadrant == 1)
              ? const BorderSide(color: Colors.white30, width: 1)
              : BorderSide.none,
          bottom: (quadrant == 2 || quadrant == 3)
              ? const BorderSide(color: Colors.white30, width: 1)
              : BorderSide.none,
          left: (quadrant == 0 || quadrant == 3)
              ? const BorderSide(color: Colors.white30, width: 1)
              : BorderSide.none,
          right: (quadrant == 1 || quadrant == 2)
              ? const BorderSide(color: Colors.white30, width: 1)
              : BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.only(bottom: 60, top: 40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Capture Button (Center)
            GestureDetector(
              onTap: _takePicture,
              child: Container(
                width: 80,
                height: 80,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.camera_rounded,
                      color: AppColors.primary, size: 36),
                ),
              ),
            ),

            // Gallery (Bottom Right Corner as requested)
            Positioned(
              right: 32,
              child: _buildCircleAction(
                icon: Icons.photo_library_rounded,
                onTap: _pickFromGallery,
                color: Colors.white12,
                tooltip: "Galeri",
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleAction(
      {required IconData icon,
      required VoidCallback onTap,
      required Color color,
      Color iconColor = Colors.white,
      String? tooltip}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Tooltip(
        message: tooltip ?? "",
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 26),
        ),
      ),
    );
  }
}

class ScannerMaskPainter extends CustomPainter {
  final double offsetY;

  ScannerMaskPainter({this.offsetY = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.7);

    // 1. Calculate the scanning rectangle
    final rectWidth = size.width * 0.72;
    final rectHeight = size.height * 0.42;
    final rectLeft = (size.width - rectWidth) / 2;
    final rectTop = (size.height - rectHeight) / 2 - 70;

    final scanRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(rectLeft, rectTop, rectWidth, rectHeight),
      const Radius.circular(19),
    );

    // 2. Draw the mask (background with hole)
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(scanRect),
      ),
      paint,
    );

    // 3. Draw the border of the hole
    final borderPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // We only draw the corners to make it look like a lens
    final cornerLength = 40.0;
    final path = Path();

    // Top Left
    path.moveTo(rectLeft, rectTop + cornerLength);
    path.lineTo(rectLeft, rectTop + 12);
    path.quadraticBezierTo(rectLeft, rectTop, rectLeft + 12, rectTop);
    path.lineTo(rectLeft + cornerLength, rectTop);

    // Top Right
    path.moveTo(rectLeft + rectWidth - cornerLength, rectTop);
    path.lineTo(rectLeft + rectWidth - 12, rectTop);
    path.quadraticBezierTo(
        rectLeft + rectWidth, rectTop, rectLeft + rectWidth, rectTop + 12);
    path.lineTo(rectLeft + rectWidth, rectTop + cornerLength);

    // Bottom Right
    path.moveTo(rectLeft + rectWidth, rectTop + rectHeight - cornerLength);
    path.lineTo(rectLeft + rectWidth, rectTop + rectHeight - 12);
    path.quadraticBezierTo(rectLeft + rectWidth, rectTop + rectHeight,
        rectLeft + rectWidth - 12, rectTop + rectHeight);
    path.lineTo(rectLeft + rectWidth - cornerLength, rectTop + rectHeight);

    // Bottom Left
    path.moveTo(rectLeft + cornerLength, rectTop + rectHeight);
    path.lineTo(rectLeft + 12, rectTop + rectHeight);
    path.quadraticBezierTo(
        rectLeft, rectTop + rectHeight, rectLeft, rectTop + rectHeight - 12);
    path.lineTo(rectLeft, rectTop + rectHeight - cornerLength);

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
