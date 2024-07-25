import 'package:get/get.dart';
import 'package:imboy/component/ui/numeric_keypad.dart';

class FaceToFaceState {

  final NumericKeypadController textEditingController =
  NumericKeypadController('');
  final RxString errorInfo = ''.obs;
  final RxString resultData = ''.obs;

  RxString longitude = "".obs; // 经度
  RxString latitude = "".obs; // 维度

  FaceToFaceState() {
    ///Initialize variables
  }
}
