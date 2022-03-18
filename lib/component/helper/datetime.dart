import 'package:imboy/config/init.dart';
import 'package:jiffy/jiffy.dart';

class DateTimeHelper {
  static String customDateHeader(DateTime dt) {
    int diff = Jiffy().diff(dt, Units.DAY) as int;
    if (diff > 6) {
      // 2022-01-22 11:58
      return Jiffy(dt).format('y-MM-dd HH:mm');
    } else if (diff > 2) {
      // 星期二 09:18
      return Jiffy(dt).format('EEEE HH:mm');
    } else {
      return Jiffy(dt).startOf(Units.MINUTE).fromNow();
    }
  }

  static String lastConversationFmt(int lasttime) {
    DateTime dt = Jiffy.unixFromMillisecondsSinceEpoch(lasttime).dateTime;
    int diff = Jiffy().diff(dt, Units.DAY) as int;
    if (diff > 6) {
      // 2022-01-22
      return Jiffy(dt).format('y-MM-dd');
    } else if (diff > 2) {
      // 星期二 09:18
      return Jiffy(dt).format('EEEE HH:mm');
    } else {
      return Jiffy(dt).startOf(Units.MINUTE).fromNow();
    }
  }

  /// 当前时间的毫秒时间戳
  static int currentTimeMillis() {
    DateTime _myTime;
    DateTime _ntpTime;
    _myTime = DateTime.now();
    // debugPrint(">>> on currentTimeMillis _myTime ${_myTime.toString()}");
    // ntpOffset 是一个全局变量
    _ntpTime = _myTime.add(Duration(milliseconds: ntpOffset));
    // debugPrint(">>> on currentTimeMillis _ntpTime ${_ntpTime.toString()}");
    return _ntpTime.millisecondsSinceEpoch;
  }
}
