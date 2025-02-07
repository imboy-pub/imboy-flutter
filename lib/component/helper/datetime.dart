import 'package:imboy/service/storage.dart';
import 'package:jiffy/jiffy.dart';
import 'package:ntp/ntp.dart';

class DateTimeHelper {
  static Future<int> getNtpOffset() async {
    String key = "ntp_offset";
    String? val = StorageService.to.getString(key);
    // debugPrint("> on currentTimeMillis val1 ${val}");
    // val = null;
    int offset = 0;
    if (val == null) {
      try {
        offset = await NTP.getNtpOffset(
          localTime: Jiffy.now().dateTime,
          lookUpAddress: 'time5.cloud.tencent.com',
        );
        // debugPrint("> on currentTimeMillis offset2 ${offset}");
        String dt = Jiffy.now().format(pattern: 'y-MM-dd HH:mm:ss');
        val = '$dt$offset';
        // debugPrint("> on currentTimeMillis val2 ${val}");
        StorageService.to.setString(key, val);
        // ignore: empty_catches
      } catch (e) {}
    } else {
      // 2022-01-23 00:30:35 字符串的长度刚好19位
      offset = Jiffy.now().diff(
        Jiffy.parse(val.substring(0, 19)),
        unit: Unit.second,
      ) as int;
      if (offset > 3600) {
        await StorageService.to.remove(key);
        return getNtpOffset();
      }
    }
    return offset;
  }

  static String dateTimeFmt(DateTime dt) {
    // iPrint("customDateHeader1 ${dt.isUtc}, ${dt.toIso8601String()}");
    int diff = Jiffy.now().diff(
      Jiffy.parseFromDateTime(dt),
      unit: Unit.day,
    ) as int;
    if (diff > 6) {
      // 2022-01-22 11:58
      return Jiffy.parseFromDateTime(dt).format(pattern: 'y-MM-dd HH:mm');
    } else if (diff > 2) {
      // 星期二 09:18
      return Jiffy.parseFromDateTime(dt).format(pattern: 'EEEE HH:mm');
    } else {
      return Jiffy.parseFromDateTime(dt).startOf(Unit.minute).fromNow();
    }
  }

  static String lastTimeFmt(int lastTime) {
    // iPrint("lasttime $lastTime DateTime.now().timeZoneOffset.inMilliseconds ${DateTime.now().timeZoneOffset.inMilliseconds}");
    DateTime dt = Jiffy.parseFromMillisecondsSinceEpoch(lastTime, isUtc: true).dateTime;
    return dateTimeFmt(dt);
  }

  static DateTime fromRfc3339(String input) {
    DateTime localTime = Jiffy.parse(input, pattern:"yyyy-MM-dd HH:mm:ss.SSSSSSZZ").dateTime.toLocal();
    return localTime;
  }

  static String millisecondToRfc3339(int millis, {bool isUtc = true}) {
    // 如果时间戳代表的是 UTC 时间，则设置 isUtc: true
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: isUtc);
    return toRfc3339(dt);
  }

  static String rfc3339() {
    return toRfc3339(DateTime.now());
  }

  static String toRfc3339(DateTime dt) {
    final tz = dt.timeZoneOffset;
    final formatted = "${Jiffy.parseFromDateTime(dt).format(pattern:"yyyy-MM-dd HH:mm:ss")}.${dt.microsecond.toString().padLeft(6, '0')}"
        "${tz.isNegative ? '-' : '+'}${tz.inHours.abs().toString().padLeft(2, '0')}:"
        "${(tz.inMinutes.abs() % 60).toString().padLeft(2, '0')}";
    return formatted;
  }


  static int rfc3339ToMillisecond(String rfc3339) {
    DateTime dt = DateTime.parse(rfc3339);
    return dt.millisecondsSinceEpoch;
  }

  static int rfc3339ToMicrosecond(String rfc3339) {
    DateTime dt = DateTime.parse(rfc3339);
    return dt.microsecondsSinceEpoch;
  }


  /// UTC时间的秒时间戳
  static int second() {
    return millisecond() ~/ 1000;
  }

  /// 当前时间的毫秒时间戳
  static int millisecond() {
    return microsecond() ~/ 1000;
  }

  /// 微秒时间戳
  static int microsecond() {
    // 获取当前时间
    DateTime now = DateTime.now();
    // 获取UTC时间的微秒级时间戳 microsecondsSinceEpoch
    return now.microsecondsSinceEpoch;
  }

}
