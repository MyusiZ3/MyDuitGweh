import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

class SlidableDeleteTile extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;

  const SlidableDeleteTile({
    super.key,
    required this.child,
    required this.onDelete,
  });

  @override
  State<SlidableDeleteTile> createState() => _SlidableDeleteTileState();
}

class _SlidableDeleteTileState extends State<SlidableDeleteTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _dragOffset = 0.0;
  static const double _maxDragDistance = 68.0;
  bool _hasHapticked = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open() {
    if (!_hasHapticked) {
      HapticFeedback.lightImpact();
      _hasHapticked = true;
    }
    setState(() {
      _animation = Tween<double>(begin: _dragOffset, end: -_maxDragDistance).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
    });
    _controller.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() => _dragOffset = -_maxDragDistance);
      }
    });
  }

  void _close() {
    _hasHapticked = false;
    setState(() {
      _animation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
    });
    _controller.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() => _dragOffset = 0.0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showDeleteBtn = _dragOffset < 0 || _controller.isAnimating;
    final cardBgColor = isDark ? const Color(0xFF1C1C22) : Colors.white;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Trash Can Action Button Layer (revealed on the right)
        if (showDeleteBtn)
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _close();
                    widget.onDelete();
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFFFF7ED),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFF97316).withOpacity(0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF97316).withOpacity(0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      CupertinoIcons.trash,
                      color: Color(0xFFF97316),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Sliding Front Card
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final offset = _controller.isAnimating ? _animation.value : _dragOffset;
            return Transform.translate(
              offset: Offset(offset, 0),
              child: Container(
                color: offset < 0 ? cardBgColor : Colors.transparent,
                child: child,
              ),
            );
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) {
              setState(() {
                _dragOffset += details.delta.dx;
                if (_dragOffset > 0) {
                  _dragOffset = 0;
                } else if (_dragOffset < -_maxDragDistance) {
                  // Damping resistance when dragging past max distance
                  final overflow = -_dragOffset - _maxDragDistance;
                  _dragOffset = -_maxDragDistance - (overflow * 0.25);
                }

                if (_dragOffset < -14 && !_hasHapticked) {
                  HapticFeedback.selectionClick();
                  _hasHapticked = true;
                }
              });
            },
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0.0;
              // Responsive trigger threshold: open on light swipe (-14px) or quick drag (-80px/s velocity)
              if (_dragOffset < -14 || velocity < -80) {
                _open();
              } else {
                _close();
              }
            },
            onTap: () {
              if (_dragOffset < 0) {
                _close();
              }
            },
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
