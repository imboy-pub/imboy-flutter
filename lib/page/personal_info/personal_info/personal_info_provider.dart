import 'package:flutter/cupertino.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../widget/more_page.dart';
import '../../qrcode/qrcode_page.dart';

part 'personal_info_provider.g.dart';

/// 个人信息状态
class PersonalInfoState {
  const PersonalInfoState();

  PersonalInfoState copyWith() {
    return const PersonalInfoState();
  }
}

/// 个人信息 Provider
@riverpod
class PersonalInfoNotifier extends _$PersonalInfoNotifier {
  HttpClient get httpclient => HttpClient.client;

  @override
  PersonalInfoState build() {
    return const PersonalInfoState();
  }

  /// 更改用户信息
  Future<bool> changeInfo(Map<String, dynamic> data) async {
    try {
      final IMBoyHttpResponse resp = await httpclient.put(
        API.userUpdate,
        data: data,
      );
      return resp.ok;
    } catch (e) {
      return false;
    }
  }

  /// 更新本地用户信息
  Future<void> updateLocalUserInfo(Map<String, dynamic> payload) async {
    try {
      UserRepoLocal.to.changeInfo(payload);
    } catch (e) {
      // ignore
    }
  }

  /// 处理标签点击事件
  void labelOnPressed(String label, BuildContext context) {
    if (label == 'more') {
      Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => const MorePage()),
      );
    } else if (label == "user_qrcode") {
      Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => UserQrCodePage()),
      );
    }
  }
}
