/// R20-A：NTP 协议字节级解析单测（纯函数，不触网）。
///
/// 用构造的 48 字节 NTP 包 fixture 锁住：
/// - 64 位时间戳读写往返（秒 + 小数位）；
/// - 标准 offset 公式 ((t2−t1)+(t3−t4))/2 与 RTT ((t4−t1)−(t3−t2))；
/// - 坏样本闸门（短包 / leap 告警 / 字段缺失 / 回显不匹配 / 负 RTT /
///   超量级 RTT 与 offset）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/helper/ntp_query.dart';

/// 构造 48 字节 NTP 响应包。
List<int> buildResponse({
  int firstByte = 0x24, // LI=0 VN=4 Mode=4(server)
  int? originateMs,
  int? receiveMs,
  int? transmitMs,
  int length = 48,
}) {
  final data = List<int>.filled(length, 0);
  data[0] = firstByte;
  if (originateMs != null) writeNtpTimestamp(data, 24, originateMs);
  if (receiveMs != null) writeNtpTimestamp(data, 32, receiveMs);
  if (transmitMs != null) writeNtpTimestamp(data, 40, transmitMs);
  return data;
}

void main() {
  group('readNtpTimestamp / writeNtpTimestamp roundtrip', () {
    test('整秒往返', () {
      final data = List<int>.filled(48, 0);
      const unixMs = 1789600000000;
      writeNtpTimestamp(data, 40, unixMs);
      expect(readNtpTimestamp(data, 40), unixMs);
    });

    test('小数毫秒往返（秒 + 小数位）', () {
      final data = List<int>.filled(48, 0);
      const unixMs = 1789600000123;
      writeNtpTimestamp(data, 32, unixMs);
      // 小数位精度 1/2^32 秒 ≈ 0.00023ms，毫秒级无损往返。
      expect(readNtpTimestamp(data, 32), unixMs);
    });

    test('全零字段返回 null（服务器未填）', () {
      final data = List<int>.filled(48, 0);
      expect(readNtpTimestamp(data, 40), isNull);
    });
  });

  group('buildNtpRequest', () {
    test('头字节 LI=0 VN=4 Mode=3；transmit 写入 t1', () {
      const t1 = 1789600000500;
      final req = buildNtpRequest(t1);
      expect(req.length, 48);
      expect(req[0], 0x23);
      expect(readNtpTimestamp(req, 40), t1);
    });
  });

  group('parseNtpResponse', () {
    test('标准样本：对称延迟 50ms/50ms、服务器快 300ms → offset=300 rtt=100', () {
      // 场景：server = client + 300ms；上行/下行各 50ms；服务器处理 5ms。
      const t1 = 1000000;
      const t2 = t1 + 50 + 300; // 服务器收到（server 钟）
      const t3 = t2 + 5; // 服务器发出
      const t4 = t3 + 50 - 300; // 客户端收到（client 钟）
      final sample = parseNtpResponse(
        buildResponse(originateMs: t1, receiveMs: t2, transmitMs: t3),
        t1Ms: t1,
        t4Ms: t4,
      );
      expect(sample, isNotNull);
      expect(sample!.offsetMs, 300);
      expect(sample.rttMs, 100);
    });

    test('下行更慢时 offset 含 (d1-d2)/2 偏差（协议固有，非实现 bug）', () {
      // d1=80, d2=20, 处理 5ms, θ=300 → offset = 300 + 30 = 330。
      const t1 = 1000000;
      const t2 = t1 + 80 + 300;
      const t3 = t2 + 5;
      const t4 = t3 + 20 - 300;
      final sample = parseNtpResponse(
        buildResponse(originateMs: t1, receiveMs: t2, transmitMs: t3),
        t1Ms: t1,
        t4Ms: t4,
      );
      expect(sample!.offsetMs, 330);
      expect(sample.rttMs, 100); // (t4-t1)=105 − 服务器处理 5ms = 网络 d1+d2
    });

    test('短包 → null', () {
      expect(
        parseNtpResponse(List<int>.filled(20, 0), t1Ms: 0, t4Ms: 1),
        isNull,
      );
    });

    test('leap indicator == 3（服务器未同步）→ null', () {
      const t1 = 1000000;
      final data = buildResponse(
        firstByte: 0xE4, // LI=3 VN=4 Mode=4
        originateMs: t1,
        receiveMs: t1 + 50,
        transmitMs: t1 + 55,
      );
      expect(parseNtpResponse(data, t1Ms: t1, t4Ms: t1 + 100), isNull);
    });

    test('transmit/receive 缺失 → null', () {
      const t1 = 1000000;
      final data = buildResponse(originateMs: t1);
      expect(parseNtpResponse(data, t1Ms: t1, t4Ms: t1 + 100), isNull);
    });

    test('originate 未回显 → null（非本请求的响应）', () {
      const t1 = 1000000;
      final data = buildResponse(receiveMs: t1 + 50, transmitMs: t1 + 55);
      expect(parseNtpResponse(data, t1Ms: t1, t4Ms: t1 + 100), isNull);
    });

    test('originate 回显与本地 t1 偏差超容差 → null', () {
      const t1 = 1000000;
      final data = buildResponse(
        originateMs: t1 + 3000, // 超过 echoTolerance 2000ms
        receiveMs: t1 + 3050,
        transmitMs: t1 + 3055,
      );
      expect(parseNtpResponse(data, t1Ms: t1, t4Ms: t1 + 3100), isNull);
    });

    test('负 RTT（时钟乱序）→ null', () {
      const t1 = 1000000;
      // t4 早于 originate 回显：不可能的因果顺序。
      final data = buildResponse(
        originateMs: t1,
        receiveMs: t1 + 10,
        transmitMs: t1 + 15,
      );
      expect(parseNtpResponse(data, t1Ms: t1, t4Ms: t1 - 5), isNull);
    });

    test('RTT 超 10s → null', () {
      const t1 = 1000000;
      final data = buildResponse(
        originateMs: t1,
        receiveMs: t1 + 50,
        transmitMs: t1 + 55,
      );
      expect(parseNtpResponse(data, t1Ms: t1, t4Ms: t1 + 20000), isNull);
    });

    test('offset 超 24h → null', () {
      const t1 = 1000000;
      final data = buildResponse(
        originateMs: t1,
        receiveMs: t1 + 25 * 3600 * 1000, // 服务器"快"超过一天
        transmitMs: t1 + 25 * 3600 * 1000 + 5,
      );
      expect(parseNtpResponse(data, t1Ms: t1, t4Ms: t1 + 100), isNull);
    });
  });
}
