import 'package:get/get.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';

class ContactDetailLogic extends GetxController {
  Future<ContactModel?> findByID(String uid) async {
    ContactModel? obj = await ContactRepo().findByUid(uid);
    return obj;
  }
}
