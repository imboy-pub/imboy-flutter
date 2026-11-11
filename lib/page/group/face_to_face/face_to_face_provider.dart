import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/location/location_service.dart';
import 'package:imboy/component/ui/numeric_keypad.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:imboy/i18n/strings.g.dart';

part 'face_to_face_provider.g.dart';

final faceToFaceLocationProvider = Provider<Future<ImboyLocation?> Function()>(
  (ref) =>
      () => LocationService().getCurrentPosition(),
);

/// 面对面建群状态
class FaceToFaceState {
  final NumericKeypadController textEditingController;
  final String errorInfo;
  final String resultData;
  final String longitude; // 经度
  final String latitude; // 纬度

  const FaceToFaceState({
    required this.textEditingController,
    this.errorInfo = '',
    this.resultData = '',
    this.longitude = '',
    this.latitude = '',
  });

  FaceToFaceState copyWith({
    NumericKeypadController? textEditingController,
    String? errorInfo,
    String? resultData,
    String? longitude,
    String? latitude,
  }) {
    return FaceToFaceState(
      textEditingController:
          textEditingController ?? this.textEditingController,
      errorInfo: errorInfo ?? this.errorInfo,
      resultData: resultData ?? this.resultData,
      longitude: longitude ?? this.longitude,
      latitude: latitude ?? this.latitude,
    );
  }
}

/// 面对面建群 Notifier
@Riverpod(keepAlive: false)
class FaceToFaceNotifier extends _$FaceToFaceNotifier {
  @override
  FaceToFaceState build() {
    final controller = NumericKeypadController('');
    ref.onDispose(controller.dispose);
    return FaceToFaceState(textEditingController: controller);
  }

  /// 更新输入结果
  void updateResult(String value) {
    state = state.copyWith(resultData: value);
  }

  /// 更新错误信息
  void updateErrorInfo(String error) {
    state = state.copyWith(errorInfo: error);
  }

  /// 清空输入
  void clearInput() {
    state.textEditingController.clearText();
    state = state.copyWith(resultData: '', errorInfo: '');
  }

  /// 获取位置
  Future<bool> getLocation() async {
    try {
      final location = await ref
          .read(faceToFaceLocationProvider)()
          .timeout(const Duration(seconds: 30));
      if (!ref.mounted || location == null) return false;
      final lon = '${location.longitude}';
      final lat = '${location.latitude}';
      if (!_isValidCoordinate(lon, lat)) return false;
      state = state.copyWith(longitude: lon, latitude: lat);
      return true;
    } catch (e) {
      iPrint('[面对面建群] 定位失败: ${e.runtimeType}');
      return false;
    }
  }

  bool _isValidCoordinate(String lon, String lat) {
    if (lon.isEmpty || lat.isEmpty) return false;

    final longitude = double.tryParse(lon);
    final latitude = double.tryParse(lat);
    if (longitude == null || latitude == null) return false;
    if (!longitude.isFinite || !latitude.isFinite) return false;

    if (longitude == 0.0 && latitude == 0.0) return false;
    if (longitude < -180 || longitude > 180) return false;
    if (latitude < -90 || latitude > 90) return false;
    return true;
  }

  /// 面对面建群
  Future<Map<String, dynamic>> faceToFace(String code) async {
    final hasLocation = await getLocation();
    if (!ref.mounted) return {};
    if (!hasLocation) {
      state = state.copyWith(longitude: '', latitude: '');
      return {
        'gid': '',
        'memberList': <PeopleModel>[],
        'error': t.common.f2fLocationRequired,
      };
    }

    iPrint('[面对面建群] 开始请求, hasLocation=$hasLocation');

    // 调用 API
    Map<String, dynamic> payload = await GroupApi().groupFace2face(
      code: code,
      longitude: state.longitude,
      latitude: state.latitude,
    );

    iPrint(
      '[面对面建群] API 响应, gid=${payload['gid'] ?? ''}, memberCount=${(payload['member_list'] ?? <dynamic>[]).length}',
    );

    // 解析成员列表
    final memberList = IMBoyHttpResponse.payloadList(payload, 'member_list');
    List<PeopleModel> memberList2 = [];
    for (var itemMap in memberList) {
      memberList2.add(
        PeopleModel(
          id: (itemMap['user_id'] ?? 0) as Object,
          account: IMBoyHttpResponse.payloadStr(itemMap, 'account') ?? '',
          avatar: IMBoyHttpResponse.payloadStr(itemMap, 'avatar') ?? '',
          nickname: _memberName(itemMap),
        ),
      );
    }

    iPrint('[面对面建群] 解析后成员数量: ${memberList2.length}');

    return {
      'gid': '${payload['gid'] ?? ''}',
      'memberList': memberList2,
      'error': '${payload['gid'] ?? ''}'.isEmpty ? t.common.tipFailed : '',
    };
  }

  /// 保存面对面建群
  Future<Map<String, dynamic>> faceToFaceSave(String gid, String code) async {
    Map<String, dynamic> payload = await GroupApi().groupFace2faceSave(
      code: code,
      gid: gid,
    );
    iPrint(
      "faceToFaceSave memberCount=${(payload['member_list'] ?? <dynamic>[]).length}",
    );

    final memberList = IMBoyHttpResponse.payloadList(payload, 'member_list');
    List<PeopleModel> memberList2 = [];
    for (var itemMap in memberList) {
      memberList2.add(
        PeopleModel(
          id: (itemMap['user_id'] ?? 0) as Object,
          account: IMBoyHttpResponse.payloadStr(itemMap, 'account') ?? '',
          avatar: IMBoyHttpResponse.payloadStr(itemMap, 'avatar') ?? '',
          nickname: _memberName(itemMap),
        ),
      );
    }

    return {
      'group': payload['group'] ?? <String, dynamic>{},
      'memberList': memberList2,
    };
  }

  String _memberName(Map<String, dynamic> member) {
    final alias = IMBoyHttpResponse.payloadStr(member, 'alias') ?? '';
    final nickname = IMBoyHttpResponse.payloadStr(member, 'nickname') ?? '';
    return alias.trim().isNotEmpty
        ? alias
        : nickname.trim().isNotEmpty
        ? nickname
        : t.main.unnamed;
  }
}
