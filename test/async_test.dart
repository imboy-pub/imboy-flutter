import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void method1() {
  List<String> myArray = <String>['a', 'b', 'c'];
  debugPrint('1 before loop');
  myArray.forEach((String value) async {
    await delayedPrint(value);
  });
  debugPrint('1 end of loop');
}

void method2() async {
  List<String> myArray = <String>['a', 'b', 'c'];
  debugPrint('2 before loop');
  for (int i = 0; i < myArray.length; i++) {
    await delayedPrint(myArray[i]);
  }
  debugPrint('2 end of loop');
}

Future<void> delayedPrint(String value) async {
  await Future.delayed(const Duration(seconds: 1));
  debugPrint('delayedPrint: $value');
}

// https://zhuanlan.zhihu.com/p/59197944
void main() {
  method1();
  method2();
  // testWidgets('Counter increments smoke test', (WidgetTester tester) async {
  //
  // });
}
