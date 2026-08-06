import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/conversation_model.dart';

/// BUG#4 家族收口：TSID 在任何情况下都不进 UI，也不进跳转参数。
///
/// 批次 14 拿到的新证据：同一个群，三条路径三种结果 ——
/// 进程恢复路径显示 `104603643803863040(2)`（TSID 直接泄漏），
/// 会话列表点进显示 `群聊(2)`，群详情页显示 `未命名`。
/// 根因是「脏值判定 + 兜底」这套逻辑在会话列表 / 跳转参数 / 聊天页
/// 各写了一遍，写歪一处就漏一条路径。
///
/// 这里锁住收口后的两条语义：
/// - `resolvedTitle`：真名或空，**不兜底**（下游还要靠"空"去继续查群名）
/// - `displayTitle`：给人看的，缺名一律「未命名」，绝不回退到内部 ID
ConversationModel _conv({required String title, String computeTitle = ''}) {
  final m = ConversationModel(
    id: 1,
    peerId: 104603643803863040,
    avatar: '',
    title: title,
    subtitle: '',
    type: 'C2G',
    msgType: 'text',
    lastTime: 0,
    lastMsgId: 0,
    unreadNum: 0,
    isShow: 1,
  );
  m.computeTitle = computeTitle;
  return m;
}

void main() {
  group('resolvedTitle：真名或空，不兜底', () {
    test('正常群名原样返回', () {
      expect(_conv(title: '产品讨论组').resolvedTitle, '产品讨论组');
    });

    test('title 存的就是 peerId（存量脏值）→ 判定为缺失', () {
      expect(
        _conv(title: '104603643803863040').resolvedTitle,
        '',
        reason: '这类脏值"非空"，纯兜底链救不回来，必须显式判定为缺失',
      );
    });

    test('title 脏但有 computeTitle → 用 computeTitle', () {
      expect(
        _conv(title: '104603643803863040', computeTitle: '张三、李四').resolvedTitle,
        '张三、李四',
      );
    });

    test('两者都拿不到 → 空串，而不是「未命名」', () {
      expect(
        _conv(title: '').resolvedTitle,
        '',
        reason: '传兜底后的「未命名」会堵死聊天页继续查群名/成员名的那条链',
      );
    });

    test('前后空白被裁掉', () {
      expect(_conv(title: '  产品讨论组  ').resolvedTitle, '产品讨论组');
    });
  });

  group('displayTitle：给人看的，绝不泄漏 TSID', () {
    test('有名字就用名字', () {
      expect(_conv(title: '产品讨论组').displayTitle, '产品讨论组');
    });

    test('脏值 peerId 不得出现在展示名里', () {
      final shown = _conv(title: '104603643803863040').displayTitle;
      expect(shown.contains('104603643803863040'), isFalse);
      expect(shown, isNotEmpty);
    });

    test('全缺名回落到统一占位，且不是空串', () {
      final shown = _conv(title: '').displayTitle;
      expect(shown, isNotEmpty);
      expect(shown.contains('104603643803863040'), isFalse);
    });
  });
}
