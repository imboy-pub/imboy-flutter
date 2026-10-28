/// W04.a（channel-group-ux-v2.2）：组织治理页建群后改名失败的待恢复意图。
///
/// 建群成功但改名失败时，gid 是既成事实，不能因页面销毁或应用重启丢失
/// “只重试改名、绝不重建群”的恢复入口。意图按「服务器来源+账号+工作区」
/// 隔离存储于本机 SharedPreferences；换账号/换来源不会读到别人的待改名。
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/config/env.dart';

String orgGroupRenamePendingKey(String account, String workspaceId) =>
    'org_group_rename_pending:'
    '${Env().apiBaseUrl.length}:'
    '${Env().apiBaseUrl}:$account:$workspaceId';

Future<void> saveOrgGroupRenamePending({
  required String account,
  required String workspaceId,
  required String gid,
  required String title,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    orgGroupRenamePendingKey(account, workspaceId),
    jsonEncode({'gid': gid, 'title': title}),
  );
}

/// 读取待恢复意图；键不存在、内容损坏或字段缺失时返回 null（安全缺省，
/// 不把损坏数据回显到界面）。
Future<({String gid, String title})?> loadOrgGroupRenamePending({
  required String account,
  required String workspaceId,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(orgGroupRenamePendingKey(account, workspaceId));
  if (raw == null) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    final gid = decoded['gid'];
    final title = decoded['title'];
    if (gid is! String || title is! String || gid.isEmpty || title.isEmpty) {
      return null;
    }
    return (gid: gid, title: title);
  } on Object {
    return null;
  }
}

Future<void> clearOrgGroupRenamePending({
  required String account,
  required String workspaceId,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(orgGroupRenamePendingKey(account, workspaceId));
}
