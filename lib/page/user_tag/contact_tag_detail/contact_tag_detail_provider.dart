import 'package:azlistview/azlistview.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/api/user_tag_api.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_tag_repo_sqlite.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'contact_tag_detail_provider.g.dart';

/// ContactTagDetail 模块的状态
class ContactTagDetailState {
  final String tagName;
  final int refererTime;
  final List<ContactModel> contactList;
  final Set<String> currIndexBarData;
  final int page;
  final int size;
  final String kwd;
  final bool isLoading;

  const ContactTagDetailState({
    this.tagName = '',
    this.refererTime = 0,
    this.contactList = const [],
    this.currIndexBarData = const {},
    this.page = 1,
    this.size = 10,
    this.kwd = '',
    this.isLoading = false,
  });

  ContactTagDetailState copyWith({
    String? tagName,
    int? refererTime,
    List<ContactModel>? contactList,
    Set<String>? currIndexBarData,
    int? page,
    int? size,
    String? kwd,
    bool? isLoading,
  }) {
    return ContactTagDetailState(
      tagName: tagName ?? this.tagName,
      refererTime: refererTime ?? this.refererTime,
      contactList: contactList ?? this.contactList,
      currIndexBarData: currIndexBarData ?? this.currIndexBarData,
      page: page ?? this.page,
      size: size ?? this.size,
      kwd: kwd ?? this.kwd,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

@riverpod
class ContactTagDetailNotifier extends _$ContactTagDetailNotifier {
  @override
  ContactTagDetailState build() {
    return const ContactTagDetailState();
  }

  /// 处理联系人列表（排序和索引）
  void handleList(List<ContactModel> list) {
    final indexData = <String>{};

    for (int i = 0; i < list.length; i++) {
      String pinyin = PinyinHelper.getPinyinE(list[i].title);
      String tag = pinyin.substring(0, 1).toUpperCase();
      list[i].namePinyin = pinyin;
      if (RegExp("[A-Z]").hasMatch(tag)) {
        list[i].nameIndex = tag;
        indexData.add(tag);
      } else {
        list[i].nameIndex = '#';
      }
    }
    indexData.add('#');

    // A-Z sort.
    SuspensionUtil.sortListBySuspensionTag(list);

    // show sus tag.
    SuspensionUtil.setShowSuspensionStatus(list);

    state = state.copyWith(contactList: list, currIndexBarData: indexData);
  }

  /// 分页获取标签关联的联系人
  Future<List<ContactModel>> pageRelation(
    bool onRefresh, {
    required int tagId,
    int page = 1,
    int size = 10,
    String? kwd,
  }) async {
    List<ContactModel> contact = [];
    Map<String, dynamic>? resp = await (UserTagApi()).pageRelation(
      tagId: tagId,
      page: 1,
      size: 1000,
      scene: 'friend',
      kwd: kwd,
    );
    List<dynamic> items = resp?['list'] ?? [];
    for (var json in items) {
      ContactModel model = ContactModel.fromMap(json);
      iPrint("pageRelation item ${model.toJson().toString()} ");
      if (model.isFriend == 1) {
        contact.insert(0, model);
      }
    }
    return contact;
  }

  /// 搜索联系人
  Future<List<dynamic>> doSearch({
    required bool onRefresh,
    required String query,
    required int tagId,
  }) async {
    iPrint("user_collect_s_doSearch $query");

    state = state.copyWith(page: 1);
    var list = await pageRelation(
      onRefresh,
      tagId: tagId,
      page: state.page,
      size: state.size,
      kwd: query.toString(),
    );
    if (list.isNotEmpty) {
      state = state.copyWith(page: state.page + 1);
    }
    handleList(list);
    return list;
  }

  /// 更新 refererTime（联系人数量）
  void updateRefererTime(int value) {
    state = state.copyWith(refererTime: value);
  }

  /// 减少 refererTime（移除一个联系人后调用）
  void decrementRefererTime() {
    final newVal = state.refererTime > 0 ? state.refererTime - 1 : 0;
    state = state.copyWith(refererTime: newVal);
  }

  /// 移除标签关联
  Future<bool> removeRelation({
    required int tagId,
    required String objectId,
    required String tagName,
    required String scene,
  }) async {
    bool res = await (UserTagApi()).removeRelation(
      tagId: tagId,
      scene: scene,
      objectId: objectId,
    );
    if (res) {
      ContactRepo().removeTag(peerId: objectId, tagName: tagName);
    }
    return res;
  }

  /// 设置标签关联
  Future<bool> setObject({
    required String scene,
    required int tagId,
    required String tagName,
    required List<ContactModel> selectedContact,
    required List<ContactModel> tagContactList,
  }) async {
    List<String> objectIds = [];
    for (var e in selectedContact) {
      objectIds.add(e.peerId);
    }
    bool res = await (UserTagApi()).setRelation(
      tagId: tagId,
      tagName: tagName,
      scene: scene,
      objectIds: objectIds,
    );
    if (res) {
      await UserTagRepo().update({
        UserTagRepo.tagId: tagId,
        UserTagRepo.refererTime: selectedContact.length,
      });
      List<String> oldObjectIds = [];
      // 处理移除情况
      for (var e in tagContactList) {
        oldObjectIds.add(e.peerId);
        if (!objectIds.contains(e.peerId)) {
          ContactRepo().removeTag(peerId: e.peerId, tagName: tagName);
          e.tag = e.tag.replaceAll("$tagName,", '');
        }
      }

      // 新增的情况
      for (var e in selectedContact) {
        if (!oldObjectIds.contains(e.peerId)) {
          ContactRepo().addTag(peerId: e.peerId, tagName: tagName);
          e.tag = "$tagName,${e.tag}";
        }
      }

      // 更新当前联系人列表
      handleList(selectedContact);
      state = state.copyWith(
        refererTime: selectedContact.length,
        contactList: selectedContact,
      );
    }
    return res;
  }

  /// 加载标签数据
  Future<void> loadTagData({
    required String tagName,
    required int refererTime,
    required int tagId,
  }) async {
    state = state.copyWith(tagName: tagName, refererTime: refererTime);

    if (refererTime > 0) {
      var list = await pageRelation(
        false,
        tagId: tagId,
        page: state.page,
        size: state.size,
        kwd: state.kwd,
      );
      handleList(list);
    }
  }
}
