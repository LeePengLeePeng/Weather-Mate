import 'dart:ui';
import 'package:flutter/material.dart';

class WeatherBackground extends StatelessWidget {
  final Widget child;
  final dynamic weather;
  const WeatherBackground({
    super.key, 
    required this.child,
    this.weather, 
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 0. 白色底色
        Container(color: Colors.white),
        
        // 右邊
        Align(
          alignment: const AlignmentDirectional(3, -0.3), 
          child: Container(
            height: 300, 
            width: 300, 
            decoration: const BoxDecoration(
              shape: BoxShape.circle, 
              color: Color.fromARGB(255, 255, 206, 133),
            ),
          ),
        ),

        // 左邊
        Align(
          alignment: const AlignmentDirectional(-3, -0.3), 
          child: Container(
            height: 300, 
            width: 300, 
            decoration: const BoxDecoration(
              shape: BoxShape.circle, 
              color: Color.fromARGB(255, 175, 236, 255),
            ),
          ),
        ),

        // 上方
        Align(
          alignment: const AlignmentDirectional(0, -1.2), 
          child: Container(
            height: 500, 
            width: 500, 
            decoration: const BoxDecoration(
              shape: BoxShape.circle, 
              color: Color.fromARGB(255, 226, 205, 255),
            ),
          ),
        ),

        // --- 2. 高斯模糊 ---
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 100.0, sigmaY: 100.0), 
          child: Container(
            decoration: const BoxDecoration(color: Colors.transparent),
          ),
        ),
        // --- 3. 內容層 (PageView) ---
        Positioned.fill(
          child: child,
        ),
      ],
    );
  }
}