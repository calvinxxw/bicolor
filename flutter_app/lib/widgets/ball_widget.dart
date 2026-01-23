import 'package:flutter/material.dart';

class BallWidget extends StatelessWidget {
  final int number;
  final bool isBlue;
  final double size;

  const BallWidget({
    super.key,
    required this.number,
    this.isBlue = false,
    this.size = 50,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isBlue ? Colors.blue : Colors.red,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          number.toString().padLeft(2, '0'),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
