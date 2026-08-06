import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/vodozemac_init.dart';
import 'package:imboy/service/group_session_service.dart';
import 'package:imboy/service/olm_session_service.dart';

/// 回归：vodozemac 的 flutter_rust_bridge 初始化是**进程级全局**的，
/// OlmSessionService 与 GroupSessionService 必须共用同一份就绪标志。
///
/// 各存一份时，谁先 init 成功、另一个的标志仍是 false，于是重复 init 并抛
/// `Bad state: Should not initialize flutter_rust_bridge twice`
/// （真机日志：`initialize megolm failed: Bad state: ...`）。
void main() {
  setUp(VodozemacInit.debugReset);
  tearDown(VodozemacInit.debugReset);

  test('Olm 侧标记就绪后，Megolm 侧也视为就绪（反之亦然）', () {
    expect(VodozemacInit.isReady, isFalse);

    OlmSessionService.debugMarkVodReady();
    expect(
      VodozemacInit.isReady,
      isTrue,
      reason: 'Olm 与 Megolm 若各持一份标志，这里就会是 false，真机上便重复 init',
    );

    VodozemacInit.debugReset();
    GroupSessionService.debugMarkVodReady();
    expect(VodozemacInit.isReady, isTrue);
  });

  test('已就绪时 ensure() 不再触发原生初始化', () async {
    VodozemacInit.debugMarkReady();
    // 未就绪时 ensure() 会调 fvod.init()，在无原生库的测试进程里必然抛异常；
    // 能安静返回即证明就绪短路生效。
    await VodozemacInit.ensure();
    expect(VodozemacInit.isReady, isTrue);
  });
}
