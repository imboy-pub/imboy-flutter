import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/store/model/user_tag_model.dart';
import 'package:imboy/store/api/user_tag_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/repository/user_tag_repo_sqlite.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_tag_save_provider.g.dart';

/// UserTagSave 模块的状态
class UserTagSaveState {
  final String text;
  final bool valueChanged;
  final bool isLoading;

  const UserTagSaveState({
    this.text = '',
    this.valueChanged = false,
    this.isLoading = false,
  });

  UserTagSaveState copyWith({
    String? text,
    bool? valueChanged,
    bool? isLoading,
  }) {
    return UserTagSaveState(
      text: text ?? this.text,
      valueChanged: valueChanged ?? this.valueChanged,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

@riverpod
class UserTagSaveNotifier extends _$UserTagSaveNotifier {
  @override
  UserTagSaveState build() {
    return const UserTagSaveState();
  }

  /// 修改标签名称
  Future<bool> changeName({
    required String scene,
    required int tagId,
    required String tagName,
  }) async {
    // 检查网络状态
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return false;
    }
    bool res2 = await UserTagApi().changeName(
      scene: scene,
      tagId: tagId,
      tagName: tagName,
    );
    if (res2 == false) {
      return false;
    }
    await UserTagRepo().update({
      UserTagRepo.tagId: tagId,
      UserTagRepo.name: tagName,
    });

    return true;
  }

  /// 添加标签
  Future<UserTagModel?> addTag({
    required String scene,
    required String tagName,
  }) async {
    // 检查网络状态
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return null;
    }
    int tagId = await UserTagApi().addTag(scene: scene, tagName: tagName);
    if (tagId > 0) {
      UserTagModel tag = UserTagModel(
        userId: parseModelInt(UserRepoLocal.to.currentUid),
        tagId: tagId,
        scene: 2,
        name: tagName,
        subtitle: '',
        refererTime: 0,
        updatedAt: 0,
        createdAt: DateTimeHelper.millisecond(),
      );
      await UserTagRepo().insert(tag);
      return tag;
    }
    return null;
  }

  /// 设置文本
  void setText(String text) {
    state = state.copyWith(text: text);
  }

  /// 检查值是否改变
  bool checkValueChanged(String originalName) {
    bool changed = state.text != originalName && state.text.isNotEmpty;
    state = state.copyWith(valueChanged: changed);
    return changed;
  }
}
