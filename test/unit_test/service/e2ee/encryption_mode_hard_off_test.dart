// E2EE 全局硬闸（服务端 storage_mode=disabled）的客户端判定守护测试。
//
// 语义（与服务端 imboy_policy:e2ee_disabled/0 对齐）：storage_mode=disabled 表示
// 「本部署整体不使用端到端加密」。它是硬闸——出现该值时**优先于 e2ee_mode**：
// 即便配置里 e2ee_mode 仍写着 required（半改配置），客户端也必须按明文走。
//
// 为什么这条必须钉死：客户端一旦在硬闸下继续加密，就会去 claim 对方设备密钥，
// 而服务端此时已随硬闸关闭密钥端点（e2ee_enabled/0 → false）——直接回到
// 「要求加密却拿不到密钥」的死锁（生产实测过同类组合），表现为 C2C 文本全部
// 发不出去，报错还指向"设备密钥"，无从定位。
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/encryption_mode.dart';

void main() {
  setUp(() {
    EncryptionModeService.debugSet(
      mode: EncryptionMode.plaintext,
      initialized: false,
    );
  });

  tearDown(() {
    EncryptionModeService.debugFetcher = null;
    EncryptionModeService.debugSet(
      mode: EncryptionMode.plaintext,
      initialized: false,
    );
  });

  Future<void> refreshWith(Map<String, dynamic> capabilities) async {
    EncryptionModeService.debugFetcher = () async => capabilities;
    await EncryptionModeService.refresh(force: true);
  }

  test(
    '硬闸优先于 e2ee_mode：storage_mode=disabled + e2ee_mode=required 走明文',
    () async {
      await refreshWith(<String, dynamic>{
        'storage_mode': 'disabled',
        'e2ee_mode': 'required',
      });

      expect(EncryptionModeService.current, EncryptionMode.plaintext);
      expect(EncryptionModeService.current.requiresEncryption, isFalse);
    },
  );

  test('交付形态：双 disabled 走明文', () async {
    await refreshWith(<String, dynamic>{
      'storage_mode': 'disabled',
      'e2ee_mode': 'disabled',
    });

    expect(EncryptionModeService.current, EncryptionMode.plaintext);
    expect(EncryptionModeService.isInitialized, isTrue);
  });

  test('对照组：合规档位维持原语义（未把硬闸写成无条件明文）', () async {
    // 既有优先级不变：e2ee_mode 优先于 storage_mode。
    // 故 e2ee_mode=compliance 才是"合规档"，而 compliance_e2ee + required 归 strict。
    await refreshWith(<String, dynamic>{
      'storage_mode': 'compliance_e2ee',
      'e2ee_mode': 'compliance',
    });

    expect(EncryptionModeService.current, EncryptionMode.complianceE2ee);
    expect(EncryptionModeService.current.requiresEncryption, isTrue);
  });

  test('对照组：e2ee_mode 优先于 storage_mode（既有语义不因硬闸分支改变）', () async {
    await refreshWith(<String, dynamic>{
      'storage_mode': 'compliance_e2ee',
      'e2ee_mode': 'required',
    });

    expect(EncryptionModeService.current, EncryptionMode.strictE2ee);
  });

  test('对照组：strict 档位维持原语义', () async {
    await refreshWith(<String, dynamic>{
      'storage_mode': 'secure_e2ee',
      'e2ee_mode': 'required',
    });

    expect(EncryptionModeService.current, EncryptionMode.strictE2ee);
  });

  test('未知枚举值一律按明文（老版本 App 拿到新档位不会被卡死）', () async {
    await refreshWith(<String, dynamic>{
      'storage_mode': 'some_future_mode',
      'e2ee_mode': 'disabled',
    });

    expect(EncryptionModeService.current, EncryptionMode.plaintext);
  });
}
