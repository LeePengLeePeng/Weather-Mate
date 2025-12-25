import 'dart:ui';
import 'package:flutter/material.dart';

class WeatherBackground extends StatelessWidget {
  final Widget child;
  final dynamic weather; // 保留這個參數，避免 home_screen 報錯

  const WeatherBackground({
    super.key, 
    required this.child,
    this.weather, // 接收但不一定需要使用，讓它與 home_screen 相容
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 0. 白色底色 (避免圓球沒蓋到的地方變黑)
        Container(color: Colors.white),

        // --- 1. 你的原始背景 Blobs ---
        
        // 右邊的黃色光暈
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

        // 左邊的藍色光暈
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

        // 上方的紫色光暈
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
        // --- 2. 高斯模糊 (讓圓球變成夢幻背景) ---
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 100.0, sigmaY: 100.0), 
          child: Container(
            decoration: const BoxDecoration(color: Colors.transparent),
          ),
        ),
        // --- 3. 內容層 (PageView) ---
        // 使用 Positioned.fill 確保內容填滿整個畫面
        Positioned.fill(
          child: child,
        ),
      ],
    );
  }
}