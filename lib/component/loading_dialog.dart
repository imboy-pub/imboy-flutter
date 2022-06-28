import 'package:flutter/material.dart';

class LoadingDialog extends StatelessWidget {
  const LoadingDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: SimpleDialog(
        key: key,
        backgroundColor: Colors.white,
        children: const <Widget>[
          Center(
            child: CircularProgressIndicator(),
          )
        ],
      ),
    );
  }
}
