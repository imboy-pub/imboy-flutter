import 'package:get/get.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/repository/user_repository.dart';

class Controller extends GetNotifier {
  Controller() : super('');

  late GetSocket socket;
  String text = '';

  @override
  void onInit() {
    String? tk = UserRepository.accessToken();

    String url =
        ws_url + '?' + Keys.tokenKey + '=' + tk!.replaceAll('+', '%2B');

    socket = GetSocket(url);
    print('onInit called');

    socket.onOpen(() {
      print('onOpen');
      change(value, status: RxStatus.success());
    });

    socket.onMessage((data) {
      print('message received: $data');
      change(data);
    });

    socket.onClose((close) {
      print('close called');
      change(value, status: RxStatus.error(close.message));
    });

    socket.onError((e) {
      print('error called');
      change(value, status: RxStatus.error(e.message));
    });

    socket.on('event', (val) {
      print(val);
    });

    socket.emit('event', 'you data');

    socket.connect();
  }

  void sendMessage() {
    if (text.isNotEmpty) {
      socket.emit('message', text);
    }
  }
}
