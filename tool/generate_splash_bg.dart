/// 生成启动画面渐变背景图片的工具脚本
/// 运行方式: dart tool/generate_splash_bg.dart
library;

import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';

void main() async {
  // 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 定义渐变颜色（与 SplashPage 一致）
  final gradient = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF42A5F5), // Light Blue
      Color(0xFF2474E5), // Primary Blue
      Color(0xFF1565C0), // Dark Blue
    ],
  );

  // 定义目标尺寸
  const sizes = [
    Size(1080, 1920), // Android 全屏
    Size(1080, 2340), // Android 长屏
    Size(1170, 2532), // iPhone 14 Pro
    Size(1125, 2436), // iPhone X/XS/11 Pro
  ];

  print('开始生成渐变背景图片...');

  for (final size in sizes) {
    try {
      await _generateGradientImage(gradient, size);
      print('✅ 已生成: ${size.width.toInt()}x${size.height.toInt()}');
    } catch (e) {
      print('❌ 生成失败 ${size.width.toInt()}x${size.height.toInt()}: $e');
    }
  }

  print('\n完成！生成的图片位于: assets/images/splash_gradient_bg.png');

  // 退出程序
  exit(0);
}

Future<void> _generateGradientImage(LinearGradient gradient, Size size) async {
  // 创建一个 RecordingCanvas 来绘制渐变
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);

  // 创建渐变着色器
  final rect = Rect.fromLTWH(0, 0, size.width, size.height);
  final shader = gradient.createShader(rect);

  // 绘制渐变背景
  final paint = Paint()..shader = shader;
  canvas.drawRect(rect, paint);

  // 转换为图片
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());

  // 将图片转换为 PNG 字节
  final byteData = await image.toByteData(format: ImageByteFormat.png);
  if (byteData == null) {
    throw Exception('无法转换图片为 PNG');
  }

  final pngBytes = byteData.buffer.asUint8List();

  // 保存文件
  final filename =
      'assets/images/splash_gradient_bg_${size.width.toInt()}x${size.height.toInt()}.png';
  final file = File(filename);
  await file.writeAsBytes(pngBytes);

  // 如果是主尺寸 (1080x1920)，额外保存一个不带尺寸后缀的版本
  if (size.width == 1080 && size.height == 1920) {
    final mainFile = File('assets/images/splash_gradient_bg.png');
    await mainFile.writeAsBytes(pngBytes);
  }

  // 释放资源
  image.dispose();
  picture.dispose();
}
