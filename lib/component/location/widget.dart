import 'dart:async';
import 'package:flutter/services.dart';
import 'package:amap_flutter_base_plus/amap_flutter_base_plus.dart';
import 'package:amap_flutter_map_plus/amap_flutter_map_plus.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
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

class _MapLocationPickerState extends State<MapLocationPicker>
    with SingleTickerProviderStateMixin, _BLoCMixin, _AnimationMixin {
  double _currentZoom = 15.0;
  AMapController? _controller;
  static const _kMinChildSize = 0.4;
  static const _kMaxChildSize = 0.7;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  FocusNode focusNode = FocusNode();
  final _iconSize = 50.0;
  double _fabHeight = 16.0;
  bool _isKeyword = false;
  bool _animate = false;
  int page = 1;
  int _seLindex = 0;
  bool _moveByUser = true;
  final _searchQueryController = TextEditingController();
  CustomStyleOptions customStyleOptions = CustomStyleOptions(false);
  //小蓝点
  MyLocationStyleOptions myLocationStyleOptions = MyLocationStyleOptions(false);
  // 当前地图中心点
  LatLng _currentCenterCoordinate = const LatLng(39.909187, 116.397451);
  CameraPosition _kInitialPosition = const CameraPosition(
    target: LatLng(39.909187, 116.397451),
    zoom: 15.0,
    tilt: 30,
    bearing: 0,
  );
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
  final Map<String, Marker> _markers = <String, Marker>{};
  AMapPosition? _sendMsg;
  @override
  void initState() {
    super.initState();
    // debugPrint("widget.latLng ${widget.latLng}");
    _currentCenterCoordinate = widget.latLng!;
    _kInitialPosition = CameraPosition(
      target: widget.latLng!,
      zoom: _currentZoom,
      tilt: 30,
      bearing: 0,
    );
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
  }

  @override
  Widget build(BuildContext context) {
    final AMapWidget amap = AMapWidget(
      privacyStatement: const AMapPrivacyStatement(
        hasContains: true,
        hasShow: true,
        hasAgree: true,
      ),
      apiKey: AMapApiKey(
        iosKey: Env().aMapIosKey,
        androidKey: Env().aMapAndroidKey,
      ),
      initialCameraPosition: _kInitialPosition,
      mapType: MapType.normal,
      buildingsEnabled: true,
      // 是否显示3D建筑物
      compassEnabled: false,
      // 是否指南针
      labelsEnabled: true,
      // 是否显示底图文字
      scaleEnabled: true,
      // 比例尺是否显示
      touchPoiEnabled: true,
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      tiltGesturesEnabled: true,
      zoomGesturesEnabled: true,
      onMapCreated: onMapCreated,
      customStyleOptions: customStyleOptions,
      myLocationStyleOptions: myLocationStyleOptions,
      onLocationChanged: _onLocationChanged,
      onCameraMove: _onCameraMove,
      onCameraMoveEnd: _onCameraMoveEnd,
      onTap: _onMapTap,
      onLongPress: _onMapLongPress,
      onPoiTouched: _onMapPoiTouched,
      markers: Set<Marker>.of(_markers.values),
    );
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
                    amap,
                    Center(
                      child: AnimatedBuilder(
                        animation: _tween,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(
                              _tween.value.dx,
                              _tween.value.dy - _iconSize / 2,
                            ),
                            child: child,
                          );
                        },
                        child: Icon(
                          Icons.location_on,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
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
                                          _changeCameraPosition(
                                            data[index].latLng,
                                          );
                                        });
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
      // 不需要地图截图：直接返回结果，无需等待 takeSnapshot
      Navigator.pop(context, map);
      return;
    }
    final marker = Marker(
      anchor: const Offset(0.5, 1),
      position: LatLng(_sendMsg!.latLng.latitude, _sendMsg!.latLng.longitude),
    );
    setState(() {
      _markers[marker.id] = marker;
    });
    Future<dynamic>.delayed(
      const Duration(milliseconds: 500),
      () => takeSnapshotReturn(map),
    );
  }

  Future<void> takeSnapshotReturn(Map<String, dynamic> map) async {
    if (!mounted) return;
    try {
      Uint8List? imageBytes = await _controller?.takeSnapshot();
      map["image"] = imageBytes;
    } catch (e) {
      // 截图失败：仍返回 map（image 缺省为 null），调用方已按
      // result["image"] == null 走「获取地图失败，请重试」提示分支，
      // 不再让用户卡在选点页无任何反馈。
    }
    if (mounted) {
      // ignore: use_build_context_synchronously
      Navigator.pop(context, map);
    }
  }

  void _onCameraMove(CameraPosition cameraPosition) {
    //这里需要保证放大缩小的时候中心点位置不变
  }

  void _onCameraMoveEnd(CameraPosition cameraPosition) {
    if (_currentZoom != cameraPosition.zoom) {
      _currentZoom = cameraPosition.zoom;
    }
    if (_moveByUser) {
      //如果是用户移动，地图中心已偏离「我的位置」，FAB 视觉状态同步置灰
      poiInfoList = [];
      _onMyLocation.add(false);
      _search(cameraPosition.target);
    }
    _moveByUser = true;
  }

  void _onMapPoiTouched(AMapPoi poi) {}

  void _onLocationChanged(AMapLocation location) {}

  void _onMapTap(LatLng latLng) {}

  void _onMapLongPress(LatLng latLng) {}

  Future<void> _showMyLocation() async {
    _changeCameraPosition(widget.latLng!); //我的位置
    _onMyLocation.add(true);
    if (!_isKeyword) {
      //如果不在文字搜索中
      _search(widget.latLng!);
    }
  }

  void onMapCreated(AMapController controller) {
    setState(() {
      _controller = controller;
      _search(widget.latLng!);
    });
  }

  void _changeCameraPosition(LatLng target) {
    _moveByUser = false;
    _controller?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: target,
          zoom: _currentZoom,
          tilt: 30,
          bearing: 0,
        ),
      ),
      animated: true,
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
    int status = response.data["status"] as int? ?? 0;
    if (response.statusCode == 200 && status == 1) {
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

mixin _AnimationMixin on SingleTickerProviderStateMixin<MapLocationPicker> {
  // 动画相关
  late AnimationController _jumpController;
  late Animation<Offset> _tween;
  @override
  void initState() {
    super.initState();
    _jumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _tween = Tween(begin: const Offset(0, 0), end: const Offset(0, -15))
        .animate(
          CurvedAnimation(parent: _jumpController, curve: Curves.easeInOut),
        );
  }

  @override
  void dispose() {
    _jumpController.dispose();
    super.dispose();
  }
}
