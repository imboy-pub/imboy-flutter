import 'package:imboy/config/init.dart';
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

  static String customDateHeader(DateTime dt) {
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
    DateTime dt = Jiffy.parseFromMillisecondsSinceEpoch(lastTime).dateTime;
    int diff = Jiffy.now().diff(
      Jiffy.parseFromDateTime(dt),
      unit: Unit.day,
    ) as int;
    if (diff > 6) {
      // 2022-01-22
      return Jiffy.parseFromDateTime(dt).format(pattern: 'y-MM-dd');
    } else if (diff > 2) {
      // 星期二 09:18
      return Jiffy.parseFromDateTime(dt).format(pattern: 'EEEE HH:mm');
    } else {
      return Jiffy.parseFromDateTime(dt).startOf(Unit.minute).fromNow();
    }
  }

  /// 当前utc0 时间戳
  static int utc() {
    return currentTimeMillis() - DateTime.now().timeZoneOffset.inMilliseconds;
  }

  /// 当前时间的毫秒时间戳
  static int currentTimeMillis() {
    DateTime myTime;
    DateTime ntpTime;
    myTime = Jiffy.now().dateTime;
    // debugPrint("> on currentTimeMillis _myTime ${_myTime.toString()}");
    // ntpOffset 是一个全局变量
    ntpTime = myTime.add(Duration(milliseconds: ntpOffset));
    // debugPrint("> on currentTimeMillis ntpTime ${ntpTime.toString()}");
    return ntpTime.millisecondsSinceEpoch;
  }

  /// UTC时间的秒时间戳
  static int utcSecond() {
    return utc() ~/ 1000;
  }
}
