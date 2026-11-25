import 'package:amap_flutter_base_plus/amap_flutter_base_plus.dart';

import 'package:imboy/config/env.dart';

/// 构建内嵌 WebView 渲染的官方 AMap JS API 地图页。
/// 与 POI 检索使用相同的 GCJ-02 坐标系；拖动结束经 FlutterBridge
/// 回传 moveend 事件，window.setMapCenter 供宿主程序化移动中心。
///
/// ⚠️ 需要 AMap 控制台单独申请一个「Web端(JS API)」类型的 Key（跟现在
/// aMapWebKey 用的「Web服务」Key 是两种不同类型，高德会分别校验），
/// 并在控制台给这个 Key 配置安全密钥(JSCode)+域名白名单。这里暂时复用
/// aMapWebKey 占位，真机验证时如果地图加载失败/控制台报 key 无效，
/// 去 AMap 控制台建一个 JS API Key 换掉。
String buildAmapWebMapHtml(LatLng center) {
  final jsKey = Env().aMapWebKey;
  return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>html,body,#map{width:100%;height:100%;margin:0;padding:0;}</style>
</head>
<body>
<div id="map"></div>
<script src="https://webapi.amap.com/maps?v=2.0&key=$jsKey"></script>
<script>
  var map = new AMap.Map('map', {
    zoom: 16,
    center: [${center.longitude}, ${center.latitude}],
    resizeEnable: true
  });
  function bridgeSend(type, data) {
    if (window.FlutterBridge) {
      window.FlutterBridge.postMessage(JSON.stringify({type: type, data: data}));
    }
  }
  map.on('dragend', function () {
    var c = map.getCenter();
    bridgeSend('moveend', {lat: c.lat, lng: c.lng});
  });
  // 供 Flutter 端程序化移动地图中心（我的位置 / 点击 POI 列表项）
  window.setMapCenter = function (lat, lng) {
    var pos = [lng, lat];
    map.setCenter(pos);
  };
</script>
</body>
</html>
''';
}
