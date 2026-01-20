import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/store/api/contact_api.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';

part 'contact_setting_tag_provider.g.dart';

/// 联系人标签设置状态类
class ContactSettingTagState {
  final bool valueChanged;
  final String val;

  const ContactSettingTagState({this.valueChanged = false, this.val = ''});

  ContactSettingTagState copyWith({bool? valueChanged, String? val}) {
    return ContactSettingTagState(
      valueChanged: valueChanged ?? this.valueChanged,
      val: val ?? this.val,
    );
  }
}

/// 联系人标签设置 Notifier
@riverpod
class ContactSettingTagNotifier extends _$ContactSettingTagNotifier {
  final FocusNode remarkFocusNode = FocusNode();
  final TextEditingController remarkTextController = TextEditingController();

  @override
  ContactSettingTagState build() {
    return const ContactSettingTagState();
  }

  /// 值变化处理
  void valueOnChange(bool isChange) {
    state = state.copyWith(valueChanged: isChange);
  }

  /// 设置值
  void setVal(String value) {
    state = state.copyWith(val: value);
  }

  /// 修改备注
  Future<bool> changeRemark(String uid, String remark) async {
    debugPrint("contact_setting_changeRemark $remark");
    bool res = await ContactApi().changeRemark(uid, remark);
    if (res) {
      await ContactRepo().update({
        ContactRepo.peerId: uid,
        ContactRepo.remark: remark,
      });
    }
    return res;
  }
}
