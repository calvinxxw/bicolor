import 'package:flutter/material.dart';

class BallWidget extends StatelessWidget {
  final int number;
  final bool isBlue;
  final double size;
  final double opacity;
  final Color? borderColor;
  final double borderWidth;

  const BallWidget({
    super.key,
    required this.number,
    this.isBlue = false,
    this.size = 32,
    this.opacity = 1.0,
    this.borderColor,
    this.borderWidth = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: (isBlue ? Colors.blue : Colors.red).withOpacity(opacity),
        shape: BoxShape.circle,
        border: borderColor != null 
          ? Border.all(color: borderColor!, width: borderWidth > 0 ? borderWidth : 2)
          : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1 * opacity),
            blurRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          number.toString().padLeft(2, '0'),
          style: TextStyle(
            color: Colors.white.withOpacity(opacity),
            fontWeight: FontWeight.bold,
            fontSize: size * 0.45,
          ),
        ),
      ),
    );
  }
}