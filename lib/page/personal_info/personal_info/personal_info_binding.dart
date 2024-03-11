import 'package:get/get.dart';

import 'personal_info_logic.dart';

class PersonalInfoBinding extends Binding {
  @override
  List<Bind> dependencies() => [
        Bind.lazyPut(() => PersonalInfoLogic()),
      ];
}
