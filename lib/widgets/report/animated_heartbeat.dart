import 'package:flutter/material.dart';

class AnimatedHeartbeat extends StatefulWidget {
  final double score;
  final IconData icon;

  const AnimatedHeartbeat({super.key, required this.score, required this.icon});

  @override
  State<AnimatedHeartbeat> createState() => _AnimatedHeartbeatState();
}

class _AnimatedHeartbeatState extends State<AnimatedHeartbeat>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _animation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _updateSpeed();
  }

  @override
  void didUpdateWidget(AnimatedHeartbeat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _updateSpeed();
    }
  }

  void _updateSpeed() {
    int durationMs = 800;
    if (widget.score >= 80) {
      durationMs = 1200; // Calm heartbeat
    } else if (widget.score < 50) {
      durationMs = 400; // Panic heartbeat
    }

    _controller.duration = Duration(milliseconds: durationMs);
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScaleTransition(
      scale: _animation,
      child: Center(
        child: Icon(
          widget.icon,
          color: isDark ? Colors.white : Colors.white,
          size: 28,
          shadows: [
            Shadow(
              color: Colors.white.withOpacity(0.5),
              blurRadius: 10,
            )
          ],
        ),
      ),
    );
  }
}
