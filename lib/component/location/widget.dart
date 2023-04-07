import 'dart:async';
import 'dart:typed_data';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:imboy/config/const.dart';

import 'amap_helper.dart';

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
    latLng = LatLng((arguments as Map)["lat"] as double,
        (arguments as Map)["lng"] as double);
    citycode = (arguments as Map)["citycode"];
    // citycode = "350100";
    // latLng = LatLng(26.017794, 119.41755599999999);
    isMapImage = (arguments as Map)["isMapImage"];
  }
}

class _MapLocationPickerState extends State<MapLocationPicker>
    with SingleTickerProviderStateMixin, _BLoCMixin, _AnimationMixin {
  double _currentZoom = 15.0;

  AMapController? _controller;
  final PanelController _panelController = PanelController();
  FocusNode focusNode = FocusNode();

  final _iconSize = 50.0;
  double _fabHeightSend = 40.0;
  double _fabHeight = 16.0;
  bool _iskeyword = false;
  bool _animate = false;
  int page = 1;
  int _selindex = 0;
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

  @override
  // ignore: overridden_fields
  final poiStream = StreamController<List<AMapPosition>>();
  List<AMapPosition> poiInfoList = [];

  String searchtype =
      "010000|020000|030000|040000|050000|060000|070000|080000|090000|100000|110000|120201|120300|140000|150400|190600|190301";
  final Map<String, Marker> _markers = <String, Marker>{};
  AMapPosition? _sendMsg;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    // debugPrint("widget.latLng ${widget.latLng}");
    _currentCenterCoordinate = widget.latLng!;
    _kInitialPosition = CameraPosition(
      target: widget.latLng!,
      zoom: _currentZoom,
      tilt: 30,
      bearing: 0,
    );
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        _panelController.open();
        _animate = true;
      } else {
        _panelController.close();
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
        iosKey: AMAP_IOS_KEY,
        androidKey: AMAP_ANDROID_KEY,
      ),
      initialCameraPosition: _kInitialPosition,
      mapType: MapType.normal,
      buildingsEnabled: true,
      // 是否显示3D建筑物
      compassEnabled: false,
      // 是否指南针
      labelsEnabled: true,
      // 是否显示底图文字
      scaleEnabled: false,
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
    final minPanelHeight = MediaQuery.of(context).size.height * 0.4;
    final maxPanelHeight = MediaQuery.of(context).size.height * 0.7;
    final widthMax = MediaQuery.of(context).size.width;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SlidingUpPanel(
          controller: _panelController,
          parallaxEnabled: true,
          parallaxOffset: 0.5,
          minHeight: minPanelHeight,
          maxHeight: maxPanelHeight,
          borderRadius: BorderRadius.circular(8),
          onPanelSlide: (double pos) => setState(() {
                _fabHeightSend =
                    pos * (maxPanelHeight - minPanelHeight) * .5 + 30;
                _fabHeight = pos * (maxPanelHeight - minPanelHeight) * .5 + 16;
              }),
          body: Column(
            children: <Widget>[
              Flexible(
                child: Stack(
                  children: <Widget>[
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
                        child: const Icon(
                          Icons.location_on,
                          size: 40,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 16.0,
                      bottom: _fabHeight,
                      child: FloatingActionButton(
                        onPressed: _showMyLocation,
                        backgroundColor: Colors.white,
                        child: StreamBuilder<bool>(
                          stream: _onMyLocation.stream,
                          initialData: true,
                          builder: (context, snapshot) {
                            return Icon(
                              Icons.gps_fixed,
                              size: 32,
                              color: snapshot.data!
                                  ? Theme.of(context).primaryColor
                                  : Colors.black54,
                            );
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      right: 16.0,
                      top: _fabHeightSend,
                      child: SizedBox(
                        width: 60,
                        child: TextButton(
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.all<Color>(
                              AppColors.primaryElement,
                            ),
                          ),
                          child: Text(
                            '发送'.tr,
                            style: const TextStyle(
                              color: AppColors.primaryElementText,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () async {
                            Map<String, dynamic>? map;
                            if (_sendMsg != null) {
                              map = {
                                "id": _sendMsg!.id,
                                "image": null,
                                "address": _sendMsg!.address,
                                "title": _sendMsg!.name,
                                "latitude": _sendMsg!.latLng.latitude,
                                "longitude": _sendMsg!.latLng.longitude,
                                // "provinceCode": _sendMsg!.pcode,
                                "adCode": _sendMsg!.adCode
                              };
                            }
                            debugPrint("sendLocation ${map.toString()}");
                            if (widget.isMapImage && _sendMsg != null) {
                              final Marker marker = Marker(
                                anchor: const Offset(0.5, 1),
                                position: LatLng(
                                  _sendMsg!.latLng.latitude,
                                  _sendMsg!.latLng.longitude,
                                ),
                                // icon: BitmapDescriptor.fromIconPath(
                                //     'assets/images/location_on.png'),
                                //使用默认hue的方式设置Marker的图标
                              );
                              setState(() {
                                //将新的marker添加到map里
                                _markers[marker.id] = marker;
                              });
                              Future.delayed(const Duration(milliseconds: 500),
                                  () {
                                takeSnapshotReturn(map!);
                              });
                            }
                          },
                        ),
                      ),
                    )
                  ],
                ),
              ),
              // 用来抵消panel的最小高度
              SizedBox(height: minPanelHeight),
            ],
          ),
          panelBuilder: (scrollController) {
            return StreamBuilder<List<AMapPosition>>(
              stream: poiStream.stream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final data = snapshot.data;
                  return EasyRefresh(
                    footer: const MaterialFooter(),
                    onLoad: _handleLoadMore,
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(
                            left: 10,
                            right: 10,
                            top: 10,
                          ),
                          alignment: Alignment.center,
                          height: 39,
                          decoration: BoxDecoration(
                            color: Colors.black12.withAlpha(10),
                            borderRadius: const BorderRadius.all(
                              Radius.circular(15.0),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: <Widget>[
                              Flexible(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: _animate ? widthMax * .8 : widthMax,
                                  decoration: BoxDecoration(
                                      borderRadius:
                                          widget.searchBarStyle.borderRadius,
                                      //color: widget.searchBarStyle.backgroundColor,
                                      color: Colors.grey.shade200),
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 10),
                                    child: Theme(
                                      data: Theme.of(context).copyWith(
                                        primaryColor: Colors.black,
                                      ),
                                      child: TextField(
                                        focusNode: focusNode,
                                        keyboardType: TextInputType.text,
                                        controller: _searchQueryController,
                                        onChanged: _onTextChanged,
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 15,
                                        ),
                                        decoration: InputDecoration(
                                          icon: const Icon(
                                            Icons.search,
                                            size: 20,
                                          ),
                                          border: InputBorder.none,
                                          hintText: "搜索地点".tr,
                                        ),
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
                                    duration: const Duration(milliseconds: 200),
                                    width: _animate
                                        ? MediaQuery.of(context).size.width * .2
                                        : 0,
                                    child: Container(
                                      color: Colors.white,
                                      child: Center(
                                        child: Text(
                                          "取消".tr,
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
                            itemCount: data!.length,
                            itemBuilder: (context, index) {
                              String distance = data[index].distance;
                              if (distance.isNotEmpty) {
                                distance = "${distance}m | ";
                              }
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selindex = index;
                                    _sendMsg = data[index];
                                    _changeCameraPosition(data[index].latLng);
                                  });
                                },
                                child: ListTile(
                                  title: Text(data[index].name),
                                  subtitle:
                                      Text("$distance${data[index].address}"),
                                  trailing: _selindex == index
                                      ? const Icon(
                                          Icons.check,
                                          color: AppColors.ButtonTextColor,
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              );
                            },
                          ),
                        )
                      ],
                    ),
                  );
                } else {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(
                        AppColors.ButtonTextColor,
                      ),
                    ),
                  );
                }
              },
            );
          }),
    );
  }

  Future<void> takeSnapshotReturn(Map<String, dynamic> map) async {
    debugPrint("> takeSnapshotReturn ${map.toString()}");
    try {
      Uint8List? imageBytes = await _controller?.takeSnapshot();
      map["image"] = imageBytes;
      // ignore: use_build_context_synchronously
      Navigator.pop(context, map);
    } catch (e) {
      //
    }
  }

  void _onCameraMove(CameraPosition cameraPosition) {
    //这里需要保证放大缩小的时候中心点位置不变
    debugPrint('onCameraMove===> ${cameraPosition.toMap()}');
  }

  void _onCameraMoveEnd(CameraPosition cameraPosition) {
    if (_currentZoom != cameraPosition.zoom) {
      _currentZoom = cameraPosition.zoom;
    }
    if (_moveByUser) {
      //如果是用户移动
      poiInfoList = [];
      _search(cameraPosition.target);
    }
    _moveByUser = true;
    debugPrint('_onCameraMoveEnd===> ${cameraPosition.toMap()}');
  }

  void _onMapPoiTouched(AMapPoi poi) {
    debugPrint('_onMapPoiTouched===> ${poi.toJson()}');
  }

  void _onLocationChanged(AMapLocation location) {
    debugPrint('_onLocationChanged ${location.toJson()}');
  }

  void _onMapTap(LatLng latLng) {
    debugPrint('_onMapTap===> ${latLng.toJson()}');
  }

  void _onMapLongPress(LatLng latLng) {
    debugPrint('_onMapLongPress===> ${latLng.toJson()}');
  }

  Future<void> _showMyLocation() async {
    _changeCameraPosition(widget.latLng!); //我的位置
    if (!_iskeyword) {
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
    _iskeyword = false;
    _selindex = 0;
    focusNode.unfocus();
    _panelController.close();
  }

  _onTextChanged(String newText) async {
    _searchkeyword(newText);
    _animate = true;
  }

  Future<void> _search(LatLng location, {bool more = false}) async {
    var response = await AMapApi.getAmapPoi(
      "${location.latitude},${location.longitude}",
      searchtype,
      10,
      page,
    );
    debugPrint("> on amap_search ${response.toString()}");
    // on amap_search {"count":"10","infocode":"10000","pois":[
    // {"parent":"",
    // "address":"宝田一路与臣田三路交叉口东南100米","distance":"22","pcode":"440000","adcode":"440306","pname":"广东省","cityname":"深圳市",
    // "type":"餐饮服务;快餐厅;快餐厅","typecode":"050300","adname":"宝安区","citycode":"0755","name":"影朵自选快餐",
    // "location":"113.876030,22.591599","id":"B0ID7UCWEP"},

    List poiList = [];
    String status = response.data["status"] ?? 0;
    if (response.statusCode == 200 && status == "1") {
      poiList = response.data["pois"];
    }
    for (var e in poiList) {
      // e['location'] "116.310905,39.992806",
      // longitude 经度坐标 -180,180
      // latitude '纬度坐标 -90,90
      poiInfoList.add(AMapPosition(
        id: e["id"],
        name: e["name"],
        latLng: LatLng(
          double.parse(e['location'].toString().split(",")[1]), // latitude
          double.parse(e['location'].toString().split(",")[0]), // longitude
        ),
        address: e["address"],
        // pcode: e["pcode"],
        adCode: e["adcode"],
        distance: e["distance"],
      ));
    }
    if (!more) {
      if (poiInfoList.isNotEmpty) {
        _sendMsg = poiInfoList[0];
      }
      page = 1;
    }
    poiStream.add(poiInfoList);
  }

  Future<void> _searchkeyword(String keyword, {bool more = false}) async {
    if (keyword.isEmpty) {
      _iskeyword = true;
      return;
    }

    if (!more) {
      poiInfoList = [];
      _selindex = -1;
    }

    var response = await AMapApi.getMapByKeyword(
      keyword,
      searchtype,
      widget.citycode,
      true,
      10,
      page,
    );

    List poiList = [];
    int status = response.data["status"] ?? 0;
    if (response.statusCode == 200 && status == 1) {
      poiList = response.data["pois"];
    }
    for (var e in poiList) {
      // e['location'] "116.310905,39.992806",
      // longitude 经度坐标 -180,180
      // latitude '纬度坐标 -90,90
      poiInfoList.add(AMapPosition(
        id: e["id"],
        name: e["name"],
        latLng: LatLng(
          double.parse(e['location'].toString().split(",")[1]), // latitude
          double.parse(e['location'].toString().split(",")[0]), // longitude
        ),
        address: e["address"],
        // pcode: e["pcode"],
        adCode: e["adCode"],
        distance: e["distance"],
      ));
    }
    if (!more) {
      page = 1;
    }
    poiStream.add(poiInfoList);
  }

  Future<void> _handleLoadMore() async {
    if (_iskeyword) {
      page++;
      _searchkeyword(_searchQueryController.text, more: true);
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
  final _onMyLocation = StreamController<bool>();

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
    _tween = Tween(
      begin: const Offset(0, 0),
      end: const Offset(0, -15),
    ).animate(
      CurvedAnimation(
        parent: _jumpController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _jumpController.dispose();
    super.dispose();
  }
}
