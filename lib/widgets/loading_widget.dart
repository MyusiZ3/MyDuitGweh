import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class LoadingWidget extends StatefulWidget {
  final double size;
  const LoadingWidget({super.key, this.size = 24});

  @override
  State<LoadingWidget> createState() => _LoadingWidgetState();
}

class _LoadingWidgetState extends State<LoadingWidget> with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo MyDuitGweh Look
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet_rounded, 
              size: 50, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          const Text(
            'MY DUIT GWEH',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          // iOS Style Loading Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              return _Dot(
                controller: _controller,
                delay: index * 0.2,
                color: AppColors.primary,
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  final Color color;

  const _Dot({required this.controller, required this.delay, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final double opacity = ((controller.value - delay).clamp(0.0, 1.0));
        // Simple sine wave for bounce effect
        final double transform = 1.0 - (0.3 * (1.0 - opacity)); 
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: 8,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3 + (0.7 * (1.0 - (controller.value - delay).abs().clamp(0, 1)))),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
