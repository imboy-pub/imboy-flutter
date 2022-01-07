import 'package:get/get_connect/http/src/response/response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/connect.dart';
import 'package:imboy/store/model/contact_model.dart';

class ContactProvider extends ConnectService {
  @override
  void onInit() {
    // 某个接口的json-to-model
    httpClient.defaultDecoder = (json) => ContactModel.fromJson(json);
    super.onInit();
  }

  // Future<Response<List<ContactModel>>> listFriend() async =>
  //     await get(API.friendList);
  Future<Response<dynamic>> listFriend() async => await get(
        API.friendList,
        contentType: "application/x-www-form-urlencoded",
      );
}
