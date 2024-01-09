import 'package:get/get.dart';

import 'uqrcode_logic.dart';

class UqrcodeBinding extends Binding {
  @override
  List<Bind> dependencies() => [
        Bind.lazyPut(() => UqrcodeLogic()),
      ];
}
