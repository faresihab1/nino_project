import 'package:flutter/material.dart';

class Background extends StatelessWidget {
  const Background({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'images/background2.png',
          fit: BoxFit.cover,
        ),

        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Image.asset(
            'images/background1.png',
            fit: BoxFit.cover,
          ),
        ),

        Image.asset(
          'images/line.png',
          fit: BoxFit.cover,
        ),
      ],
    );
  }
}