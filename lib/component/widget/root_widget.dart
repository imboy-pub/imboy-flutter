import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/w_popup_menu.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/helper/func.dart';
import 'package:imboy/page/friend_add/friend_add_view.dart';
import 'package:imboy/page/group_launch/group_launch_view.dart';
import 'package:imboy/page/help/help_view.dart';
import 'package:imboy/page/language/language_view.dart';
import 'package:imboy/page/search/search_view.dart';

GlobalKey<ScaffoldState> scaffoldGK;

class RootPage extends StatefulWidget {
  @override
  _RootPageState createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  @override
  void initState() {
    super.initState();
    ifBrokenNetwork();
  }

  ifBrokenNetwork() async {
    // final ifNetWork = await SharedUtil.instance.getBoolean(Keys.brokenNetwork);
    // if (ifNetWork) {
    //   /// 监测网络变化
    //   subscription.onConnectivityChanged
    //       .listen((ConnectivityResult result) async {
    //     if (result == ConnectivityResult.mobile ||
    //         result == ConnectivityResult.wifi) {
    //       final currentUser = await im.getCurrentLoginUser();
    //       if (currentUser == '' || currentUser == null) {
    //         final account = await SharedUtil.instance.getString(Keys.account);
    //         im.imAutoLogin(account);
    //       }
    //       await SharedUtil.instance.saveBoolean(Keys.brokenNetwork, false);
    //     }
    //   });
    // } else {
    //   return;
    // }
  }

  @override
  Widget build(BuildContext context) {
    // final gloabl = Provider.of<GlobalModel>(context, listen: false);
    List<TabBarModel> pages = <TabBarModel>[];
    return new Scaffold(
      key: scaffoldGK,
      body: new RootTabBar(pages: pages, currentIndex: 0),
    );
  }
}

class LoadImage extends StatelessWidget {
  final String img;

  LoadImage(this.img);

  @override
  Widget build(BuildContext context) {
    return new Container(
      margin: EdgeInsets.only(bottom: 2.0),
      child: new Image.asset(img, fit: BoxFit.cover, gaplessPlayback: true),
    );
  }
}

typedef CheckLogin(index);

class RootTabBar extends StatefulWidget {
  RootTabBar({this.pages, this.checkLogin, this.currentIndex = 0});

  final List pages;
  final CheckLogin checkLogin;
  final int currentIndex;

  @override
  State<StatefulWidget> createState() => new RootTabBarState();
}

class RootTabBarState extends State<RootTabBar> {
  var pages = [];
  int currentIndex;
  var contents = [];
  PageController pageController;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.currentIndex;
    pageController = PageController(initialPage: currentIndex);
    for (int i = 0; i < widget.pages.length; i++) {
      TabBarModel model = widget.pages[i];
      pages.add(
        new BottomNavigationBarItem(
          icon: model.icon,
          activeIcon: model.selectIcon,
          label: model.title,
        ),
      );
    }
  }

  actionsHandle(v) {
    if (v == '添加朋友') {
      Get.to(FriendAddPage());
    } else if (v == '发起群聊') {
      Get.to(GroupLaunchPage());
    } else if (v == '帮助与反馈') {
      // routePush(new HelpPage(CONST_HELP_URL, '帮助与反馈'));
      Get.to(HelpPage());
    } else {
      Get.to(LanguagePage());
    }
  }

  @override
  Widget build(BuildContext context) {
    final List actions = [
      {"title": '发起群聊', 'icon': 'assets/images/contacts_add_newmessage.png'},
      {"title": '添加朋友', 'icon': 'assets/images/ic_add_friend.webp'},
      {"title": '扫一扫', 'icon': ''},
      {"title": '收付款', 'icon': ''},
      {"title": '帮助与反馈', 'icon': ''},
    ];

    final BottomNavigationBar bottomNavigationBar = new BottomNavigationBar(
      items: pages,
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      fixedColor: Colors.green,
      unselectedItemColor: mainTextColor,
      onTap: (int index) {
        setState(() => currentIndex = index);
        pageController.jumpToPage(currentIndex);
      },
      unselectedFontSize: 18.0,
      selectedFontSize: 18.0,
      elevation: 0,
    );

    var appBar = new ComMomBar(
      title: widget.pages[currentIndex].title,
      showShadow: false,
      rightDMActions: <Widget>[
        new InkWell(
          child: new Container(
            width: 60.0,
            child: new Image.asset('assets/images/search_black.webp'),
          ),
          onTap: () => Get.to(SearchPage()),
        ),
        new WPopupMenu(
          menuWidth: winWidth(context) / 2.5,
          alignment: Alignment.center,
          onValueChanged: (String value) {
            if (!strNoEmpty(value)) {
              return;
            }
            actionsHandle(value);
          },
          actions: actions,
          child: new Container(
            margin: EdgeInsets.symmetric(horizontal: 15.0),
            child: new Image.asset('assets/images/add_addressicon.png',
                color: Colors.black, width: 22.0, fit: BoxFit.fitWidth),
          ),
        )
      ],
    );

    return new Scaffold(
      bottomNavigationBar: new Theme(
        data: new ThemeData(
          canvasColor: Colors.grey[50],
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
        ),
        child: new Container(
          decoration: BoxDecoration(
              border: Border(top: BorderSide(color: lineColor, width: 0.2))),
          child: bottomNavigationBar,
        ),
      ),
      appBar: widget.pages[currentIndex].title != '我的' ? appBar : null,
      body: new ScrollConfiguration(
        // behavior: MyBehavior(),
        behavior: null,
        child: new PageView.builder(
          itemBuilder: (BuildContext context, int index) =>
              widget.pages[index].page,
          controller: pageController,
          itemCount: pages.length,
          physics: Platform.isAndroid
              ? new ClampingScrollPhysics()
              : new NeverScrollableScrollPhysics(),
          onPageChanged: (int index) {
            setState(() => currentIndex = index);
          },
        ),
      ),
    );
  }

  winWidth(BuildContext context) {}
}

class TabBarModel {
  const TabBarModel({this.title, this.page, this.icon, this.selectIcon});

  final String title;
  final Widget icon;
  final Widget selectIcon;
  final Widget page;
}
