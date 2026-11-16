import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/store/api/contact_api.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/ui_events.dart';

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
  ContactSettingTagNotifier({ContactApi? contactApi, this.persistRemark})
    : _contactApi = contactApi ?? ContactApi();
  final ContactApi _contactApi;
  final Future<int> Function(
    String uid,
    String remark,
    String account,
    bool Function() current,
  )?
  persistRemark;

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
    final scope = authSessionReader.current;
    final owner = AccountLocalTaskOwner.capture(uid: scope.uid);
    bool current() =>
        ref.mounted &&
        authSessionReader.isCurrent(scope) &&
        AccountLocalTaskOwner.capture(uid: scope.uid) == owner;
    if (!current()) return false;
    final res = await _contactApi.changeRemark(uid, remark);
    if (!res || !current()) return false;
    final changed =
        await (persistRemark?.call(uid, remark, owner.uid, current) ??
            _persistRemark(uid, remark, owner.uid, current));
    if (changed <= 0 || !current()) return false;
    AppEventBus.fire(
      ContactUpdatedEvent(
        userId: uid,
        updateType: ContactUpdateType.remarkUpdated,
        updatedFields: const ['remark'],
      ),
    );
    return true;
  }

  Future<int> _persistRemark(
    String uid,
    String remark,
    String account,
    bool Function() current,
  ) async {
    final db = await SqliteService.to.db;
    if (!current() || db == null) return 0;
    return db.transaction((txn) async {
      if (!current()) return 0;
      final changed = await ContactRepo().update(
        {ContactRepo.peerId: uid, ContactRepo.remark: remark},
        txn: txn,
        account: account,
      );
      if (!current()) throw StateError('Remark owner changed');
      return changed;
    });
  }
}
