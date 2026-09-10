import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  bool _useAiAnalysis = false;
  bool _hasApiKey = false;

  late AnimationController _animationController;
  late Animation<double> _scanLineAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const Color _pastelPrimary = Color(0xFF60A5FA);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadApiConfig();
    _initializeCamera();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeCamera() async {
    try {
      await Future.delayed(const Duration(milliseconds: 400));

      _cameras = await availableCameras();
      if (_cameras.isEmpty) throw 'Kamera tidak ditemukan';

      _controller = CameraController(
        _cameras.first,
        ResolutionPreset.ultraHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      try {
        await _controller!.setFlashMode(FlashMode.off);
        await _controller!.setFocusMode(FocusMode.auto);
      } catch (e) {
        debugPrint('Focus Mode Error: $e');
      }

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
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _loadApiConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('user_ai_api_key');
    if (mounted) {
      setState(() {
        _hasApiKey = key != null && key.isNotEmpty;
        final savedState = prefs.getBool('receipt_scanner_use_ai_mode') ?? true;
        _useAiAnalysis = savedState;
      });
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _controller!.value.isTakingPicture ||
        _isProcessing) {
      return;
    }

    try {
      setState(() => _isProcessing = true);
      HapticFeedback.mediumImpact();

      final image = await _controller!.takePicture();
      if (mounted) {
        Navigator.pop(context, {'image': image, 'useAi': _useAiAnalysis});
      }
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
        Navigator.pop(context, {'image': image, 'useAi': _useAiAnalysis});
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
        body: Center(
          child: CircularProgressIndicator(color: _pastelPrimary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Preview with Tap-to-Focus
          GestureDetector(
            onTapDown: (TapDownDetails details) async {
              if (_controller == null || !_controller!.value.isInitialized)
                return;
              final screenSize = MediaQuery.of(context).size;
              final x = details.localPosition.dx / screenSize.width;
              final y = details.localPosition.dy / screenSize.height;
              try {
                await _controller!.setFocusPoint(Offset(x, y));
                await _controller!.setFocusMode(FocusMode.auto);
              } catch (e) {
                debugPrint('Tap to Focus Error: $e');
              }
            },
            child: _buildCameraPreview(),
          ),

          // 2. Clean Scanner Overlay (Pastel Lens & Mask)
          _buildScannerOverlay(context),

          // 3. Top Header Bar (Flash, Title, Close)
          _buildTopBar(context),

          // 4. Bottom Controls Bar (Gallery, Shutter, AI Mode Switch)
          _buildControls(context),

          // 5. Processing Glass Loading Overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: _pastelPrimary,
                            strokeWidth: 3,
                          ),
                          SizedBox(height: 16),
                          Text(
                            "Memproses Struk...",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Container(color: Colors.black);
    }

    final size = MediaQuery.of(context).size;

    return SizedBox(
      width: size.width,
      height: size.height,
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller!.value.previewSize!.height,
            height: _controller!.value.previewSize!.width,
            child: CameraPreview(_controller!),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 16,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Flash Action
          _buildCircleAction(
            icon: _isFlashOn
                ? CupertinoIcons.bolt_fill
                : CupertinoIcons.bolt_slash_fill,
            onTap: _toggleFlash,
            color: _isFlashOn ? _pastelPrimary : Colors.black.withOpacity(0.4),
            iconColor: Colors.white,
            tooltip: "Flash",
          ),

          // Title Badge
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.doc_text_viewfinder,
                        color: _pastelPrimary, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Scan Struk',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Close Action
          _buildCircleAction(
            icon: CupertinoIcons.xmark,
            onTap: () => Navigator.pop(context),
            color: Colors.black.withOpacity(0.4),
            iconColor: Colors.white,
            tooltip: "Tutup",
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final rectWidth = size.width * 0.76;
    final rectHeight = size.height * 0.44;

    return Stack(
      children: [
        // Subtle Lens Pulse Glow
        Center(
          child: Transform.translate(
            offset: const Offset(0, -45),
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: rectWidth,
                height: rectHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: _pastelPrimary.withOpacity(0.12),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Dark Mask Painter
        CustomPaint(
          painter: ScannerMaskPainter(),
          size: Size.infinite,
        ),

        // Scanning Sweeping Line Animation
        AnimatedBuilder(
          animation: _scanLineAnimation,
          builder: (context, child) {
            final rectLeft = (size.width - rectWidth) / 2;
            final rectTop = (size.height - rectHeight) / 2 - 45;

            return Positioned(
              top: rectTop + (rectHeight * _scanLineAnimation.value),
              left: rectLeft + 8,
              right: rectLeft + 8,
              child: Column(
                children: [
                  Container(
                    height: 2.5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: _pastelPrimary.withOpacity(0.8),
                          blurRadius: 12,
                          spreadRadius: 1.5,
                        ),
                      ],
                      gradient: LinearGradient(
                        colors: [
                          _pastelPrimary.withOpacity(0),
                          _pastelPrimary,
                          _pastelPrimary.withOpacity(0),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _pastelPrimary.withOpacity(0.12),
                          _pastelPrimary.withOpacity(0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // Clean Hint Text Pill
        Positioned(
          top: (size.height / 2) + (rectHeight / 2) - 15,
          left: 0,
          right: 0,
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.viewfinder,
                          color: _pastelPrimary, size: 16),
                      SizedBox(width: 8),
                      Text(
                        "Posisikan struk di dalam kotak",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildControls(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.only(bottom: 50, top: 32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Shutter Button (Center)
            _BouncingScaleButton(
              onTap: _takePicture,
              child: Container(
                width: 78,
                height: 78,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.85), width: 3.5),
                  boxShadow: [
                    BoxShadow(
                      color: _pastelPrimary.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    color: _pastelPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.camera_fill,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
            ),

            // Gallery Action Button (Bottom Right)
            Positioned(
              right: 36,
              child: _buildCircleAction(
                icon: CupertinoIcons.photo_fill,
                onTap: _pickFromGallery,
                color: Colors.black.withOpacity(0.4),
                iconColor: Colors.white,
                tooltip: "Galeri",
              ),
            ),

            // AI Mode Toggle Pill (Bottom Left)
            Positioned(
              left: 20,
              child: GestureDetector(
                onTap: () {
                  if (_hasApiKey) {
                    _showAiSourcePicker();
                  } else {
                    _toggleAiMode(!_useAiAnalysis);
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _useAiAnalysis
                              ? _pastelPrimary.withOpacity(0.4)
                              : Colors.white.withOpacity(0.12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "AI",
                                style: TextStyle(
                                  color: _useAiAnalysis
                                      ? Colors.white
                                      : Colors.white60,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_useAiAnalysis)
                                Text(
                                  _hasApiKey ? 'Custom Key' : 'System AI',
                                  style: const TextStyle(
                                    color: _pastelPrimary,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 2),
                          Transform.scale(
                            scale: 0.75,
                            child: Switch(
                              value: _useAiAnalysis,
                              onChanged: (val) => _toggleAiMode(val),
                              activeColor: _pastelPrimary,
                              inactiveThumbColor: Colors.white70,
                              inactiveTrackColor: Colors.white24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleAiMode(bool enable) async {
    setState(() {
      _useAiAnalysis = enable;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('receipt_scanner_use_ai_mode', enable);
  }

  void _showAiSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardBg = Theme.of(context).cardColor;
        final textColor = isDark ? Colors.white : const Color(0xFF18181B);

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Opsi AI Scanner',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pilih opsi sumber AI yang ingin digunakan untuk menganalisis struk belanja:',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              // Option 1: Custom API Key
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _toggleAiMode(true);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _hasApiKey
                        ? _pastelPrimary.withOpacity(0.12)
                        : (isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _hasApiKey ? _pastelPrimary : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _pastelPrimary.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.lock_fill,
                            color: _pastelPrimary, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'API Key Pribadi (Custom)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                if (_hasApiKey) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _pastelPrimary.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Aktif',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: _pastelPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Menggunakan Gemini/Groq API Key milikmu yang disetel di Chat AI.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Option 2: System AI
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _toggleAiMode(true);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC4B5FD).withOpacity(0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.sparkles,
                            color: Color(0xFF8B5CF6), size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'System AI (Bawaan Aplikasi)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Menggunakan kuota server AI terintegrasi MyDuitGweh.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCircleAction(
      {required IconData icon,
      required VoidCallback onTap,
      required Color color,
      Color iconColor = Colors.white,
      String? tooltip}) {
    return _BouncingScaleButton(
      onTap: onTap,
      child: Tooltip(
        message: tooltip ?? "",
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}

class _BouncingScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _BouncingScaleButton({
    required this.child,
    required this.onTap,
  });

  @override
  State<_BouncingScaleButton> createState() => _BouncingScaleButtonState();
}

class _BouncingScaleButtonState extends State<_BouncingScaleButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class ScannerMaskPainter extends CustomPainter {
  final double offsetY;

  ScannerMaskPainter({this.offsetY = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.65);

    // Calculate scanning rectangle
    final rectWidth = size.width * 0.76;
    final rectHeight = size.height * 0.44;
    final rectLeft = (size.width - rectWidth) / 2;
    final rectTop = (size.height - rectHeight) / 2 - 45;

    final scanRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(rectLeft, rectTop, rectWidth, rectHeight),
      const Radius.circular(24),
    );

    // Draw dark background mask with smooth cutout
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(scanRect),
      ),
      paint,
    );

    // Draw smooth pastel corner lens brackets
    final borderPaint = Paint()
      ..color = const Color(0xFF60A5FA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final cornerLength = 36.0;
    final radius = 24.0;
    final path = Path();

    // Top Left Corner
    path.moveTo(rectLeft, rectTop + cornerLength);
    path.lineTo(rectLeft, rectTop + radius);
    path.quadraticBezierTo(rectLeft, rectTop, rectLeft + radius, rectTop);
    path.lineTo(rectLeft + cornerLength, rectTop);

    // Top Right Corner
    path.moveTo(rectLeft + rectWidth - cornerLength, rectTop);
    path.lineTo(rectLeft + rectWidth - radius, rectTop);
    path.quadraticBezierTo(
        rectLeft + rectWidth, rectTop, rectLeft + rectWidth, rectTop + radius);
    path.lineTo(rectLeft + rectWidth, rectTop + cornerLength);

    // Bottom Right Corner
    path.moveTo(rectLeft + rectWidth, rectTop + rectHeight - cornerLength);
    path.lineTo(rectLeft + rectWidth, rectTop + rectHeight - radius);
    path.quadraticBezierTo(rectLeft + rectWidth, rectTop + rectHeight,
        rectLeft + rectWidth - radius, rectTop + rectHeight);
    path.lineTo(rectLeft + rectWidth - cornerLength, rectTop + rectHeight);

    // Bottom Left Corner
    path.moveTo(rectLeft + cornerLength, rectTop + rectHeight);
    path.lineTo(rectLeft + radius, rectTop + rectHeight);
    path.quadraticBezierTo(rectLeft, rectTop + rectHeight, rectLeft,
        rectTop + rectHeight - radius);
    path.lineTo(rectLeft, rectTop + rectHeight - cornerLength);

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
