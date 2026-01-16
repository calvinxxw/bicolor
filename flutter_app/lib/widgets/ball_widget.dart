import 'package:flutter/material.dart';

class BallWidget extends StatelessWidget {
  final int number;
  final bool isBlue;

  const BallWidget({
    super.key,
    required this.number,
    this.isBlue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: isBlue ? Colors.blue : Colors.red,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          number.toString().padLeft(2, '0'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
