// integration_test/flows/pg_helper.dart
//
// 集成测试 PG 直连助手（批次120 引入）。
//
// 背景：flutter_tester 沙盒禁 spawn 子进程（Process.run psql = Operation
// not permitted），此前后端数据断言/造数全靠宿主 bash 轮询编排，脆弱且
// 无法在测试进程内做中途状态切换。本助手用纯 dart postgres 客户端直连
// 本地 PG（4323），让测试用例内部即可完成：
//   - 服务端状态断言（密码 hash 变更、注销申请落库等）
//   - 中途造数（清空 password 构造「未设密」态等）
//
// 仅允许指向本地测试库；默认参数即本机 4323/imboy_v1。
// 跑法示例：
//   flutter test integration_test/mine/account_security_lifecycle_test.dart \
//     -d macos --dart-define=TEST_PG_HOST=127.0.0.1
import 'package:postgres/postgres.dart';

class TestPg {
  TestPg._();

  static Connection? _conn;

  static Future<Connection> _open() async {
    final host = const String.fromEnvironment(
      'TEST_PG_HOST',
      defaultValue: '127.0.0.1',
    );
    final port =
        int.tryParse(
          const String.fromEnvironment('TEST_PG_PORT', defaultValue: '4323'),
        ) ??
        4323;
    final db = const String.fromEnvironment(
      'TEST_PG_DB',
      defaultValue: 'imboy_v1',
    );
    final user = const String.fromEnvironment(
      'TEST_PG_USER',
      defaultValue: 'imboy_user',
    );
    final pwd = const String.fromEnvironment(
      'TEST_PG_PASSWORD',
      defaultValue: 'abc54321',
    );
    return Connection.open(
      Endpoint(
        host: host,
        port: port,
        database: db,
        username: user,
        password: pwd,
      ),
      settings: ConnectionSettings(sslMode: SslMode.disable),
    );
  }

  /// 执行一条语句（自动重连一次；连接随 test 进程生命周期复用）。
  /// 占位符用 @name（Sql.named），参数走 execute 的 parameters。
  static Future<Result> execute(
    String sql, [
    Map<String, Object?>? params,
  ]) async {
    _conn ??= await _open();
    try {
      return await _conn!.execute(
        Sql.named(sql),
        parameters: params ?? const {},
      );
    } on Object {
      // 长场景中间隔较久，连接可能被服务端断开：重开一次再试
      try {
        await _conn?.close();
      } catch (_) {}
      _conn = await _open();
      return await _conn!.execute(
        Sql.named(sql),
        parameters: params ?? const {},
      );
    }
  }

  /// 取单值（首行首列），空结果返回 null。
  static Future<Object?> scalar(
    String sql, [
    Map<String, Object?>? params,
  ]) async {
    final r = await execute(sql, params);
    if (r.isEmpty) return null;
    return r[0][0];
  }

  static Future<void> close() async {
    try {
      await _conn?.close();
    } catch (_) {}
    _conn = null;
  }
}
