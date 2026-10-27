/// RFC 4330 SNTP 查询与 64 位时间戳解析（R20-A）。
///
/// 替代 package:ntp 的黑盒 `getNtpOffset`：这里把**协议解析做成纯函数**
/// （可对构造字节流单测），时钟偏移用标准 NTP 公式
/// `offset = ((t2 - t1) + (t3 - t4)) / 2`（t1/t4 为客户端收发时刻，
/// t2/t3 为服务器收发时刻），该公式天然完成 RTT 补偿的一半；
/// 另以 `rtt = (t4 - t1) - (t2 - t3)` 作为样本合理性闸门。
///
/// 非纯函数的 [queryNtp] 只负责 UDP 收发（dart:io，移动/桌面平台；
/// Web 平台由 NtpHelper 前置分支跳过，不会触达本函数）。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

/// NTP epoch（1900-01-01）与 Unix epoch（1970-01-01）的秒差。
const int ntpEpochOffsetSeconds = 2208988800;

/// 单次 NTP 采样结果。
class NtpSample {
  const NtpSample({required this.offsetMs, required this.rttMs});

  /// 服务器时钟 − 本地时钟（毫秒），按 ((t2−t1)+(t3−t4))/2 取整。
  final int offsetMs;

  /// 往返时延（毫秒）：((t4 − t1) − (t2 − t3))。
  final int rttMs;
}

/// 采样合理性上限：RTT 超过 10s 视为坏样本（NTP 服务器/网络异常）。
const int maxSaneRttMs = 10 * 1000;

/// 采样合理性上限：|offset| 超过 24h 视为坏样本（与 sv_ts 校正同一口径）。
const int maxSaneOffsetMs = 24 * 3600 * 1000;

/// 读取 48 字节 NTP 包中 [offset] 位置的 64 位时间戳，转 Unix epoch 毫秒。
///
/// 布局：高 32 位为自 1900 起的整秒，低 32 位为小数秒（单位 1/2^32 秒）。
/// 全零字段（服务器未填）返回 null。
@visibleForTesting
int? readNtpTimestamp(List<int> data, int offset) {
  int seconds = 0;
  int fraction = 0;
  for (var i = 0; i < 4; i++) {
    seconds = (seconds << 8) | (data[offset + i] & 0xff);
    fraction = (fraction << 8) | (data[offset + 4 + i] & 0xff);
  }
  if (seconds == 0 && fraction == 0) return null;
  final unixSeconds = seconds - ntpEpochOffsetSeconds;
  // 小数秒 → 毫秒：32 位小数量化误差远小于 1ms，四舍五入保证
  // 任意整毫秒写入后无损读回（floor 会把 123ms 读成 122ms）。
  final millis = (fraction * 1000 + 0x80000000) >>> 32;
  return unixSeconds * 1000 + millis;
}

/// 把 Unix epoch 毫秒写成 64 位 NTP 时间戳（大端），写入 [target] 的
/// [offset] 位置。构造客户端请求的 transmit 字段用。
@visibleForTesting
void writeNtpTimestamp(List<int> target, int offset, int unixMs) {
  final unixSeconds = unixMs ~/ 1000;
  final remainderMs = unixMs - unixSeconds * 1000;
  final seconds = unixSeconds + ntpEpochOffsetSeconds;
  final fraction = (remainderMs << 32) ~/ 1000;
  for (var i = 0; i < 4; i++) {
    target[offset + i] = (seconds >> (8 * (3 - i))) & 0xff;
  }
  for (var i = 0; i < 4; i++) {
    target[offset + 4 + i] = (fraction >> (8 * (3 - i))) & 0xff;
  }
}

/// 构造 48 字节 SNTP 客户端请求（LI=0, VN=4, Mode=3）。
///
/// transmit 字段写 入[t1Ms]，服务器会将其原样回显为 originate timestamp，
/// 响应解析据此校验"这是本请求的响应"。
@visibleForTesting
List<int> buildNtpRequest(int t1Ms) {
  final data = List<int>.filled(48, 0);
  data[0] = 0x23; // 00 100 011：LI=0（无告警）、版本 4、模式 3（客户端）
  writeNtpTimestamp(data, 40, t1Ms);
  return data;
}

/// 解析 NTP 响应并计算 offset/RTT（纯函数，t1/t4 由调用方注入便于单测）。
///
/// 返回 null 的全部情形（均视为坏样本，调用方应丢弃重试）：
///   - 包长不足 48 字节；
///   - leap indicator == 3（服务器时钟未同步，kiss-o'-death 类告警）；
///   - originate（t1 回显）/receive（t2）/transmit（t3）任一字段缺失；
///   - originate 与本地记录的 t1 偏差超过 [echoToleranceMs]（响应串包）；
///   - RTT 为负或超过 [maxSaneRttMs]；
///   - |offset| 超过 [maxSaneOffsetMs]。
@visibleForTesting
NtpSample? parseNtpResponse(
  List<int> data, {
  required int t1Ms,
  required int t4Ms,
  int echoToleranceMs = 2000,
}) {
  if (data.length < 48) return null;
  final leapIndicator = (data[0] >> 6) & 0x3;
  if (leapIndicator == 3) return null; // alarm：服务器自身未同步

  final originateMs = readNtpTimestamp(data, 24); // 服务器回显的 t1
  final receiveMs = readNtpTimestamp(data, 32); // t2：服务器收到
  final transmitMs = readNtpTimestamp(data, 40); // t3：服务器发出
  if (originateMs == null || receiveMs == null || transmitMs == null) {
    return null;
  }
  if ((originateMs - t1Ms).abs() > echoToleranceMs) return null;

  // RTT = (t4 - t1') - (t3 - t2)，t1' 用服务器回显值（排除请求在途抖动）。
  final rttMs = (t4Ms - originateMs) - (transmitMs - receiveMs);
  if (rttMs < 0 || rttMs > maxSaneRttMs) return null;

  // offset = ((t2 - t1') + (t3 - t4)) / 2，四舍五入到整数毫秒。
  final offsetMs = (((receiveMs - originateMs) + (transmitMs - t4Ms)) / 2)
      .round();
  if (offsetMs.abs() > maxSaneOffsetMs) return null;

  return NtpSample(offsetMs: offsetMs, rttMs: rttMs);
}

/// 向 [host]（UDP 123）发起一次 SNTP 查询。
///
/// 抛出 [Exception]/[TimeoutException] 表示本次查询失败；
/// 解析判定为坏样本同样抛错，由上层按"保留 last-good"语义处理。
Future<NtpSample> queryNtp(
  String host, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final addresses = await InternetAddress.lookup(host);
  if (addresses.isEmpty) {
    throw Exception('NTP: could not resolve $host');
  }
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  try {
    final t1Ms = DateTime.now().millisecondsSinceEpoch;
    socket.send(buildNtpRequest(t1Ms), addresses.first, 123);

    await socket.firstWhere((e) => e == RawSocketEvent.read).timeout(timeout);
    final t4Ms = DateTime.now().millisecondsSinceEpoch;
    final packet = socket.receive();
    if (packet == null) {
      throw Exception('NTP: empty response from $host');
    }
    final sample = parseNtpResponse(packet.data, t1Ms: t1Ms, t4Ms: t4Ms);
    if (sample == null) {
      throw Exception('NTP: unusable sample from $host');
    }
    return sample;
  } finally {
    socket.close();
  }
}
