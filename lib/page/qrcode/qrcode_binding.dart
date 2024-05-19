import 'package:get/get.dart';

import 'qrcode_logic.dart';

class QrCodeBinding extends Binding {
  @override
  List<Bind> dependencies() => [
        Bind.lazyPut(() => QrCodeLogic()),
      ];
}
