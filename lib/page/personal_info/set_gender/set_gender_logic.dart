import 'package:get/get.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'set_gender_state.dart';

/// 设置性别页面逻辑控制器
///
/// 功能说明：
/// - 维护 selectedGender / originalGender / pendingGender / isSaving 状态
/// - 防重复提交与节流（通过 isSaving 与 pendingGender 控制）
/// - 调用后端占位接口并根据返回码进行错误分类提示
/// - 成功时同步本地用户缓存并回滚 UI 到最新状态；失败时回滚并提示
class SetGenderLogic extends GetxController {
  final SetGenderState state = SetGenderState();

  // 当前选中的性别（'0'|'1'|'2'|'3'）
  final RxString selectedGender = ''.obs;

  // 正在提交的目标性别（用于在视图上显示 loading）
  final RxString pendingGender = ''.obs;

  // 保存中标记，防止重复提交
  final RxBool isSaving = false.obs;

  // 原始性别（用于回滚）
  String originalGender = '';

  @override
  void onInit() {
    super.onInit();
    _loadCurrentGender();
  }

  /// 加载当前性别
  /// 用途：从本地用户信息读取当前性别并初始化状态
  /// 返回：void
  void _loadCurrentGender() {
    try {
      final userInfo = UserRepoLocal.to.current;
      originalGender = userInfo.gender.toString();
      selectedGender.value = originalGender;
    } catch (e) {
      iPrint('加载性别失败: $e');
    }
  }

  /// 选择性别（入口）
  /// 用途：处理用户点击性别选项的流程（节流 -> 调用 API -> 同步本地 -> 回滚/提示）
  /// 参数：gender String 性别 id（'1' 男 / '2' 女 / '3' 保密 / '0' 未知）
  /// 返回：void
  void selectGender(String gender) async {
    // 若正在提交或选择相同值，忽略
    if (isSaving.value) return;
    if (selectedGender.value == gender) return;

    // 标记为正在提交并记录 pending
    isSaving.value = true;
    pendingGender.value = gender;

    try {
      final apiResult = await _updateGenderAPI(gender);

      if (apiResult) {
        // 更新本地用户信息
        await _updateLocalUserInfo(int.tryParse(gender) ?? 0);

        // 更新状态
        selectedGender.value = gender;
        originalGender = gender;

        Get.snackbar('tipSuccess'.tr, 'genderUpdateSuccess'.tr);
        Get.back(result: true);
      } else {
        // 根据错误码做差异化提示并回滚
        await _handleSaveError('', '');
      }
    } catch (e) {
      iPrint('设置性别失败: $e');
      // 网络异常回滚并提示
      await _revertToOriginal();
      Get.snackbar('tipFailed'.tr, 'genderNetworkError'.tr);
    } finally {
      // 清理 pending 与保存状态
      pendingGender.value = '';
      isSaving.value = false;
    }
  }

  /// 更新本地用户信息
  /// 用途：保存成功后同步本地缓存中的 gender 字段
  /// 参数：genderInt int
  /// 返回：Future<void>
  Future<void> _updateLocalUserInfo(int genderInt) async {
    try {
      final payload = UserRepoLocal.to.current.toMap();
      payload['gender'] = genderInt;
      UserRepoLocal.to.changeInfo(payload);
      // TODO: 若需要，通知其他控制器刷新用户相关显示
    } catch (e) {
      iPrint('本地用户信息更新失败: $e');
    }
  }

  /// 处理保存错误并回滚
  /// 用途：根据不同错误码给出提示并恢复原始状态
  Future<void> _handleSaveError(String errorCode, String errorMessage) async {
    await _revertToOriginal();

    switch (errorCode) {
      case 'GENDER_CONFLICT':
        Get.snackbar('tipFailed'.tr, 'genderConflictError'.tr);
        break;
      case 'GENDER_INVALID':
        Get.snackbar('tipFailed'.tr, 'genderUpdateFailed'.tr);
        break;
      case 'GENDER_SENSITIVE':
        Get.snackbar('tipFailed'.tr, 'genderUpdateFailed'.tr);
        break;
      default:
        Get.snackbar('tipFailed'.tr, 'genderUpdateFailed'.tr);
        break;
    }
  }

  /// 回滚到原始性别
  Future<void> _revertToOriginal() async {
    selectedGender.value = originalGender;
    // 已经在本地缓存中，因此不需要额外操作
  }


  /// 调用 API 更新性别（占位）
  /// 用途：向后端发送更新请求，按约定解析返回的错误码
  /// 返回：Future<_ApiResult>
  Future<bool> _updateGenderAPI(String gender) async {
    return true;
  }
}