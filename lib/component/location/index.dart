import 'dart:async';
import 'dart:math' as math;
import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:fl_amap/fl_amap.dart' as flmap;
import 'package:flutter/material.dart';
import 'package:imboy/component/helper/permission.dart';
import 'package:imboy/config/const.dart';

///  直接获取定位
///  @param needsAddress 是否需要详细地址信息 默认false
Future<flmap.AMapLocation?> getLocation([bool needsAddress = false]) async {
  // 检查网络状态
  var res = await Connectivity().checkConnectivity();
  if (res == ConnectivityResult.none) {
    return null;
  }
  bool serviceStatusIsEnabled = await requestLocationPermission();
  if (serviceStatusIsEnabled == false) {
    return null;
  }
  await flmap.setAMapKey(
    iosKey: AMAP_IOS_KEY,
    androidKey: AMAP_ANDROID_KEY,
  );

  /// 初始化AMap
  await flmap.FlAMapLocation().initialize(flmap.AMapLocationOption(
    gpsFirst: true,
    locationMode: flmap.AMapLocationMode.batterySaving,
    desiredAccuracy:
        flmap.CLLocationAccuracy.kCLLocationAccuracyNearestTenMeters,
  ));
  return flmap.FlAMapLocation().getLocation(needsAddress);
}

class AMapPosition {
  String id = "";
  String name = "";
  LatLng? latLng;
  String address = "";
  String pcode = "";
  String adcode = "";
  String distance = "";

  AMapPosition({
    required this.id,
    required this.name,
    required List<double> latlng,
    required this.address,
    required this.pcode,
    required this.adcode,
    required this.distance,
  }) {
    latLng = LatLng.fromJson(latlng);
  }
}

class LocationHelper {
  static const double EARTH_RADIUS = 6378.137; // 单位千米

  //获取城市名称
  static String getCityName(province, city) {
    if (citiesData[province] != null) {
      Map<String, dynamic> cityName = citiesData[province];
      return cityName[city]["name"];
    }

    return province == "allCode" ? "全国" : province;
  }

  //获取省份和城市
  static String getProvinceCityName(province, city) {
    if (citiesData[province] != null) {
      Map<String, dynamic> cityName = citiesData[province];
      return provincesData[province]! + cityName[city]["name"];
    }
    return "太阳系";
  }

  //获取城市名称，高德地图的adCode
  static String getCityNameByGaoDe(String code) {
    return "${code.substring(0, 4)}00";
  }

  //计算两个坐标的直线距离
  static double getRadian(double degree) {
    return degree * math.pi / 180.0;
  }

  //返回m
  static double getDistance(
      double lat1, double lng1, double lat2, double lng2) {
    double radLat1 = getRadian(lat1);
    double radLat2 = getRadian(lat2);
    double a = radLat1 - radLat2; // 两点纬度差
    double b = getRadian(lng1) - getRadian(lng2); // 两点的经度差
    double s = 2 *
        math.asin(math.sqrt(math.pow(math.sin(a / 2), 2) +
            math.cos(radLat1) *
                math.cos(radLat2) *
                math.pow(math.sin(b / 2), 2)));
    s = s * EARTH_RADIUS;
    return s * 1000;
  }

  static Widget getTextDistance(
      double? lat1, double? lng1, double? lat2, double? lng2) {
    if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) {
      return const SizedBox.shrink();
    }
    double dist = getDistance(lat1, lng1, lat2, lng2);
    if (dist > 100000) {
      return const SizedBox.shrink();
    } else {
      return Text(
        '${(dist / 1000).toStringAsFixed(2)}km',
        style: const TextStyle(color: Colors.black54, fontSize: 11),
        overflow: TextOverflow.ellipsis,
      );
    }
  }

  static Widget getWidgetDistance(
      double lat1, double lng1, double lat2, double lng2, String address) {
    if (lat2 <= 0) {
      return const SizedBox.shrink();
    }
    double dist = getDistance(lat1, lng1, lat2, lng2);
    if (dist > 100) {
      return const SizedBox.shrink();
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              address,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
          lat1 != 0 && lat1 != 0
              ? Expanded(
                  flex: 1,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${dist}km',
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
              : const SizedBox.shrink()
        ],
      );
    }
  }

  ///高德定位搜索https://restapi.amap.com/v5/place/text?parameters
  /// https://lbs.amap.com/api/webservice/guide/api/search
  static Future<Response> getAmapPoi(
    String location,
    String types,
    int page,
    int size,
  ) async {
    return await Dio()
        .get("https://restapi.amap.com/v5/place/around", queryParameters: {
      "key": AMAP_WEBS_KEY,
      "location": location,
      "types": types,
      "page_size": page.toString(),
      "page_num": size.toString()
    });
  }

  static Future<Response> getMapByKeyword(
    String keywords,
    String types,
    String region,
    bool cityLimit,
    int page,
    int size,
  ) async {
    return await Dio()
        .get("https://restapi.amap.com/v5/place/text", queryParameters: {
      "key": AMAP_WEBS_KEY,
      "keywords": keywords,
      "types": types,
      "region": region,
      "citylimit": cityLimit.toString(),
      "page_size": page.toString(),
      "page_num": size.toString()
    });
  }
}

const Map<String, String> provincesData = {
  "allCode": "全国",
  "110000": "北京",
  "120000": "天津",
  "130000": "河北",
  "140000": "山西",
  "150000": "内蒙古",
  "210000": "辽宁",
  "220000": "吉林",
  "230000": "黑龙江",
  "310000": "上海",
  "320000": "江苏",
  "330000": "浙江",
  "340000": "安徽",
  "350000": "福建",
  "360000": "江西",
  "370000": "山东",
  "410000": "河南",
  "420000": "湖北",
  "430000": "湖南",
  "440000": "广东",
  "450000": "广西",
  "460000": "海南",
  "500000": "重庆",
  "510000": "四川",
  "520000": "贵州",
  "530000": "云南",
  "540000": "西藏",
  "610000": "陕西",
  "620000": "甘肃",
  "630000": "青海",
  "640000": "宁夏",
  "650000": "新疆",
  "710000": "中国台湾",
  "810000": "中国香港",
  "820000": "中国澳门"
};

const Map<String, dynamic> citiesData = {
  "110000": {
    "110100": {"name": "北京", "alpha": "b"}
  },
  "120000": {
    "120100": {"name": "天津", "alpha": "t"}
  },
  "130000": {
    "130100": {"name": "石家庄", "alpha": "s"},
    "130200": {"name": "唐山", "alpha": "t"},
    "130300": {"name": "秦皇岛", "alpha": "q"},
    "130400": {"name": "邯郸", "alpha": "h"},
    "130500": {"name": "邢台", "alpha": "x"},
    "130600": {"name": "保定", "alpha": "b"},
    "130700": {"name": "张家口", "alpha": "z"},
    "130800": {"name": "承德", "alpha": "c"},
    "130900": {"name": "沧州", "alpha": "c"},
    "131000": {"name": "廊坊", "alpha": "l"},
    "131100": {"name": "衡水", "alpha": "h"}
  },
  "140000": {
    "140100": {"name": "太原", "alpha": "t"},
    "140200": {"name": "大同", "alpha": "d"},
    "140300": {"name": "阳泉", "alpha": "y"},
    "140400": {"name": "长治", "alpha": "c"},
    "140500": {"name": "晋城", "alpha": "j"},
    "140600": {"name": "朔州", "alpha": "s"},
    "140700": {"name": "晋中", "alpha": "j"},
    "140800": {"name": "运城", "alpha": "y"},
    "140900": {"name": "忻州", "alpha": "x"},
    "141000": {"name": "临汾", "alpha": "l"},
    "141100": {"name": "吕梁", "alpha": "l"}
  },
  "150000": {
    "150100": {"name": "呼和浩特", "alpha": "h"},
    "150200": {"name": "包头", "alpha": "b"},
    "150300": {"name": "乌海", "alpha": "w"},
    "150400": {"name": "赤峰", "alpha": "c"},
    "150500": {"name": "通辽", "alpha": "t"},
    "150600": {"name": "鄂尔多斯", "alpha": "e"},
    "150700": {"name": "呼伦贝尔", "alpha": "h"},
    "150800": {"name": "巴彦淖尔", "alpha": "b"},
    "150900": {"name": "乌兰察布", "alpha": "w"},
    "152200": {"name": "兴安盟", "alpha": "x"},
    "152500": {"name": "锡林郭勒盟", "alpha": "x"},
    "152900": {"name": "阿拉善盟", "alpha": "a"}
  },
  "210000": {
    "210100": {"name": "沈阳", "alpha": "s"},
    "210200": {"name": "大连", "alpha": "d"},
    "210300": {"name": "鞍山", "alpha": "a"},
    "210400": {"name": "抚顺", "alpha": "f"},
    "210500": {"name": "本溪", "alpha": "b"},
    "210600": {"name": "丹东", "alpha": "d"},
    "210700": {"name": "锦州", "alpha": "j"},
    "210800": {"name": "营口", "alpha": "y"},
    "210900": {"name": "阜新", "alpha": "f"},
    "211000": {"name": "辽阳", "alpha": "l"},
    "211100": {"name": "盘锦", "alpha": "p"},
    "211200": {"name": "铁岭", "alpha": "t"},
    "211300": {"name": "朝阳", "alpha": "c"},
    "211400": {"name": "葫芦岛", "alpha": "h"}
  },
  "220000": {
    "220100": {"name": "长春", "alpha": "c"},
    "220200": {"name": "吉林", "alpha": "j"},
    "220300": {"name": "四平", "alpha": "s"},
    "220400": {"name": "辽源", "alpha": "l"},
    "220500": {"name": "通化", "alpha": "t"},
    "220600": {"name": "白山", "alpha": "b"},
    "220700": {"name": "松原", "alpha": "s"},
    "220800": {"name": "白城", "alpha": "b"},
    "222400": {"name": "延边", "alpha": "y"}
  },
  "230000": {
    "230100": {"name": "哈尔滨", "alpha": "h"},
    "230200": {"name": "齐齐哈尔", "alpha": "q"},
    "230300": {"name": "鸡西", "alpha": "j"},
    "230400": {"name": "鹤岗", "alpha": "h"},
    "230500": {"name": "双鸭山", "alpha": "s"},
    "230600": {"name": "大庆", "alpha": "d"},
    "230700": {"name": "伊春", "alpha": "y"},
    "230800": {"name": "佳木斯", "alpha": "j"},
    "230900": {"name": "七台河", "alpha": "q"},
    "231000": {"name": "牡丹江", "alpha": "m"},
    "231100": {"name": "黑河", "alpha": "h"},
    "231200": {"name": "绥化", "alpha": "s"},
    "232700": {"name": "大兴安岭", "alpha": "d"}
  },
  "310000": {
    "310100": {"name": "上海", "alpha": "s"}
  },
  "320000": {
    "320100": {"name": "南京", "alpha": "n"},
    "320200": {"name": "无锡", "alpha": "w"},
    "320300": {"name": "徐州", "alpha": "x"},
    "320400": {"name": "常州", "alpha": "c"},
    "320500": {"name": "苏州", "alpha": "s"},
    "320600": {"name": "南通", "alpha": "n"},
    "320700": {"name": "连云港", "alpha": "l"},
    "320800": {"name": "淮安", "alpha": "h"},
    "320900": {"name": "盐城", "alpha": "y"},
    "321000": {"name": "扬州", "alpha": "y"},
    "321100": {"name": "镇江", "alpha": "z"},
    "321200": {"name": "泰州", "alpha": "t"},
    "321300": {"name": "宿迁", "alpha": "s"}
  },
  "330000": {
    "330100": {"name": "杭州", "alpha": "h"},
    "330200": {"name": "宁波", "alpha": "n"},
    "330300": {"name": "温州", "alpha": "w"},
    "330400": {"name": "嘉兴", "alpha": "j"},
    "330500": {"name": "湖州", "alpha": "h"},
    "330600": {"name": "绍兴", "alpha": "s"},
    "330700": {"name": "金华", "alpha": "j"},
    "330800": {"name": "衢州", "alpha": "q"},
    "330900": {"name": "舟山", "alpha": "z"},
    "331000": {"name": "台州", "alpha": "t"},
    "331100": {"name": "丽水", "alpha": "l"}
  },
  "340000": {
    "340100": {"name": "合肥", "alpha": "h"},
    "340200": {"name": "芜湖", "alpha": "w"},
    "340300": {"name": "蚌埠", "alpha": "b"},
    "340400": {"name": "淮南", "alpha": "h"},
    "340500": {"name": "马鞍山", "alpha": "m"},
    "340600": {"name": "淮北", "alpha": "h"},
    "340700": {"name": "铜陵", "alpha": "t"},
    "340800": {"name": "安庆", "alpha": "a"},
    "341000": {"name": "黄山", "alpha": "h"},
    "341100": {"name": "滁州", "alpha": "c"},
    "341200": {"name": "阜阳", "alpha": "f"},
    "341300": {"name": "宿州", "alpha": "s"},
    "341500": {"name": "六安", "alpha": "l"},
    "341600": {"name": "亳州", "alpha": "b"},
    "341700": {"name": "池州", "alpha": "c"},
    "341800": {"name": "宣城", "alpha": "x"}
  },
  "350000": {
    "350100": {"name": "福州", "alpha": "f"},
    "350200": {"name": "厦门", "alpha": "x"},
    "350300": {"name": "莆田", "alpha": "p"},
    "350400": {"name": "三明", "alpha": "s"},
    "350500": {"name": "泉州", "alpha": "q"},
    "350600": {"name": "漳州", "alpha": "z"},
    "350700": {"name": "南平", "alpha": "n"},
    "350800": {"name": "龙岩", "alpha": "l"},
    "350900": {"name": "宁德", "alpha": "n"}
  },
  "360000": {
    "360100": {"name": "南昌", "alpha": "n"},
    "360200": {"name": "景德镇", "alpha": "j"},
    "360300": {"name": "萍乡", "alpha": "p"},
    "360400": {"name": "九江", "alpha": "j"},
    "360500": {"name": "新余", "alpha": "x"},
    "360600": {"name": "鹰潭", "alpha": "y"},
    "360700": {"name": "赣州", "alpha": "g"},
    "360800": {"name": "吉安", "alpha": "j"},
    "360900": {"name": "宜春", "alpha": "y"},
    "361000": {"name": "抚州", "alpha": "f"},
    "361100": {"name": "上饶", "alpha": "s"}
  },
  "370000": {
    "370100": {"name": "济南", "alpha": "j"},
    "370200": {"name": "青岛", "alpha": "q"},
    "370300": {"name": "淄博", "alpha": "z"},
    "370400": {"name": "枣庄", "alpha": "z"},
    "370500": {"name": "东营", "alpha": "d"},
    "370600": {"name": "烟台", "alpha": "y"},
    "370700": {"name": "潍坊", "alpha": "w"},
    "370800": {"name": "济宁", "alpha": "j"},
    "370900": {"name": "泰安", "alpha": "t"},
    "371000": {"name": "威海", "alpha": "w"},
    "371100": {"name": "日照", "alpha": "r"},
    "371200": {"name": "莱芜", "alpha": "l"},
    "371300": {"name": "临沂", "alpha": "l"},
    "371400": {"name": "德州", "alpha": "d"},
    "371500": {"name": "聊城", "alpha": "l"},
    "371600": {"name": "滨州", "alpha": "b"},
    "371700": {"name": "菏泽", "alpha": "h"}
  },
  "410000": {
    "410100": {"name": "郑州", "alpha": "z"},
    "410200": {"name": "开封", "alpha": "k"},
    "410300": {"name": "洛阳", "alpha": "l"},
    "410400": {"name": "平顶山", "alpha": "p"},
    "410500": {"name": "安阳", "alpha": "a"},
    "410600": {"name": "鹤壁", "alpha": "h"},
    "410700": {"name": "新乡", "alpha": "x"},
    "410800": {"name": "焦作", "alpha": "j"},
    "410900": {"name": "濮阳", "alpha": "p"},
    "411000": {"name": "许昌", "alpha": "x"},
    "411100": {"name": "漯河", "alpha": "l"},
    "411200": {"name": "三门峡", "alpha": "s"},
    "411300": {"name": "南阳", "alpha": "n"},
    "411400": {"name": "商丘", "alpha": "s"},
    "411500": {"name": "信阳", "alpha": "x"},
    "411600": {"name": "周口", "alpha": "z"},
    "411700": {"name": "驻马店", "alpha": "z"},
    "419000": {"name": "直辖县级行政区划", "alpha": "s"}
  },
  "420000": {
    "420100": {"name": "武汉", "alpha": "w"},
    "420200": {"name": "黄石", "alpha": "h"},
    "420300": {"name": "十堰", "alpha": "s"},
    "420500": {"name": "宜昌", "alpha": "y"},
    "420600": {"name": "襄阳", "alpha": "x"},
    "420700": {"name": "鄂州", "alpha": "e"},
    "420800": {"name": "荆门", "alpha": "j"},
    "420900": {"name": "孝感", "alpha": "x"},
    "421000": {"name": "荆州", "alpha": "j"},
    "421100": {"name": "黄冈", "alpha": "h"},
    "421200": {"name": "咸宁", "alpha": "x"},
    "421300": {"name": "随州", "alpha": "s"},
    "422800": {"name": "恩施土家族苗族自治州", "alpha": "e"},
    "429000": {"name": "直辖县级行政区划", "alpha": "s"}
  },
  "430000": {
    "430100": {"name": "长沙", "alpha": "c"},
    "430200": {"name": "株洲", "alpha": "z"},
    "430300": {"name": "湘潭", "alpha": "x"},
    "430400": {"name": "衡阳", "alpha": "h"},
    "430500": {"name": "邵阳", "alpha": "s"},
    "430600": {"name": "岳阳", "alpha": "y"},
    "430700": {"name": "常德", "alpha": "c"},
    "430800": {"name": "张家界", "alpha": "z"},
    "430900": {"name": "益阳", "alpha": "y"},
    "431000": {"name": "郴州", "alpha": "c"},
    "431100": {"name": "永州", "alpha": "y"},
    "431200": {"name": "怀化", "alpha": "h"},
    "431300": {"name": "娄底", "alpha": "l"},
    "433100": {"name": "湘西土家族苗族自治州", "alpha": "x"}
  },
  "440000": {
    "440100": {"name": "广州", "alpha": "g"},
    "440200": {"name": "韶关", "alpha": "s"},
    "440300": {"name": "深圳", "alpha": "s"},
    "440400": {"name": "珠海", "alpha": "z"},
    "440500": {"name": "汕头", "alpha": "s"},
    "440600": {"name": "佛山", "alpha": "f"},
    "440700": {"name": "江门", "alpha": "j"},
    "440800": {"name": "湛江", "alpha": "z"},
    "440900": {"name": "茂名", "alpha": "m"},
    "441200": {"name": "肇庆", "alpha": "z"},
    "441300": {"name": "惠州", "alpha": "h"},
    "441400": {"name": "梅州", "alpha": "m"},
    "441500": {"name": "汕尾", "alpha": "s"},
    "441600": {"name": "河源", "alpha": "h"},
    "441700": {"name": "阳江", "alpha": "y"},
    "441800": {"name": "清远", "alpha": "q"},
    "441900": {"name": "东莞", "alpha": "d"},
    "442000": {"name": "中山", "alpha": "z"},
    "445100": {"name": "潮州", "alpha": "c"},
    "445200": {"name": "揭阳", "alpha": "j"},
    "445300": {"name": "云浮", "alpha": "y"}
  },
  "450000": {
    "450100": {"name": "南宁", "alpha": "n"},
    "450200": {"name": "柳州", "alpha": "l"},
    "450300": {"name": "桂林", "alpha": "g"},
    "450400": {"name": "梧州", "alpha": "w"},
    "450500": {"name": "北海", "alpha": "b"},
    "450600": {"name": "防城港", "alpha": "f"},
    "450700": {"name": "钦州", "alpha": "q"},
    "450800": {"name": "贵港", "alpha": "g"},
    "450900": {"name": "玉林", "alpha": "y"},
    "451000": {"name": "百色", "alpha": "b"},
    "451100": {"name": "贺州", "alpha": "h"},
    "451200": {"name": "河池", "alpha": "h"},
    "451300": {"name": "来宾", "alpha": "l"},
    "451400": {"name": "崇左", "alpha": "c"}
  },
  "460000": {
    "460100": {"name": "海口", "alpha": "h"},
    "460200": {"name": "三亚", "alpha": "s"},
    "460300": {"name": "三沙", "alpha": "s"},
    "460400": {"name": "儋州", "alpha": "d"},
    "469000": {"name": "直辖县级行政区划", "alpha": "s"}
  },
  "500000": {
    "500100": {"name": "重庆市", "alpha": "s"},
    "500200": {"name": "县", "alpha": "x"}
  },
  "510000": {
    "510100": {"name": "成都", "alpha": "c"},
    "510300": {"name": "自贡", "alpha": "z"},
    "510400": {"name": "攀枝花", "alpha": "p"},
    "510500": {"name": "泸州", "alpha": "l"},
    "510600": {"name": "德阳", "alpha": "d"},
    "510700": {"name": "绵阳", "alpha": "m"},
    "510800": {"name": "广元", "alpha": "g"},
    "510900": {"name": "遂宁", "alpha": "s"},
    "511000": {"name": "内江", "alpha": "n"},
    "511100": {"name": "乐山", "alpha": "l"},
    "511300": {"name": "南充", "alpha": "n"},
    "511400": {"name": "眉山", "alpha": "m"},
    "511500": {"name": "宜宾", "alpha": "y"},
    "511600": {"name": "广安", "alpha": "g"},
    "511700": {"name": "达州", "alpha": "d"},
    "511800": {"name": "雅安", "alpha": "y"},
    "511900": {"name": "巴中", "alpha": "b"},
    "512000": {"name": "资阳", "alpha": "z"},
    "513200": {"name": "阿坝藏族羌族自治州", "alpha": "a"},
    "513300": {"name": "甘孜藏族自治州", "alpha": "g"},
    "513400": {"name": "凉山彝族自治州", "alpha": "l"}
  },
  "520000": {
    "520100": {"name": "贵阳", "alpha": "g"},
    "520200": {"name": "六盘水", "alpha": "l"},
    "520300": {"name": "遵义", "alpha": "z"},
    "520400": {"name": "安顺", "alpha": "a"},
    "520500": {"name": "毕节", "alpha": "b"},
    "520600": {"name": "铜仁", "alpha": "t"},
    "522300": {"name": "黔西南布依族苗族自治州", "alpha": "q"},
    "522600": {"name": "黔东南苗族侗族自治州", "alpha": "q"},
    "522700": {"name": "黔南布依族苗族自治州", "alpha": "q"}
  },
  "530000": {
    "530100": {"name": "昆明", "alpha": "k"},
    "530300": {"name": "曲靖", "alpha": "q"},
    "530400": {"name": "玉溪", "alpha": "y"},
    "530500": {"name": "保山", "alpha": "b"},
    "530600": {"name": "昭通", "alpha": "z"},
    "530700": {"name": "丽江", "alpha": "l"},
    "530800": {"name": "普洱", "alpha": "p"},
    "530900": {"name": "临沧", "alpha": "l"},
    "532300": {"name": "楚雄彝族自治州", "alpha": "c"},
    "532500": {"name": "红河哈尼族彝族自治州", "alpha": "h"},
    "532600": {"name": "文山壮族苗族自治州", "alpha": "w"},
    "532800": {"name": "西双版纳傣族自治州", "alpha": "x"},
    "532900": {"name": "大理白族自治州", "alpha": "d"},
    "533100": {"name": "德宏傣族景颇族自治州", "alpha": "d"},
    "533300": {"name": "怒江傈僳族自治州", "alpha": "n"},
    "533400": {"name": "迪庆藏族自治州", "alpha": "d"}
  },
  "540000": {
    "540100": {"name": "拉萨", "alpha": "l"},
    "540200": {"name": "日喀则", "alpha": "r"},
    "540300": {"name": "昌都", "alpha": "c"},
    "540400": {"name": "林芝", "alpha": "l"},
    "540500": {"name": "山南", "alpha": "s"},
    "540600": {"name": "那曲", "alpha": "n"},
    "542500": {"name": "阿里地区", "alpha": "a"}
  },
  "610000": {
    "610100": {"name": "西安", "alpha": "x"},
    "610200": {"name": "铜川", "alpha": "t"},
    "610300": {"name": "宝鸡", "alpha": "b"},
    "610400": {"name": "咸阳", "alpha": "x"},
    "610500": {"name": "渭南", "alpha": "w"},
    "610600": {"name": "延安", "alpha": "y"},
    "610700": {"name": "汉中", "alpha": "h"},
    "610800": {"name": "榆林", "alpha": "y"},
    "610900": {"name": "安康", "alpha": "a"},
    "611000": {"name": "商洛", "alpha": "s"}
  },
  "620000": {
    "620100": {"name": "兰州", "alpha": "l"},
    "620200": {"name": "嘉峪关", "alpha": "j"},
    "620300": {"name": "金昌", "alpha": "j"},
    "620400": {"name": "白银", "alpha": "b"},
    "620500": {"name": "天水", "alpha": "t"},
    "620600": {"name": "武威", "alpha": "w"},
    "620700": {"name": "张掖", "alpha": "z"},
    "620800": {"name": "平凉", "alpha": "p"},
    "620900": {"name": "酒泉", "alpha": "j"},
    "621000": {"name": "庆阳", "alpha": "q"},
    "621100": {"name": "定西", "alpha": "d"},
    "621200": {"name": "陇南", "alpha": "l"},
    "622900": {"name": "临夏回族自治州", "alpha": "l"},
    "623000": {"name": "甘南藏族自治州", "alpha": "g"}
  },
  "630000": {
    "630100": {"name": "西宁", "alpha": "x"},
    "630200": {"name": "海东", "alpha": "h"},
    "632200": {"name": "海北藏族自治州", "alpha": "h"},
    "632300": {"name": "黄南藏族自治州", "alpha": "h"},
    "632500": {"name": "海南藏族自治州", "alpha": "h"},
    "632600": {"name": "果洛藏族自治州", "alpha": "g"},
    "632700": {"name": "玉树藏族自治州", "alpha": "y"},
    "632800": {"name": "海西蒙古族藏族自治州", "alpha": "h"}
  },
  "640000": {
    "640100": {"name": "银川", "alpha": "y"},
    "640200": {"name": "石嘴山", "alpha": "s"},
    "640300": {"name": "吴忠", "alpha": "w"},
    "640400": {"name": "固原", "alpha": "g"},
    "640500": {"name": "中卫", "alpha": "z"}
  },
  "650000": {
    "650100": {"name": "乌鲁木齐", "alpha": "w"},
    "650200": {"name": "克拉玛依", "alpha": "k"},
    "650400": {"name": "吐鲁番", "alpha": "t"},
    "650500": {"name": "哈密", "alpha": "h"},
    "652300": {"name": "昌吉回族自治州", "alpha": "c"},
    "652700": {"name": "博尔塔拉蒙古自治州", "alpha": "b"},
    "652800": {"name": "巴音郭楞蒙古自治州", "alpha": "b"},
    "652900": {"name": "阿克苏地区", "alpha": "a"},
    "653000": {"name": "克孜勒苏柯尔克孜自治州", "alpha": "k"},
    "653100": {"name": "喀什地区", "alpha": "k"},
    "653200": {"name": "和田地区", "alpha": "h"},
    "654000": {"name": "伊犁哈萨克自治州", "alpha": "y"},
    "654200": {"name": "塔城地区", "alpha": "t"},
    "654300": {"name": "阿勒泰地区", "alpha": "a"},
    "659000": {"name": "自治区直辖县级行政区划", "alpha": "z"}
  },
  "710000": {
    // "710100": {"name": "台北", "alpha": "t"},
    // "710200": {"name": "高雄", "alpha": "g"},
    // "710300": {"name": "基隆", "alpha": "t"},
    // "710400": {"name": "台中", "alpha": "t"},
    // "710500": {"name": "台南", "alpha": "t"},
    // "710600": {"name": "新竹", "alpha": "t"},
    // "710700": {"name": "嘉义", "alpha": "t"},
    // "710800": {"name": "新北", "alpha": "t"},
    // "710900": {"name": "桃园", "alpha": "t"},
    "710000": {"name": "中国台湾", "alpha": "t"}
  },
  "810000": {
    "810100": {"name": "中国香港", "alpha": "x"}
  },
  "820000": {
    "820100": {"name": "中国澳门", "alpha": "a"}
  },
};

const Map<String, dynamic> regionData = {
  "110100": {
    "110101": {"name": "东城区", "alpha": "d"},
    "110102": {"name": "西城区", "alpha": "x"},
    "110105": {"name": "朝阳区", "alpha": "c"},
    "110106": {"name": "丰台区", "alpha": "f"},
    "110107": {"name": "石景山区", "alpha": "s"},
    "110108": {"name": "海淀区", "alpha": "h"},
    "110109": {"name": "门头沟区", "alpha": "m"},
    "110111": {"name": "房山区", "alpha": "f"},
    "110112": {"name": "通州区", "alpha": "t"},
    "110113": {"name": "顺义区", "alpha": "s"},
    "110114": {"name": "昌平区", "alpha": "c"},
    "110115": {"name": "大兴区", "alpha": "d"},
    "110116": {"name": "怀柔区", "alpha": "h"},
    "110117": {"name": "平谷区", "alpha": "p"},
    "110118": {"name": "密云区", "alpha": "m"},
    "110119": {"name": "延庆区", "alpha": "y"}
  },
  "120100": {
    "120101": {"name": "和平区", "alpha": "h"},
    "120102": {"name": "河东区", "alpha": "h"},
    "120103": {"name": "河西区", "alpha": "h"},
    "120104": {"name": "南开区", "alpha": "n"},
    "120105": {"name": "河北区", "alpha": "h"},
    "120106": {"name": "红桥区", "alpha": "h"},
    "120110": {"name": "东丽区", "alpha": "d"},
    "120111": {"name": "西青区", "alpha": "x"},
    "120112": {"name": "津南区", "alpha": "j"},
    "120113": {"name": "北辰区", "alpha": "b"},
    "120114": {"name": "武清区", "alpha": "w"},
    "120115": {"name": "宝坻区", "alpha": "b"},
    "120116": {"name": "滨海新区", "alpha": "b"},
    "120117": {"name": "宁河区", "alpha": "n"},
    "120118": {"name": "静海区", "alpha": "j"},
    "120119": {"name": "蓟州区", "alpha": "j"}
  },
  "130100": {
    "130102": {"name": "长安区", "alpha": "c"},
    "130104": {"name": "桥西区", "alpha": "q"},
    "130105": {"name": "新华区", "alpha": "x"},
    "130107": {"name": "井陉矿区", "alpha": "j"},
    "130108": {"name": "裕华区", "alpha": "y"},
    "130109": {"name": "藁城区", "alpha": "g"},
    "130110": {"name": "鹿泉区", "alpha": "l"},
    "130111": {"name": "栾城区", "alpha": "l"},
    "130121": {"name": "井陉县", "alpha": "j"},
    "130123": {"name": "正定县", "alpha": "z"},
    "130125": {"name": "行唐县", "alpha": "x"},
    "130126": {"name": "灵寿县", "alpha": "l"},
    "130127": {"name": "高邑县", "alpha": "g"},
    "130128": {"name": "深泽县", "alpha": "s"},
    "130129": {"name": "赞皇县", "alpha": "z"},
    "130130": {"name": "无极县", "alpha": "w"},
    "130131": {"name": "平山县", "alpha": "p"},
    "130132": {"name": "元氏县", "alpha": "y"},
    "130133": {"name": "赵县", "alpha": "z"},
    "130171": {"name": "石家庄高新技术产业开发区", "alpha": "s"},
    "130172": {"name": "石家庄循环化工园区", "alpha": "s"},
    "130181": {"name": "辛集", "alpha": "x"},
    "130183": {"name": "晋州", "alpha": "j"},
    "130184": {"name": "新乐", "alpha": "x"}
  },
  "130200": {
    "130202": {"name": "路南区", "alpha": "l"},
    "130203": {"name": "路北区", "alpha": "l"},
    "130204": {"name": "古冶区", "alpha": "g"},
    "130205": {"name": "开平区", "alpha": "k"},
    "130207": {"name": "丰南区", "alpha": "f"},
    "130208": {"name": "丰润区", "alpha": "f"},
    "130209": {"name": "曹妃甸区", "alpha": "c"},
    "130224": {"name": "滦南县", "alpha": "l"},
    "130225": {"name": "乐亭县", "alpha": "l"},
    "130227": {"name": "迁西县", "alpha": "q"},
    "130229": {"name": "玉田县", "alpha": "y"},
    "130271": {"name": "唐山芦台经济技术开发区", "alpha": "t"},
    "130272": {"name": "唐山汉沽管理区", "alpha": "t"},
    "130273": {"name": "唐山高新技术产业开发区", "alpha": "t"},
    "130274": {"name": "河北唐山海港经济开发区", "alpha": "h"},
    "130281": {"name": "遵化", "alpha": "z"},
    "130283": {"name": "迁安", "alpha": "q"},
    "130284": {"name": "滦州", "alpha": "l"}
  },
  "130300": {
    "130302": {"name": "海港区", "alpha": "h"},
    "130303": {"name": "山海关区", "alpha": "s"},
    "130304": {"name": "北戴河区", "alpha": "b"},
    "130306": {"name": "抚宁区", "alpha": "f"},
    "130321": {"name": "青龙满族自治县", "alpha": "q"},
    "130322": {"name": "昌黎县", "alpha": "c"},
    "130324": {"name": "卢龙县", "alpha": "l"},
    "130371": {"name": "秦皇岛经济技术开发区", "alpha": "q"},
    "130372": {"name": "北戴河新区", "alpha": "b"}
  },
  "130400": {
    "130402": {"name": "邯山区", "alpha": "h"},
    "130403": {"name": "丛台区", "alpha": "c"},
    "130404": {"name": "复兴区", "alpha": "f"},
    "130406": {"name": "峰峰矿区", "alpha": "f"},
    "130407": {"name": "肥乡区", "alpha": "f"},
    "130408": {"name": "永年区", "alpha": "y"},
    "130423": {"name": "临漳县", "alpha": "l"},
    "130424": {"name": "成安县", "alpha": "c"},
    "130425": {"name": "大名县", "alpha": "d"},
    "130426": {"name": "涉县", "alpha": "s"},
    "130427": {"name": "磁县", "alpha": "c"},
    "130430": {"name": "邱县", "alpha": "q"},
    "130431": {"name": "鸡泽县", "alpha": "j"},
    "130432": {"name": "广平县", "alpha": "g"},
    "130433": {"name": "馆陶县", "alpha": "g"},
    "130434": {"name": "魏县", "alpha": "w"},
    "130435": {"name": "曲周县", "alpha": "q"},
    "130471": {"name": "邯郸经济技术开发区", "alpha": "h"},
    "130473": {"name": "邯郸冀南新区", "alpha": "h"},
    "130481": {"name": "武安", "alpha": "w"}
  },
  "130500": {
    "130502": {"name": "桥东区", "alpha": "q"},
    "130503": {"name": "桥西区", "alpha": "q"},
    "130521": {"name": "邢台县", "alpha": "x"},
    "130522": {"name": "临城县", "alpha": "l"},
    "130523": {"name": "内丘县", "alpha": "n"},
    "130524": {"name": "柏乡县", "alpha": "b"},
    "130525": {"name": "隆尧县", "alpha": "l"},
    "130526": {"name": "任县", "alpha": "r"},
    "130527": {"name": "南和县", "alpha": "n"},
    "130528": {"name": "宁晋县", "alpha": "n"},
    "130529": {"name": "巨鹿县", "alpha": "j"},
    "130530": {"name": "新河县", "alpha": "x"},
    "130531": {"name": "广宗县", "alpha": "g"},
    "130532": {"name": "平乡县", "alpha": "p"},
    "130533": {"name": "威县", "alpha": "w"},
    "130534": {"name": "清河县", "alpha": "q"},
    "130535": {"name": "临西县", "alpha": "l"},
    "130571": {"name": "河北邢台经济开发区", "alpha": "h"},
    "130581": {"name": "南宫", "alpha": "n"},
    "130582": {"name": "沙河", "alpha": "s"}
  },
  "130600": {
    "130602": {"name": "竞秀区", "alpha": "j"},
    "130606": {"name": "莲池区", "alpha": "l"},
    "130607": {"name": "满城区", "alpha": "m"},
    "130608": {"name": "清苑区", "alpha": "q"},
    "130609": {"name": "徐水区", "alpha": "x"},
    "130623": {"name": "涞水县", "alpha": "l"},
    "130624": {"name": "阜平县", "alpha": "f"},
    "130626": {"name": "定兴县", "alpha": "d"},
    "130627": {"name": "唐县", "alpha": "t"},
    "130628": {"name": "高阳县", "alpha": "g"},
    "130629": {"name": "容城县", "alpha": "r"},
    "130630": {"name": "涞源县", "alpha": "l"},
    "130631": {"name": "望都县", "alpha": "w"},
    "130632": {"name": "安新县", "alpha": "a"},
    "130633": {"name": "易县", "alpha": "y"},
    "130634": {"name": "曲阳县", "alpha": "q"},
    "130635": {"name": "蠡县", "alpha": "l"},
    "130636": {"name": "顺平县", "alpha": "s"},
    "130637": {"name": "博野县", "alpha": "b"},
    "130638": {"name": "雄县", "alpha": "x"},
    "130671": {"name": "保定高新技术产业开发区", "alpha": "b"},
    "130672": {"name": "保定白沟新城", "alpha": "b"},
    "130681": {"name": "涿州", "alpha": "z"},
    "130682": {"name": "定州", "alpha": "d"},
    "130683": {"name": "安国", "alpha": "a"},
    "130684": {"name": "高碑店", "alpha": "g"}
  },
  "130700": {
    "130702": {"name": "桥东区", "alpha": "q"},
    "130703": {"name": "桥西区", "alpha": "q"},
    "130705": {"name": "宣化区", "alpha": "x"},
    "130706": {"name": "下花园区", "alpha": "x"},
    "130708": {"name": "万全区", "alpha": "w"},
    "130709": {"name": "崇礼区", "alpha": "c"},
    "130722": {"name": "张北县", "alpha": "z"},
    "130723": {"name": "康保县", "alpha": "k"},
    "130724": {"name": "沽源县", "alpha": "g"},
    "130725": {"name": "尚义县", "alpha": "s"},
    "130726": {"name": "蔚县", "alpha": "y"},
    "130727": {"name": "阳原县", "alpha": "y"},
    "130728": {"name": "怀安县", "alpha": "h"},
    "130730": {"name": "怀来县", "alpha": "h"},
    "130731": {"name": "涿鹿县", "alpha": "z"},
    "130732": {"name": "赤城县", "alpha": "c"},
    "130771": {"name": "张家口高新技术产业开发区", "alpha": "z"},
    "130772": {"name": "张家口察北管理区", "alpha": "z"},
    "130773": {"name": "张家口塞北管理区", "alpha": "z"}
  },
  "130800": {
    "130802": {"name": "双桥区", "alpha": "s"},
    "130803": {"name": "双滦区", "alpha": "s"},
    "130804": {"name": "鹰手营子矿区", "alpha": "y"},
    "130821": {"name": "承德县", "alpha": "c"},
    "130822": {"name": "兴隆县", "alpha": "x"},
    "130824": {"name": "滦平县", "alpha": "l"},
    "130825": {"name": "隆化县", "alpha": "l"},
    "130826": {"name": "丰宁满族自治县", "alpha": "f"},
    "130827": {"name": "宽城满族自治县", "alpha": "k"},
    "130828": {"name": "围场满族蒙古族自治县", "alpha": "w"},
    "130871": {"name": "承德高新技术产业开发区", "alpha": "c"},
    "130881": {"name": "平泉", "alpha": "p"}
  },
  "130900": {
    "130902": {"name": "新华区", "alpha": "x"},
    "130903": {"name": "运河区", "alpha": "y"},
    "130921": {"name": "沧县", "alpha": "c"},
    "130922": {"name": "青县", "alpha": "q"},
    "130923": {"name": "东光县", "alpha": "d"},
    "130924": {"name": "海兴县", "alpha": "h"},
    "130925": {"name": "盐山县", "alpha": "y"},
    "130926": {"name": "肃宁县", "alpha": "s"},
    "130927": {"name": "南皮县", "alpha": "n"},
    "130928": {"name": "吴桥县", "alpha": "w"},
    "130929": {"name": "献县", "alpha": "x"},
    "130930": {"name": "孟村回族自治县", "alpha": "m"},
    "130971": {"name": "河北沧州经济开发区", "alpha": "h"},
    "130972": {"name": "沧州高新技术产业开发区", "alpha": "c"},
    "130973": {"name": "沧州渤海新区", "alpha": "c"},
    "130981": {"name": "泊头", "alpha": "b"},
    "130982": {"name": "任丘", "alpha": "r"},
    "130983": {"name": "黄骅", "alpha": "h"},
    "130984": {"name": "河间", "alpha": "h"}
  },
  "131000": {
    "131002": {"name": "安次区", "alpha": "a"},
    "131003": {"name": "广阳区", "alpha": "g"},
    "131022": {"name": "固安县", "alpha": "g"},
    "131023": {"name": "永清县", "alpha": "y"},
    "131024": {"name": "香河县", "alpha": "x"},
    "131025": {"name": "大城县", "alpha": "d"},
    "131026": {"name": "文安县", "alpha": "w"},
    "131028": {"name": "大厂回族自治县", "alpha": "d"},
    "131071": {"name": "廊坊经济技术开发区", "alpha": "l"},
    "131081": {"name": "霸州", "alpha": "b"},
    "131082": {"name": "三河", "alpha": "s"}
  },
  "131100": {
    "131102": {"name": "桃城区", "alpha": "t"},
    "131103": {"name": "冀州区", "alpha": "j"},
    "131121": {"name": "枣强县", "alpha": "z"},
    "131122": {"name": "武邑县", "alpha": "w"},
    "131123": {"name": "武强县", "alpha": "w"},
    "131124": {"name": "饶阳县", "alpha": "r"},
    "131125": {"name": "安平县", "alpha": "a"},
    "131126": {"name": "故城县", "alpha": "g"},
    "131127": {"name": "景县", "alpha": "j"},
    "131128": {"name": "阜城县", "alpha": "f"},
    "131171": {"name": "河北衡水高新技术产业开发区", "alpha": "h"},
    "131172": {"name": "衡水滨湖新区", "alpha": "h"},
    "131182": {"name": "深州", "alpha": "s"}
  },
  "140100": {
    "140105": {"name": "小店区", "alpha": "x"},
    "140106": {"name": "迎泽区", "alpha": "y"},
    "140107": {"name": "杏花岭区", "alpha": "x"},
    "140108": {"name": "尖草坪区", "alpha": "j"},
    "140109": {"name": "万柏林区", "alpha": "w"},
    "140110": {"name": "晋源区", "alpha": "j"},
    "140121": {"name": "清徐县", "alpha": "q"},
    "140122": {"name": "阳曲县", "alpha": "y"},
    "140123": {"name": "娄烦县", "alpha": "l"},
    "140171": {"name": "山西转型综合改革示范区", "alpha": "s"},
    "140181": {"name": "古交", "alpha": "g"}
  },
  "140200": {
    "140212": {"name": "新荣区", "alpha": "x"},
    "140213": {"name": "平城区", "alpha": "p"},
    "140214": {"name": "云冈区", "alpha": "y"},
    "140215": {"name": "云州区", "alpha": "y"},
    "140221": {"name": "阳高县", "alpha": "y"},
    "140222": {"name": "天镇县", "alpha": "t"},
    "140223": {"name": "广灵县", "alpha": "g"},
    "140224": {"name": "灵丘县", "alpha": "l"},
    "140225": {"name": "浑源县", "alpha": "h"},
    "140226": {"name": "左云县", "alpha": "z"},
    "140271": {"name": "山西大同经济开发区", "alpha": "s"}
  },
  "140300": {
    "140302": {"name": "城区", "alpha": "c"},
    "140303": {"name": "矿区", "alpha": "k"},
    "140311": {"name": "郊区", "alpha": "j"},
    "140321": {"name": "平定县", "alpha": "p"},
    "140322": {"name": "盂县", "alpha": "y"}
  },
  "140400": {
    "140403": {"name": "潞州区", "alpha": "l"},
    "140404": {"name": "上党区", "alpha": "s"},
    "140405": {"name": "屯留区", "alpha": "t"},
    "140406": {"name": "潞城区", "alpha": "l"},
    "140423": {"name": "襄垣县", "alpha": "x"},
    "140425": {"name": "平顺县", "alpha": "p"},
    "140426": {"name": "黎城县", "alpha": "l"},
    "140427": {"name": "壶关县", "alpha": "h"},
    "140428": {"name": "长子县", "alpha": "c"},
    "140429": {"name": "武乡县", "alpha": "w"},
    "140430": {"name": "沁县", "alpha": "q"},
    "140431": {"name": "沁源县", "alpha": "q"},
    "140471": {"name": "山西长治高新技术产业园区", "alpha": "s"}
  },
  "140500": {
    "140502": {"name": "城区", "alpha": "c"},
    "140521": {"name": "沁水县", "alpha": "q"},
    "140522": {"name": "阳城县", "alpha": "y"},
    "140524": {"name": "陵川县", "alpha": "l"},
    "140525": {"name": "泽州县", "alpha": "z"},
    "140581": {"name": "高平", "alpha": "g"}
  },
  "140600": {
    "140602": {"name": "朔城区", "alpha": "s"},
    "140603": {"name": "平鲁区", "alpha": "p"},
    "140621": {"name": "山阴县", "alpha": "s"},
    "140622": {"name": "应县", "alpha": "y"},
    "140623": {"name": "右玉县", "alpha": "y"},
    "140671": {"name": "山西朔州经济开发区", "alpha": "s"},
    "140681": {"name": "怀仁", "alpha": "h"}
  },
  "140700": {
    "140702": {"name": "榆次区", "alpha": "y"},
    "140721": {"name": "榆社县", "alpha": "y"},
    "140722": {"name": "左权县", "alpha": "z"},
    "140723": {"name": "和顺县", "alpha": "h"},
    "140724": {"name": "昔阳县", "alpha": "x"},
    "140725": {"name": "寿阳县", "alpha": "s"},
    "140726": {"name": "太谷县", "alpha": "t"},
    "140727": {"name": "祁县", "alpha": "q"},
    "140728": {"name": "平遥县", "alpha": "p"},
    "140729": {"name": "灵石县", "alpha": "l"},
    "140781": {"name": "介休", "alpha": "j"}
  },
  "140800": {
    "140802": {"name": "盐湖区", "alpha": "y"},
    "140821": {"name": "临猗县", "alpha": "l"},
    "140822": {"name": "万荣县", "alpha": "w"},
    "140823": {"name": "闻喜县", "alpha": "w"},
    "140824": {"name": "稷山县", "alpha": "j"},
    "140825": {"name": "新绛县", "alpha": "x"},
    "140826": {"name": "绛县", "alpha": "j"},
    "140827": {"name": "垣曲县", "alpha": "y"},
    "140828": {"name": "夏县", "alpha": "x"},
    "140829": {"name": "平陆县", "alpha": "p"},
    "140830": {"name": "芮城县", "alpha": "r"},
    "140881": {"name": "永济", "alpha": "y"},
    "140882": {"name": "河津", "alpha": "h"}
  },
  "140900": {
    "140902": {"name": "忻府区", "alpha": "x"},
    "140921": {"name": "定襄县", "alpha": "d"},
    "140922": {"name": "五台县", "alpha": "w"},
    "140923": {"name": "代县", "alpha": "d"},
    "140924": {"name": "繁峙县", "alpha": "f"},
    "140925": {"name": "宁武县", "alpha": "n"},
    "140926": {"name": "静乐县", "alpha": "j"},
    "140927": {"name": "神池县", "alpha": "s"},
    "140928": {"name": "五寨县", "alpha": "w"},
    "140929": {"name": "岢岚县", "alpha": "k"},
    "140930": {"name": "河曲县", "alpha": "h"},
    "140931": {"name": "保德县", "alpha": "b"},
    "140932": {"name": "偏关县", "alpha": "p"},
    "140971": {"name": "五台山风景名胜区", "alpha": "w"},
    "140981": {"name": "原平", "alpha": "y"}
  },
  "141000": {
    "141002": {"name": "尧都区", "alpha": "y"},
    "141021": {"name": "曲沃县", "alpha": "q"},
    "141022": {"name": "翼城县", "alpha": "y"},
    "141023": {"name": "襄汾县", "alpha": "x"},
    "141024": {"name": "洪洞县", "alpha": "h"},
    "141025": {"name": "古县", "alpha": "g"},
    "141026": {"name": "安泽县", "alpha": "a"},
    "141027": {"name": "浮山县", "alpha": "f"},
    "141028": {"name": "吉县", "alpha": "j"},
    "141029": {"name": "乡宁县", "alpha": "x"},
    "141030": {"name": "大宁县", "alpha": "d"},
    "141031": {"name": "隰县", "alpha": "x"},
    "141032": {"name": "永和县", "alpha": "y"},
    "141033": {"name": "蒲县", "alpha": "p"},
    "141034": {"name": "汾西县", "alpha": "f"},
    "141081": {"name": "侯马", "alpha": "h"},
    "141082": {"name": "霍州", "alpha": "h"}
  },
  "141100": {
    "141102": {"name": "离石区", "alpha": "l"},
    "141121": {"name": "文水县", "alpha": "w"},
    "141122": {"name": "交城县", "alpha": "j"},
    "141123": {"name": "兴县", "alpha": "x"},
    "141124": {"name": "临县", "alpha": "l"},
    "141125": {"name": "柳林县", "alpha": "l"},
    "141126": {"name": "石楼县", "alpha": "s"},
    "141127": {"name": "岚县", "alpha": "l"},
    "141128": {"name": "方山县", "alpha": "f"},
    "141129": {"name": "中阳县", "alpha": "z"},
    "141130": {"name": "交口县", "alpha": "j"},
    "141181": {"name": "孝义", "alpha": "x"},
    "141182": {"name": "汾阳", "alpha": "f"}
  },
  "150100": {
    "150102": {"name": "新城区", "alpha": "x"},
    "150103": {"name": "回民区", "alpha": "h"},
    "150104": {"name": "玉泉区", "alpha": "y"},
    "150105": {"name": "赛罕区", "alpha": "s"},
    "150121": {"name": "土默特左旗", "alpha": "t"},
    "150122": {"name": "托克托县", "alpha": "t"},
    "150123": {"name": "和林格尔县", "alpha": "h"},
    "150124": {"name": "清水河县", "alpha": "q"},
    "150125": {"name": "武川县", "alpha": "w"},
    "150171": {"name": "呼和浩特金海工业园区", "alpha": "h"},
    "150172": {"name": "呼和浩特经济技术开发区", "alpha": "h"}
  },
  "150200": {
    "150202": {"name": "东河区", "alpha": "d"},
    "150203": {"name": "昆都仑区", "alpha": "k"},
    "150204": {"name": "青山区", "alpha": "q"},
    "150205": {"name": "石拐区", "alpha": "s"},
    "150206": {"name": "白云鄂博矿区", "alpha": "b"},
    "150207": {"name": "九原区", "alpha": "j"},
    "150221": {"name": "土默特右旗", "alpha": "t"},
    "150222": {"name": "固阳县", "alpha": "g"},
    "150223": {"name": "达尔罕茂明安联合旗", "alpha": "d"},
    "150271": {"name": "包头稀土高新技术产业开发区", "alpha": "b"}
  },
  "150300": {
    "150302": {"name": "海勃湾区", "alpha": "h"},
    "150303": {"name": "海南区", "alpha": "h"},
    "150304": {"name": "乌达区", "alpha": "w"}
  },
  "150400": {
    "150402": {"name": "红山区", "alpha": "h"},
    "150403": {"name": "元宝山区", "alpha": "y"},
    "150404": {"name": "松山区", "alpha": "s"},
    "150421": {"name": "阿鲁科尔沁旗", "alpha": "a"},
    "150422": {"name": "巴林左旗", "alpha": "b"},
    "150423": {"name": "巴林右旗", "alpha": "b"},
    "150424": {"name": "林西县", "alpha": "l"},
    "150425": {"name": "克什克腾旗", "alpha": "k"},
    "150426": {"name": "翁牛特旗", "alpha": "w"},
    "150428": {"name": "喀喇沁旗", "alpha": "k"},
    "150429": {"name": "宁城县", "alpha": "n"},
    "150430": {"name": "敖汉旗", "alpha": "a"}
  },
  "150500": {
    "150502": {"name": "科尔沁区", "alpha": "k"},
    "150521": {"name": "科尔沁左翼中旗", "alpha": "k"},
    "150522": {"name": "科尔沁左翼后旗", "alpha": "k"},
    "150523": {"name": "开鲁县", "alpha": "k"},
    "150524": {"name": "库伦旗", "alpha": "k"},
    "150525": {"name": "奈曼旗", "alpha": "n"},
    "150526": {"name": "扎鲁特旗", "alpha": "z"},
    "150571": {"name": "通辽经济技术开发区", "alpha": "t"},
    "150581": {"name": "霍林郭勒", "alpha": "h"}
  },
  "150600": {
    "150602": {"name": "东胜区", "alpha": "d"},
    "150603": {"name": "康巴什区", "alpha": "k"},
    "150621": {"name": "达拉特旗", "alpha": "d"},
    "150622": {"name": "准格尔旗", "alpha": "z"},
    "150623": {"name": "鄂托克前旗", "alpha": "e"},
    "150624": {"name": "鄂托克旗", "alpha": "e"},
    "150625": {"name": "杭锦旗", "alpha": "h"},
    "150626": {"name": "乌审旗", "alpha": "w"},
    "150627": {"name": "伊金霍洛旗", "alpha": "y"}
  },
  "150700": {
    "150702": {"name": "海拉尔区", "alpha": "h"},
    "150703": {"name": "扎赉诺尔区", "alpha": "z"},
    "150721": {"name": "阿荣旗", "alpha": "a"},
    "150722": {"name": "莫力达瓦达斡尔族自治旗", "alpha": "m"},
    "150723": {"name": "鄂伦春自治旗", "alpha": "e"},
    "150724": {"name": "鄂温克族自治旗", "alpha": "e"},
    "150725": {"name": "陈巴尔虎旗", "alpha": "c"},
    "150726": {"name": "新巴尔虎左旗", "alpha": "x"},
    "150727": {"name": "新巴尔虎右旗", "alpha": "x"},
    "150781": {"name": "满洲里", "alpha": "m"},
    "150782": {"name": "牙克石", "alpha": "y"},
    "150783": {"name": "扎兰屯", "alpha": "z"},
    "150784": {"name": "额尔古纳", "alpha": "e"},
    "150785": {"name": "根河", "alpha": "g"}
  },
  "150800": {
    "150802": {"name": "临河区", "alpha": "l"},
    "150821": {"name": "五原县", "alpha": "w"},
    "150822": {"name": "磴口县", "alpha": "d"},
    "150823": {"name": "乌拉特前旗", "alpha": "w"},
    "150824": {"name": "乌拉特中旗", "alpha": "w"},
    "150825": {"name": "乌拉特后旗", "alpha": "w"},
    "150826": {"name": "杭锦后旗", "alpha": "h"}
  },
  "150900": {
    "150902": {"name": "集宁区", "alpha": "j"},
    "150921": {"name": "卓资县", "alpha": "z"},
    "150922": {"name": "化德县", "alpha": "h"},
    "150923": {"name": "商都县", "alpha": "s"},
    "150924": {"name": "兴和县", "alpha": "x"},
    "150925": {"name": "凉城县", "alpha": "l"},
    "150926": {"name": "察哈尔右翼前旗", "alpha": "c"},
    "150927": {"name": "察哈尔右翼中旗", "alpha": "c"},
    "150928": {"name": "察哈尔右翼后旗", "alpha": "c"},
    "150929": {"name": "四子王旗", "alpha": "s"},
    "150981": {"name": "丰镇", "alpha": "f"}
  },
  "152200": {
    "152201": {"name": "乌兰浩特", "alpha": "w"},
    "152202": {"name": "阿尔山", "alpha": "a"},
    "152221": {"name": "科尔沁右翼前旗", "alpha": "k"},
    "152222": {"name": "科尔沁右翼中旗", "alpha": "k"},
    "152223": {"name": "扎赉特旗", "alpha": "z"},
    "152224": {"name": "突泉县", "alpha": "t"}
  },
  "152500": {
    "152501": {"name": "二连浩特", "alpha": "e"},
    "152502": {"name": "锡林浩特", "alpha": "x"},
    "152522": {"name": "阿巴嘎旗", "alpha": "a"},
    "152523": {"name": "苏尼特左旗", "alpha": "s"},
    "152524": {"name": "苏尼特右旗", "alpha": "s"},
    "152525": {"name": "东乌珠穆沁旗", "alpha": "d"},
    "152526": {"name": "西乌珠穆沁旗", "alpha": "x"},
    "152527": {"name": "太仆寺旗", "alpha": "t"},
    "152528": {"name": "镶黄旗", "alpha": "x"},
    "152529": {"name": "正镶白旗", "alpha": "z"},
    "152530": {"name": "正蓝旗", "alpha": "z"},
    "152531": {"name": "多伦县", "alpha": "d"},
    "152571": {"name": "乌拉盖管委会", "alpha": "w"}
  },
  "152900": {
    "152921": {"name": "阿拉善左旗", "alpha": "a"},
    "152922": {"name": "阿拉善右旗", "alpha": "a"},
    "152923": {"name": "额济纳旗", "alpha": "e"},
    "152971": {"name": "内蒙古阿拉善经济开发区", "alpha": "n"}
  },
  "210100": {
    "210102": {"name": "和平区", "alpha": "h"},
    "210103": {"name": "沈河区", "alpha": "s"},
    "210104": {"name": "大东区", "alpha": "d"},
    "210105": {"name": "皇姑区", "alpha": "h"},
    "210106": {"name": "铁西区", "alpha": "t"},
    "210111": {"name": "苏家屯区", "alpha": "s"},
    "210112": {"name": "浑南区", "alpha": "h"},
    "210113": {"name": "沈北新区", "alpha": "s"},
    "210114": {"name": "于洪区", "alpha": "y"},
    "210115": {"name": "辽中区", "alpha": "l"},
    "210123": {"name": "康平县", "alpha": "k"},
    "210124": {"name": "法库县", "alpha": "f"},
    "210181": {"name": "新民", "alpha": "x"}
  },
  "210200": {
    "210202": {"name": "中山区", "alpha": "z"},
    "210203": {"name": "西岗区", "alpha": "x"},
    "210204": {"name": "沙河口区", "alpha": "s"},
    "210211": {"name": "甘井子区", "alpha": "g"},
    "210212": {"name": "旅顺口区", "alpha": "l"},
    "210213": {"name": "金州区", "alpha": "j"},
    "210214": {"name": "普兰店区", "alpha": "p"},
    "210224": {"name": "长海县", "alpha": "c"},
    "210281": {"name": "瓦房店", "alpha": "w"},
    "210283": {"name": "庄河", "alpha": "z"}
  },
  "210300": {
    "210302": {"name": "铁东区", "alpha": "t"},
    "210303": {"name": "铁西区", "alpha": "t"},
    "210304": {"name": "立山区", "alpha": "l"},
    "210311": {"name": "千山区", "alpha": "q"},
    "210321": {"name": "台安县", "alpha": "t"},
    "210323": {"name": "岫岩满族自治县", "alpha": "x"},
    "210381": {"name": "海城", "alpha": "h"}
  },
  "210400": {
    "210402": {"name": "新抚区", "alpha": "x"},
    "210403": {"name": "东洲区", "alpha": "d"},
    "210404": {"name": "望花区", "alpha": "w"},
    "210411": {"name": "顺城区", "alpha": "s"},
    "210421": {"name": "抚顺县", "alpha": "f"},
    "210422": {"name": "新宾满族自治县", "alpha": "x"},
    "210423": {"name": "清原满族自治县", "alpha": "q"}
  },
  "210500": {
    "210502": {"name": "平山区", "alpha": "p"},
    "210503": {"name": "溪湖区", "alpha": "x"},
    "210504": {"name": "明山区", "alpha": "m"},
    "210505": {"name": "南芬区", "alpha": "n"},
    "210521": {"name": "本溪满族自治县", "alpha": "b"},
    "210522": {"name": "桓仁满族自治县", "alpha": "h"}
  },
  "210600": {
    "210602": {"name": "元宝区", "alpha": "y"},
    "210603": {"name": "振兴区", "alpha": "z"},
    "210604": {"name": "振安区", "alpha": "z"},
    "210624": {"name": "宽甸满族自治县", "alpha": "k"},
    "210681": {"name": "东港", "alpha": "d"},
    "210682": {"name": "凤城", "alpha": "f"}
  },
  "210700": {
    "210702": {"name": "古塔区", "alpha": "g"},
    "210703": {"name": "凌河区", "alpha": "l"},
    "210711": {"name": "太和区", "alpha": "t"},
    "210726": {"name": "黑山县", "alpha": "h"},
    "210727": {"name": "义县", "alpha": "y"},
    "210781": {"name": "凌海", "alpha": "l"},
    "210782": {"name": "北镇", "alpha": "b"}
  },
  "210800": {
    "210802": {"name": "站前区", "alpha": "z"},
    "210803": {"name": "西区", "alpha": "x"},
    "210804": {"name": "鲅鱼圈区", "alpha": "b"},
    "210811": {"name": "老边区", "alpha": "l"},
    "210881": {"name": "盖州", "alpha": "g"},
    "210882": {"name": "大石桥", "alpha": "d"}
  },
  "210900": {
    "210902": {"name": "海州区", "alpha": "h"},
    "210903": {"name": "新邱区", "alpha": "x"},
    "210904": {"name": "太平区", "alpha": "t"},
    "210905": {"name": "清河门区", "alpha": "q"},
    "210911": {"name": "细河区", "alpha": "x"},
    "210921": {"name": "阜新蒙古族自治县", "alpha": "f"},
    "210922": {"name": "彰武县", "alpha": "z"}
  },
  "211000": {
    "211002": {"name": "白塔区", "alpha": "b"},
    "211003": {"name": "文圣区", "alpha": "w"},
    "211004": {"name": "宏伟区", "alpha": "h"},
    "211005": {"name": "弓长岭区", "alpha": "g"},
    "211011": {"name": "太子河区", "alpha": "t"},
    "211021": {"name": "辽阳县", "alpha": "l"},
    "211081": {"name": "灯塔", "alpha": "d"}
  },
  "211100": {
    "211102": {"name": "双台子区", "alpha": "s"},
    "211103": {"name": "兴隆台区", "alpha": "x"},
    "211104": {"name": "大洼区", "alpha": "d"},
    "211122": {"name": "盘山县", "alpha": "p"}
  },
  "211200": {
    "211202": {"name": "银州区", "alpha": "y"},
    "211204": {"name": "清河区", "alpha": "q"},
    "211221": {"name": "铁岭县", "alpha": "t"},
    "211223": {"name": "西丰县", "alpha": "x"},
    "211224": {"name": "昌图县", "alpha": "c"},
    "211281": {"name": "调兵山", "alpha": "t"},
    "211282": {"name": "开原", "alpha": "k"}
  },
  "211300": {
    "211302": {"name": "双塔区", "alpha": "s"},
    "211303": {"name": "龙城区", "alpha": "l"},
    "211321": {"name": "朝阳县", "alpha": "c"},
    "211322": {"name": "建平县", "alpha": "j"},
    "211324": {"name": "喀喇沁左翼蒙古族自治县", "alpha": "k"},
    "211381": {"name": "北票", "alpha": "b"},
    "211382": {"name": "凌源", "alpha": "l"}
  },
  "211400": {
    "211402": {"name": "连山区", "alpha": "l"},
    "211403": {"name": "龙港区", "alpha": "l"},
    "211404": {"name": "南票区", "alpha": "n"},
    "211421": {"name": "绥中县", "alpha": "s"},
    "211422": {"name": "建昌县", "alpha": "j"},
    "211481": {"name": "兴城", "alpha": "x"}
  },
  "220100": {
    "220102": {"name": "南关区", "alpha": "n"},
    "220103": {"name": "宽城区", "alpha": "k"},
    "220104": {"name": "朝阳区", "alpha": "c"},
    "220105": {"name": "二道区", "alpha": "e"},
    "220106": {"name": "绿园区", "alpha": "l"},
    "220112": {"name": "双阳区", "alpha": "s"},
    "220113": {"name": "九台区", "alpha": "j"},
    "220122": {"name": "农安县", "alpha": "n"},
    "220171": {"name": "长春经济技术开发区", "alpha": "c"},
    "220172": {"name": "长春净月高新技术产业开发区", "alpha": "c"},
    "220173": {"name": "长春高新技术产业开发区", "alpha": "c"},
    "220174": {"name": "长春汽车经济技术开发区", "alpha": "c"},
    "220182": {"name": "榆树", "alpha": "y"},
    "220183": {"name": "德惠", "alpha": "d"}
  },
  "220200": {
    "220202": {"name": "昌邑区", "alpha": "c"},
    "220203": {"name": "龙潭区", "alpha": "l"},
    "220204": {"name": "船营区", "alpha": "c"},
    "220211": {"name": "丰满区", "alpha": "f"},
    "220221": {"name": "永吉县", "alpha": "y"},
    "220271": {"name": "吉林经济开发区", "alpha": "j"},
    "220272": {"name": "吉林高新技术产业开发区", "alpha": "j"},
    "220273": {"name": "吉林中国新加坡食品区", "alpha": "j"},
    "220281": {"name": "蛟河", "alpha": "j"},
    "220282": {"name": "桦甸", "alpha": "h"},
    "220283": {"name": "舒兰", "alpha": "s"},
    "220284": {"name": "磐石", "alpha": "p"}
  },
  "220300": {
    "220302": {"name": "铁西区", "alpha": "t"},
    "220303": {"name": "铁东区", "alpha": "t"},
    "220322": {"name": "梨树县", "alpha": "l"},
    "220323": {"name": "伊通满族自治县", "alpha": "y"},
    "220381": {"name": "公主岭", "alpha": "g"},
    "220382": {"name": "双辽", "alpha": "s"}
  },
  "220400": {
    "220402": {"name": "龙山区", "alpha": "l"},
    "220403": {"name": "西安区", "alpha": "x"},
    "220421": {"name": "东丰县", "alpha": "d"},
    "220422": {"name": "东辽县", "alpha": "d"}
  },
  "220500": {
    "220502": {"name": "东昌区", "alpha": "d"},
    "220503": {"name": "二道江区", "alpha": "e"},
    "220521": {"name": "通化县", "alpha": "t"},
    "220523": {"name": "辉南县", "alpha": "h"},
    "220524": {"name": "柳河县", "alpha": "l"},
    "220581": {"name": "梅河口", "alpha": "m"},
    "220582": {"name": "集安", "alpha": "j"}
  },
  "220600": {
    "220602": {"name": "浑江区", "alpha": "h"},
    "220605": {"name": "江源区", "alpha": "j"},
    "220621": {"name": "抚松县", "alpha": "f"},
    "220622": {"name": "靖宇县", "alpha": "j"},
    "220623": {"name": "长白朝鲜族自治县", "alpha": "c"},
    "220681": {"name": "临江", "alpha": "l"}
  },
  "220700": {
    "220702": {"name": "宁江区", "alpha": "n"},
    "220721": {"name": "前郭尔罗斯蒙古族自治县", "alpha": "q"},
    "220722": {"name": "长岭县", "alpha": "c"},
    "220723": {"name": "乾安县", "alpha": "q"},
    "220771": {"name": "吉林松原经济开发区", "alpha": "j"},
    "220781": {"name": "扶余", "alpha": "f"}
  },
  "220800": {
    "220802": {"name": "洮北区", "alpha": "t"},
    "220821": {"name": "镇赉县", "alpha": "z"},
    "220822": {"name": "通榆县", "alpha": "t"},
    "220871": {"name": "吉林白城经济开发区", "alpha": "j"},
    "220881": {"name": "洮南", "alpha": "t"},
    "220882": {"name": "大安", "alpha": "d"}
  },
  "222400": {
    "222401": {"name": "延吉", "alpha": "y"},
    "222402": {"name": "图们", "alpha": "t"},
    "222403": {"name": "敦化", "alpha": "d"},
    "222404": {"name": "珲春", "alpha": "h"},
    "222405": {"name": "龙井", "alpha": "l"},
    "222406": {"name": "和龙", "alpha": "h"},
    "222424": {"name": "汪清县", "alpha": "w"},
    "222426": {"name": "安图县", "alpha": "a"}
  },
  "230100": {
    "230102": {"name": "道里区", "alpha": "d"},
    "230103": {"name": "南岗区", "alpha": "n"},
    "230104": {"name": "道外区", "alpha": "d"},
    "230108": {"name": "平房区", "alpha": "p"},
    "230109": {"name": "松北区", "alpha": "s"},
    "230110": {"name": "香坊区", "alpha": "x"},
    "230111": {"name": "呼兰区", "alpha": "h"},
    "230112": {"name": "阿城区", "alpha": "a"},
    "230113": {"name": "双城区", "alpha": "s"},
    "230123": {"name": "依兰县", "alpha": "y"},
    "230124": {"name": "方正县", "alpha": "f"},
    "230125": {"name": "宾县", "alpha": "b"},
    "230126": {"name": "巴彦县", "alpha": "b"},
    "230127": {"name": "木兰县", "alpha": "m"},
    "230128": {"name": "通河县", "alpha": "t"},
    "230129": {"name": "延寿县", "alpha": "y"},
    "230183": {"name": "尚志", "alpha": "s"},
    "230184": {"name": "五常", "alpha": "w"}
  },
  "230200": {
    "230202": {"name": "龙沙区", "alpha": "l"},
    "230203": {"name": "建华区", "alpha": "j"},
    "230204": {"name": "铁锋区", "alpha": "t"},
    "230205": {"name": "昂昂溪区", "alpha": "a"},
    "230206": {"name": "富拉尔基区", "alpha": "f"},
    "230207": {"name": "碾子山区", "alpha": "n"},
    "230208": {"name": "梅里斯达斡尔族区", "alpha": "m"},
    "230221": {"name": "龙江县", "alpha": "l"},
    "230223": {"name": "依安县", "alpha": "y"},
    "230224": {"name": "泰来县", "alpha": "t"},
    "230225": {"name": "甘南县", "alpha": "g"},
    "230227": {"name": "富裕县", "alpha": "f"},
    "230229": {"name": "克山县", "alpha": "k"},
    "230230": {"name": "克东县", "alpha": "k"},
    "230231": {"name": "拜泉县", "alpha": "b"},
    "230281": {"name": "讷河", "alpha": "n"}
  },
  "230300": {
    "230302": {"name": "鸡冠区", "alpha": "j"},
    "230303": {"name": "恒山区", "alpha": "h"},
    "230304": {"name": "滴道区", "alpha": "d"},
    "230305": {"name": "梨树区", "alpha": "l"},
    "230306": {"name": "城子河区", "alpha": "c"},
    "230307": {"name": "麻山区", "alpha": "m"},
    "230321": {"name": "鸡东县", "alpha": "j"},
    "230381": {"name": "虎林", "alpha": "h"},
    "230382": {"name": "密山", "alpha": "m"}
  },
  "230400": {
    "230402": {"name": "向阳区", "alpha": "x"},
    "230403": {"name": "工农区", "alpha": "g"},
    "230404": {"name": "南山区", "alpha": "n"},
    "230405": {"name": "兴安区", "alpha": "x"},
    "230406": {"name": "东山区", "alpha": "d"},
    "230407": {"name": "兴山区", "alpha": "x"},
    "230421": {"name": "萝北县", "alpha": "l"},
    "230422": {"name": "绥滨县", "alpha": "s"}
  },
  "230500": {
    "230502": {"name": "尖山区", "alpha": "j"},
    "230503": {"name": "岭东区", "alpha": "l"},
    "230505": {"name": "四方台区", "alpha": "s"},
    "230506": {"name": "宝山区", "alpha": "b"},
    "230521": {"name": "集贤县", "alpha": "j"},
    "230522": {"name": "友谊县", "alpha": "y"},
    "230523": {"name": "宝清县", "alpha": "b"},
    "230524": {"name": "饶河县", "alpha": "r"}
  },
  "230600": {
    "230602": {"name": "萨尔图区", "alpha": "s"},
    "230603": {"name": "龙凤区", "alpha": "l"},
    "230604": {"name": "让胡路区", "alpha": "r"},
    "230605": {"name": "红岗区", "alpha": "h"},
    "230606": {"name": "大同区", "alpha": "d"},
    "230621": {"name": "肇州县", "alpha": "z"},
    "230622": {"name": "肇源县", "alpha": "z"},
    "230623": {"name": "林甸县", "alpha": "l"},
    "230624": {"name": "杜尔伯特蒙古族自治县", "alpha": "d"},
    "230671": {"name": "大庆高新技术产业开发区", "alpha": "d"}
  },
  "230700": {
    "230702": {"name": "伊春区", "alpha": "y"},
    "230703": {"name": "南岔区", "alpha": "n"},
    "230704": {"name": "友好区", "alpha": "y"},
    "230705": {"name": "西林区", "alpha": "x"},
    "230706": {"name": "翠峦区", "alpha": "c"},
    "230707": {"name": "新青区", "alpha": "x"},
    "230708": {"name": "美溪区", "alpha": "m"},
    "230709": {"name": "金山屯区", "alpha": "j"},
    "230710": {"name": "五营区", "alpha": "w"},
    "230711": {"name": "乌马河区", "alpha": "w"},
    "230712": {"name": "汤旺河区", "alpha": "t"},
    "230713": {"name": "带岭区", "alpha": "d"},
    "230714": {"name": "乌伊岭区", "alpha": "w"},
    "230715": {"name": "红星区", "alpha": "h"},
    "230716": {"name": "上甘岭区", "alpha": "s"},
    "230722": {"name": "嘉荫县", "alpha": "j"},
    "230781": {"name": "铁力", "alpha": "t"}
  },
  "230800": {
    "230803": {"name": "向阳区", "alpha": "x"},
    "230804": {"name": "前进区", "alpha": "q"},
    "230805": {"name": "东风区", "alpha": "d"},
    "230811": {"name": "郊区", "alpha": "j"},
    "230822": {"name": "桦南县", "alpha": "h"},
    "230826": {"name": "桦川县", "alpha": "h"},
    "230828": {"name": "汤原县", "alpha": "t"},
    "230881": {"name": "同江", "alpha": "t"},
    "230882": {"name": "富锦", "alpha": "f"},
    "230883": {"name": "抚远", "alpha": "f"}
  },
  "230900": {
    "230902": {"name": "新兴区", "alpha": "x"},
    "230903": {"name": "桃山区", "alpha": "t"},
    "230904": {"name": "茄子河区", "alpha": "q"},
    "230921": {"name": "勃利县", "alpha": "b"}
  },
  "231000": {
    "231002": {"name": "东安区", "alpha": "d"},
    "231003": {"name": "阳明区", "alpha": "y"},
    "231004": {"name": "爱民区", "alpha": "a"},
    "231005": {"name": "西安区", "alpha": "x"},
    "231025": {"name": "林口县", "alpha": "l"},
    "231071": {"name": "牡丹江经济技术开发区", "alpha": "m"},
    "231081": {"name": "绥芬河", "alpha": "s"},
    "231083": {"name": "海林", "alpha": "h"},
    "231084": {"name": "宁安", "alpha": "n"},
    "231085": {"name": "穆棱", "alpha": "m"},
    "231086": {"name": "东宁", "alpha": "d"}
  },
  "231100": {
    "231102": {"name": "爱辉区", "alpha": "a"},
    "231121": {"name": "嫩江县", "alpha": "n"},
    "231123": {"name": "逊克县", "alpha": "x"},
    "231124": {"name": "孙吴县", "alpha": "s"},
    "231181": {"name": "北安", "alpha": "b"},
    "231182": {"name": "五大连池", "alpha": "w"}
  },
  "231200": {
    "231202": {"name": "北林区", "alpha": "b"},
    "231221": {"name": "望奎县", "alpha": "w"},
    "231222": {"name": "兰西县", "alpha": "l"},
    "231223": {"name": "青冈县", "alpha": "q"},
    "231224": {"name": "庆安县", "alpha": "q"},
    "231225": {"name": "明水县", "alpha": "m"},
    "231226": {"name": "绥棱县", "alpha": "s"},
    "231281": {"name": "安达", "alpha": "a"},
    "231282": {"name": "肇东", "alpha": "z"},
    "231283": {"name": "海伦", "alpha": "h"}
  },
  "232700": {
    "232701": {"name": "漠河", "alpha": "m"},
    "232721": {"name": "呼玛县", "alpha": "h"},
    "232722": {"name": "塔河县", "alpha": "t"},
    "232761": {"name": "加格达奇区", "alpha": "j"},
    "232762": {"name": "松岭区", "alpha": "s"},
    "232763": {"name": "新林区", "alpha": "x"},
    "232764": {"name": "呼中区", "alpha": "h"}
  },
  "310100": {
    "310101": {"name": "黄浦区", "alpha": "h"},
    "310104": {"name": "徐汇区", "alpha": "x"},
    "310105": {"name": "长宁区", "alpha": "c"},
    "310106": {"name": "静安区", "alpha": "j"},
    "310107": {"name": "普陀区", "alpha": "p"},
    "310109": {"name": "虹口区", "alpha": "h"},
    "310110": {"name": "杨浦区", "alpha": "y"},
    "310112": {"name": "闵行区", "alpha": "m"},
    "310113": {"name": "宝山区", "alpha": "b"},
    "310114": {"name": "嘉定区", "alpha": "j"},
    "310115": {"name": "浦东新区", "alpha": "p"},
    "310116": {"name": "金山区", "alpha": "j"},
    "310117": {"name": "松江区", "alpha": "s"},
    "310118": {"name": "青浦区", "alpha": "q"},
    "310120": {"name": "奉贤区", "alpha": "f"},
    "310151": {"name": "崇明区", "alpha": "c"}
  },
  "320100": {
    "320102": {"name": "玄武区", "alpha": "x"},
    "320104": {"name": "秦淮区", "alpha": "q"},
    "320105": {"name": "建邺区", "alpha": "j"},
    "320106": {"name": "鼓楼区", "alpha": "g"},
    "320111": {"name": "浦口区", "alpha": "p"},
    "320113": {"name": "栖霞区", "alpha": "q"},
    "320114": {"name": "雨花台区", "alpha": "y"},
    "320115": {"name": "江宁区", "alpha": "j"},
    "320116": {"name": "六合区", "alpha": "l"},
    "320117": {"name": "溧水区", "alpha": "l"},
    "320118": {"name": "高淳区", "alpha": "g"}
  },
  "320200": {
    "320205": {"name": "锡山区", "alpha": "x"},
    "320206": {"name": "惠山区", "alpha": "h"},
    "320211": {"name": "滨湖区", "alpha": "b"},
    "320213": {"name": "梁溪区", "alpha": "l"},
    "320214": {"name": "新吴区", "alpha": "x"},
    "320281": {"name": "江阴", "alpha": "j"},
    "320282": {"name": "宜兴", "alpha": "y"}
  },
  "320300": {
    "320302": {"name": "鼓楼区", "alpha": "g"},
    "320303": {"name": "云龙区", "alpha": "y"},
    "320305": {"name": "贾汪区", "alpha": "j"},
    "320311": {"name": "泉山区", "alpha": "q"},
    "320312": {"name": "铜山区", "alpha": "t"},
    "320321": {"name": "丰县", "alpha": "f"},
    "320322": {"name": "沛县", "alpha": "p"},
    "320324": {"name": "睢宁县", "alpha": "h"},
    "320371": {"name": "徐州经济技术开发区", "alpha": "x"},
    "320381": {"name": "新沂", "alpha": "x"},
    "320382": {"name": "邳州", "alpha": "p"}
  },
  "320400": {
    "320402": {"name": "天宁区", "alpha": "t"},
    "320404": {"name": "钟楼区", "alpha": "z"},
    "320411": {"name": "新北区", "alpha": "x"},
    "320412": {"name": "武进区", "alpha": "w"},
    "320413": {"name": "金坛区", "alpha": "j"},
    "320481": {"name": "溧阳", "alpha": "l"}
  },
  "320500": {
    "320505": {"name": "虎丘区", "alpha": "h"},
    "320506": {"name": "吴中区", "alpha": "w"},
    "320507": {"name": "相城区", "alpha": "x"},
    "320508": {"name": "姑苏区", "alpha": "g"},
    "320509": {"name": "吴江区", "alpha": "w"},
    "320571": {"name": "苏州工业园区", "alpha": "s"},
    "320581": {"name": "常熟", "alpha": "c"},
    "320582": {"name": "张家港", "alpha": "z"},
    "320583": {"name": "昆山", "alpha": "k"},
    "320585": {"name": "太仓", "alpha": "t"}
  },
  "320600": {
    "320602": {"name": "崇川区", "alpha": "c"},
    "320611": {"name": "港闸区", "alpha": "g"},
    "320612": {"name": "通州区", "alpha": "t"},
    "320623": {"name": "如东县", "alpha": "r"},
    "320671": {"name": "南通经济技术开发区", "alpha": "n"},
    "320681": {"name": "启东", "alpha": "q"},
    "320682": {"name": "如皋", "alpha": "r"},
    "320684": {"name": "海门", "alpha": "h"},
    "320685": {"name": "海安", "alpha": "h"}
  },
  "320700": {
    "320703": {"name": "连云区", "alpha": "l"},
    "320706": {"name": "海州区", "alpha": "h"},
    "320707": {"name": "赣榆区", "alpha": "g"},
    "320722": {"name": "东海县", "alpha": "d"},
    "320723": {"name": "灌云县", "alpha": "g"},
    "320724": {"name": "灌南县", "alpha": "g"},
    "320771": {"name": "连云港经济技术开发区", "alpha": "l"},
    "320772": {"name": "连云港高新技术产业开发区", "alpha": "l"}
  },
  "320800": {
    "320803": {"name": "淮安区", "alpha": "h"},
    "320804": {"name": "淮阴区", "alpha": "h"},
    "320812": {"name": "清江浦区", "alpha": "q"},
    "320813": {"name": "洪泽区", "alpha": "h"},
    "320826": {"name": "涟水县", "alpha": "l"},
    "320830": {"name": "盱眙县", "alpha": "x"},
    "320831": {"name": "金湖县", "alpha": "j"},
    "320871": {"name": "淮安经济技术开发区", "alpha": "h"}
  },
  "320900": {
    "320902": {"name": "亭湖区", "alpha": "t"},
    "320903": {"name": "盐都区", "alpha": "y"},
    "320904": {"name": "大丰区", "alpha": "d"},
    "320921": {"name": "响水县", "alpha": "x"},
    "320922": {"name": "滨海县", "alpha": "b"},
    "320923": {"name": "阜宁县", "alpha": "f"},
    "320924": {"name": "射阳县", "alpha": "s"},
    "320925": {"name": "建湖县", "alpha": "j"},
    "320971": {"name": "盐城经济技术开发区", "alpha": "y"},
    "320981": {"name": "东台", "alpha": "d"}
  },
  "321000": {
    "321002": {"name": "广陵区", "alpha": "g"},
    "321003": {"name": "邗江区", "alpha": "h"},
    "321012": {"name": "江都区", "alpha": "j"},
    "321023": {"name": "宝应县", "alpha": "b"},
    "321071": {"name": "扬州经济技术开发区", "alpha": "y"},
    "321081": {"name": "仪征", "alpha": "y"},
    "321084": {"name": "高邮", "alpha": "g"}
  },
  "321100": {
    "321102": {"name": "京口区", "alpha": "j"},
    "321111": {"name": "润州区", "alpha": "r"},
    "321112": {"name": "丹徒区", "alpha": "d"},
    "321171": {"name": "镇江新区", "alpha": "z"},
    "321181": {"name": "丹阳", "alpha": "d"},
    "321182": {"name": "扬中", "alpha": "y"},
    "321183": {"name": "句容", "alpha": "j"}
  },
  "321200": {
    "321202": {"name": "海陵区", "alpha": "h"},
    "321203": {"name": "高港区", "alpha": "g"},
    "321204": {"name": "姜堰区", "alpha": "j"},
    "321271": {"name": "泰州医药高新技术产业开发区", "alpha": "t"},
    "321281": {"name": "兴化", "alpha": "x"},
    "321282": {"name": "靖江", "alpha": "j"},
    "321283": {"name": "泰兴", "alpha": "t"}
  },
  "321300": {
    "321302": {"name": "宿城区", "alpha": "s"},
    "321311": {"name": "宿豫区", "alpha": "s"},
    "321322": {"name": "沭阳县", "alpha": "s"},
    "321323": {"name": "泗阳县", "alpha": "s"},
    "321324": {"name": "泗洪县", "alpha": "s"},
    "321371": {"name": "宿迁经济技术开发区", "alpha": "s"}
  },
  "330100": {
    "330102": {"name": "上城区", "alpha": "s"},
    "330103": {"name": "下城区", "alpha": "x"},
    "330104": {"name": "江干区", "alpha": "j"},
    "330105": {"name": "拱墅区", "alpha": "g"},
    "330106": {"name": "西湖区", "alpha": "x"},
    "330108": {"name": "滨江区", "alpha": "b"},
    "330109": {"name": "萧山区", "alpha": "x"},
    "330110": {"name": "余杭区", "alpha": "y"},
    "330111": {"name": "富阳区", "alpha": "f"},
    "330112": {"name": "临安区", "alpha": "l"},
    "330122": {"name": "桐庐县", "alpha": "t"},
    "330127": {"name": "淳安县", "alpha": "c"},
    "330182": {"name": "建德", "alpha": "j"}
  },
  "330200": {
    "330203": {"name": "海曙区", "alpha": "h"},
    "330205": {"name": "江北区", "alpha": "j"},
    "330206": {"name": "北仑区", "alpha": "b"},
    "330211": {"name": "镇海区", "alpha": "z"},
    "330212": {"name": "鄞州区", "alpha": "y"},
    "330213": {"name": "奉化区", "alpha": "f"},
    "330225": {"name": "象山县", "alpha": "x"},
    "330226": {"name": "宁海县", "alpha": "n"},
    "330281": {"name": "余姚", "alpha": "y"},
    "330282": {"name": "慈溪", "alpha": "c"}
  },
  "330300": {
    "330302": {"name": "鹿城区", "alpha": "l"},
    "330303": {"name": "龙湾区", "alpha": "l"},
    "330304": {"name": "瓯海区", "alpha": "o"},
    "330305": {"name": "洞头区", "alpha": "d"},
    "330324": {"name": "永嘉县", "alpha": "y"},
    "330326": {"name": "平阳县", "alpha": "p"},
    "330327": {"name": "苍南县", "alpha": "c"},
    "330328": {"name": "文成县", "alpha": "w"},
    "330329": {"name": "泰顺县", "alpha": "t"},
    "330371": {"name": "温州经济技术开发区", "alpha": "w"},
    "330381": {"name": "瑞安", "alpha": "r"},
    "330382": {"name": "乐清", "alpha": "l"}
  },
  "330400": {
    "330402": {"name": "南湖区", "alpha": "n"},
    "330411": {"name": "秀洲区", "alpha": "x"},
    "330421": {"name": "嘉善县", "alpha": "j"},
    "330424": {"name": "海盐县", "alpha": "h"},
    "330481": {"name": "海宁", "alpha": "h"},
    "330482": {"name": "平湖", "alpha": "p"},
    "330483": {"name": "桐乡", "alpha": "t"}
  },
  "330500": {
    "330502": {"name": "吴兴区", "alpha": "w"},
    "330503": {"name": "南浔区", "alpha": "n"},
    "330521": {"name": "德清县", "alpha": "d"},
    "330522": {"name": "长兴县", "alpha": "c"},
    "330523": {"name": "安吉县", "alpha": "a"}
  },
  "330600": {
    "330602": {"name": "越城区", "alpha": "y"},
    "330603": {"name": "柯桥区", "alpha": "k"},
    "330604": {"name": "上虞区", "alpha": "s"},
    "330624": {"name": "新昌县", "alpha": "x"},
    "330681": {"name": "诸暨", "alpha": "z"},
    "330683": {"name": "嵊州", "alpha": "s"}
  },
  "330700": {
    "330702": {"name": "婺城区", "alpha": "w"},
    "330703": {"name": "金东区", "alpha": "j"},
    "330723": {"name": "武义县", "alpha": "w"},
    "330726": {"name": "浦江县", "alpha": "p"},
    "330727": {"name": "磐安县", "alpha": "p"},
    "330781": {"name": "兰溪", "alpha": "l"},
    "330782": {"name": "义乌", "alpha": "y"},
    "330783": {"name": "东阳", "alpha": "d"},
    "330784": {"name": "永康", "alpha": "y"}
  },
  "330800": {
    "330802": {"name": "柯城区", "alpha": "k"},
    "330803": {"name": "衢江区", "alpha": "q"},
    "330822": {"name": "常山县", "alpha": "c"},
    "330824": {"name": "开化县", "alpha": "k"},
    "330825": {"name": "龙游县", "alpha": "l"},
    "330881": {"name": "江山", "alpha": "j"}
  },
  "330900": {
    "330902": {"name": "定海区", "alpha": "d"},
    "330903": {"name": "普陀区", "alpha": "p"},
    "330921": {"name": "岱山县", "alpha": "d"},
    "330922": {"name": "嵊泗县", "alpha": "s"}
  },
  "331000": {
    "331002": {"name": "椒江区", "alpha": "j"},
    "331003": {"name": "黄岩区", "alpha": "h"},
    "331004": {"name": "路桥区", "alpha": "l"},
    "331022": {"name": "三门县", "alpha": "s"},
    "331023": {"name": "天台县", "alpha": "t"},
    "331024": {"name": "仙居县", "alpha": "x"},
    "331081": {"name": "温岭", "alpha": "w"},
    "331082": {"name": "临海", "alpha": "l"},
    "331083": {"name": "玉环", "alpha": "y"}
  },
  "331100": {
    "331102": {"name": "莲都区", "alpha": "l"},
    "331121": {"name": "青田县", "alpha": "q"},
    "331122": {"name": "缙云县", "alpha": "j"},
    "331123": {"name": "遂昌县", "alpha": "s"},
    "331124": {"name": "松阳县", "alpha": "s"},
    "331125": {"name": "云和县", "alpha": "y"},
    "331126": {"name": "庆元县", "alpha": "q"},
    "331127": {"name": "景宁畲族自治县", "alpha": "j"},
    "331181": {"name": "龙泉", "alpha": "l"}
  },
  "340100": {
    "340102": {"name": "瑶海区", "alpha": "y"},
    "340103": {"name": "庐阳区", "alpha": "l"},
    "340104": {"name": "蜀山区", "alpha": "s"},
    "340111": {"name": "包河区", "alpha": "b"},
    "340121": {"name": "长丰县", "alpha": "c"},
    "340122": {"name": "肥东县", "alpha": "f"},
    "340123": {"name": "肥西县", "alpha": "f"},
    "340124": {"name": "庐江县", "alpha": "l"},
    "340171": {"name": "合肥高新技术产业开发区", "alpha": "h"},
    "340172": {"name": "合肥经济技术开发区", "alpha": "h"},
    "340173": {"name": "合肥新站高新技术产业开发区", "alpha": "h"},
    "340181": {"name": "巢湖", "alpha": "c"}
  },
  "340200": {
    "340202": {"name": "镜湖区", "alpha": "j"},
    "340203": {"name": "弋江区", "alpha": "y"},
    "340207": {"name": "鸠江区", "alpha": "j"},
    "340208": {"name": "三山区", "alpha": "s"},
    "340221": {"name": "芜湖县", "alpha": "w"},
    "340222": {"name": "繁昌县", "alpha": "f"},
    "340223": {"name": "南陵县", "alpha": "n"},
    "340225": {"name": "无为县", "alpha": "w"},
    "340271": {"name": "芜湖经济技术开发区", "alpha": "w"},
    "340272": {"name": "安徽芜湖长江大桥经济开发区", "alpha": "a"}
  },
  "340300": {
    "340302": {"name": "龙子湖区", "alpha": "l"},
    "340303": {"name": "蚌山区", "alpha": "b"},
    "340304": {"name": "禹会区", "alpha": "y"},
    "340311": {"name": "淮上区", "alpha": "h"},
    "340321": {"name": "怀远县", "alpha": "h"},
    "340322": {"name": "五河县", "alpha": "w"},
    "340323": {"name": "固镇县", "alpha": "g"},
    "340371": {"name": "蚌埠高新技术开发区", "alpha": "b"},
    "340372": {"name": "蚌埠经济开发区", "alpha": "b"}
  },
  "340400": {
    "340402": {"name": "大通区", "alpha": "d"},
    "340403": {"name": "田家庵区", "alpha": "t"},
    "340404": {"name": "谢家集区", "alpha": "x"},
    "340405": {"name": "八公山区", "alpha": "b"},
    "340406": {"name": "潘集区", "alpha": "p"},
    "340421": {"name": "凤台县", "alpha": "f"},
    "340422": {"name": "寿县", "alpha": "s"}
  },
  "340500": {
    "340503": {"name": "花山区", "alpha": "h"},
    "340504": {"name": "雨山区", "alpha": "y"},
    "340506": {"name": "博望区", "alpha": "b"},
    "340521": {"name": "当涂县", "alpha": "d"},
    "340522": {"name": "含山县", "alpha": "h"},
    "340523": {"name": "和县", "alpha": "h"}
  },
  "340600": {
    "340602": {"name": "杜集区", "alpha": "d"},
    "340603": {"name": "相山区", "alpha": "x"},
    "340604": {"name": "烈山区", "alpha": "l"},
    "340621": {"name": "濉溪县", "alpha": "s"}
  },
  "340700": {
    "340705": {"name": "铜官区", "alpha": "t"},
    "340706": {"name": "义安区", "alpha": "y"},
    "340711": {"name": "郊区", "alpha": "j"},
    "340722": {"name": "枞阳县", "alpha": "z"}
  },
  "340800": {
    "340802": {"name": "迎江区", "alpha": "y"},
    "340803": {"name": "大观区", "alpha": "d"},
    "340811": {"name": "宜秀区", "alpha": "y"},
    "340822": {"name": "怀宁县", "alpha": "h"},
    "340825": {"name": "太湖县", "alpha": "t"},
    "340826": {"name": "宿松县", "alpha": "s"},
    "340827": {"name": "望江县", "alpha": "w"},
    "340828": {"name": "岳西县", "alpha": "y"},
    "340871": {"name": "安徽安庆经济开发区", "alpha": "a"},
    "340881": {"name": "桐城", "alpha": "t"},
    "340882": {"name": "潜山", "alpha": "q"}
  },
  "341000": {
    "341002": {"name": "屯溪区", "alpha": "t"},
    "341003": {"name": "黄山区", "alpha": "h"},
    "341004": {"name": "徽州区", "alpha": "h"},
    "341021": {"name": "歙县", "alpha": "s"},
    "341022": {"name": "休宁县", "alpha": "x"},
    "341023": {"name": "黟县", "alpha": "y"},
    "341024": {"name": "祁门县", "alpha": "q"}
  },
  "341100": {
    "341102": {"name": "琅琊区", "alpha": "l"},
    "341103": {"name": "南谯区", "alpha": "n"},
    "341122": {"name": "来安县", "alpha": "l"},
    "341124": {"name": "全椒县", "alpha": "q"},
    "341125": {"name": "定远县", "alpha": "d"},
    "341126": {"name": "凤阳县", "alpha": "f"},
    "341171": {"name": "苏滁现代产业园", "alpha": "s"},
    "341172": {"name": "滁州经济技术开发区", "alpha": "c"},
    "341181": {"name": "天长", "alpha": "t"},
    "341182": {"name": "明光", "alpha": "m"}
  },
  "341200": {
    "341202": {"name": "颍州区", "alpha": "y"},
    "341203": {"name": "颍东区", "alpha": "y"},
    "341204": {"name": "颍泉区", "alpha": "y"},
    "341221": {"name": "临泉县", "alpha": "l"},
    "341222": {"name": "太和县", "alpha": "t"},
    "341225": {"name": "阜南县", "alpha": "f"},
    "341226": {"name": "颍上县", "alpha": "y"},
    "341271": {"name": "阜阳合肥现代产业园区", "alpha": "f"},
    "341272": {"name": "阜阳经济技术开发区", "alpha": "f"},
    "341282": {"name": "界首", "alpha": "j"}
  },
  "341300": {
    "341302": {"name": "埇桥区", "alpha": "y"},
    "341321": {"name": "砀山县", "alpha": "d"},
    "341322": {"name": "萧县", "alpha": "x"},
    "341323": {"name": "灵璧县", "alpha": "l"},
    "341324": {"name": "泗县", "alpha": "s"},
    "341371": {"name": "宿州马鞍山现代产业园区", "alpha": "s"},
    "341372": {"name": "宿州经济技术开发区", "alpha": "s"}
  },
  "341500": {
    "341502": {"name": "金安区", "alpha": "j"},
    "341503": {"name": "裕安区", "alpha": "y"},
    "341504": {"name": "叶集区", "alpha": "y"},
    "341522": {"name": "霍邱县", "alpha": "h"},
    "341523": {"name": "舒城县", "alpha": "s"},
    "341524": {"name": "金寨县", "alpha": "j"},
    "341525": {"name": "霍山县", "alpha": "h"}
  },
  "341600": {
    "341602": {"name": "谯城区", "alpha": "q"},
    "341621": {"name": "涡阳县", "alpha": "w"},
    "341622": {"name": "蒙城县", "alpha": "m"},
    "341623": {"name": "利辛县", "alpha": "l"}
  },
  "341700": {
    "341702": {"name": "贵池区", "alpha": "g"},
    "341721": {"name": "东至县", "alpha": "d"},
    "341722": {"name": "石台县", "alpha": "s"},
    "341723": {"name": "青阳县", "alpha": "q"}
  },
  "341800": {
    "341802": {"name": "宣州区", "alpha": "x"},
    "341821": {"name": "郎溪县", "alpha": "l"},
    "341822": {"name": "广德县", "alpha": "g"},
    "341823": {"name": "泾县", "alpha": "j"},
    "341824": {"name": "绩溪县", "alpha": "j"},
    "341825": {"name": "旌德县", "alpha": "j"},
    "341871": {"name": "宣城经济开发区", "alpha": "x"},
    "341881": {"name": "宁国", "alpha": "n"}
  },
  "350100": {
    "350102": {"name": "鼓楼区", "alpha": "g"},
    "350103": {"name": "台江区", "alpha": "t"},
    "350104": {"name": "仓山区", "alpha": "c"},
    "350105": {"name": "马尾区", "alpha": "m"},
    "350111": {"name": "晋安区", "alpha": "j"},
    "350112": {"name": "长乐区", "alpha": "c"},
    "350121": {"name": "闽侯县", "alpha": "m"},
    "350122": {"name": "连江县", "alpha": "l"},
    "350123": {"name": "罗源县", "alpha": "l"},
    "350124": {"name": "闽清县", "alpha": "m"},
    "350125": {"name": "永泰县", "alpha": "y"},
    "350128": {"name": "平潭县", "alpha": "p"},
    "350181": {"name": "福清", "alpha": "f"}
  },
  "350200": {
    "350203": {"name": "思明区", "alpha": "s"},
    "350205": {"name": "海沧区", "alpha": "h"},
    "350206": {"name": "湖里区", "alpha": "h"},
    "350211": {"name": "集美区", "alpha": "j"},
    "350212": {"name": "同安区", "alpha": "t"},
    "350213": {"name": "翔安区", "alpha": "x"}
  },
  "350300": {
    "350302": {"name": "城厢区", "alpha": "c"},
    "350303": {"name": "涵江区", "alpha": "h"},
    "350304": {"name": "荔城区", "alpha": "l"},
    "350305": {"name": "秀屿区", "alpha": "x"},
    "350322": {"name": "仙游县", "alpha": "x"}
  },
  "350400": {
    "350402": {"name": "梅列区", "alpha": "m"},
    "350403": {"name": "三元区", "alpha": "s"},
    "350421": {"name": "明溪县", "alpha": "m"},
    "350423": {"name": "清流县", "alpha": "q"},
    "350424": {"name": "宁化县", "alpha": "n"},
    "350425": {"name": "大田县", "alpha": "d"},
    "350426": {"name": "尤溪县", "alpha": "y"},
    "350427": {"name": "沙县", "alpha": "s"},
    "350428": {"name": "将乐县", "alpha": "j"},
    "350429": {"name": "泰宁县", "alpha": "t"},
    "350430": {"name": "建宁县", "alpha": "j"},
    "350481": {"name": "永安", "alpha": "y"}
  },
  "350500": {
    "350502": {"name": "鲤城区", "alpha": "l"},
    "350503": {"name": "丰泽区", "alpha": "f"},
    "350504": {"name": "洛江区", "alpha": "l"},
    "350505": {"name": "泉港区", "alpha": "q"},
    "350521": {"name": "惠安县", "alpha": "h"},
    "350524": {"name": "安溪县", "alpha": "a"},
    "350525": {"name": "永春县", "alpha": "y"},
    "350526": {"name": "德化县", "alpha": "d"},
    "350527": {"name": "金门县", "alpha": "j"},
    "350581": {"name": "石狮", "alpha": "s"},
    "350582": {"name": "晋江", "alpha": "j"},
    "350583": {"name": "南安", "alpha": "n"}
  },
  "350600": {
    "350602": {"name": "芗城区", "alpha": "x"},
    "350603": {"name": "龙文区", "alpha": "l"},
    "350622": {"name": "云霄县", "alpha": "y"},
    "350623": {"name": "漳浦县", "alpha": "z"},
    "350624": {"name": "诏安县", "alpha": "z"},
    "350625": {"name": "长泰县", "alpha": "c"},
    "350626": {"name": "东山县", "alpha": "d"},
    "350627": {"name": "南靖县", "alpha": "n"},
    "350628": {"name": "平和县", "alpha": "p"},
    "350629": {"name": "华安县", "alpha": "h"},
    "350681": {"name": "龙海", "alpha": "l"}
  },
  "350700": {
    "350702": {"name": "延平区", "alpha": "y"},
    "350703": {"name": "建阳区", "alpha": "j"},
    "350721": {"name": "顺昌县", "alpha": "s"},
    "350722": {"name": "浦城县", "alpha": "p"},
    "350723": {"name": "光泽县", "alpha": "g"},
    "350724": {"name": "松溪县", "alpha": "s"},
    "350725": {"name": "政和县", "alpha": "z"},
    "350781": {"name": "邵武", "alpha": "s"},
    "350782": {"name": "武夷山", "alpha": "w"},
    "350783": {"name": "建瓯", "alpha": "j"}
  },
  "350800": {
    "350802": {"name": "新罗区", "alpha": "x"},
    "350803": {"name": "永定区", "alpha": "y"},
    "350821": {"name": "长汀县", "alpha": "c"},
    "350823": {"name": "上杭县", "alpha": "s"},
    "350824": {"name": "武平县", "alpha": "w"},
    "350825": {"name": "连城县", "alpha": "l"},
    "350881": {"name": "漳平", "alpha": "z"}
  },
  "350900": {
    "350902": {"name": "蕉城区", "alpha": "j"},
    "350921": {"name": "霞浦县", "alpha": "x"},
    "350922": {"name": "古田县", "alpha": "g"},
    "350923": {"name": "屏南县", "alpha": "p"},
    "350924": {"name": "寿宁县", "alpha": "s"},
    "350925": {"name": "周宁县", "alpha": "z"},
    "350926": {"name": "柘荣县", "alpha": "z"},
    "350981": {"name": "福安", "alpha": "f"},
    "350982": {"name": "福鼎", "alpha": "f"}
  },
  "360100": {
    "360102": {"name": "东湖区", "alpha": "d"},
    "360103": {"name": "西湖区", "alpha": "x"},
    "360104": {"name": "青云谱区", "alpha": "q"},
    "360105": {"name": "湾里区", "alpha": "w"},
    "360111": {"name": "青山湖区", "alpha": "q"},
    "360112": {"name": "新建区", "alpha": "x"},
    "360121": {"name": "南昌县", "alpha": "n"},
    "360123": {"name": "安义县", "alpha": "a"},
    "360124": {"name": "进贤县", "alpha": "j"}
  },
  "360200": {
    "360202": {"name": "昌江区", "alpha": "c"},
    "360203": {"name": "珠山区", "alpha": "z"},
    "360222": {"name": "浮梁县", "alpha": "f"},
    "360281": {"name": "乐平", "alpha": "l"}
  },
  "360300": {
    "360302": {"name": "安源区", "alpha": "a"},
    "360313": {"name": "湘东区", "alpha": "x"},
    "360321": {"name": "莲花县", "alpha": "l"},
    "360322": {"name": "上栗县", "alpha": "s"},
    "360323": {"name": "芦溪县", "alpha": "l"}
  },
  "360400": {
    "360402": {"name": "濂溪区", "alpha": "l"},
    "360403": {"name": "浔阳区", "alpha": "x"},
    "360404": {"name": "柴桑区", "alpha": "c"},
    "360423": {"name": "武宁县", "alpha": "w"},
    "360424": {"name": "修水县", "alpha": "x"},
    "360425": {"name": "永修县", "alpha": "y"},
    "360426": {"name": "德安县", "alpha": "d"},
    "360428": {"name": "都昌县", "alpha": "d"},
    "360429": {"name": "湖口县", "alpha": "h"},
    "360430": {"name": "彭泽县", "alpha": "p"},
    "360481": {"name": "瑞昌", "alpha": "r"},
    "360482": {"name": "共青城", "alpha": "g"},
    "360483": {"name": "庐山", "alpha": "l"}
  },
  "360500": {
    "360502": {"name": "渝水区", "alpha": "y"},
    "360521": {"name": "分宜县", "alpha": "f"}
  },
  "360600": {
    "360602": {"name": "月湖区", "alpha": "y"},
    "360603": {"name": "余江区", "alpha": "y"},
    "360681": {"name": "贵溪", "alpha": "g"}
  },
  "360700": {
    "360702": {"name": "章贡区", "alpha": "z"},
    "360703": {"name": "南康区", "alpha": "n"},
    "360704": {"name": "赣县区", "alpha": "g"},
    "360722": {"name": "信丰县", "alpha": "x"},
    "360723": {"name": "大余县", "alpha": "d"},
    "360724": {"name": "上犹县", "alpha": "s"},
    "360725": {"name": "崇义县", "alpha": "c"},
    "360726": {"name": "安远县", "alpha": "a"},
    "360727": {"name": "龙南县", "alpha": "l"},
    "360728": {"name": "定南县", "alpha": "d"},
    "360729": {"name": "全南县", "alpha": "q"},
    "360730": {"name": "宁都县", "alpha": "n"},
    "360731": {"name": "于都县", "alpha": "y"},
    "360732": {"name": "兴国县", "alpha": "x"},
    "360733": {"name": "会昌县", "alpha": "h"},
    "360734": {"name": "寻乌县", "alpha": "x"},
    "360735": {"name": "石城县", "alpha": "s"},
    "360781": {"name": "瑞金", "alpha": "r"}
  },
  "360800": {
    "360802": {"name": "吉州区", "alpha": "j"},
    "360803": {"name": "青原区", "alpha": "q"},
    "360821": {"name": "吉安县", "alpha": "j"},
    "360822": {"name": "吉水县", "alpha": "j"},
    "360823": {"name": "峡江县", "alpha": "x"},
    "360824": {"name": "新干县", "alpha": "x"},
    "360825": {"name": "永丰县", "alpha": "y"},
    "360826": {"name": "泰和县", "alpha": "t"},
    "360827": {"name": "遂川县", "alpha": "s"},
    "360828": {"name": "万安县", "alpha": "w"},
    "360829": {"name": "安福县", "alpha": "a"},
    "360830": {"name": "永新县", "alpha": "y"},
    "360881": {"name": "井冈山", "alpha": "j"}
  },
  "360900": {
    "360902": {"name": "袁州区", "alpha": "y"},
    "360921": {"name": "奉新县", "alpha": "f"},
    "360922": {"name": "万载县", "alpha": "w"},
    "360923": {"name": "上高县", "alpha": "s"},
    "360924": {"name": "宜丰县", "alpha": "y"},
    "360925": {"name": "靖安县", "alpha": "j"},
    "360926": {"name": "铜鼓县", "alpha": "t"},
    "360981": {"name": "丰城", "alpha": "f"},
    "360982": {"name": "樟树", "alpha": "z"},
    "360983": {"name": "高安", "alpha": "g"}
  },
  "361000": {
    "361002": {"name": "临川区", "alpha": "l"},
    "361003": {"name": "东乡区", "alpha": "d"},
    "361021": {"name": "南城县", "alpha": "n"},
    "361022": {"name": "黎川县", "alpha": "l"},
    "361023": {"name": "南丰县", "alpha": "n"},
    "361024": {"name": "崇仁县", "alpha": "c"},
    "361025": {"name": "乐安县", "alpha": "l"},
    "361026": {"name": "宜黄县", "alpha": "y"},
    "361027": {"name": "金溪县", "alpha": "j"},
    "361028": {"name": "资溪县", "alpha": "z"},
    "361030": {"name": "广昌县", "alpha": "g"}
  },
  "361100": {
    "361102": {"name": "信州区", "alpha": "x"},
    "361103": {"name": "广丰区", "alpha": "g"},
    "361121": {"name": "上饶县", "alpha": "s"},
    "361123": {"name": "玉山县", "alpha": "y"},
    "361124": {"name": "铅山县", "alpha": "q"},
    "361125": {"name": "横峰县", "alpha": "h"},
    "361126": {"name": "弋阳县", "alpha": "y"},
    "361127": {"name": "余干县", "alpha": "y"},
    "361128": {"name": "鄱阳县", "alpha": "p"},
    "361129": {"name": "万年县", "alpha": "w"},
    "361130": {"name": "婺源县", "alpha": "w"},
    "361181": {"name": "德兴", "alpha": "d"}
  },
  "370100": {
    "370102": {"name": "历下区", "alpha": "l"},
    "370103": {"name": "中区", "alpha": "s"},
    "370104": {"name": "槐荫区", "alpha": "h"},
    "370105": {"name": "天桥区", "alpha": "t"},
    "370112": {"name": "历城区", "alpha": "l"},
    "370113": {"name": "长清区", "alpha": "c"},
    "370114": {"name": "章丘区", "alpha": "z"},
    "370115": {"name": "济阳区", "alpha": "j"},
    "370124": {"name": "平阴县", "alpha": "p"},
    "370126": {"name": "商河县", "alpha": "s"},
    "370171": {"name": "济南高新技术产业开发区", "alpha": "j"}
  },
  "370200": {
    "370202": {"name": "南区", "alpha": "s"},
    "370203": {"name": "北区", "alpha": "s"},
    "370211": {"name": "黄岛区", "alpha": "h"},
    "370212": {"name": "崂山区", "alpha": "l"},
    "370213": {"name": "李沧区", "alpha": "l"},
    "370214": {"name": "城阳区", "alpha": "c"},
    "370215": {"name": "即墨区", "alpha": "j"},
    "370271": {"name": "青岛高新技术产业开发区", "alpha": "q"},
    "370281": {"name": "胶州", "alpha": "j"},
    "370283": {"name": "平度", "alpha": "p"},
    "370285": {"name": "莱西", "alpha": "l"}
  },
  "370300": {
    "370302": {"name": "淄川区", "alpha": "z"},
    "370303": {"name": "张店区", "alpha": "z"},
    "370304": {"name": "博山区", "alpha": "b"},
    "370305": {"name": "临淄区", "alpha": "l"},
    "370306": {"name": "周村区", "alpha": "z"},
    "370321": {"name": "桓台县", "alpha": "h"},
    "370322": {"name": "高青县", "alpha": "g"},
    "370323": {"name": "沂源县", "alpha": "y"}
  },
  "370400": {
    "370402": {"name": "中区", "alpha": "s"},
    "370403": {"name": "薛城区", "alpha": "x"},
    "370404": {"name": "峄城区", "alpha": "y"},
    "370405": {"name": "台儿庄区", "alpha": "t"},
    "370406": {"name": "山亭区", "alpha": "s"},
    "370481": {"name": "滕州", "alpha": "t"}
  },
  "370500": {
    "370502": {"name": "东营区", "alpha": "d"},
    "370503": {"name": "河口区", "alpha": "h"},
    "370505": {"name": "垦利区", "alpha": "k"},
    "370522": {"name": "利津县", "alpha": "l"},
    "370523": {"name": "广饶县", "alpha": "g"},
    "370571": {"name": "东营经济技术开发区", "alpha": "d"},
    "370572": {"name": "东营港经济开发区", "alpha": "d"}
  },
  "370600": {
    "370602": {"name": "芝罘区", "alpha": "z"},
    "370611": {"name": "福山区", "alpha": "f"},
    "370612": {"name": "牟平区", "alpha": "m"},
    "370613": {"name": "莱山区", "alpha": "l"},
    "370634": {"name": "长岛县", "alpha": "c"},
    "370671": {"name": "烟台高新技术产业开发区", "alpha": "y"},
    "370672": {"name": "烟台经济技术开发区", "alpha": "y"},
    "370681": {"name": "龙口", "alpha": "l"},
    "370682": {"name": "莱阳", "alpha": "l"},
    "370683": {"name": "莱州", "alpha": "l"},
    "370684": {"name": "蓬莱", "alpha": "p"},
    "370685": {"name": "招远", "alpha": "z"},
    "370686": {"name": "栖霞", "alpha": "q"},
    "370687": {"name": "海阳", "alpha": "h"}
  },
  "370700": {
    "370702": {"name": "潍城区", "alpha": "w"},
    "370703": {"name": "寒亭区", "alpha": "h"},
    "370704": {"name": "坊子区", "alpha": "f"},
    "370705": {"name": "奎文区", "alpha": "k"},
    "370724": {"name": "临朐县", "alpha": "l"},
    "370725": {"name": "昌乐县", "alpha": "c"},
    "370772": {"name": "潍坊滨海经济技术开发区", "alpha": "w"},
    "370781": {"name": "青州", "alpha": "q"},
    "370782": {"name": "诸城", "alpha": "z"},
    "370783": {"name": "寿光", "alpha": "s"},
    "370784": {"name": "安丘", "alpha": "a"},
    "370785": {"name": "高密", "alpha": "g"},
    "370786": {"name": "昌邑", "alpha": "c"}
  },
  "370800": {
    "370811": {"name": "任城区", "alpha": "r"},
    "370812": {"name": "兖州区", "alpha": "y"},
    "370826": {"name": "微山县", "alpha": "w"},
    "370827": {"name": "鱼台县", "alpha": "y"},
    "370828": {"name": "金乡县", "alpha": "j"},
    "370829": {"name": "嘉祥县", "alpha": "j"},
    "370830": {"name": "汶上县", "alpha": "w"},
    "370831": {"name": "泗水县", "alpha": "s"},
    "370832": {"name": "梁山县", "alpha": "l"},
    "370871": {"name": "济宁高新技术产业开发区", "alpha": "j"},
    "370881": {"name": "曲阜", "alpha": "q"},
    "370883": {"name": "邹城", "alpha": "z"}
  },
  "370900": {
    "370902": {"name": "泰山区", "alpha": "t"},
    "370911": {"name": "岱岳区", "alpha": "d"},
    "370921": {"name": "宁阳县", "alpha": "n"},
    "370923": {"name": "东平县", "alpha": "d"},
    "370982": {"name": "新泰", "alpha": "x"},
    "370983": {"name": "肥城", "alpha": "f"}
  },
  "371000": {
    "371002": {"name": "环翠区", "alpha": "h"},
    "371003": {"name": "文登区", "alpha": "w"},
    "371071": {"name": "威海火炬高技术产业开发区", "alpha": "w"},
    "371072": {"name": "威海经济技术开发区", "alpha": "w"},
    "371073": {"name": "威海临港经济技术开发区", "alpha": "w"},
    "371082": {"name": "荣成", "alpha": "r"},
    "371083": {"name": "乳山", "alpha": "r"}
  },
  "371100": {
    "371102": {"name": "东港区", "alpha": "d"},
    "371103": {"name": "岚山区", "alpha": "l"},
    "371121": {"name": "五莲县", "alpha": "w"},
    "371122": {"name": "莒县", "alpha": "j"},
    "371171": {"name": "日照经济技术开发区", "alpha": "r"}
  },
  "371200": {
    "371202": {"name": "莱城区", "alpha": "l"},
    "371203": {"name": "钢城区", "alpha": "g"}
  },
  "371300": {
    "371302": {"name": "兰山区", "alpha": "l"},
    "371311": {"name": "罗庄区", "alpha": "l"},
    "371312": {"name": "河东区", "alpha": "h"},
    "371321": {"name": "沂南县", "alpha": "y"},
    "371322": {"name": "郯城县", "alpha": "t"},
    "371323": {"name": "沂水县", "alpha": "y"},
    "371324": {"name": "兰陵县", "alpha": "l"},
    "371325": {"name": "费县", "alpha": "f"},
    "371326": {"name": "平邑县", "alpha": "p"},
    "371327": {"name": "莒南县", "alpha": "j"},
    "371328": {"name": "蒙阴县", "alpha": "m"},
    "371329": {"name": "临沭县", "alpha": "l"},
    "371371": {"name": "临沂高新技术产业开发区", "alpha": "l"},
    "371372": {"name": "临沂经济技术开发区", "alpha": "l"},
    "371373": {"name": "临沂临港经济开发区", "alpha": "l"}
  },
  "371400": {
    "371402": {"name": "德城区", "alpha": "d"},
    "371403": {"name": "陵城区", "alpha": "l"},
    "371422": {"name": "宁津县", "alpha": "n"},
    "371423": {"name": "庆云县", "alpha": "q"},
    "371424": {"name": "临邑县", "alpha": "l"},
    "371425": {"name": "齐河县", "alpha": "q"},
    "371426": {"name": "平原县", "alpha": "p"},
    "371427": {"name": "夏津县", "alpha": "x"},
    "371428": {"name": "武城县", "alpha": "w"},
    "371471": {"name": "德州经济技术开发区", "alpha": "d"},
    "371472": {"name": "德州运河经济开发区", "alpha": "d"},
    "371481": {"name": "乐陵", "alpha": "l"},
    "371482": {"name": "禹城", "alpha": "y"}
  },
  "371500": {
    "371502": {"name": "东昌府区", "alpha": "d"},
    "371521": {"name": "阳谷县", "alpha": "y"},
    "371522": {"name": "莘县", "alpha": "s"},
    "371523": {"name": "茌平县", "alpha": "c"},
    "371524": {"name": "东阿县", "alpha": "d"},
    "371525": {"name": "冠县", "alpha": "g"},
    "371526": {"name": "高唐县", "alpha": "g"},
    "371581": {"name": "临清", "alpha": "l"}
  },
  "371600": {
    "371602": {"name": "滨城区", "alpha": "b"},
    "371603": {"name": "沾化区", "alpha": "z"},
    "371621": {"name": "惠民县", "alpha": "h"},
    "371622": {"name": "阳信县", "alpha": "y"},
    "371623": {"name": "无棣县", "alpha": "w"},
    "371625": {"name": "博兴县", "alpha": "b"},
    "371681": {"name": "邹平", "alpha": "z"}
  },
  "371700": {
    "371702": {"name": "牡丹区", "alpha": "m"},
    "371703": {"name": "定陶区", "alpha": "d"},
    "371721": {"name": "曹县", "alpha": "c"},
    "371722": {"name": "单县", "alpha": "d"},
    "371723": {"name": "成武县", "alpha": "c"},
    "371724": {"name": "巨野县", "alpha": "j"},
    "371725": {"name": "郓城县", "alpha": "y"},
    "371726": {"name": "鄄城县", "alpha": "j"},
    "371728": {"name": "东明县", "alpha": "d"},
    "371771": {"name": "菏泽经济技术开发区", "alpha": "h"},
    "371772": {"name": "菏泽高新技术开发区", "alpha": "h"}
  },
  "410100": {
    "410102": {"name": "中原区", "alpha": "z"},
    "410103": {"name": "二七区", "alpha": "e"},
    "410104": {"name": "管城回族区", "alpha": "g"},
    "410105": {"name": "金水区", "alpha": "j"},
    "410106": {"name": "上街区", "alpha": "s"},
    "410108": {"name": "惠济区", "alpha": "h"},
    "410122": {"name": "中牟县", "alpha": "z"},
    "410171": {"name": "郑州经济技术开发区", "alpha": "z"},
    "410172": {"name": "郑州高新技术产业开发区", "alpha": "z"},
    "410173": {"name": "郑州航空港经济综合实验区", "alpha": "z"},
    "410181": {"name": "巩义", "alpha": "g"},
    "410182": {"name": "荥阳", "alpha": "x"},
    "410183": {"name": "新密", "alpha": "x"},
    "410184": {"name": "新郑", "alpha": "x"},
    "410185": {"name": "登封", "alpha": "d"}
  },
  "410200": {
    "410202": {"name": "龙亭区", "alpha": "l"},
    "410203": {"name": "顺河回族区", "alpha": "s"},
    "410204": {"name": "鼓楼区", "alpha": "g"},
    "410205": {"name": "禹王台区", "alpha": "y"},
    "410212": {"name": "祥符区", "alpha": "x"},
    "410221": {"name": "杞县", "alpha": "q"},
    "410222": {"name": "通许县", "alpha": "t"},
    "410223": {"name": "尉氏县", "alpha": "w"},
    "410225": {"name": "兰考县", "alpha": "l"}
  },
  "410300": {
    "410302": {"name": "老城区", "alpha": "l"},
    "410303": {"name": "西工区", "alpha": "x"},
    "410304": {"name": "瀍河回族区", "alpha": "c"},
    "410305": {"name": "涧西区", "alpha": "j"},
    "410306": {"name": "吉利区", "alpha": "j"},
    "410311": {"name": "洛龙区", "alpha": "l"},
    "410322": {"name": "孟津县", "alpha": "m"},
    "410323": {"name": "新安县", "alpha": "x"},
    "410324": {"name": "栾川县", "alpha": "l"},
    "410325": {"name": "嵩县", "alpha": "s"},
    "410326": {"name": "汝阳县", "alpha": "r"},
    "410327": {"name": "宜阳县", "alpha": "y"},
    "410328": {"name": "洛宁县", "alpha": "l"},
    "410329": {"name": "伊川县", "alpha": "y"},
    "410371": {"name": "洛阳高新技术产业开发区", "alpha": "l"},
    "410381": {"name": "偃师", "alpha": "y"}
  },
  "410400": {
    "410402": {"name": "新华区", "alpha": "x"},
    "410403": {"name": "卫东区", "alpha": "w"},
    "410404": {"name": "石龙区", "alpha": "s"},
    "410411": {"name": "湛河区", "alpha": "z"},
    "410421": {"name": "宝丰县", "alpha": "b"},
    "410422": {"name": "叶县", "alpha": "y"},
    "410423": {"name": "鲁山县", "alpha": "l"},
    "410425": {"name": "郏县", "alpha": "j"},
    "410471": {"name": "平顶山高新技术产业开发区", "alpha": "p"},
    "410472": {"name": "平顶山新城区", "alpha": "p"},
    "410481": {"name": "舞钢", "alpha": "w"},
    "410482": {"name": "汝州", "alpha": "r"}
  },
  "410500": {
    "410502": {"name": "文峰区", "alpha": "w"},
    "410503": {"name": "北关区", "alpha": "b"},
    "410505": {"name": "殷都区", "alpha": "y"},
    "410506": {"name": "龙安区", "alpha": "l"},
    "410522": {"name": "安阳县", "alpha": "a"},
    "410523": {"name": "汤阴县", "alpha": "t"},
    "410526": {"name": "滑县", "alpha": "h"},
    "410527": {"name": "内黄县", "alpha": "n"},
    "410571": {"name": "安阳高新技术产业开发区", "alpha": "a"},
    "410581": {"name": "林州", "alpha": "l"}
  },
  "410600": {
    "410602": {"name": "鹤山区", "alpha": "h"},
    "410603": {"name": "山城区", "alpha": "s"},
    "410611": {"name": "淇滨区", "alpha": "q"},
    "410621": {"name": "浚县", "alpha": "j"},
    "410622": {"name": "淇县", "alpha": "q"},
    "410671": {"name": "鹤壁经济技术开发区", "alpha": "h"}
  },
  "410700": {
    "410702": {"name": "红旗区", "alpha": "h"},
    "410703": {"name": "卫滨区", "alpha": "w"},
    "410704": {"name": "凤泉区", "alpha": "f"},
    "410711": {"name": "牧野区", "alpha": "m"},
    "410721": {"name": "新乡县", "alpha": "x"},
    "410724": {"name": "获嘉县", "alpha": "h"},
    "410725": {"name": "原阳县", "alpha": "y"},
    "410726": {"name": "延津县", "alpha": "y"},
    "410727": {"name": "封丘县", "alpha": "f"},
    "410728": {"name": "长垣县", "alpha": "c"},
    "410771": {"name": "新乡高新技术产业开发区", "alpha": "x"},
    "410772": {"name": "新乡经济技术开发区", "alpha": "x"},
    "410773": {"name": "新乡平原城乡一体化示范区", "alpha": "x"},
    "410781": {"name": "卫辉", "alpha": "w"},
    "410782": {"name": "辉县", "alpha": "h"}
  },
  "410800": {
    "410802": {"name": "解放区", "alpha": "j"},
    "410803": {"name": "中站区", "alpha": "z"},
    "410804": {"name": "马村区", "alpha": "m"},
    "410811": {"name": "山阳区", "alpha": "s"},
    "410821": {"name": "修武县", "alpha": "x"},
    "410822": {"name": "博爱县", "alpha": "b"},
    "410823": {"name": "武陟县", "alpha": "w"},
    "410825": {"name": "温县", "alpha": "w"},
    "410871": {"name": "焦作城乡一体化示范区", "alpha": "j"},
    "410882": {"name": "沁阳", "alpha": "q"},
    "410883": {"name": "孟州", "alpha": "m"}
  },
  "410900": {
    "410902": {"name": "华龙区", "alpha": "h"},
    "410922": {"name": "清丰县", "alpha": "q"},
    "410923": {"name": "南乐县", "alpha": "n"},
    "410926": {"name": "范县", "alpha": "f"},
    "410927": {"name": "台前县", "alpha": "t"},
    "410928": {"name": "濮阳县", "alpha": "p"},
    "410971": {"name": "河南濮阳工业园区", "alpha": "h"},
    "410972": {"name": "濮阳经济技术开发区", "alpha": "p"}
  },
  "411000": {
    "411002": {"name": "魏都区", "alpha": "w"},
    "411003": {"name": "建安区", "alpha": "j"},
    "411024": {"name": "鄢陵县", "alpha": "y"},
    "411025": {"name": "襄城县", "alpha": "x"},
    "411071": {"name": "许昌经济技术开发区", "alpha": "x"},
    "411081": {"name": "禹州", "alpha": "y"},
    "411082": {"name": "长葛", "alpha": "c"}
  },
  "411100": {
    "411102": {"name": "源汇区", "alpha": "y"},
    "411103": {"name": "郾城区", "alpha": "y"},
    "411104": {"name": "召陵区", "alpha": "z"},
    "411121": {"name": "舞阳县", "alpha": "w"},
    "411122": {"name": "临颍县", "alpha": "l"},
    "411171": {"name": "漯河经济技术开发区", "alpha": "l"}
  },
  "411200": {
    "411202": {"name": "湖滨区", "alpha": "h"},
    "411203": {"name": "陕州区", "alpha": "s"},
    "411221": {"name": "渑池县", "alpha": "m"},
    "411224": {"name": "卢氏县", "alpha": "l"},
    "411271": {"name": "河南三门峡经济开发区", "alpha": "h"},
    "411281": {"name": "义马", "alpha": "y"},
    "411282": {"name": "灵宝", "alpha": "l"}
  },
  "411300": {
    "411302": {"name": "宛城区", "alpha": "w"},
    "411303": {"name": "卧龙区", "alpha": "w"},
    "411321": {"name": "南召县", "alpha": "n"},
    "411322": {"name": "方城县", "alpha": "f"},
    "411323": {"name": "西峡县", "alpha": "x"},
    "411324": {"name": "镇平县", "alpha": "z"},
    "411325": {"name": "内乡县", "alpha": "n"},
    "411326": {"name": "淅川县", "alpha": "x"},
    "411327": {"name": "社旗县", "alpha": "s"},
    "411328": {"name": "唐河县", "alpha": "t"},
    "411329": {"name": "新野县", "alpha": "x"},
    "411330": {"name": "桐柏县", "alpha": "t"},
    "411371": {"name": "南阳高新技术产业开发区", "alpha": "n"},
    "411372": {"name": "南阳城乡一体化示范区", "alpha": "n"},
    "411381": {"name": "邓州", "alpha": "d"}
  },
  "411400": {
    "411402": {"name": "梁园区", "alpha": "l"},
    "411403": {"name": "睢阳区", "alpha": "h"},
    "411421": {"name": "民权县", "alpha": "m"},
    "411422": {"name": "睢县", "alpha": "h"},
    "411423": {"name": "宁陵县", "alpha": "n"},
    "411424": {"name": "柘城县", "alpha": "z"},
    "411425": {"name": "虞城县", "alpha": "y"},
    "411426": {"name": "夏邑县", "alpha": "x"},
    "411471": {"name": "豫东综合物流产业聚集区", "alpha": "y"},
    "411472": {"name": "河南商丘经济开发区", "alpha": "h"},
    "411481": {"name": "永城", "alpha": "y"}
  },
  "411500": {
    "411502": {"name": "浉河区", "alpha": "s"},
    "411503": {"name": "平桥区", "alpha": "p"},
    "411521": {"name": "罗山县", "alpha": "l"},
    "411522": {"name": "光山县", "alpha": "g"},
    "411523": {"name": "新县", "alpha": "x"},
    "411524": {"name": "商城县", "alpha": "s"},
    "411525": {"name": "固始县", "alpha": "g"},
    "411526": {"name": "潢川县", "alpha": "h"},
    "411527": {"name": "淮滨县", "alpha": "h"},
    "411528": {"name": "息县", "alpha": "x"},
    "411571": {"name": "信阳高新技术产业开发区", "alpha": "x"}
  },
  "411600": {
    "411602": {"name": "川汇区", "alpha": "c"},
    "411621": {"name": "扶沟县", "alpha": "f"},
    "411622": {"name": "西华县", "alpha": "x"},
    "411623": {"name": "商水县", "alpha": "s"},
    "411624": {"name": "沈丘县", "alpha": "s"},
    "411625": {"name": "郸城县", "alpha": "d"},
    "411626": {"name": "淮阳县", "alpha": "h"},
    "411627": {"name": "太康县", "alpha": "t"},
    "411628": {"name": "鹿邑县", "alpha": "l"},
    "411671": {"name": "河南周口经济开发区", "alpha": "h"},
    "411681": {"name": "项城", "alpha": "x"}
  },
  "411700": {
    "411702": {"name": "驿城区", "alpha": "y"},
    "411721": {"name": "西平县", "alpha": "x"},
    "411722": {"name": "上蔡县", "alpha": "s"},
    "411723": {"name": "平舆县", "alpha": "p"},
    "411724": {"name": "正阳县", "alpha": "z"},
    "411725": {"name": "确山县", "alpha": "q"},
    "411726": {"name": "泌阳县", "alpha": "b"},
    "411727": {"name": "汝南县", "alpha": "r"},
    "411728": {"name": "遂平县", "alpha": "s"},
    "411729": {"name": "新蔡县", "alpha": "x"},
    "411771": {"name": "河南驻马店经济开发区", "alpha": "h"}
  },
  "419000": {
    "419000": {"name": "济源", "alpha": "j"},
    "419001": {"name": "济源", "alpha": "j"}
  },
  "420100": {
    "420102": {"name": "江岸区", "alpha": "j"},
    "420103": {"name": "江汉区", "alpha": "j"},
    "420104": {"name": "硚口区", "alpha": "q"},
    "420105": {"name": "汉阳区", "alpha": "h"},
    "420106": {"name": "武昌区", "alpha": "w"},
    "420107": {"name": "青山区", "alpha": "q"},
    "420111": {"name": "洪山区", "alpha": "h"},
    "420112": {"name": "东西湖区", "alpha": "d"},
    "420113": {"name": "汉南区", "alpha": "h"},
    "420114": {"name": "蔡甸区", "alpha": "c"},
    "420115": {"name": "江夏区", "alpha": "j"},
    "420116": {"name": "黄陂区", "alpha": "h"},
    "420117": {"name": "新洲区", "alpha": "x"}
  },
  "420200": {
    "420202": {"name": "黄石港区", "alpha": "h"},
    "420203": {"name": "西塞山区", "alpha": "x"},
    "420204": {"name": "下陆区", "alpha": "x"},
    "420205": {"name": "铁山区", "alpha": "t"},
    "420222": {"name": "阳新县", "alpha": "y"},
    "420281": {"name": "大冶", "alpha": "d"}
  },
  "420300": {
    "420302": {"name": "茅箭区", "alpha": "m"},
    "420303": {"name": "张湾区", "alpha": "z"},
    "420304": {"name": "郧阳区", "alpha": "y"},
    "420322": {"name": "郧西县", "alpha": "y"},
    "420323": {"name": "竹山县", "alpha": "z"},
    "420324": {"name": "竹溪县", "alpha": "z"},
    "420325": {"name": "房县", "alpha": "f"},
    "420381": {"name": "丹江口", "alpha": "d"}
  },
  "420500": {
    "420502": {"name": "西陵区", "alpha": "x"},
    "420503": {"name": "伍家岗区", "alpha": "w"},
    "420504": {"name": "点军区", "alpha": "d"},
    "420505": {"name": "猇亭区", "alpha": "x"},
    "420506": {"name": "夷陵区", "alpha": "y"},
    "420525": {"name": "远安县", "alpha": "y"},
    "420526": {"name": "兴山县", "alpha": "x"},
    "420527": {"name": "秭归县", "alpha": "z"},
    "420528": {"name": "长阳土家族自治县", "alpha": "c"},
    "420529": {"name": "五峰土家族自治县", "alpha": "w"},
    "420581": {"name": "宜都", "alpha": "y"},
    "420582": {"name": "当阳", "alpha": "d"},
    "420583": {"name": "枝江", "alpha": "z"}
  },
  "420600": {
    "420602": {"name": "襄城区", "alpha": "x"},
    "420606": {"name": "樊城区", "alpha": "f"},
    "420607": {"name": "襄州区", "alpha": "x"},
    "420624": {"name": "南漳县", "alpha": "n"},
    "420625": {"name": "谷城县", "alpha": "g"},
    "420626": {"name": "保康县", "alpha": "b"},
    "420682": {"name": "老河口", "alpha": "l"},
    "420683": {"name": "枣阳", "alpha": "z"},
    "420684": {"name": "宜城", "alpha": "y"}
  },
  "420700": {
    "420702": {"name": "梁子湖区", "alpha": "l"},
    "420703": {"name": "华容区", "alpha": "h"},
    "420704": {"name": "鄂城区", "alpha": "e"}
  },
  "420800": {
    "420802": {"name": "东宝区", "alpha": "d"},
    "420804": {"name": "掇刀区", "alpha": "d"},
    "420822": {"name": "沙洋县", "alpha": "s"},
    "420881": {"name": "钟祥", "alpha": "z"},
    "420882": {"name": "京山", "alpha": "j"}
  },
  "420900": {
    "420902": {"name": "孝南区", "alpha": "x"},
    "420921": {"name": "孝昌县", "alpha": "x"},
    "420922": {"name": "大悟县", "alpha": "d"},
    "420923": {"name": "云梦县", "alpha": "y"},
    "420981": {"name": "应城", "alpha": "y"},
    "420982": {"name": "安陆", "alpha": "a"},
    "420984": {"name": "汉川", "alpha": "h"}
  },
  "421000": {
    "421002": {"name": "沙区", "alpha": "s"},
    "421003": {"name": "荆州区", "alpha": "j"},
    "421022": {"name": "公安县", "alpha": "g"},
    "421023": {"name": "监利县", "alpha": "j"},
    "421024": {"name": "江陵县", "alpha": "j"},
    "421071": {"name": "荆州经济技术开发区", "alpha": "j"},
    "421081": {"name": "石首", "alpha": "s"},
    "421083": {"name": "洪湖", "alpha": "h"},
    "421087": {"name": "松滋", "alpha": "s"}
  },
  "421100": {
    "421102": {"name": "黄州区", "alpha": "h"},
    "421121": {"name": "团风县", "alpha": "t"},
    "421122": {"name": "红安县", "alpha": "h"},
    "421123": {"name": "罗田县", "alpha": "l"},
    "421124": {"name": "英山县", "alpha": "y"},
    "421125": {"name": "浠水县", "alpha": "x"},
    "421126": {"name": "蕲春县", "alpha": "q"},
    "421127": {"name": "黄梅县", "alpha": "h"},
    "421171": {"name": "龙感湖管理区", "alpha": "l"},
    "421181": {"name": "麻城", "alpha": "m"},
    "421182": {"name": "武穴", "alpha": "w"}
  },
  "421200": {
    "421202": {"name": "咸安区", "alpha": "x"},
    "421221": {"name": "嘉鱼县", "alpha": "j"},
    "421222": {"name": "通城县", "alpha": "t"},
    "421223": {"name": "崇阳县", "alpha": "c"},
    "421224": {"name": "通山县", "alpha": "t"},
    "421281": {"name": "赤壁", "alpha": "c"}
  },
  "421300": {
    "421303": {"name": "曾都区", "alpha": "c"},
    "421321": {"name": "随县", "alpha": "s"},
    "421381": {"name": "广水", "alpha": "g"}
  },
  "422800": {
    "422801": {"name": "恩施", "alpha": "e"},
    "422802": {"name": "利川", "alpha": "l"},
    "422822": {"name": "建始县", "alpha": "j"},
    "422823": {"name": "巴东县", "alpha": "b"},
    "422825": {"name": "宣恩县", "alpha": "x"},
    "422826": {"name": "咸丰县", "alpha": "x"},
    "422827": {"name": "来凤县", "alpha": "l"},
    "422828": {"name": "鹤峰县", "alpha": "h"}
  },
  "429000": {
    "429004": {"name": "仙桃", "alpha": "x"},
    "429005": {"name": "潜江", "alpha": "q"},
    "429006": {"name": "天门", "alpha": "t"},
    "429021": {"name": "神农架林区", "alpha": "s"}
  },
  "430100": {
    "430102": {"name": "芙蓉区", "alpha": "f"},
    "430103": {"name": "天心区", "alpha": "t"},
    "430104": {"name": "岳麓区", "alpha": "y"},
    "430105": {"name": "开福区", "alpha": "k"},
    "430111": {"name": "雨花区", "alpha": "y"},
    "430112": {"name": "望城区", "alpha": "w"},
    "430121": {"name": "长沙县", "alpha": "c"},
    "430181": {"name": "浏阳", "alpha": "l"},
    "430182": {"name": "宁乡", "alpha": "n"}
  },
  "430200": {
    "430202": {"name": "荷塘区", "alpha": "h"},
    "430203": {"name": "芦淞区", "alpha": "l"},
    "430204": {"name": "石峰区", "alpha": "s"},
    "430211": {"name": "天元区", "alpha": "t"},
    "430212": {"name": "渌口区", "alpha": "l"},
    "430223": {"name": "攸县", "alpha": "y"},
    "430224": {"name": "茶陵县", "alpha": "c"},
    "430225": {"name": "炎陵县", "alpha": "y"},
    "430271": {"name": "云龙示范区", "alpha": "y"},
    "430281": {"name": "醴陵", "alpha": "l"}
  },
  "430300": {
    "430302": {"name": "雨湖区", "alpha": "y"},
    "430304": {"name": "岳塘区", "alpha": "y"},
    "430321": {"name": "湘潭县", "alpha": "x"},
    "430371": {"name": "湖南湘潭高新技术产业园区", "alpha": "h"},
    "430372": {"name": "湘潭昭山示范区", "alpha": "x"},
    "430373": {"name": "湘潭九华示范区", "alpha": "x"},
    "430381": {"name": "湘乡", "alpha": "x"},
    "430382": {"name": "韶山", "alpha": "s"}
  },
  "430400": {
    "430405": {"name": "珠晖区", "alpha": "z"},
    "430406": {"name": "雁峰区", "alpha": "y"},
    "430407": {"name": "石鼓区", "alpha": "s"},
    "430408": {"name": "蒸湘区", "alpha": "z"},
    "430412": {"name": "南岳区", "alpha": "n"},
    "430421": {"name": "衡阳县", "alpha": "h"},
    "430422": {"name": "衡南县", "alpha": "h"},
    "430423": {"name": "衡山县", "alpha": "h"},
    "430424": {"name": "衡东县", "alpha": "h"},
    "430426": {"name": "祁东县", "alpha": "q"},
    "430471": {"name": "衡阳综合保税区", "alpha": "h"},
    "430472": {"name": "湖南衡阳高新技术产业园区", "alpha": "h"},
    "430473": {"name": "湖南衡阳松木经济开发区", "alpha": "h"},
    "430481": {"name": "耒阳", "alpha": "l"},
    "430482": {"name": "常宁", "alpha": "c"}
  },
  "430500": {
    "430502": {"name": "双清区", "alpha": "s"},
    "430503": {"name": "大祥区", "alpha": "d"},
    "430511": {"name": "北塔区", "alpha": "b"},
    "430521": {"name": "邵东县", "alpha": "s"},
    "430522": {"name": "新邵县", "alpha": "x"},
    "430523": {"name": "邵阳县", "alpha": "s"},
    "430524": {"name": "隆回县", "alpha": "l"},
    "430525": {"name": "洞口县", "alpha": "d"},
    "430527": {"name": "绥宁县", "alpha": "s"},
    "430528": {"name": "新宁县", "alpha": "x"},
    "430529": {"name": "城步苗族自治县", "alpha": "c"},
    "430581": {"name": "武冈", "alpha": "w"}
  },
  "430600": {
    "430602": {"name": "岳阳楼区", "alpha": "y"},
    "430603": {"name": "云溪区", "alpha": "y"},
    "430611": {"name": "君山区", "alpha": "j"},
    "430621": {"name": "岳阳县", "alpha": "y"},
    "430623": {"name": "华容县", "alpha": "h"},
    "430624": {"name": "湘阴县", "alpha": "x"},
    "430626": {"name": "平江县", "alpha": "p"},
    "430671": {"name": "岳阳屈原管理区", "alpha": "y"},
    "430681": {"name": "汨罗", "alpha": "m"},
    "430682": {"name": "临湘", "alpha": "l"}
  },
  "430700": {
    "430702": {"name": "武陵区", "alpha": "w"},
    "430703": {"name": "鼎城区", "alpha": "d"},
    "430721": {"name": "安乡县", "alpha": "a"},
    "430722": {"name": "汉寿县", "alpha": "h"},
    "430723": {"name": "澧县", "alpha": "l"},
    "430724": {"name": "临澧县", "alpha": "l"},
    "430725": {"name": "桃源县", "alpha": "t"},
    "430726": {"name": "石门县", "alpha": "s"},
    "430771": {"name": "常德西洞庭管理区", "alpha": "c"},
    "430781": {"name": "津", "alpha": "j"}
  },
  "430800": {
    "430802": {"name": "永定区", "alpha": "y"},
    "430811": {"name": "武陵源区", "alpha": "w"},
    "430821": {"name": "慈利县", "alpha": "c"},
    "430822": {"name": "桑植县", "alpha": "s"}
  },
  "430900": {
    "430902": {"name": "资阳区", "alpha": "z"},
    "430903": {"name": "赫山区", "alpha": "h"},
    "430921": {"name": "南县", "alpha": "n"},
    "430922": {"name": "桃江县", "alpha": "t"},
    "430923": {"name": "安化县", "alpha": "a"},
    "430971": {"name": "益阳大通湖管理区", "alpha": "y"},
    "430972": {"name": "湖南益阳高新技术产业园区", "alpha": "h"},
    "430981": {"name": "沅江", "alpha": "y"}
  },
  "431000": {
    "431002": {"name": "北湖区", "alpha": "b"},
    "431003": {"name": "苏仙区", "alpha": "s"},
    "431021": {"name": "桂阳县", "alpha": "g"},
    "431022": {"name": "宜章县", "alpha": "y"},
    "431023": {"name": "永兴县", "alpha": "y"},
    "431024": {"name": "嘉禾县", "alpha": "j"},
    "431025": {"name": "临武县", "alpha": "l"},
    "431026": {"name": "汝城县", "alpha": "r"},
    "431027": {"name": "桂东县", "alpha": "g"},
    "431028": {"name": "安仁县", "alpha": "a"},
    "431081": {"name": "资兴", "alpha": "z"}
  },
  "431100": {
    "431102": {"name": "零陵区", "alpha": "l"},
    "431103": {"name": "冷水滩区", "alpha": "l"},
    "431121": {"name": "祁阳县", "alpha": "q"},
    "431122": {"name": "东安县", "alpha": "d"},
    "431123": {"name": "双牌县", "alpha": "s"},
    "431124": {"name": "道县", "alpha": "d"},
    "431125": {"name": "江永县", "alpha": "j"},
    "431126": {"name": "宁远县", "alpha": "n"},
    "431127": {"name": "蓝山县", "alpha": "l"},
    "431128": {"name": "新田县", "alpha": "x"},
    "431129": {"name": "江华瑶族自治县", "alpha": "j"},
    "431171": {"name": "永州经济技术开发区", "alpha": "y"},
    "431172": {"name": "永州金洞管理区", "alpha": "y"},
    "431173": {"name": "永州回龙圩管理区", "alpha": "y"}
  },
  "431200": {
    "431202": {"name": "鹤城区", "alpha": "h"},
    "431221": {"name": "中方县", "alpha": "z"},
    "431222": {"name": "沅陵县", "alpha": "y"},
    "431223": {"name": "辰溪县", "alpha": "c"},
    "431224": {"name": "溆浦县", "alpha": "x"},
    "431225": {"name": "会同县", "alpha": "h"},
    "431226": {"name": "麻阳苗族自治县", "alpha": "m"},
    "431227": {"name": "新晃侗族自治县", "alpha": "x"},
    "431228": {"name": "芷江侗族自治县", "alpha": "z"},
    "431229": {"name": "靖州苗族侗族自治县", "alpha": "j"},
    "431230": {"name": "通道侗族自治县", "alpha": "t"},
    "431271": {"name": "怀化洪江管理区", "alpha": "h"},
    "431281": {"name": "洪江", "alpha": "h"}
  },
  "431300": {
    "431302": {"name": "娄星区", "alpha": "l"},
    "431321": {"name": "双峰县", "alpha": "s"},
    "431322": {"name": "新化县", "alpha": "x"},
    "431381": {"name": "冷水江", "alpha": "l"},
    "431382": {"name": "涟源", "alpha": "l"}
  },
  "433100": {
    "433101": {"name": "吉首", "alpha": "j"},
    "433122": {"name": "泸溪县", "alpha": "l"},
    "433123": {"name": "凤凰县", "alpha": "f"},
    "433124": {"name": "花垣县", "alpha": "h"},
    "433125": {"name": "保靖县", "alpha": "b"},
    "433126": {"name": "古丈县", "alpha": "g"},
    "433127": {"name": "永顺县", "alpha": "y"},
    "433130": {"name": "龙山县", "alpha": "l"},
    "433172": {"name": "湖南吉首经济开发区", "alpha": "h"},
    "433173": {"name": "湖南永顺经济开发区", "alpha": "h"}
  },
  "440100": {
    "440103": {"name": "荔湾区", "alpha": "l"},
    "440104": {"name": "越秀区", "alpha": "y"},
    "440105": {"name": "海珠区", "alpha": "h"},
    "440106": {"name": "天河区", "alpha": "t"},
    "440111": {"name": "白云区", "alpha": "b"},
    "440112": {"name": "黄埔区", "alpha": "h"},
    "440113": {"name": "番禺区", "alpha": "f"},
    "440114": {"name": "花都区", "alpha": "h"},
    "440115": {"name": "南沙区", "alpha": "n"},
    "440117": {"name": "从化区", "alpha": "c"},
    "440118": {"name": "增城区", "alpha": "z"}
  },
  "440200": {
    "440203": {"name": "武江区", "alpha": "w"},
    "440204": {"name": "浈江区", "alpha": "z"},
    "440205": {"name": "曲江区", "alpha": "q"},
    "440222": {"name": "始兴县", "alpha": "s"},
    "440224": {"name": "仁化县", "alpha": "r"},
    "440229": {"name": "翁源县", "alpha": "w"},
    "440232": {"name": "乳源瑶族自治县", "alpha": "r"},
    "440233": {"name": "新丰县", "alpha": "x"},
    "440281": {"name": "乐昌", "alpha": "l"},
    "440282": {"name": "南雄", "alpha": "n"}
  },
  "440300": {
    "440303": {"name": "罗湖区", "alpha": "l"},
    "440304": {"name": "福田区", "alpha": "f"},
    "440305": {"name": "南山区", "alpha": "n"},
    "440306": {"name": "宝安区", "alpha": "b"},
    "440307": {"name": "龙岗区", "alpha": "l"},
    "440308": {"name": "盐田区", "alpha": "y"},
    "440309": {"name": "龙华区", "alpha": "l"},
    "440310": {"name": "坪山区", "alpha": "p"},
    "440311": {"name": "光明区", "alpha": "g"}
  },
  "440400": {
    "440402": {"name": "香洲区", "alpha": "x"},
    "440403": {"name": "斗门区", "alpha": "d"},
    "440404": {"name": "金湾区", "alpha": "j"}
  },
  "440500": {
    "440507": {"name": "龙湖区", "alpha": "l"},
    "440511": {"name": "金平区", "alpha": "j"},
    "440512": {"name": "濠江区", "alpha": "h"},
    "440513": {"name": "潮阳区", "alpha": "c"},
    "440514": {"name": "潮南区", "alpha": "c"},
    "440515": {"name": "澄海区", "alpha": "c"},
    "440523": {"name": "南澳县", "alpha": "n"}
  },
  "440600": {
    "440604": {"name": "禅城区", "alpha": "c"},
    "440605": {"name": "南海区", "alpha": "n"},
    "440606": {"name": "顺德区", "alpha": "s"},
    "440607": {"name": "三水区", "alpha": "s"},
    "440608": {"name": "高明区", "alpha": "g"}
  },
  "440700": {
    "440703": {"name": "蓬江区", "alpha": "p"},
    "440704": {"name": "江海区", "alpha": "j"},
    "440705": {"name": "新会区", "alpha": "x"},
    "440781": {"name": "台山", "alpha": "t"},
    "440783": {"name": "开平", "alpha": "k"},
    "440784": {"name": "鹤山", "alpha": "h"},
    "440785": {"name": "恩平", "alpha": "e"}
  },
  "440800": {
    "440802": {"name": "赤坎区", "alpha": "c"},
    "440803": {"name": "霞山区", "alpha": "x"},
    "440804": {"name": "坡头区", "alpha": "p"},
    "440811": {"name": "麻章区", "alpha": "m"},
    "440823": {"name": "遂溪县", "alpha": "s"},
    "440825": {"name": "徐闻县", "alpha": "x"},
    "440881": {"name": "廉江", "alpha": "l"},
    "440882": {"name": "雷州", "alpha": "l"},
    "440883": {"name": "吴川", "alpha": "w"}
  },
  "440900": {
    "440902": {"name": "茂南区", "alpha": "m"},
    "440904": {"name": "电白区", "alpha": "d"},
    "440981": {"name": "高州", "alpha": "g"},
    "440982": {"name": "化州", "alpha": "h"},
    "440983": {"name": "信宜", "alpha": "x"}
  },
  "441200": {
    "441202": {"name": "端州区", "alpha": "d"},
    "441203": {"name": "鼎湖区", "alpha": "d"},
    "441204": {"name": "高要区", "alpha": "g"},
    "441223": {"name": "广宁县", "alpha": "g"},
    "441224": {"name": "怀集县", "alpha": "h"},
    "441225": {"name": "封开县", "alpha": "f"},
    "441226": {"name": "德庆县", "alpha": "d"},
    "441284": {"name": "四会", "alpha": "s"}
  },
  "441300": {
    "441302": {"name": "惠城区", "alpha": "h"},
    "441303": {"name": "惠阳区", "alpha": "h"},
    "441322": {"name": "博罗县", "alpha": "b"},
    "441323": {"name": "惠东县", "alpha": "h"},
    "441324": {"name": "龙门县", "alpha": "l"}
  },
  "441400": {
    "441402": {"name": "梅江区", "alpha": "m"},
    "441403": {"name": "梅县区", "alpha": "m"},
    "441422": {"name": "大埔县", "alpha": "d"},
    "441423": {"name": "丰顺县", "alpha": "f"},
    "441424": {"name": "五华县", "alpha": "w"},
    "441426": {"name": "平远县", "alpha": "p"},
    "441427": {"name": "蕉岭县", "alpha": "j"},
    "441481": {"name": "兴宁", "alpha": "x"}
  },
  "441500": {
    "441502": {"name": "城区", "alpha": "c"},
    "441521": {"name": "海丰县", "alpha": "h"},
    "441523": {"name": "陆河县", "alpha": "l"},
    "441581": {"name": "陆丰", "alpha": "l"}
  },
  "441600": {
    "441602": {"name": "源城区", "alpha": "y"},
    "441621": {"name": "紫金县", "alpha": "z"},
    "441622": {"name": "龙川县", "alpha": "l"},
    "441623": {"name": "连平县", "alpha": "l"},
    "441624": {"name": "和平县", "alpha": "h"},
    "441625": {"name": "东源县", "alpha": "d"}
  },
  "441700": {
    "441702": {"name": "江城区", "alpha": "j"},
    "441704": {"name": "阳东区", "alpha": "y"},
    "441721": {"name": "阳西县", "alpha": "y"},
    "441781": {"name": "阳春", "alpha": "y"}
  },
  "441800": {
    "441802": {"name": "清城区", "alpha": "q"},
    "441803": {"name": "清新区", "alpha": "q"},
    "441821": {"name": "佛冈县", "alpha": "f"},
    "441823": {"name": "阳山县", "alpha": "y"},
    "441825": {"name": "连山壮族瑶族自治县", "alpha": "l"},
    "441826": {"name": "连南瑶族自治县", "alpha": "l"},
    "441881": {"name": "英德", "alpha": "y"},
    "441882": {"name": "连州", "alpha": "l"}
  },
  "441900": {
    "441900003": {"name": "东城街道", "alpha": "d"},
    "441900004": {"name": "南城街道", "alpha": "n"},
    "441900005": {"name": "万江街道", "alpha": "w"},
    "441900006": {"name": "莞城街道", "alpha": "w"},
    "441900101": {"name": "石碣镇", "alpha": "s"},
    "441900102": {"name": "石龙镇", "alpha": "s"},
    "441900103": {"name": "茶山镇", "alpha": "c"},
    "441900104": {"name": "石排镇", "alpha": "s"},
    "441900105": {"name": "企石镇", "alpha": "q"},
    "441900106": {"name": "横沥镇", "alpha": "h"},
    "441900107": {"name": "桥头镇", "alpha": "q"},
    "441900108": {"name": "谢岗镇", "alpha": "x"},
    "441900109": {"name": "东坑镇", "alpha": "d"},
    "441900110": {"name": "常平镇", "alpha": "c"},
    "441900111": {"name": "寮步镇", "alpha": "l"},
    "441900112": {"name": "樟木头镇", "alpha": "z"},
    "441900113": {"name": "大朗镇", "alpha": "d"},
    "441900114": {"name": "黄江镇", "alpha": "h"},
    "441900115": {"name": "清溪镇", "alpha": "q"},
    "441900116": {"name": "塘厦镇", "alpha": "t"},
    "441900117": {"name": "凤岗镇", "alpha": "f"},
    "441900118": {"name": "大岭山镇", "alpha": "d"},
    "441900119": {"name": "长安镇", "alpha": "c"},
    "441900121": {"name": "虎门镇", "alpha": "h"},
    "441900122": {"name": "厚街镇", "alpha": "h"},
    "441900123": {"name": "沙田镇", "alpha": "s"},
    "441900124": {"name": "道滘镇", "alpha": "d"},
    "441900125": {"name": "洪梅镇", "alpha": "h"},
    "441900126": {"name": "麻涌镇", "alpha": "m"},
    "441900127": {"name": "望牛墩镇", "alpha": "w"},
    "441900128": {"name": "中堂镇", "alpha": "z"},
    "441900129": {"name": "高埗镇", "alpha": "g"},
    "441900401": {"name": "松山湖管委会", "alpha": "s"},
    "441900402": {"name": "东莞港", "alpha": "d"},
    "441900403": {"name": "东莞生态园", "alpha": "d"}
  },
  "442000": {
    "442000001": {"name": "石岐区街道", "alpha": "s"},
    "442000002": {"name": "东区街道", "alpha": "d"},
    "442000003": {"name": "火炬开发区街道", "alpha": "h"},
    "442000004": {"name": "西区街道", "alpha": "x"},
    "442000005": {"name": "南区街道", "alpha": "n"},
    "442000006": {"name": "五桂山街道", "alpha": "w"},
    "442000100": {"name": "小榄镇", "alpha": "x"},
    "442000101": {"name": "黄圃镇", "alpha": "h"},
    "442000102": {"name": "民众镇", "alpha": "m"},
    "442000103": {"name": "东凤镇", "alpha": "d"},
    "442000104": {"name": "东升镇", "alpha": "d"},
    "442000105": {"name": "古镇镇", "alpha": "g"},
    "442000106": {"name": "沙溪镇", "alpha": "s"},
    "442000107": {"name": "坦洲镇", "alpha": "t"},
    "442000108": {"name": "港口镇", "alpha": "g"},
    "442000109": {"name": "三角镇", "alpha": "s"},
    "442000110": {"name": "横栏镇", "alpha": "h"},
    "442000111": {"name": "南头镇", "alpha": "n"},
    "442000112": {"name": "阜沙镇", "alpha": "f"},
    "442000113": {"name": "南朗镇", "alpha": "n"},
    "442000114": {"name": "三乡镇", "alpha": "s"},
    "442000115": {"name": "板芙镇", "alpha": "b"},
    "442000116": {"name": "大涌镇", "alpha": "d"},
    "442000117": {"name": "神湾镇", "alpha": "s"}
  },
  "445100": {
    "445102": {"name": "湘桥区", "alpha": "x"},
    "445103": {"name": "潮安区", "alpha": "c"},
    "445122": {"name": "饶平县", "alpha": "r"}
  },
  "445200": {
    "445202": {"name": "榕城区", "alpha": "r"},
    "445203": {"name": "揭东区", "alpha": "j"},
    "445222": {"name": "揭西县", "alpha": "j"},
    "445224": {"name": "惠来县", "alpha": "h"},
    "445281": {"name": "普宁", "alpha": "p"}
  },
  "445300": {
    "445302": {"name": "云城区", "alpha": "y"},
    "445303": {"name": "云安区", "alpha": "y"},
    "445321": {"name": "新兴县", "alpha": "x"},
    "445322": {"name": "郁南县", "alpha": "y"},
    "445381": {"name": "罗定", "alpha": "l"}
  },
  "450100": {
    "450102": {"name": "兴宁区", "alpha": "x"},
    "450103": {"name": "青秀区", "alpha": "q"},
    "450105": {"name": "江南区", "alpha": "j"},
    "450107": {"name": "西乡塘区", "alpha": "x"},
    "450108": {"name": "良庆区", "alpha": "l"},
    "450109": {"name": "邕宁区", "alpha": "y"},
    "450110": {"name": "武鸣区", "alpha": "w"},
    "450123": {"name": "隆安县", "alpha": "l"},
    "450124": {"name": "马山县", "alpha": "m"},
    "450125": {"name": "上林县", "alpha": "s"},
    "450126": {"name": "宾阳县", "alpha": "b"},
    "450127": {"name": "横县", "alpha": "h"}
  },
  "450200": {
    "450202": {"name": "城中区", "alpha": "c"},
    "450203": {"name": "鱼峰区", "alpha": "y"},
    "450204": {"name": "柳南区", "alpha": "l"},
    "450205": {"name": "柳北区", "alpha": "l"},
    "450206": {"name": "柳江区", "alpha": "l"},
    "450222": {"name": "柳城县", "alpha": "l"},
    "450223": {"name": "鹿寨县", "alpha": "l"},
    "450224": {"name": "融安县", "alpha": "r"},
    "450225": {"name": "融水苗族自治县", "alpha": "r"},
    "450226": {"name": "三江侗族自治县", "alpha": "s"}
  },
  "450300": {
    "450302": {"name": "秀峰区", "alpha": "x"},
    "450303": {"name": "叠彩区", "alpha": "d"},
    "450304": {"name": "象山区", "alpha": "x"},
    "450305": {"name": "七星区", "alpha": "q"},
    "450311": {"name": "雁山区", "alpha": "y"},
    "450312": {"name": "临桂区", "alpha": "l"},
    "450321": {"name": "阳朔县", "alpha": "y"},
    "450323": {"name": "灵川县", "alpha": "l"},
    "450324": {"name": "全州县", "alpha": "q"},
    "450325": {"name": "兴安县", "alpha": "x"},
    "450326": {"name": "永福县", "alpha": "y"},
    "450327": {"name": "灌阳县", "alpha": "g"},
    "450328": {"name": "龙胜各族自治县", "alpha": "l"},
    "450329": {"name": "资源县", "alpha": "z"},
    "450330": {"name": "平乐县", "alpha": "p"},
    "450332": {"name": "恭城瑶族自治县", "alpha": "g"},
    "450381": {"name": "荔浦", "alpha": "l"}
  },
  "450400": {
    "450403": {"name": "万秀区", "alpha": "w"},
    "450405": {"name": "长洲区", "alpha": "c"},
    "450406": {"name": "龙圩区", "alpha": "l"},
    "450421": {"name": "苍梧县", "alpha": "c"},
    "450422": {"name": "藤县", "alpha": "t"},
    "450423": {"name": "蒙山县", "alpha": "m"},
    "450481": {"name": "岑溪", "alpha": "c"}
  },
  "450500": {
    "450502": {"name": "海城区", "alpha": "h"},
    "450503": {"name": "银海区", "alpha": "y"},
    "450512": {"name": "铁山港区", "alpha": "t"},
    "450521": {"name": "合浦县", "alpha": "h"}
  },
  "450600": {
    "450602": {"name": "港口区", "alpha": "g"},
    "450603": {"name": "防城区", "alpha": "f"},
    "450621": {"name": "上思县", "alpha": "s"},
    "450681": {"name": "东兴", "alpha": "d"}
  },
  "450700": {
    "450702": {"name": "钦南区", "alpha": "q"},
    "450703": {"name": "钦北区", "alpha": "q"},
    "450721": {"name": "灵山县", "alpha": "l"},
    "450722": {"name": "浦北县", "alpha": "p"}
  },
  "450800": {
    "450802": {"name": "港北区", "alpha": "g"},
    "450803": {"name": "港南区", "alpha": "g"},
    "450804": {"name": "覃塘区", "alpha": "t"},
    "450821": {"name": "平南县", "alpha": "p"},
    "450881": {"name": "桂平", "alpha": "g"}
  },
  "450900": {
    "450902": {"name": "玉州区", "alpha": "y"},
    "450903": {"name": "福绵区", "alpha": "f"},
    "450921": {"name": "容县", "alpha": "r"},
    "450922": {"name": "陆川县", "alpha": "l"},
    "450923": {"name": "博白县", "alpha": "b"},
    "450924": {"name": "兴业县", "alpha": "x"},
    "450981": {"name": "北流", "alpha": "b"}
  },
  "451000": {
    "451002": {"name": "右江区", "alpha": "y"},
    "451021": {"name": "田阳县", "alpha": "t"},
    "451022": {"name": "田东县", "alpha": "t"},
    "451023": {"name": "平果县", "alpha": "p"},
    "451024": {"name": "德保县", "alpha": "d"},
    "451026": {"name": "那坡县", "alpha": "n"},
    "451027": {"name": "凌云县", "alpha": "l"},
    "451028": {"name": "乐业县", "alpha": "l"},
    "451029": {"name": "田林县", "alpha": "t"},
    "451030": {"name": "西林县", "alpha": "x"},
    "451031": {"name": "隆林各族自治县", "alpha": "l"},
    "451081": {"name": "靖西", "alpha": "j"}
  },
  "451100": {
    "451102": {"name": "八步区", "alpha": "b"},
    "451103": {"name": "平桂区", "alpha": "p"},
    "451121": {"name": "昭平县", "alpha": "z"},
    "451122": {"name": "钟山县", "alpha": "z"},
    "451123": {"name": "富川瑶族自治县", "alpha": "f"}
  },
  "451200": {
    "451202": {"name": "金城江区", "alpha": "j"},
    "451203": {"name": "宜州区", "alpha": "y"},
    "451221": {"name": "南丹县", "alpha": "n"},
    "451222": {"name": "天峨县", "alpha": "t"},
    "451223": {"name": "凤山县", "alpha": "f"},
    "451224": {"name": "东兰县", "alpha": "d"},
    "451225": {"name": "罗城仫佬族自治县", "alpha": "l"},
    "451226": {"name": "环江毛南族自治县", "alpha": "h"},
    "451227": {"name": "巴马瑶族自治县", "alpha": "b"},
    "451228": {"name": "都安瑶族自治县", "alpha": "d"},
    "451229": {"name": "大化瑶族自治县", "alpha": "d"}
  },
  "451300": {
    "451302": {"name": "兴宾区", "alpha": "x"},
    "451321": {"name": "忻城县", "alpha": "x"},
    "451322": {"name": "象州县", "alpha": "x"},
    "451323": {"name": "武宣县", "alpha": "w"},
    "451324": {"name": "金秀瑶族自治县", "alpha": "j"},
    "451381": {"name": "合山", "alpha": "h"}
  },
  "451400": {
    "451402": {"name": "江州区", "alpha": "j"},
    "451421": {"name": "扶绥县", "alpha": "f"},
    "451422": {"name": "宁明县", "alpha": "n"},
    "451423": {"name": "龙州县", "alpha": "l"},
    "451424": {"name": "大新县", "alpha": "d"},
    "451425": {"name": "天等县", "alpha": "t"},
    "451481": {"name": "凭祥", "alpha": "p"}
  },
  "460100": {
    "460105": {"name": "秀英区", "alpha": "x"},
    "460106": {"name": "龙华区", "alpha": "l"},
    "460107": {"name": "琼山区", "alpha": "q"},
    "460108": {"name": "美兰区", "alpha": "m"}
  },
  "460200": {
    "460202": {"name": "海棠区", "alpha": "h"},
    "460203": {"name": "吉阳区", "alpha": "j"},
    "460204": {"name": "天涯区", "alpha": "t"},
    "460205": {"name": "崖州区", "alpha": "y"}
  },
  "460300": {
    "460321": {"name": "西沙群岛", "alpha": "x"},
    "460322": {"name": "南沙群岛", "alpha": "n"},
    "460323": {"name": "中沙群岛的岛礁及其海域", "alpha": "z"}
  },
  "460400": {
    "460400100": {"name": "那大镇", "alpha": "n"},
    "460400101": {"name": "和庆镇", "alpha": "h"},
    "460400102": {"name": "南丰镇", "alpha": "n"},
    "460400103": {"name": "大成镇", "alpha": "d"},
    "460400104": {"name": "雅星镇", "alpha": "y"},
    "460400105": {"name": "兰洋镇", "alpha": "l"},
    "460400106": {"name": "光村镇", "alpha": "g"},
    "460400107": {"name": "木棠镇", "alpha": "m"},
    "460400108": {"name": "海头镇", "alpha": "h"},
    "460400109": {"name": "峨蔓镇", "alpha": "e"},
    "460400111": {"name": "王五镇", "alpha": "w"},
    "460400112": {"name": "白马井镇", "alpha": "b"},
    "460400113": {"name": "中和镇", "alpha": "z"},
    "460400114": {"name": "排浦镇", "alpha": "p"},
    "460400115": {"name": "东成镇", "alpha": "d"},
    "460400116": {"name": "新州镇", "alpha": "x"},
    "460400499": {"name": "洋浦经济开发区", "alpha": "y"},
    "460400500": {"name": "华南热作学院", "alpha": "h"}
  },
  "469000": {
    "469001": {"name": "五指山", "alpha": "w"},
    "469002": {"name": "琼海", "alpha": "q"},
    "469005": {"name": "文昌", "alpha": "w"},
    "469006": {"name": "万宁", "alpha": "w"},
    "469007": {"name": "东方", "alpha": "d"},
    "469021": {"name": "定安县", "alpha": "d"},
    "469022": {"name": "屯昌县", "alpha": "t"},
    "469023": {"name": "澄迈县", "alpha": "c"},
    "469024": {"name": "临高县", "alpha": "l"},
    "469025": {"name": "白沙黎族自治县", "alpha": "b"},
    "469026": {"name": "昌江黎族自治县", "alpha": "c"},
    "469027": {"name": "乐东黎族自治县", "alpha": "l"},
    "469028": {"name": "陵水黎族自治县", "alpha": "l"},
    "469029": {"name": "保亭黎族苗族自治县", "alpha": "b"},
    "469030": {"name": "琼中黎族苗族自治县", "alpha": "q"}
  },
  "500100": {
    "500101": {"name": "万州区", "alpha": "w"},
    "500102": {"name": "涪陵区", "alpha": "f"},
    "500103": {"name": "渝中区", "alpha": "y"},
    "500104": {"name": "大渡口区", "alpha": "d"},
    "500105": {"name": "江北区", "alpha": "j"},
    "500106": {"name": "沙坪坝区", "alpha": "s"},
    "500107": {"name": "九龙坡区", "alpha": "j"},
    "500108": {"name": "南岸区", "alpha": "n"},
    "500109": {"name": "北碚区", "alpha": "b"},
    "500110": {"name": "綦江区", "alpha": "q"},
    "500111": {"name": "大足区", "alpha": "d"},
    "500112": {"name": "渝北区", "alpha": "y"},
    "500113": {"name": "巴南区", "alpha": "b"},
    "500114": {"name": "黔江区", "alpha": "q"},
    "500115": {"name": "长寿区", "alpha": "c"},
    "500116": {"name": "江津区", "alpha": "j"},
    "500117": {"name": "合川区", "alpha": "h"},
    "500118": {"name": "永川区", "alpha": "y"},
    "500119": {"name": "南川区", "alpha": "n"},
    "500120": {"name": "璧山区", "alpha": "b"},
    "500151": {"name": "铜梁区", "alpha": "t"},
    "500152": {"name": "潼南区", "alpha": "t"},
    "500153": {"name": "荣昌区", "alpha": "r"},
    "500154": {"name": "开州区", "alpha": "k"},
    "500155": {"name": "梁平区", "alpha": "l"},
    "500156": {"name": "武隆区", "alpha": "w"}
  },
  "500200": {
    "500229": {"name": "城口县", "alpha": "c"},
    "500230": {"name": "丰都县", "alpha": "f"},
    "500231": {"name": "垫江县", "alpha": "d"},
    "500233": {"name": "忠县", "alpha": "z"},
    "500235": {"name": "云阳县", "alpha": "y"},
    "500236": {"name": "奉节县", "alpha": "f"},
    "500237": {"name": "巫山县", "alpha": "w"},
    "500238": {"name": "巫溪县", "alpha": "w"},
    "500240": {"name": "石柱土家族自治县", "alpha": "s"},
    "500241": {"name": "秀山土家族苗族自治县", "alpha": "x"},
    "500242": {"name": "酉阳土家族苗族自治县", "alpha": "y"},
    "500243": {"name": "彭水苗族土家族自治县", "alpha": "p"}
  },
  "510100": {
    "510104": {"name": "锦江区", "alpha": "j"},
    "510105": {"name": "青羊区", "alpha": "q"},
    "510106": {"name": "金牛区", "alpha": "j"},
    "510107": {"name": "武侯区", "alpha": "w"},
    "510108": {"name": "成华区", "alpha": "c"},
    "510112": {"name": "龙泉驿区", "alpha": "l"},
    "510113": {"name": "青白江区", "alpha": "q"},
    "510114": {"name": "新都区", "alpha": "x"},
    "510115": {"name": "温江区", "alpha": "w"},
    "510116": {"name": "双流区", "alpha": "s"},
    "510117": {"name": "郫都区", "alpha": "p"},
    "510121": {"name": "金堂县", "alpha": "j"},
    "510129": {"name": "大邑县", "alpha": "d"},
    "510131": {"name": "蒲江县", "alpha": "p"},
    "510132": {"name": "新津县", "alpha": "x"},
    "510181": {"name": "都江堰", "alpha": "d"},
    "510182": {"name": "彭州", "alpha": "p"},
    "510183": {"name": "邛崃", "alpha": "q"},
    "510184": {"name": "崇州", "alpha": "c"},
    "510185": {"name": "简阳", "alpha": "j"}
  },
  "510300": {
    "510302": {"name": "自流井区", "alpha": "z"},
    "510303": {"name": "贡井区", "alpha": "g"},
    "510304": {"name": "大安区", "alpha": "d"},
    "510311": {"name": "沿滩区", "alpha": "y"},
    "510321": {"name": "荣县", "alpha": "r"},
    "510322": {"name": "富顺县", "alpha": "f"}
  },
  "510400": {
    "510402": {"name": "东区", "alpha": "d"},
    "510403": {"name": "西区", "alpha": "x"},
    "510411": {"name": "仁和区", "alpha": "r"},
    "510421": {"name": "米易县", "alpha": "m"},
    "510422": {"name": "盐边县", "alpha": "y"}
  },
  "510500": {
    "510502": {"name": "江阳区", "alpha": "j"},
    "510503": {"name": "纳溪区", "alpha": "n"},
    "510504": {"name": "龙马潭区", "alpha": "l"},
    "510521": {"name": "泸县", "alpha": "l"},
    "510522": {"name": "合江县", "alpha": "h"},
    "510524": {"name": "叙永县", "alpha": "x"},
    "510525": {"name": "古蔺县", "alpha": "g"}
  },
  "510600": {
    "510603": {"name": "旌阳区", "alpha": "j"},
    "510604": {"name": "罗江区", "alpha": "l"},
    "510623": {"name": "中江县", "alpha": "z"},
    "510681": {"name": "广汉", "alpha": "g"},
    "510682": {"name": "什邡", "alpha": "s"},
    "510683": {"name": "绵竹", "alpha": "m"}
  },
  "510700": {
    "510703": {"name": "涪城区", "alpha": "f"},
    "510704": {"name": "游仙区", "alpha": "y"},
    "510705": {"name": "安州区", "alpha": "a"},
    "510722": {"name": "三台县", "alpha": "s"},
    "510723": {"name": "盐亭县", "alpha": "y"},
    "510725": {"name": "梓潼县", "alpha": "z"},
    "510726": {"name": "北川羌族自治县", "alpha": "b"},
    "510727": {"name": "平武县", "alpha": "p"},
    "510781": {"name": "江油", "alpha": "j"}
  },
  "510800": {
    "510802": {"name": "利州区", "alpha": "l"},
    "510811": {"name": "昭化区", "alpha": "z"},
    "510812": {"name": "朝天区", "alpha": "c"},
    "510821": {"name": "旺苍县", "alpha": "w"},
    "510822": {"name": "青川县", "alpha": "q"},
    "510823": {"name": "剑阁县", "alpha": "j"},
    "510824": {"name": "苍溪县", "alpha": "c"}
  },
  "510900": {
    "510903": {"name": "船山区", "alpha": "c"},
    "510904": {"name": "安居区", "alpha": "a"},
    "510921": {"name": "蓬溪县", "alpha": "p"},
    "510922": {"name": "射洪县", "alpha": "s"},
    "510923": {"name": "大英县", "alpha": "d"}
  },
  "511000": {
    "511002": {"name": "中区", "alpha": "s"},
    "511011": {"name": "东兴区", "alpha": "d"},
    "511024": {"name": "威远县", "alpha": "w"},
    "511025": {"name": "资中县", "alpha": "z"},
    "511071": {"name": "内江经济开发区", "alpha": "n"},
    "511083": {"name": "隆昌", "alpha": "l"}
  },
  "511100": {
    "511102": {"name": "中区", "alpha": "s"},
    "511111": {"name": "沙湾区", "alpha": "s"},
    "511112": {"name": "五通桥区", "alpha": "w"},
    "511113": {"name": "金口河区", "alpha": "j"},
    "511123": {"name": "犍为县", "alpha": "j"},
    "511124": {"name": "井研县", "alpha": "j"},
    "511126": {"name": "夹江县", "alpha": "j"},
    "511129": {"name": "沐川县", "alpha": "m"},
    "511132": {"name": "峨边彝族自治县", "alpha": "e"},
    "511133": {"name": "马边彝族自治县", "alpha": "m"},
    "511181": {"name": "峨眉山", "alpha": "e"}
  },
  "511300": {
    "511302": {"name": "顺庆区", "alpha": "s"},
    "511303": {"name": "高坪区", "alpha": "g"},
    "511304": {"name": "嘉陵区", "alpha": "j"},
    "511321": {"name": "南部县", "alpha": "n"},
    "511322": {"name": "营山县", "alpha": "y"},
    "511323": {"name": "蓬安县", "alpha": "p"},
    "511324": {"name": "仪陇县", "alpha": "y"},
    "511325": {"name": "西充县", "alpha": "x"},
    "511381": {"name": "阆中", "alpha": "l"}
  },
  "511400": {
    "511402": {"name": "东坡区", "alpha": "d"},
    "511403": {"name": "彭山区", "alpha": "p"},
    "511421": {"name": "仁寿县", "alpha": "r"},
    "511423": {"name": "洪雅县", "alpha": "h"},
    "511424": {"name": "丹棱县", "alpha": "d"},
    "511425": {"name": "青神县", "alpha": "q"}
  },
  "511500": {
    "511502": {"name": "翠屏区", "alpha": "c"},
    "511503": {"name": "南溪区", "alpha": "n"},
    "511504": {"name": "叙州区", "alpha": "x"},
    "511523": {"name": "江安县", "alpha": "j"},
    "511524": {"name": "长宁县", "alpha": "c"},
    "511525": {"name": "高县", "alpha": "g"},
    "511526": {"name": "珙县", "alpha": "g"},
    "511527": {"name": "筠连县", "alpha": "y"},
    "511528": {"name": "兴文县", "alpha": "x"},
    "511529": {"name": "屏山县", "alpha": "p"}
  },
  "511600": {
    "511602": {"name": "广安区", "alpha": "g"},
    "511603": {"name": "前锋区", "alpha": "q"},
    "511621": {"name": "岳池县", "alpha": "y"},
    "511622": {"name": "武胜县", "alpha": "w"},
    "511623": {"name": "邻水县", "alpha": "l"},
    "511681": {"name": "华蓥", "alpha": "h"}
  },
  "511700": {
    "511702": {"name": "通川区", "alpha": "t"},
    "511703": {"name": "达川区", "alpha": "d"},
    "511722": {"name": "宣汉县", "alpha": "x"},
    "511723": {"name": "开江县", "alpha": "k"},
    "511724": {"name": "大竹县", "alpha": "d"},
    "511725": {"name": "渠县", "alpha": "q"},
    "511771": {"name": "达州经济开发区", "alpha": "d"},
    "511781": {"name": "万源", "alpha": "w"}
  },
  "511800": {
    "511802": {"name": "雨城区", "alpha": "y"},
    "511803": {"name": "名山区", "alpha": "m"},
    "511822": {"name": "荥经县", "alpha": "x"},
    "511823": {"name": "汉源县", "alpha": "h"},
    "511824": {"name": "石棉县", "alpha": "s"},
    "511825": {"name": "天全县", "alpha": "t"},
    "511826": {"name": "芦山县", "alpha": "l"},
    "511827": {"name": "宝兴县", "alpha": "b"}
  },
  "511900": {
    "511902": {"name": "巴州区", "alpha": "b"},
    "511903": {"name": "恩阳区", "alpha": "e"},
    "511921": {"name": "通江县", "alpha": "t"},
    "511922": {"name": "南江县", "alpha": "n"},
    "511923": {"name": "平昌县", "alpha": "p"},
    "511971": {"name": "巴中经济开发区", "alpha": "b"}
  },
  "512000": {
    "512002": {"name": "雁江区", "alpha": "y"},
    "512021": {"name": "安岳县", "alpha": "a"},
    "512022": {"name": "乐至县", "alpha": "l"}
  },
  "513200": {
    "513201": {"name": "马尔康", "alpha": "m"},
    "513221": {"name": "汶川县", "alpha": "w"},
    "513222": {"name": "理县", "alpha": "l"},
    "513223": {"name": "茂县", "alpha": "m"},
    "513224": {"name": "松潘县", "alpha": "s"},
    "513225": {"name": "九寨沟县", "alpha": "j"},
    "513226": {"name": "金川县", "alpha": "j"},
    "513227": {"name": "小金县", "alpha": "x"},
    "513228": {"name": "黑水县", "alpha": "h"},
    "513230": {"name": "壤塘县", "alpha": "r"},
    "513231": {"name": "阿坝县", "alpha": "a"},
    "513232": {"name": "若尔盖县", "alpha": "r"},
    "513233": {"name": "红原县", "alpha": "h"}
  },
  "513300": {
    "513301": {"name": "康定", "alpha": "k"},
    "513322": {"name": "泸定县", "alpha": "l"},
    "513323": {"name": "丹巴县", "alpha": "d"},
    "513324": {"name": "九龙县", "alpha": "j"},
    "513325": {"name": "雅江县", "alpha": "y"},
    "513326": {"name": "道孚县", "alpha": "d"},
    "513327": {"name": "炉霍县", "alpha": "l"},
    "513328": {"name": "甘孜县", "alpha": "g"},
    "513329": {"name": "新龙县", "alpha": "x"},
    "513330": {"name": "德格县", "alpha": "d"},
    "513331": {"name": "白玉县", "alpha": "b"},
    "513332": {"name": "石渠县", "alpha": "s"},
    "513333": {"name": "色达县", "alpha": "s"},
    "513334": {"name": "理塘县", "alpha": "l"},
    "513335": {"name": "巴塘县", "alpha": "b"},
    "513336": {"name": "乡城县", "alpha": "x"},
    "513337": {"name": "稻城县", "alpha": "d"},
    "513338": {"name": "得荣县", "alpha": "d"}
  },
  "513400": {
    "513401": {"name": "西昌", "alpha": "x"},
    "513422": {"name": "木里藏族自治县", "alpha": "m"},
    "513423": {"name": "盐源县", "alpha": "y"},
    "513424": {"name": "德昌县", "alpha": "d"},
    "513425": {"name": "会理县", "alpha": "h"},
    "513426": {"name": "会东县", "alpha": "h"},
    "513427": {"name": "宁南县", "alpha": "n"},
    "513428": {"name": "普格县", "alpha": "p"},
    "513429": {"name": "布拖县", "alpha": "b"},
    "513430": {"name": "金阳县", "alpha": "j"},
    "513431": {"name": "昭觉县", "alpha": "z"},
    "513432": {"name": "喜德县", "alpha": "x"},
    "513433": {"name": "冕宁县", "alpha": "m"},
    "513434": {"name": "越西县", "alpha": "y"},
    "513435": {"name": "甘洛县", "alpha": "g"},
    "513436": {"name": "美姑县", "alpha": "m"},
    "513437": {"name": "雷波县", "alpha": "l"}
  },
  "520100": {
    "520102": {"name": "南明区", "alpha": "n"},
    "520103": {"name": "云岩区", "alpha": "y"},
    "520111": {"name": "花溪区", "alpha": "h"},
    "520112": {"name": "乌当区", "alpha": "w"},
    "520113": {"name": "白云区", "alpha": "b"},
    "520115": {"name": "观山湖区", "alpha": "g"},
    "520121": {"name": "开阳县", "alpha": "k"},
    "520122": {"name": "息烽县", "alpha": "x"},
    "520123": {"name": "修文县", "alpha": "x"},
    "520181": {"name": "清镇", "alpha": "q"}
  },
  "520200": {
    "520201": {"name": "钟山区", "alpha": "z"},
    "520203": {"name": "六枝特区", "alpha": "l"},
    "520221": {"name": "水城县", "alpha": "s"},
    "520281": {"name": "盘州", "alpha": "p"}
  },
  "520300": {
    "520302": {"name": "红花岗区", "alpha": "h"},
    "520303": {"name": "汇川区", "alpha": "h"},
    "520304": {"name": "播州区", "alpha": "b"},
    "520322": {"name": "桐梓县", "alpha": "t"},
    "520323": {"name": "绥阳县", "alpha": "s"},
    "520324": {"name": "正安县", "alpha": "z"},
    "520325": {"name": "道真仡佬族苗族自治县", "alpha": "d"},
    "520326": {"name": "务川仡佬族苗族自治县", "alpha": "w"},
    "520327": {"name": "凤冈县", "alpha": "f"},
    "520328": {"name": "湄潭县", "alpha": "m"},
    "520329": {"name": "余庆县", "alpha": "y"},
    "520330": {"name": "习水县", "alpha": "x"},
    "520381": {"name": "赤水", "alpha": "c"},
    "520382": {"name": "仁怀", "alpha": "r"}
  },
  "520400": {
    "520402": {"name": "西秀区", "alpha": "x"},
    "520403": {"name": "平坝区", "alpha": "p"},
    "520422": {"name": "普定县", "alpha": "p"},
    "520423": {"name": "镇宁布依族苗族自治县", "alpha": "z"},
    "520424": {"name": "关岭布依族苗族自治县", "alpha": "g"},
    "520425": {"name": "紫云苗族布依族自治县", "alpha": "z"}
  },
  "520500": {
    "520502": {"name": "七星关区", "alpha": "q"},
    "520521": {"name": "大方县", "alpha": "d"},
    "520522": {"name": "黔西县", "alpha": "q"},
    "520523": {"name": "金沙县", "alpha": "j"},
    "520524": {"name": "织金县", "alpha": "z"},
    "520525": {"name": "纳雍县", "alpha": "n"},
    "520526": {"name": "威宁彝族回族苗族自治县", "alpha": "w"},
    "520527": {"name": "赫章县", "alpha": "h"}
  },
  "520600": {
    "520602": {"name": "碧江区", "alpha": "b"},
    "520603": {"name": "万山区", "alpha": "w"},
    "520621": {"name": "江口县", "alpha": "j"},
    "520622": {"name": "玉屏侗族自治县", "alpha": "y"},
    "520623": {"name": "石阡县", "alpha": "s"},
    "520624": {"name": "思南县", "alpha": "s"},
    "520625": {"name": "印江土家族苗族自治县", "alpha": "y"},
    "520626": {"name": "德江县", "alpha": "d"},
    "520627": {"name": "沿河土家族自治县", "alpha": "y"},
    "520628": {"name": "松桃苗族自治县", "alpha": "s"}
  },
  "522300": {
    "522301": {"name": "兴义", "alpha": "x"},
    "522302": {"name": "兴仁", "alpha": "x"},
    "522323": {"name": "普安县", "alpha": "p"},
    "522324": {"name": "晴隆县", "alpha": "q"},
    "522325": {"name": "贞丰县", "alpha": "z"},
    "522326": {"name": "望谟县", "alpha": "w"},
    "522327": {"name": "册亨县", "alpha": "c"},
    "522328": {"name": "安龙县", "alpha": "a"}
  },
  "522600": {
    "522601": {"name": "凯里", "alpha": "k"},
    "522622": {"name": "黄平县", "alpha": "h"},
    "522623": {"name": "施秉县", "alpha": "s"},
    "522624": {"name": "三穗县", "alpha": "s"},
    "522625": {"name": "镇远县", "alpha": "z"},
    "522626": {"name": "岑巩县", "alpha": "c"},
    "522627": {"name": "天柱县", "alpha": "t"},
    "522628": {"name": "锦屏县", "alpha": "j"},
    "522629": {"name": "剑河县", "alpha": "j"},
    "522630": {"name": "台江县", "alpha": "t"},
    "522631": {"name": "黎平县", "alpha": "l"},
    "522632": {"name": "榕江县", "alpha": "r"},
    "522633": {"name": "从江县", "alpha": "c"},
    "522634": {"name": "雷山县", "alpha": "l"},
    "522635": {"name": "麻江县", "alpha": "m"},
    "522636": {"name": "丹寨县", "alpha": "d"}
  },
  "522700": {
    "522701": {"name": "都匀", "alpha": "d"},
    "522702": {"name": "福泉", "alpha": "f"},
    "522722": {"name": "荔波县", "alpha": "l"},
    "522723": {"name": "贵定县", "alpha": "g"},
    "522725": {"name": "瓮安县", "alpha": "w"},
    "522726": {"name": "独山县", "alpha": "d"},
    "522727": {"name": "平塘县", "alpha": "p"},
    "522728": {"name": "罗甸县", "alpha": "l"},
    "522729": {"name": "长顺县", "alpha": "c"},
    "522730": {"name": "龙里县", "alpha": "l"},
    "522731": {"name": "惠水县", "alpha": "h"},
    "522732": {"name": "三都水族自治县", "alpha": "s"}
  },
  "530100": {
    "530102": {"name": "五华区", "alpha": "w"},
    "530103": {"name": "盘龙区", "alpha": "p"},
    "530111": {"name": "官渡区", "alpha": "g"},
    "530112": {"name": "西山区", "alpha": "x"},
    "530113": {"name": "东川区", "alpha": "d"},
    "530114": {"name": "呈贡区", "alpha": "c"},
    "530115": {"name": "晋宁区", "alpha": "j"},
    "530124": {"name": "富民县", "alpha": "f"},
    "530125": {"name": "宜良县", "alpha": "y"},
    "530126": {"name": "石林彝族自治县", "alpha": "s"},
    "530127": {"name": "嵩明县", "alpha": "s"},
    "530128": {"name": "禄劝彝族苗族自治县", "alpha": "l"},
    "530129": {"name": "寻甸回族彝族自治县", "alpha": "x"},
    "530181": {"name": "安宁", "alpha": "a"}
  },
  "530300": {
    "530302": {"name": "麒麟区", "alpha": "q"},
    "530303": {"name": "沾益区", "alpha": "z"},
    "530304": {"name": "马龙区", "alpha": "m"},
    "530322": {"name": "陆良县", "alpha": "l"},
    "530323": {"name": "师宗县", "alpha": "s"},
    "530324": {"name": "罗平县", "alpha": "l"},
    "530325": {"name": "富源县", "alpha": "f"},
    "530326": {"name": "会泽县", "alpha": "h"},
    "530381": {"name": "宣威", "alpha": "x"}
  },
  "530400": {
    "530402": {"name": "红塔区", "alpha": "h"},
    "530403": {"name": "江川区", "alpha": "j"},
    "530422": {"name": "澄江县", "alpha": "c"},
    "530423": {"name": "通海县", "alpha": "t"},
    "530424": {"name": "华宁县", "alpha": "h"},
    "530425": {"name": "易门县", "alpha": "y"},
    "530426": {"name": "峨山彝族自治县", "alpha": "e"},
    "530427": {"name": "新平彝族傣族自治县", "alpha": "x"},
    "530428": {"name": "元江哈尼族彝族傣族自治县", "alpha": "y"}
  },
  "530500": {
    "530502": {"name": "隆阳区", "alpha": "l"},
    "530521": {"name": "施甸县", "alpha": "s"},
    "530523": {"name": "龙陵县", "alpha": "l"},
    "530524": {"name": "昌宁县", "alpha": "c"},
    "530581": {"name": "腾冲", "alpha": "t"}
  },
  "530600": {
    "530602": {"name": "昭阳区", "alpha": "z"},
    "530621": {"name": "鲁甸县", "alpha": "l"},
    "530622": {"name": "巧家县", "alpha": "q"},
    "530623": {"name": "盐津县", "alpha": "y"},
    "530624": {"name": "大关县", "alpha": "d"},
    "530625": {"name": "永善县", "alpha": "y"},
    "530626": {"name": "绥江县", "alpha": "s"},
    "530627": {"name": "镇雄县", "alpha": "z"},
    "530628": {"name": "彝良县", "alpha": "y"},
    "530629": {"name": "威信县", "alpha": "w"},
    "530681": {"name": "水富", "alpha": "s"}
  },
  "530700": {
    "530702": {"name": "古城区", "alpha": "g"},
    "530721": {"name": "玉龙纳西族自治县", "alpha": "y"},
    "530722": {"name": "永胜县", "alpha": "y"},
    "530723": {"name": "华坪县", "alpha": "h"},
    "530724": {"name": "宁蒗彝族自治县", "alpha": "n"}
  },
  "530800": {
    "530802": {"name": "思茅区", "alpha": "s"},
    "530821": {"name": "宁洱哈尼族彝族自治县", "alpha": "n"},
    "530822": {"name": "墨江哈尼族自治县", "alpha": "m"},
    "530823": {"name": "景东彝族自治县", "alpha": "j"},
    "530824": {"name": "景谷傣族彝族自治县", "alpha": "j"},
    "530825": {"name": "镇沅彝族哈尼族拉祜族自治县", "alpha": "z"},
    "530826": {"name": "江城哈尼族彝族自治县", "alpha": "j"},
    "530827": {"name": "孟连傣族拉祜族佤族自治县", "alpha": "m"},
    "530828": {"name": "澜沧拉祜族自治县", "alpha": "l"},
    "530829": {"name": "西盟佤族自治县", "alpha": "x"}
  },
  "530900": {
    "530902": {"name": "临翔区", "alpha": "l"},
    "530921": {"name": "凤庆县", "alpha": "f"},
    "530922": {"name": "云县", "alpha": "y"},
    "530923": {"name": "永德县", "alpha": "y"},
    "530924": {"name": "镇康县", "alpha": "z"},
    "530925": {"name": "双江拉祜族佤族布朗族傣族自治县", "alpha": "s"},
    "530926": {"name": "耿马傣族佤族自治县", "alpha": "g"},
    "530927": {"name": "沧源佤族自治县", "alpha": "c"}
  },
  "532300": {
    "532301": {"name": "楚雄", "alpha": "c"},
    "532322": {"name": "双柏县", "alpha": "s"},
    "532323": {"name": "牟定县", "alpha": "m"},
    "532324": {"name": "南华县", "alpha": "n"},
    "532325": {"name": "姚安县", "alpha": "y"},
    "532326": {"name": "大姚县", "alpha": "d"},
    "532327": {"name": "永仁县", "alpha": "y"},
    "532328": {"name": "元谋县", "alpha": "y"},
    "532329": {"name": "武定县", "alpha": "w"},
    "532331": {"name": "禄丰县", "alpha": "l"}
  },
  "532500": {
    "532501": {"name": "个旧", "alpha": "g"},
    "532502": {"name": "开远", "alpha": "k"},
    "532503": {"name": "蒙自", "alpha": "m"},
    "532504": {"name": "弥勒", "alpha": "m"},
    "532523": {"name": "屏边苗族自治县", "alpha": "p"},
    "532524": {"name": "建水县", "alpha": "j"},
    "532525": {"name": "石屏县", "alpha": "s"},
    "532527": {"name": "泸西县", "alpha": "l"},
    "532528": {"name": "元阳县", "alpha": "y"},
    "532529": {"name": "红河县", "alpha": "h"},
    "532530": {"name": "金平苗族瑶族傣族自治县", "alpha": "j"},
    "532531": {"name": "绿春县", "alpha": "l"},
    "532532": {"name": "河口瑶族自治县", "alpha": "h"}
  },
  "532600": {
    "532601": {"name": "文山", "alpha": "w"},
    "532622": {"name": "砚山县", "alpha": "y"},
    "532623": {"name": "西畴县", "alpha": "x"},
    "532624": {"name": "麻栗坡县", "alpha": "m"},
    "532625": {"name": "马关县", "alpha": "m"},
    "532626": {"name": "丘北县", "alpha": "q"},
    "532627": {"name": "广南县", "alpha": "g"},
    "532628": {"name": "富宁县", "alpha": "f"}
  },
  "532800": {
    "532801": {"name": "景洪", "alpha": "j"},
    "532822": {"name": "勐海县", "alpha": "m"},
    "532823": {"name": "勐腊县", "alpha": "m"}
  },
  "532900": {
    "532901": {"name": "大理", "alpha": "d"},
    "532922": {"name": "漾濞彝族自治县", "alpha": "y"},
    "532923": {"name": "祥云县", "alpha": "x"},
    "532924": {"name": "宾川县", "alpha": "b"},
    "532925": {"name": "弥渡县", "alpha": "m"},
    "532926": {"name": "南涧彝族自治县", "alpha": "n"},
    "532927": {"name": "巍山彝族回族自治县", "alpha": "w"},
    "532928": {"name": "永平县", "alpha": "y"},
    "532929": {"name": "云龙县", "alpha": "y"},
    "532930": {"name": "洱源县", "alpha": "e"},
    "532931": {"name": "剑川县", "alpha": "j"},
    "532932": {"name": "鹤庆县", "alpha": "h"}
  },
  "533100": {
    "533102": {"name": "瑞丽", "alpha": "r"},
    "533103": {"name": "芒", "alpha": "m"},
    "533122": {"name": "梁河县", "alpha": "l"},
    "533123": {"name": "盈江县", "alpha": "y"},
    "533124": {"name": "陇川县", "alpha": "l"}
  },
  "533300": {
    "533301": {"name": "泸水", "alpha": "l"},
    "533323": {"name": "福贡县", "alpha": "f"},
    "533324": {"name": "贡山独龙族怒族自治县", "alpha": "g"},
    "533325": {"name": "兰坪白族普米族自治县", "alpha": "l"}
  },
  "533400": {
    "533401": {"name": "香格里拉", "alpha": "x"},
    "533422": {"name": "德钦县", "alpha": "d"},
    "533423": {"name": "维西傈僳族自治县", "alpha": "w"}
  },
  "540100": {
    "540102": {"name": "城关区", "alpha": "c"},
    "540103": {"name": "堆龙德庆区", "alpha": "d"},
    "540104": {"name": "达孜区", "alpha": "d"},
    "540121": {"name": "林周县", "alpha": "l"},
    "540122": {"name": "当雄县", "alpha": "d"},
    "540123": {"name": "尼木县", "alpha": "n"},
    "540124": {"name": "曲水县", "alpha": "q"},
    "540127": {"name": "墨竹工卡县", "alpha": "m"},
    "540171": {"name": "格尔木藏青工业园区", "alpha": "g"},
    "540172": {"name": "拉萨经济技术开发区", "alpha": "l"},
    "540173": {"name": "西藏文化旅游创意园区", "alpha": "x"},
    "540174": {"name": "达孜工业园区", "alpha": "d"}
  },
  "540200": {
    "540202": {"name": "桑珠孜区", "alpha": "s"},
    "540221": {"name": "南木林县", "alpha": "n"},
    "540222": {"name": "江孜县", "alpha": "j"},
    "540223": {"name": "定日县", "alpha": "d"},
    "540224": {"name": "萨迦县", "alpha": "s"},
    "540225": {"name": "拉孜县", "alpha": "l"},
    "540226": {"name": "昂仁县", "alpha": "a"},
    "540227": {"name": "谢通门县", "alpha": "x"},
    "540228": {"name": "白朗县", "alpha": "b"},
    "540229": {"name": "仁布县", "alpha": "r"},
    "540230": {"name": "康马县", "alpha": "k"},
    "540231": {"name": "定结县", "alpha": "d"},
    "540232": {"name": "仲巴县", "alpha": "z"},
    "540233": {"name": "亚东县", "alpha": "y"},
    "540234": {"name": "吉隆县", "alpha": "j"},
    "540235": {"name": "聂拉木县", "alpha": "n"},
    "540236": {"name": "萨嘎县", "alpha": "s"},
    "540237": {"name": "岗巴县", "alpha": "g"}
  },
  "540300": {
    "540302": {"name": "卡若区", "alpha": "k"},
    "540321": {"name": "江达县", "alpha": "j"},
    "540322": {"name": "贡觉县", "alpha": "g"},
    "540323": {"name": "类乌齐县", "alpha": "l"},
    "540324": {"name": "丁青县", "alpha": "d"},
    "540325": {"name": "察雅县", "alpha": "c"},
    "540326": {"name": "八宿县", "alpha": "b"},
    "540327": {"name": "左贡县", "alpha": "z"},
    "540328": {"name": "芒康县", "alpha": "m"},
    "540329": {"name": "洛隆县", "alpha": "l"},
    "540330": {"name": "边坝县", "alpha": "b"}
  },
  "540400": {
    "540402": {"name": "巴宜区", "alpha": "b"},
    "540421": {"name": "工布江达县", "alpha": "g"},
    "540422": {"name": "米林县", "alpha": "m"},
    "540423": {"name": "墨脱县", "alpha": "m"},
    "540424": {"name": "波密县", "alpha": "b"},
    "540425": {"name": "察隅县", "alpha": "c"},
    "540426": {"name": "朗县", "alpha": "l"}
  },
  "540500": {
    "540502": {"name": "乃东区", "alpha": "n"},
    "540521": {"name": "扎囊县", "alpha": "z"},
    "540522": {"name": "贡嘎县", "alpha": "g"},
    "540523": {"name": "桑日县", "alpha": "s"},
    "540524": {"name": "琼结县", "alpha": "q"},
    "540525": {"name": "曲松县", "alpha": "q"},
    "540526": {"name": "措美县", "alpha": "c"},
    "540527": {"name": "洛扎县", "alpha": "l"},
    "540528": {"name": "加查县", "alpha": "j"},
    "540529": {"name": "隆子县", "alpha": "l"},
    "540530": {"name": "错那县", "alpha": "c"},
    "540531": {"name": "浪卡子县", "alpha": "l"}
  },
  "540600": {
    "540602": {"name": "色尼区", "alpha": "s"},
    "540621": {"name": "嘉黎县", "alpha": "j"},
    "540622": {"name": "比如县", "alpha": "b"},
    "540623": {"name": "聂荣县", "alpha": "n"},
    "540624": {"name": "安多县", "alpha": "a"},
    "540625": {"name": "申扎县", "alpha": "s"},
    "540626": {"name": "索县", "alpha": "s"},
    "540627": {"name": "班戈县", "alpha": "b"},
    "540628": {"name": "巴青县", "alpha": "b"},
    "540629": {"name": "尼玛县", "alpha": "n"},
    "540630": {"name": "双湖县", "alpha": "s"}
  },
  "542500": {
    "542521": {"name": "普兰县", "alpha": "p"},
    "542522": {"name": "札达县", "alpha": "z"},
    "542523": {"name": "噶尔县", "alpha": "g"},
    "542524": {"name": "日土县", "alpha": "r"},
    "542525": {"name": "革吉县", "alpha": "g"},
    "542526": {"name": "改则县", "alpha": "g"},
    "542527": {"name": "措勤县", "alpha": "c"}
  },
  "610100": {
    "610102": {"name": "新城区", "alpha": "x"},
    "610103": {"name": "碑林区", "alpha": "b"},
    "610104": {"name": "莲湖区", "alpha": "l"},
    "610111": {"name": "灞桥区", "alpha": "b"},
    "610112": {"name": "未央区", "alpha": "w"},
    "610113": {"name": "雁塔区", "alpha": "y"},
    "610114": {"name": "阎良区", "alpha": "y"},
    "610115": {"name": "临潼区", "alpha": "l"},
    "610116": {"name": "长安区", "alpha": "c"},
    "610117": {"name": "高陵区", "alpha": "g"},
    "610118": {"name": "鄠邑区", "alpha": "h"},
    "610122": {"name": "蓝田县", "alpha": "l"},
    "610124": {"name": "周至县", "alpha": "z"}
  },
  "610200": {
    "610202": {"name": "王益区", "alpha": "w"},
    "610203": {"name": "印台区", "alpha": "y"},
    "610204": {"name": "耀州区", "alpha": "y"},
    "610222": {"name": "宜君县", "alpha": "y"}
  },
  "610300": {
    "610302": {"name": "渭滨区", "alpha": "w"},
    "610303": {"name": "金台区", "alpha": "j"},
    "610304": {"name": "陈仓区", "alpha": "c"},
    "610322": {"name": "凤翔县", "alpha": "f"},
    "610323": {"name": "岐山县", "alpha": "q"},
    "610324": {"name": "扶风县", "alpha": "f"},
    "610326": {"name": "眉县", "alpha": "m"},
    "610327": {"name": "陇县", "alpha": "l"},
    "610328": {"name": "千阳县", "alpha": "q"},
    "610329": {"name": "麟游县", "alpha": "l"},
    "610330": {"name": "凤县", "alpha": "f"},
    "610331": {"name": "太白县", "alpha": "t"}
  },
  "610400": {
    "610402": {"name": "秦都区", "alpha": "q"},
    "610403": {"name": "杨陵区", "alpha": "y"},
    "610404": {"name": "渭城区", "alpha": "w"},
    "610422": {"name": "三原县", "alpha": "s"},
    "610423": {"name": "泾阳县", "alpha": "j"},
    "610424": {"name": "乾县", "alpha": "q"},
    "610425": {"name": "礼泉县", "alpha": "l"},
    "610426": {"name": "永寿县", "alpha": "y"},
    "610428": {"name": "长武县", "alpha": "c"},
    "610429": {"name": "旬邑县", "alpha": "x"},
    "610430": {"name": "淳化县", "alpha": "c"},
    "610431": {"name": "武功县", "alpha": "w"},
    "610481": {"name": "兴平", "alpha": "x"},
    "610482": {"name": "彬州", "alpha": "b"}
  },
  "610500": {
    "610502": {"name": "临渭区", "alpha": "l"},
    "610503": {"name": "华州区", "alpha": "h"},
    "610522": {"name": "潼关县", "alpha": "t"},
    "610523": {"name": "大荔县", "alpha": "d"},
    "610524": {"name": "合阳县", "alpha": "h"},
    "610525": {"name": "澄城县", "alpha": "c"},
    "610526": {"name": "蒲城县", "alpha": "p"},
    "610527": {"name": "白水县", "alpha": "b"},
    "610528": {"name": "富平县", "alpha": "f"},
    "610581": {"name": "韩城", "alpha": "h"},
    "610582": {"name": "华阴", "alpha": "h"}
  },
  "610600": {
    "610602": {"name": "宝塔区", "alpha": "b"},
    "610603": {"name": "安塞区", "alpha": "a"},
    "610621": {"name": "延长县", "alpha": "y"},
    "610622": {"name": "延川县", "alpha": "y"},
    "610623": {"name": "子长县", "alpha": "z"},
    "610625": {"name": "志丹县", "alpha": "z"},
    "610626": {"name": "吴起县", "alpha": "w"},
    "610627": {"name": "甘泉县", "alpha": "g"},
    "610628": {"name": "富县", "alpha": "f"},
    "610629": {"name": "洛川县", "alpha": "l"},
    "610630": {"name": "宜川县", "alpha": "y"},
    "610631": {"name": "黄龙县", "alpha": "h"},
    "610632": {"name": "黄陵县", "alpha": "h"}
  },
  "610700": {
    "610702": {"name": "汉台区", "alpha": "h"},
    "610703": {"name": "南郑区", "alpha": "n"},
    "610722": {"name": "城固县", "alpha": "c"},
    "610723": {"name": "洋县", "alpha": "y"},
    "610724": {"name": "西乡县", "alpha": "x"},
    "610725": {"name": "勉县", "alpha": "m"},
    "610726": {"name": "宁强县", "alpha": "n"},
    "610727": {"name": "略阳县", "alpha": "l"},
    "610728": {"name": "镇巴县", "alpha": "z"},
    "610729": {"name": "留坝县", "alpha": "l"},
    "610730": {"name": "佛坪县", "alpha": "f"}
  },
  "610800": {
    "610802": {"name": "榆阳区", "alpha": "y"},
    "610803": {"name": "横山区", "alpha": "h"},
    "610822": {"name": "府谷县", "alpha": "f"},
    "610824": {"name": "靖边县", "alpha": "j"},
    "610825": {"name": "定边县", "alpha": "d"},
    "610826": {"name": "绥德县", "alpha": "s"},
    "610827": {"name": "米脂县", "alpha": "m"},
    "610828": {"name": "佳县", "alpha": "j"},
    "610829": {"name": "吴堡县", "alpha": "w"},
    "610830": {"name": "清涧县", "alpha": "q"},
    "610831": {"name": "子洲县", "alpha": "z"},
    "610881": {"name": "神木", "alpha": "s"}
  },
  "610900": {
    "610902": {"name": "汉滨区", "alpha": "h"},
    "610921": {"name": "汉阴县", "alpha": "h"},
    "610922": {"name": "石泉县", "alpha": "s"},
    "610923": {"name": "宁陕县", "alpha": "n"},
    "610924": {"name": "紫阳县", "alpha": "z"},
    "610925": {"name": "岚皋县", "alpha": "l"},
    "610926": {"name": "平利县", "alpha": "p"},
    "610927": {"name": "镇坪县", "alpha": "z"},
    "610928": {"name": "旬阳县", "alpha": "x"},
    "610929": {"name": "白河县", "alpha": "b"}
  },
  "611000": {
    "611002": {"name": "商州区", "alpha": "s"},
    "611021": {"name": "洛南县", "alpha": "l"},
    "611022": {"name": "丹凤县", "alpha": "d"},
    "611023": {"name": "商南县", "alpha": "s"},
    "611024": {"name": "山阳县", "alpha": "s"},
    "611025": {"name": "镇安县", "alpha": "z"},
    "611026": {"name": "柞水县", "alpha": "z"}
  },
  "620100": {
    "620102": {"name": "城关区", "alpha": "c"},
    "620103": {"name": "七里河区", "alpha": "q"},
    "620104": {"name": "西固区", "alpha": "x"},
    "620105": {"name": "安宁区", "alpha": "a"},
    "620111": {"name": "红古区", "alpha": "h"},
    "620121": {"name": "永登县", "alpha": "y"},
    "620122": {"name": "皋兰县", "alpha": "g"},
    "620123": {"name": "榆中县", "alpha": "y"},
    "620171": {"name": "兰州新区", "alpha": "l"}
  },
  "620200": {
    "620201100": {"name": "新城镇", "alpha": "x"},
    "620201101": {"name": "峪泉镇", "alpha": "y"},
    "620201102": {"name": "文殊镇", "alpha": "w"},
    "620201401": {"name": "雄关区", "alpha": "x"},
    "620201402": {"name": "镜铁区", "alpha": "j"},
    "620201403": {"name": "长城区", "alpha": "c"}
  },
  "620300": {
    "620302": {"name": "金川区", "alpha": "j"},
    "620321": {"name": "永昌县", "alpha": "y"}
  },
  "620400": {
    "620402": {"name": "白银区", "alpha": "b"},
    "620403": {"name": "平川区", "alpha": "p"},
    "620421": {"name": "靖远县", "alpha": "j"},
    "620422": {"name": "会宁县", "alpha": "h"},
    "620423": {"name": "景泰县", "alpha": "j"}
  },
  "620500": {
    "620502": {"name": "秦州区", "alpha": "q"},
    "620503": {"name": "麦积区", "alpha": "m"},
    "620521": {"name": "清水县", "alpha": "q"},
    "620522": {"name": "秦安县", "alpha": "q"},
    "620523": {"name": "甘谷县", "alpha": "g"},
    "620524": {"name": "武山县", "alpha": "w"},
    "620525": {"name": "张家川回族自治县", "alpha": "z"}
  },
  "620600": {
    "620602": {"name": "凉州区", "alpha": "l"},
    "620621": {"name": "民勤县", "alpha": "m"},
    "620622": {"name": "古浪县", "alpha": "g"},
    "620623": {"name": "天祝藏族自治县", "alpha": "t"}
  },
  "620700": {
    "620702": {"name": "甘州区", "alpha": "g"},
    "620721": {"name": "肃南裕固族自治县", "alpha": "s"},
    "620722": {"name": "民乐县", "alpha": "m"},
    "620723": {"name": "临泽县", "alpha": "l"},
    "620724": {"name": "高台县", "alpha": "g"},
    "620725": {"name": "山丹县", "alpha": "s"}
  },
  "620800": {
    "620802": {"name": "崆峒区", "alpha": "k"},
    "620821": {"name": "泾川县", "alpha": "j"},
    "620822": {"name": "灵台县", "alpha": "l"},
    "620823": {"name": "崇信县", "alpha": "c"},
    "620825": {"name": "庄浪县", "alpha": "z"},
    "620826": {"name": "静宁县", "alpha": "j"},
    "620881": {"name": "华亭", "alpha": "h"}
  },
  "620900": {
    "620902": {"name": "肃州区", "alpha": "s"},
    "620921": {"name": "金塔县", "alpha": "j"},
    "620922": {"name": "瓜州县", "alpha": "g"},
    "620923": {"name": "肃北蒙古族自治县", "alpha": "s"},
    "620924": {"name": "阿克塞哈萨克族自治县", "alpha": "a"},
    "620981": {"name": "玉门", "alpha": "y"},
    "620982": {"name": "敦煌", "alpha": "d"}
  },
  "621000": {
    "621002": {"name": "西峰区", "alpha": "x"},
    "621021": {"name": "庆城县", "alpha": "q"},
    "621022": {"name": "环县", "alpha": "h"},
    "621023": {"name": "华池县", "alpha": "h"},
    "621024": {"name": "合水县", "alpha": "h"},
    "621025": {"name": "正宁县", "alpha": "z"},
    "621026": {"name": "宁县", "alpha": "n"},
    "621027": {"name": "镇原县", "alpha": "z"}
  },
  "621100": {
    "621102": {"name": "安定区", "alpha": "a"},
    "621121": {"name": "通渭县", "alpha": "t"},
    "621122": {"name": "陇西县", "alpha": "l"},
    "621123": {"name": "渭源县", "alpha": "w"},
    "621124": {"name": "临洮县", "alpha": "l"},
    "621125": {"name": "漳县", "alpha": "z"},
    "621126": {"name": "岷县", "alpha": "m"}
  },
  "621200": {
    "621202": {"name": "武都区", "alpha": "w"},
    "621221": {"name": "成县", "alpha": "c"},
    "621222": {"name": "文县", "alpha": "w"},
    "621223": {"name": "宕昌县", "alpha": "d"},
    "621224": {"name": "康县", "alpha": "k"},
    "621225": {"name": "西和县", "alpha": "x"},
    "621226": {"name": "礼县", "alpha": "l"},
    "621227": {"name": "徽县", "alpha": "h"},
    "621228": {"name": "两当县", "alpha": "l"}
  },
  "622900": {
    "622901": {"name": "临夏", "alpha": "l"},
    "622921": {"name": "临夏县", "alpha": "l"},
    "622922": {"name": "康乐县", "alpha": "k"},
    "622923": {"name": "永靖县", "alpha": "y"},
    "622924": {"name": "广河县", "alpha": "g"},
    "622925": {"name": "和政县", "alpha": "h"},
    "622926": {"name": "东乡族自治县", "alpha": "d"},
    "622927": {"name": "积石山保安族东乡族撒拉族自治县", "alpha": "j"}
  },
  "623000": {
    "623001": {"name": "合作", "alpha": "h"},
    "623021": {"name": "临潭县", "alpha": "l"},
    "623022": {"name": "卓尼县", "alpha": "z"},
    "623023": {"name": "舟曲县", "alpha": "z"},
    "623024": {"name": "迭部县", "alpha": "d"},
    "623025": {"name": "玛曲县", "alpha": "m"},
    "623026": {"name": "碌曲县", "alpha": "l"},
    "623027": {"name": "夏河县", "alpha": "x"}
  },
  "630100": {
    "630102": {"name": "城东区", "alpha": "c"},
    "630103": {"name": "城中区", "alpha": "c"},
    "630104": {"name": "城西区", "alpha": "c"},
    "630105": {"name": "城北区", "alpha": "c"},
    "630121": {"name": "大通回族土族自治县", "alpha": "d"},
    "630122": {"name": "湟中县", "alpha": "h"},
    "630123": {"name": "湟源县", "alpha": "h"}
  },
  "630200": {
    "630202": {"name": "乐都区", "alpha": "l"},
    "630203": {"name": "平安区", "alpha": "p"},
    "630222": {"name": "民和回族土族自治县", "alpha": "m"},
    "630223": {"name": "互助土族自治县", "alpha": "h"},
    "630224": {"name": "化隆回族自治县", "alpha": "h"},
    "630225": {"name": "循化撒拉族自治县", "alpha": "x"}
  },
  "632200": {
    "632221": {"name": "门源回族自治县", "alpha": "m"},
    "632222": {"name": "祁连县", "alpha": "q"},
    "632223": {"name": "海晏县", "alpha": "h"},
    "632224": {"name": "刚察县", "alpha": "g"}
  },
  "632300": {
    "632321": {"name": "同仁县", "alpha": "t"},
    "632322": {"name": "尖扎县", "alpha": "j"},
    "632323": {"name": "泽库县", "alpha": "z"},
    "632324": {"name": "河南蒙古族自治县", "alpha": "h"}
  },
  "632500": {
    "632521": {"name": "共和县", "alpha": "g"},
    "632522": {"name": "同德县", "alpha": "t"},
    "632523": {"name": "贵德县", "alpha": "g"},
    "632524": {"name": "兴海县", "alpha": "x"},
    "632525": {"name": "贵南县", "alpha": "g"}
  },
  "632600": {
    "632621": {"name": "玛沁县", "alpha": "m"},
    "632622": {"name": "班玛县", "alpha": "b"},
    "632623": {"name": "甘德县", "alpha": "g"},
    "632624": {"name": "达日县", "alpha": "d"},
    "632625": {"name": "久治县", "alpha": "j"},
    "632626": {"name": "玛多县", "alpha": "m"}
  },
  "632700": {
    "632701": {"name": "玉树", "alpha": "y"},
    "632722": {"name": "杂多县", "alpha": "z"},
    "632723": {"name": "称多县", "alpha": "c"},
    "632724": {"name": "治多县", "alpha": "z"},
    "632725": {"name": "囊谦县", "alpha": "n"},
    "632726": {"name": "曲麻莱县", "alpha": "q"}
  },
  "632800": {
    "632801": {"name": "格尔木", "alpha": "g"},
    "632802": {"name": "德令哈", "alpha": "d"},
    "632803": {"name": "茫崖", "alpha": "m"},
    "632821": {"name": "乌兰县", "alpha": "w"},
    "632822": {"name": "都兰县", "alpha": "d"},
    "632823": {"name": "天峻县", "alpha": "t"},
    "632857": {"name": "大柴旦行政委员会", "alpha": "d"}
  },
  "640100": {
    "640104": {"name": "兴庆区", "alpha": "x"},
    "640105": {"name": "西夏区", "alpha": "x"},
    "640106": {"name": "金凤区", "alpha": "j"},
    "640121": {"name": "永宁县", "alpha": "y"},
    "640122": {"name": "贺兰县", "alpha": "h"},
    "640181": {"name": "灵武", "alpha": "l"}
  },
  "640200": {
    "640202": {"name": "大武口区", "alpha": "d"},
    "640205": {"name": "惠农区", "alpha": "h"},
    "640221": {"name": "平罗县", "alpha": "p"}
  },
  "640300": {
    "640302": {"name": "利通区", "alpha": "l"},
    "640303": {"name": "红寺堡区", "alpha": "h"},
    "640323": {"name": "盐池县", "alpha": "y"},
    "640324": {"name": "同心县", "alpha": "t"},
    "640381": {"name": "青铜峡", "alpha": "q"}
  },
  "640400": {
    "640402": {"name": "原州区", "alpha": "y"},
    "640422": {"name": "西吉县", "alpha": "x"},
    "640423": {"name": "隆德县", "alpha": "l"},
    "640424": {"name": "泾源县", "alpha": "j"},
    "640425": {"name": "彭阳县", "alpha": "p"}
  },
  "640500": {
    "640502": {"name": "沙坡头区", "alpha": "s"},
    "640521": {"name": "中宁县", "alpha": "z"},
    "640522": {"name": "海原县", "alpha": "h"}
  },
  "650100": {
    "650102": {"name": "天山区", "alpha": "t"},
    "650103": {"name": "沙依巴克区", "alpha": "s"},
    "650104": {"name": "新区", "alpha": "x"},
    "650105": {"name": "水磨沟区", "alpha": "s"},
    "650106": {"name": "头屯河区", "alpha": "t"},
    "650107": {"name": "达坂城区", "alpha": "d"},
    "650109": {"name": "米东区", "alpha": "m"},
    "650121": {"name": "乌鲁木齐县", "alpha": "w"},
    "650171": {"name": "乌鲁木齐经济技术开发区", "alpha": "w"},
    "650172": {"name": "乌鲁木齐高新技术产业开发区", "alpha": "w"}
  },
  "650200": {
    "650202": {"name": "独山子区", "alpha": "d"},
    "650203": {"name": "克拉玛依区", "alpha": "k"},
    "650204": {"name": "白碱滩区", "alpha": "b"},
    "650205": {"name": "乌尔禾区", "alpha": "w"}
  },
  "650400": {
    "650402": {"name": "高昌区", "alpha": "g"},
    "650421": {"name": "鄯善县", "alpha": "s"},
    "650422": {"name": "托克逊县", "alpha": "t"}
  },
  "650500": {
    "650502": {"name": "伊州区", "alpha": "y"},
    "650521": {"name": "巴里坤哈萨克自治县", "alpha": "b"},
    "650522": {"name": "伊吾县", "alpha": "y"}
  },
  "652300": {
    "652301": {"name": "昌吉", "alpha": "c"},
    "652302": {"name": "阜康", "alpha": "f"},
    "652323": {"name": "呼图壁县", "alpha": "h"},
    "652324": {"name": "玛纳斯县", "alpha": "m"},
    "652325": {"name": "奇台县", "alpha": "q"},
    "652327": {"name": "吉木萨尔县", "alpha": "j"},
    "652328": {"name": "木垒哈萨克自治县", "alpha": "m"}
  },
  "652700": {
    "652701": {"name": "博乐", "alpha": "b"},
    "652702": {"name": "阿拉山口", "alpha": "a"},
    "652722": {"name": "精河县", "alpha": "j"},
    "652723": {"name": "温泉县", "alpha": "w"}
  },
  "652800": {
    "652801": {"name": "库尔勒", "alpha": "k"},
    "652822": {"name": "轮台县", "alpha": "l"},
    "652823": {"name": "尉犁县", "alpha": "y"},
    "652824": {"name": "若羌县", "alpha": "r"},
    "652825": {"name": "且末县", "alpha": "q"},
    "652826": {"name": "焉耆回族自治县", "alpha": "y"},
    "652827": {"name": "和静县", "alpha": "h"},
    "652828": {"name": "和硕县", "alpha": "h"},
    "652829": {"name": "博湖县", "alpha": "b"},
    "652871": {"name": "库尔勒经济技术开发区", "alpha": "k"}
  },
  "652900": {
    "652901": {"name": "阿克苏", "alpha": "a"},
    "652922": {"name": "温宿县", "alpha": "w"},
    "652923": {"name": "库车县", "alpha": "k"},
    "652924": {"name": "沙雅县", "alpha": "s"},
    "652925": {"name": "新和县", "alpha": "x"},
    "652926": {"name": "拜城县", "alpha": "b"},
    "652927": {"name": "乌什县", "alpha": "w"},
    "652928": {"name": "阿瓦提县", "alpha": "a"},
    "652929": {"name": "柯坪县", "alpha": "k"}
  },
  "653000": {
    "653001": {"name": "阿图什", "alpha": "a"},
    "653022": {"name": "阿克陶县", "alpha": "a"},
    "653023": {"name": "阿合奇县", "alpha": "a"},
    "653024": {"name": "乌恰县", "alpha": "w"}
  },
  "653100": {
    "653101": {"name": "喀什", "alpha": "k"},
    "653121": {"name": "疏附县", "alpha": "s"},
    "653122": {"name": "疏勒县", "alpha": "s"},
    "653123": {"name": "英吉沙县", "alpha": "y"},
    "653124": {"name": "泽普县", "alpha": "z"},
    "653125": {"name": "莎车县", "alpha": "s"},
    "653126": {"name": "叶城县", "alpha": "y"},
    "653127": {"name": "麦盖提县", "alpha": "m"},
    "653128": {"name": "岳普湖县", "alpha": "y"},
    "653129": {"name": "伽师县", "alpha": "j"},
    "653130": {"name": "巴楚县", "alpha": "b"},
    "653131": {"name": "塔什库尔干塔吉克自治县", "alpha": "t"}
  },
  "653200": {
    "653201": {"name": "和田", "alpha": "h"},
    "653221": {"name": "和田县", "alpha": "h"},
    "653222": {"name": "墨玉县", "alpha": "m"},
    "653223": {"name": "皮山县", "alpha": "p"},
    "653224": {"name": "洛浦县", "alpha": "l"},
    "653225": {"name": "策勒县", "alpha": "c"},
    "653226": {"name": "于田县", "alpha": "y"},
    "653227": {"name": "民丰县", "alpha": "m"}
  },
  "654000": {
    "654002": {"name": "伊宁", "alpha": "y"},
    "654003": {"name": "奎屯", "alpha": "k"},
    "654004": {"name": "霍尔果斯", "alpha": "h"},
    "654021": {"name": "伊宁县", "alpha": "y"},
    "654022": {"name": "察布查尔锡伯自治县", "alpha": "c"},
    "654023": {"name": "霍城县", "alpha": "h"},
    "654024": {"name": "巩留县", "alpha": "g"},
    "654025": {"name": "新源县", "alpha": "x"},
    "654026": {"name": "昭苏县", "alpha": "z"},
    "654027": {"name": "特克斯县", "alpha": "t"},
    "654028": {"name": "尼勒克县", "alpha": "n"}
  },
  "654200": {
    "654201": {"name": "塔城", "alpha": "t"},
    "654202": {"name": "乌苏", "alpha": "w"},
    "654221": {"name": "额敏县", "alpha": "e"},
    "654223": {"name": "沙湾县", "alpha": "s"},
    "654224": {"name": "托里县", "alpha": "t"},
    "654225": {"name": "裕民县", "alpha": "y"},
    "654226": {"name": "和布克赛尔蒙古自治县", "alpha": "h"}
  },
  "654300": {
    "654301": {"name": "阿勒泰", "alpha": "a"},
    "654321": {"name": "布尔津县", "alpha": "b"},
    "654322": {"name": "富蕴县", "alpha": "f"},
    "654323": {"name": "福海县", "alpha": "f"},
    "654324": {"name": "哈巴河县", "alpha": "h"},
    "654325": {"name": "青河县", "alpha": "q"},
    "654326": {"name": "吉木乃县", "alpha": "j"}
  },
  "659000": {
    "659001": {"name": "石河子", "alpha": "s"},
    "659002": {"name": "阿拉尔", "alpha": "a"},
    "659003": {"name": "图木舒克", "alpha": "t"},
    "659004": {"name": "五家渠", "alpha": "w"},
    "659006": {"name": "铁门关", "alpha": "t"}
  },
  "810100": {
    "810101": {"name": "中西区", "alpha": "z"},
    "810102": {"name": "湾仔区", "alpha": "w"},
    "810103": {"name": "东区", "alpha": "d"},
    "810104": {"name": "南区", "alpha": "n"},
    "810105": {"name": "油尖旺区", "alpha": "y"},
    "810106": {"name": "深水埗区", "alpha": "s"},
    "810107": {"name": "九龙城区", "alpha": "j"},
    "810108": {"name": "黄大仙区", "alpha": "h"},
    "810109": {"name": "观塘区", "alpha": "g"},
    "810110": {"name": "荃湾区", "alpha": "q"},
    "810111": {"name": "屯门区", "alpha": "t"},
    "810112": {"name": "元朗区", "alpha": "y"},
    "810113": {"name": "北区", "alpha": "b"},
    "810114": {"name": "大埔区", "alpha": "d"},
    "810115": {"name": "西贡区", "alpha": "x"},
    "810116": {"name": "沙田区", "alpha": "s"},
    "810117": {"name": "葵青区", "alpha": "k"},
    "810118": {"name": "离岛区", "alpha": "l"}
  },
  "820100": {
    "820101": {"name": "花地玛堂区", "alpha": "h"},
    "820102": {"name": "花王堂区", "alpha": "h"},
    "820103": {"name": "望德堂区", "alpha": "w"},
    "820104": {"name": "大堂区", "alpha": "d"},
    "820105": {"name": "风顺堂区", "alpha": "f"},
    "820106": {"name": "嘉模堂区", "alpha": "j"},
    "820107": {"name": "路凼填海区", "alpha": "l"},
    "820108": {"name": "圣方济各堂区", "alpha": "s"}
  }
};
