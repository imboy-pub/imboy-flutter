import 'package:get/get.dart';

import 'search_logic.dart';

class SearchBinding extends Binding {
  @override
  List<Bind> dependencies() => [
        Bind.lazyPut(() => SearchLogic()),
      ];
}
