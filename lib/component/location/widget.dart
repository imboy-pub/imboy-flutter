import 'dart:async';
import 'dart:convert';

import 'package:amap_flutter_base_plus/amap_flutter_base_plus.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'amap_helper.dart';
import 'package:imboy/i18n/strings.g.dart'; // 确保这个文件中没有使用 niku

class SearchBarStyle {
  final Color backgroundColor;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  const SearchBarStyle({
    this.backgroundColor = const Color.fromRGBO(142, 142, 147, .15),
    this.padding = const EdgeInsets.all(5.0),
    this.borderRadius = const BorderRadius.all(Radius.circular(5.0)),
  });
}

// ignore: must_be_immutable
class MapLocationPicker extends StatefulWidget {
  @override
  // ignore: library_private_types_in_public_api
  _MapLocationPickerState createState() => _MapLocationPickerState();
  Object? arguments;
  LatLng? latLng;
  String citycode = "";
  SearchBarStyle searchBarStyle = const SearchBarStyle();
  bool isMapImage = false; //是否要返回地图截图
  //LatLng(26.017794, 119.41755599999999)
  MapLocationPicker({super.key, this.arguments}) {
    latLng = LatLng(
      (arguments as Map)["lat"] as double,
      (arguments as Map)["lng"] as double,
    );
    citycode = (arguments as Map)["citycode"] as String;
    // citycode = "350100";
    // latLng = LatLng(26.017794, 119.41755599999999);
    isMapImage = (arguments as Map)["isMapImage"] as bool;
  }
}

class _MapLocationPickerState extends State<MapLocationPicker> with _BLoCMixin {
  static const _kMinChildSize = 0.4;
  static const _kMaxChildSize = 0.7;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  FocusNode focusNode = FocusNode();
  double _fabHeight = 16.0;
  bool _isKeyword = false;
  bool _animate = false;
  int page = 1;
  int _seLindex = 0;
  final _searchQueryController = TextEditingController();
  // 地图当前居中的坐标（默认=设备当前定位，拖动地图/选中 POI/点「我的位置」时更新）
  LatLng _currentCenterCoordinate = const LatLng(39.909187, 116.397451);
  late final WebViewController _webViewController;
  void _onSheetExtentChanged() {
    if (!mounted || !_sheetController.isAttached) return;
    final screenH = MediaQuery.of(context).size.height;
    final range = (_kMaxChildSize - _kMinChildSize) * screenH;
    final pos =
        ((_sheetController.size - _kMinChildSize) /
                (_kMaxChildSize - _kMinChildSize))
            .clamp(0.0, 1.0);
    setState(() {
      _fabHeight = pos * range * .5 + 16;
    });
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetExtentChanged);
    _sheetController.dispose();
    super.dispose();
  }

  @override
  // ignore: overridden_fields
  final poiStream = StreamController<List<AMapPosition>>();
  List<AMapPosition> poiInfoList = [];
  String searchType =
      "010000|020000|030000|040000|050000|060000|070000|080000|090000|100000|110000|120201|120300|140000|150400|190600|190301";
  AMapPosition? _sendMsg;
  @override
  void initState() {
    super.initState();
    _currentCenterCoordinate = widget.latLng!;
    _sheetController.addListener(_onSheetExtentChanged);
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        _sheetController.animateTo(
          _kMaxChildSize,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        _animate = true;
      } else {
        _sheetController.animateTo(
          _kMinChildSize,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
    _initWebViewMap();
    // 不再有原生地图 onMapCreated 回调来触发首次搜索，这里直接调
    _search(widget.latLng!);
  }

  // 用高德官方 JS 地图 API（webapi.amap.com/maps）通过 WebView 渲染，
  // 而不是原生 amap_flutter_map_plus——JS API 是高德官方给 Web/WebView
  // 场景设计的产品，天然支持拖拽/缩放，坐标系跟 POI 搜索一致（GCJ-02），
  // webview_flutter 在 iOS/Android/macOS 上都有实现，不用再区分平台。
  //
  // ⚠️ 需要 AMap 控制台单独申请一个「Web端(JS API)」类型的 Key（跟现在
  // aMapWebKey 用的「Web服务」Key 是两种不同类型，高德会分别校验），
  // 并在控制台给这个 Key 配置安全密钥(JSCode)+域名白名单。这里暂时复用
  // aMapWebKey 占位，真机验证时如果地图加载失败/控制台报 key 无效，
  // 去 AMap 控制台建一个 JS API Key 换掉。
  void _initWebViewMap() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: _onWebViewMessage,
      )
      ..loadHtmlString(_buildMapHtml(widget.latLng!));
  }

  void _onWebViewMessage(JavaScriptMessage message) {
    if (!mounted) return;
    try {
      final payload = jsonDecode(message.message) as Map<String, dynamic>;
      final type = payload['type'] as String?;
      final data = payload['data'] as Map<String, dynamic>?;
      if (type == 'moveend' && data != null) {
        final lat = (data['lat'] as num).toDouble();
        final lng = (data['lng'] as num).toDouble();
        setState(() {
          _currentCenterCoordinate = LatLng(lat, lng);
        });
        _onMyLocation.add(false);
        poiInfoList = [];
        _search(_currentCenterCoordinate);
      }
    } catch (e) {
      // JS 桥消息解析失败不影响地图本身可用性，忽略即可
    }
  }

  String _buildMapHtml(LatLng center) {
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
  var marker = new AMap.Marker({
    position: [${center.longitude}, ${center.latitude}],
    map: map
  });
  function bridgeSend(type, data) {
    if (window.FlutterBridge) {
      window.FlutterBridge.postMessage(JSON.stringify({type: type, data: data}));
    }
  }
  map.on('dragend', function () {
    var c = map.getCenter();
    marker.setPosition(c);
    bridgeSend('moveend', {lat: c.lat, lng: c.lng});
  });
  // 供 Flutter 端程序化移动地图中心（我的位置 / 点击 POI 列表项）
  window.setMapCenter = function (lat, lng) {
    var pos = [lng, lat];
    map.setCenter(pos);
    marker.setPosition(pos);
  };
</script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    final widthMax = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 背景层：地图 + FAB
          Column(
            children: [
              Flexible(
                child: Stack(
                  children: [
                    // 高德官方 JS 地图 API，WebView 渲染：真正可拖拽/缩放，
                    // 跟 POI 搜索同一套 GCJ-02 坐标系，iOS/Android/macOS
                    // 都有 webview_flutter 实现，不用再区分平台。
                    Positioned.fill(
                      child: WebViewWidget(controller: _webViewController),
                    ),
                    Positioned(
                      right: 16.0,
                      bottom: _fabHeight,
                      child: FloatingActionButton(
                        backgroundColor: AppColors.getSurfaceColor(
                          Theme.of(context).brightness,
                        ),
                        onPressed: _showMyLocation,
                        child: StreamBuilder<bool>(
                          stream: _onMyLocation.stream,
                          initialData: true,
                          builder: (context, snapshot) {
                            return Icon(
                              Icons.gps_fixed,
                              size: 26,
                              color: snapshot.data!
                                  ? AppColors.primary
                                  : AppColors.iosGray,
                            );
                          },
                        ),
                      ),
                    ),
                    // 顶部悬浮头部：毛玻璃质感圆形按钮承载返回/发送，替代此前
                    // 直接浮在地图上的裸图标，兼具层次感与「浮在任意地图配色
                    // 之上都清晰可辨」的对比度；固定贴顶（SafeArea），不再随
                    // 底部滑动面板的拖拽偏移量联动
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.regular,
                            vertical: AppSpacing.small,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Semantics(
                                button: true,
                                label: MaterialLocalizations.of(
                                  context,
                                ).backButtonTooltip,
                                child: _frostedIconButton(
                                  onTap: () => Navigator.of(context).pop(),
                                  icon: Icon(
                                    Icons.arrow_back_ios_new,
                                    size: 18,
                                    color: AppColors.getIosBlue(
                                      Theme.of(context).brightness,
                                    ),
                                  ),
                                ),
                              ),
                              _sendButton(context),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 为面板最小高度留空
              SizedBox(height: screenHeight * _kMinChildSize),
            ],
          ),
          // 滑动面板（替代 SlidingUpPanel）
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: _kMinChildSize,
            minChildSize: _kMinChildSize,
            maxChildSize: _kMaxChildSize,
            snap: true,
            snapSizes: const [_kMinChildSize, _kMaxChildSize],
            builder: (context, scrollController) {
              final brightness = Theme.of(context).brightness;
              return ClipRRect(
                // 顶部圆角：这是贴底部的面板，只有上边缘该圆角，四角全圆是错误语义
                borderRadius: AppRadius.bottomSheet,
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.surface,
                  child: StreamBuilder<List<AMapPosition>>(
                    stream: poiStream.stream,
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final data = snapshot.data!;
                        return EasyRefresh(
                          footer: const MaterialFooter(),
                          onLoad: _handleLoadMore,
                          child: Column(
                            children: [
                              // 拖拽把手：提示面板可上下拖动，此前完全没有可视化提示
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Center(
                                  child: Container(
                                    width: 36,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: AppColors.getIosSeparator(
                                        brightness,
                                      ),
                                      borderRadius: AppRadius.borderRadiusTiny,
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                // 之前只有 top:10，下边完全没有间距，搜索栏和下面
                                // 的 POI 列表贴在一起；补 bottom 让它和列表分开
                                margin: const EdgeInsets.only(
                                  left: 10,
                                  right: 10,
                                  top: 10,
                                  bottom: AppSpacing.small,
                                ),
                                alignment: Alignment.center,
                                height: 39,
                                decoration: BoxDecoration(
                                  color: AppColors.getSurfaceGrouped(
                                    brightness,
                                  ),
                                  borderRadius: AppRadius.borderRadiusRegular,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: <Widget>[
                                    Flexible(
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        width: _animate
                                            ? widthMax * .8
                                            : widthMax,
                                        decoration: BoxDecoration(
                                          borderRadius: widget
                                              .searchBarStyle
                                              .borderRadius,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surface,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            left: 10,
                                          ),
                                          child: TextField(
                                            focusNode: focusNode,
                                            keyboardType: TextInputType.text,
                                            controller: _searchQueryController,
                                            onChanged: _onTextChanged,
                                            cursorColor: AppColors.primary,
                                            style: context.textStyle(
                                              FontSizeType.subheadline,
                                              color: AppColors.getTextColor(
                                                brightness,
                                              ),
                                            ),
                                            decoration: InputDecoration(
                                              icon: Icon(
                                                Icons.search,
                                                size: 20,
                                                color: AppColors.getTextColor(
                                                  brightness,
                                                  isSecondary: true,
                                                ),
                                              ),
                                              border: InputBorder.none,
                                              hintText: t.common.searchLocation,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _cancel,
                                      child: AnimatedOpacity(
                                        opacity: _animate ? 1.0 : 0,
                                        curve: Curves.easeIn,
                                        duration: Duration(
                                          milliseconds: _animate ? 1000 : 0,
                                        ),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          width: _animate
                                              ? MediaQuery.of(
                                                      context,
                                                    ).size.width *
                                                    .2
                                              : 0,
                                          child: ColoredBox(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.surface,
                                            child: Center(
                                              child: Text(
                                                t.common.buttonCancel,
                                                style: TextStyle(
                                                  color: AppColors.getIosBlue(
                                                    brightness,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  controller: scrollController,
                                  shrinkWrap: true,
                                  itemCount: data.length,
                                  itemBuilder: (context, index) {
                                    String distance = data[index].distance;
                                    if (distance.isNotEmpty) {
                                      distance = "${distance}m | ";
                                    }
                                    final isSelected = _seLindex == index;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _seLindex = index;
                                          _sendMsg = data[index];
                                          _currentCenterCoordinate =
                                              data[index].latLng;
                                        });
                                        _onMyLocation.add(false);
                                        _panMapTo(data[index].latLng);
                                      },
                                      child: Container(
                                        // 选中态背景高亮：此前只有末尾一个对号，
                                        // 整行没有任何「已选中」的视觉反馈
                                        color: isSelected
                                            ? AppColors.primary.withValues(
                                                alpha: 0.08,
                                              )
                                            : Colors.transparent,
                                        child: ListTile(
                                          title: Text(data[index].name),
                                          subtitle: Text(
                                            "$distance${data[index].address}",
                                          ),
                                          trailing: isSelected
                                              ? Icon(
                                                  Icons.check,
                                                  color: AppColors.primary,
                                                )
                                              : const SizedBox.shrink(),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return Center(
                        child: CircularProgressIndicator(
                          // 之前用 onPrimary（配合主色背景才有效）画在普通 surface
                          // 背景上，浅色主题下近乎不可见
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 44×44 命中区域的圆形毛玻璃按钮：满足最小触达区，且用中性 surface 底色
  /// + 阴影而非直接透明，保证浮在任意地图配色上都有稳定对比度
  Widget _frostedIconButton({
    required VoidCallback onTap,
    required Widget icon,
  }) {
    final surface = AppColors.getSurfaceColor(Theme.of(context).brightness);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: surface.withValues(alpha: 0.9),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }

  /// 发送按钮：未选中 POI 时用置灰样式表达「暂不可用」而非看起来和平时一样，
  /// 但仍可点击——点击时走 _handleSend 的空值兜底提示，而不是变成真正禁用
  /// 拿不到任何反馈
  Widget _sendButton(BuildContext context) {
    final enabled = _sendMsg != null;
    return Material(
      color: enabled ? AppColors.primary : AppColors.iosGray3,
      elevation: enabled ? 2 : 0,
      shadowColor: Theme.of(context).shadowColor.withValues(alpha: 0.2),
      borderRadius: AppRadius.borderRadiusRegular,
      child: InkWell(
        borderRadius: AppRadius.borderRadiusRegular,
        onTap: _handleSend,
        child: Container(
          constraints: const BoxConstraints(minWidth: 64, minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
          alignment: Alignment.center,
          child: Text(
            t.common.buttonSend,
            style: TextStyle(
              color: enabled ? AppColors.onPrimary : AppColors.iosGray,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSend() async {
    // POI 搜索尚未返回结果时点发送：给出反馈而不是静默无反应
    if (_sendMsg == null) {
      AppLoading.showToast(t.common.selectLocationFailed);
      return;
    }
    final map = <String, dynamic>{
      "id": _sendMsg!.id,
      "image": null,
      "address": _sendMsg!.address,
      "title": _sendMsg!.name,
      "latitude": _sendMsg!.latLng.latitude,
      "longitude": _sendMsg!.latLng.longitude,
      "adCode": _sendMsg!.adCode,
    };
    if (!widget.isMapImage) {
      // 不需要地图截图：直接返回结果
      Navigator.pop(context, map);
      return;
    }
    await takeSnapshotReturn(map);
  }

  /// 内嵌地图预览图：直接拉官方静态地图图片二进制，marker 已经烤在图里，
  /// 不再需要（也不再可能）等交互式地图渲染完 marker 再截屏
  Future<void> takeSnapshotReturn(Map<String, dynamic> map) async {
    if (!mounted) return;
    final bytes = await AMapApi.fetchStaticMapBytes(
      latitude: _sendMsg!.latLng.latitude,
      longitude: _sendMsg!.latLng.longitude,
    );
    // bytes 可能为 null（网络失败）：调用方已按 result["image"] == null
    // 走「获取地图失败，请重试」提示分支，不再让用户卡在选点页无任何反馈。
    map["image"] = bytes;
    if (mounted) {
      Navigator.pop(context, map);
    }
  }

  Future<void> _showMyLocation() async {
    _recenterTo(widget.latLng!); // 我的位置
    _panMapTo(widget.latLng!);
    _onMyLocation.add(true);
    if (!_isKeyword) {
      //如果不在文字搜索中
      _search(widget.latLng!);
    }
  }

  /// 更新地图中心坐标状态（供 FAB 高亮/预览等 UI 使用）
  void _recenterTo(LatLng target) {
    setState(() {
      _currentCenterCoordinate = target;
    });
  }

  /// 程序化移动 JS 地图中心（我的位置 / 点击 POI 列表项），
  /// 对应 HTML 里挂在 window 上的 setMapCenter
  void _panMapTo(LatLng target) {
    _webViewController.runJavaScript(
      'window.setMapCenter && window.setMapCenter(${target.latitude}, ${target.longitude});',
    );
  }

  void _cancel() {
    _animate = false;
    _isKeyword = false;
    _seLindex = 0;
    _searchQueryController.clear();
    focusNode.unfocus();
    _sheetController.animateTo(
      _kMinChildSize,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _onTextChanged(String newText) async {
    _searchKeyword(newText);
    _animate = true;
  }

  Future<void> _search(LatLng location, {bool more = false}) async {
    var response = await AMapApi.getAmapPoi(
      "${location.latitude},${location.longitude}",
      searchType,
      10,
      page,
    );
    // 安全日志：不输出完整响应数据
    // on amap_search {"count":"10","infocode":"10000","pois":[
    // {"parent":"",
    // "address":"宝田一路与臣田三路交叉口东南100米","distance":"22","pcode":"440000","adcode":"440306","pname":"广东省","cityname":"深圳市",
    // "type":"餐饮服务;快餐厅;快餐厅","typecode":"050300","adname":"宝安区","citycode":"0755","name":"影朵自选快餐",
    // "location":"113.876030,22.591599","id":"B0ID7UCWEP"},
    List<dynamic> poiList = [];
    String status = response.data["status"] as String? ?? '0';
    if (response.statusCode == 200 && status == "1") {
      poiList = response.data["pois"] as List<dynamic>;
    }
    for (var e in poiList) {
      // e['location'] "116.310905,39.992806",
      // longitude 经度坐标 -180,180
      // latitude '纬度坐标 -90,90
      poiInfoList.add(
        AMapPosition(
          id: e['id'] as String,
          name: e['name'] as String,
          latLng: LatLng(
            double.parse(e['location'].toString().split(",")[1]), // latitude
            double.parse(e['location'].toString().split(",")[0]), // longitude
          ),
          address: (e['address'] ?? '') as String,
          // pcode: e['pcode'],
          adCode: (e['adcode'] ?? '') as String,
          distance: (e['distance'] ?? '') as String,
        ),
      );
    }
    if (!more) {
      if (poiInfoList.isNotEmpty) {
        _sendMsg = poiInfoList[0];
      }
      page = 1;
    }
    poiStream.add(poiInfoList);
  }

  Future<void> _searchKeyword(String keyword, {bool more = false}) async {
    if (keyword.isEmpty) {
      _isKeyword = true;
      return;
    }
    if (!more) {
      poiInfoList = [];
      _seLindex = -1;
    }
    var response = await AMapApi.getMapByKeyword(
      keyword,
      searchType,
      widget.citycode,
      true,
      10,
      page,
    );
    List<dynamic> poiList = [];
    // 高德 v5/place/text 接口的 status 字段是字符串（"1"/"0"），跟
    // v5/place/around（_search 用的那个）一样；这里此前按 int 强转，
    // 每次关键字搜索必然抛 "type 'String' is not a subtype of type 'int?'"，
    // 搜索框输入什么都没有结果返回。
    String status = response.data["status"] as String? ?? '0';
    if (response.statusCode == 200 && status == "1") {
      poiList = response.data["pois"] as List<dynamic>;
    }
    for (var e in poiList) {
      // e['location'] "116.310905,39.992806",
      // longitude 经度坐标 -180,180
      // latitude '纬度坐标 -90,90
      poiInfoList.add(
        AMapPosition(
          id: e['id'] as String,
          name: e['name'] as String,
          latLng: LatLng(
            double.parse(e['location'].toString().split(",")[1]), // latitude
            double.parse(e['location'].toString().split(",")[0]), // longitude
          ),
          address: (e['address'] ?? '') as String,
          // pcode: e['pcode'],
          adCode: (e['adcode'] ?? '') as String,
          distance: (e['distance'] ?? '') as String,
        ),
      );
    }
    if (!more) {
      page = 1;
    }
    poiStream.add(poiInfoList);
  }

  Future<void> _handleLoadMore() async {
    if (_isKeyword) {
      page++;
      _searchKeyword(_searchQueryController.text, more: true);
    } else {
      page++;
      _search(_currentCenterCoordinate, more: true);
    }
  }
}

mixin _BLoCMixin on State<MapLocationPicker> {
  // poi流
  final poiStream = StreamController<List<AMapPosition>>();
  // 是否在我的位置
  // ponytail: broadcast 流——StreamBuilder 在 hot reload/重渲染时会重新订阅，
  // 单订阅流会抛 "Stream has already been listened to"。
  final _onMyLocation = StreamController<bool>.broadcast();
  @override
  void dispose() {
    poiStream.close();
    _onMyLocation.close();
    super.dispose();
  }
}
