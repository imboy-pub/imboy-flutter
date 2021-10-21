
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void method1(){
  List<String> myArray = <String>['a','b','c'];
  print('1 before loop');
  myArray.forEach((String value) async {
    await delayedPrint(value);
  });
  print('1 end of loop');
}

void method2() async {
  List<String> myArray = <String>['a','b','c'];
  print('2 before loop');
  for(int i=0; i<myArray.length; i++) {
    await delayedPrint(myArray[i]);
  }
  print('2 end of loop');
}

Future<void> delayedPrint(String value) async {
  await Future.delayed(Duration(seconds: 1));
  print('delayedPrint: $value');
}



// https://zhuanlan.zhihu.com/p/59197944
void main() {
  method1();
  method2();
  // testWidgets('Counter increments smoke test', (WidgetTester tester) async {
  //
  // });
}