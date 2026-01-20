import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

part 'scanner_provider.g.dart';

/// Scanner 状态模型
class ScannerState {
  final String? barcodeStr;
  final Barcode? barcode;
  final BarcodeCapture? capture;
  final bool isStarted;
  final bool attainableResult;
  final bool isProcessing;

  const ScannerState({
    this.barcodeStr,
    this.barcode,
    this.capture,
    this.isStarted = true,
    this.attainableResult = true,
    this.isProcessing = false,
  });

  ScannerState copyWith({
    String? barcodeStr,
    Barcode? barcode,
    BarcodeCapture? capture,
    bool? isStarted,
    bool? attainableResult,
    bool? isProcessing,
  }) {
    return ScannerState(
      barcodeStr: barcodeStr ?? this.barcodeStr,
      barcode: barcode ?? this.barcode,
      capture: capture ?? this.capture,
      isStarted: isStarted ?? this.isStarted,
      attainableResult: attainableResult ?? this.attainableResult,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

/// Scanner Provider - 使用 @riverpod 注解
@riverpod
class ScannerNotifier extends _$ScannerNotifier {
  Timer? _resultResetTimer;

  @override
  ScannerState build() {
    ref.onDispose(() {
      _resultResetTimer?.cancel();
    });
    return const ScannerState();
  }

  /// 更新条码数据
  void updateBarcode(BarcodeCapture barcodes) {
    final barcodeValue = barcodes.barcodes.last.rawValue;
    state = state.copyWith(
      capture: barcodes,
      barcode: barcodes.barcodes.first,
      barcodeStr: barcodeValue,
    );
  }

  /// 开始处理（防止重复处理）
  void startProcessing() {
    state = state.copyWith(attainableResult: false, isProcessing: true);
    // 2秒后允许再次处理
    _resultResetTimer?.cancel();
    _resultResetTimer = Timer(const Duration(seconds: 2), () {
      state = state.copyWith(attainableResult: true, isProcessing: false);
    });
  }

  /// 切换扫描状态
  void toggleScanning(bool started) {
    state = state.copyWith(isStarted: started);
  }

  /// 重置状态
  void reset() {
    state = const ScannerState();
  }
}
