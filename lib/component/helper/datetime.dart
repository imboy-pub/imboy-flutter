import 'package:imboy/config/init.dart';
import 'package:jiffy/jiffy.dart';

class DateTimeHelper {
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
    // DateTime dt = Jiffy.unixFromMillisecondsSinceEpoch(lastTime).dateTime;
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

  /// 当前时间的秒时间戳
  static int currentTimeSecond() {
    return currentTimeMillis() ~/ 1000;
  }
}
