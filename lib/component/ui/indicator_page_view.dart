import 'package:flutter/material.dart';

class IndicatorPageView extends StatefulWidget {
  final PageController pageC;
  final List<Widget> pages;

  const IndicatorPageView({Key? key, required this.pageC, required this.pages})
      : super(key: key);

  @override
  IndicatorPageViewState createState() => IndicatorPageViewState();
}

class IndicatorPageViewState extends State<IndicatorPageView> {
  int currentMoreIndex = 0;
  double size = 5.0;

  Widget itemView(index) {
    return Container(
      height: size,
      width: size,
      margin: EdgeInsets.symmetric(horizontal: size),
      decoration: BoxDecoration(
        color: currentMoreIndex == index
            ? Colors.black
            : Colors.grey.withOpacity(0.3),
        borderRadius: BorderRadius.all(
          Radius.circular(size / 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          ScrollConfiguration(
            behavior: MyBehavior(),
            child: PageView(
              controller: widget.pageC,
              onPageChanged: (v) {
                setState(() => currentMoreIndex = v);
              },
              children: widget.pages,
            ),
          ),
          Container(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.pages.length, itemView),
            ),
          )
        ],
      ),
      onTap: () {},
    );
  }
}

class MyBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}
