import 'package:flutter/material.dart';


class SOSButton extends StatefulWidget {
  final VoidCallback onPressed;
  final double? width;
  final double height;

  const SOSButton({
    super.key,
    required this.onPressed,
    this.width,
    this.height = 180.0,
  });

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTap: widget.onPressed,
            child: Container(
              width: widget.width ?? 200,
              height: widget.height,
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE91E63), // Pink 500
                    Color(0xFFC2185B), // Pink 700
                    Color(0xFF880E4F), // Pink 900
                  ],
                ),
                boxShadow: [
                  // Inner glow
                  BoxShadow(
                    color: const Color(0xFFE91E63).withOpacity(0.6),
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: const Offset(0, 0),
                  ),
                  // Outer pulse simulation (static layers for depth)
                  BoxShadow(
                    color: const Color(0xFFC2185B).withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 10 * _controller.value,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(
                    Icons.touch_app,
                    color: Colors.white70,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'TAP FOR HELP',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
