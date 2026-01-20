import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'qrcode_provider.g.dart';

/// QrCode 数据模型
class QrCodeModel {
  final String qrcodeData;
  final int expiredAt;

  const QrCodeModel({this.qrcodeData = '', this.expiredAt = 0});

  QrCodeModel copyWith({String? qrcodeData, int? expiredAt}) {
    return QrCodeModel(
      qrcodeData: qrcodeData ?? this.qrcodeData,
      expiredAt: expiredAt ?? this.expiredAt,
    );
  }
}

/// QrCode Provider - 使用 @riverpod 注解
@riverpod
class QrCodeNotifier extends _$QrCodeNotifier {
  @override
  QrCodeModel build() => const QrCodeModel();

  /// 更新二维码数据
  void updateQrcodeData(String data) {
    state = state.copyWith(qrcodeData: data);
  }

  /// 更新过期时间
  void updateExpiredAt(int timestamp) {
    state = state.copyWith(expiredAt: timestamp);
  }

  /// 重置状态
  void reset() {
    state = const QrCodeModel();
  }
}
