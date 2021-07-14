import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/view/null_view.dart';
import 'package:imboy/component/widget/chat/contact_item.dart';
import 'package:imboy/component/widget/chat/contact_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/helper/constant.dart';
import 'package:imboy/helper/win_media.dart';
import 'package:imboy/page/search/search_view.dart';
import 'package:imboy/store/model/contact_model.dart';

import 'contacts_logic.dart';
import 'contacts_state.dart';

class ContactsPage extends StatefulWidget {
  _ContactsPageState createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage>
    with AutomaticKeepAliveClientMixin {
  final ContactsLogic logic = Get.put(ContactsLogic());
  final ContactsState state = Get.find<ContactsLogic>().state;

  var indexBarBg = Colors.transparent;
  var currentLetter = '';
  var isNull = false;

  TextEditingController _searchC = new TextEditingController();

  ScrollController sC;
  List<ContactModel> _contacts = [];
  StreamSubscription<dynamic> _messageStreamSubscription;

  List<ContactItem> _functionButtons = [
    new ContactItem(
        identifier: 'new_friend',
        account: '',
        avatar: contactAssets + 'ic_new_friend.webp',
        title: '新的朋友'),
    new ContactItem(
        identifier: 'ic_group',
        account: '',
        avatar: contactAssets + 'ic_group.webp',
        title: '群聊'),
    new ContactItem(
        identifier: 'ic_tag',
        account: '',
        avatar: contactAssets + 'ic_tag.webp',
        title: '标签'),
  ];
  final Map _letterPosMap = {INDEX_BAR_WORDS[0]: 0.0};

  Future getContacts() async {
    List<ContactModel> listContact = await logic.listFriend();
    isNull = listContact.isEmpty;
    debugPrint("listContact " + listContact.toString());
    _contacts.clear();
    _contacts..addAll(listContact);
    _contacts.sort(
        (ContactModel a, ContactModel b) => a.nickname.compareTo(b.nickname));
    sC = new ScrollController();

    /// 计算用于 IndexBar 进行定位的关键通讯录列表项的位置
    var _totalPos =
        _functionButtons.length * ContactItemState.heightItem(false);
    for (int i = 0; i < _contacts.length; i++) {
      bool _hasGroupTitle = true;
      if (i > 0 &&
          _contacts[i].nickname.compareTo(_contacts[i - 1].nickname) == 0)
        _hasGroupTitle = false;

      if (_hasGroupTitle) _letterPosMap[_contacts[i].nickname] = _totalPos;

      _totalPos += ContactItemState.heightItem(_hasGroupTitle);
    }
    if (mounted) setState(() {});
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    Get.delete<ContactsLogic>();
    if (sC != null) sC.dispose();
    super.dispose();
  }

  String _getLetter(BuildContext context, double tileHeight, Offset globalPos) {
    RenderBox _box = context.findRenderObject();
    var local = _box.globalToLocal(globalPos);
    int index = (local.dy ~/ tileHeight).clamp(0, INDEX_BAR_WORDS.length - 1);
    return INDEX_BAR_WORDS[index];
  }

  void _jumpToIndex(String letter) {
    if (_letterPosMap.isNotEmpty) {
      final _pos = _letterPosMap[letter];
      if (_pos != null)
        sC.animateTo(_pos,
            curve: Curves.easeOut, duration: Duration(milliseconds: 200));
    }
  }

  Widget _buildIndexBar(BuildContext context, BoxConstraints constraints) {
    final List<Widget> _letters = INDEX_BAR_WORDS
        .map((String word) =>
            new Expanded(child: new Text(word, style: TextStyle(fontSize: 12))))
        .toList();

    final double _totalHeight = constraints.biggest.height;
    final double _tileHeight = _totalHeight / _letters.length;

    void jumpTo(details) {
      indexBarBg = Colors.black26;
      currentLetter = _getLetter(context, _tileHeight, details.globalPosition);
      _jumpToIndex(currentLetter);
      setState(() {});
    }

    void transparentMethod() {
      indexBarBg = Colors.transparent;
      currentLetter = null;
      setState(() {});
    }

    return new GestureDetector(
      onVerticalDragDown: (DragDownDetails details) => jumpTo(details),
      onVerticalDragEnd: (DragEndDetails details) => transparentMethod(),
      onVerticalDragUpdate: (DragUpdateDetails details) => jumpTo(details),
      child: new Column(children: _letters),
    );
  }

  @override
  void initState() {
    super.initState();
    getContacts();
    initPlatformState();
  }

  void canCelListener() {
    if (_messageStreamSubscription != null) _messageStreamSubscription.cancel();
  }

  Future<void> initPlatformState() async {
    if (!mounted) return;
    if (_messageStreamSubscription == null) {
      // _messageStreamSubscription =
      //     im.ws.onMessage.listen((dynamic onData) => getContacts());
    }
  }

  @override
  Widget build(BuildContext context) {
    var appBar = new ComMomBar(
      title: "联系人",
      showShadow: false,
      rightDMActions: <Widget>[
        new InkWell(
          child: new Container(
            width: 60.0,
            child:
                new Image(image: AssetImage('assets/images/search_black.webp')),
          ),
          onTap: () => Get.to(() => SearchPage()),
        ),
        // new WPopupMenu(
        //   menuWidth: winWidth(context) / 2.5,
        //   alignment: Alignment.center,
        //   onValueChanged: (String value) {
        //     if (!strNoEmpty(value)) {
        //       return;
        //     }
        //     actionsHandle(value);
        //   },
        //   actions: actions,
        //   child: new Container(
        //     margin: EdgeInsets.symmetric(horizontal: 15.0),
        //     child: new Image(
        //       image: AssetImage('assets/images/add_addressicon.png'),
        //       color: Colors.black,
        //       width: 22.0,
        //       fit: BoxFit.fitWidth,
        //     ),
        //   ),
        // )
      ],
    );

    List<Widget> body = [
      new ContactView(
          sC: sC, functionButtons: _functionButtons, contacts: _contacts),
      new Positioned(
        width: Constants.IndexBarWidth,
        right: 0.0,
        top: 120.0,
        bottom: 120.0,
        child: new Container(
          color: indexBarBg,
          child: new LayoutBuilder(builder: _buildIndexBar),
        ),
      ),
    ];

    if (isNull) {
      body.add(new HomeNullView(str: '无联系人'));
    }

    if (currentLetter != null && currentLetter.isNotEmpty) {
      var row = [
        new Container(
            width: Constants.IndexLetterBoxSize,
            height: Constants.IndexLetterBoxSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.IndexLetterBoxBg,
              borderRadius: BorderRadius.all(
                  Radius.circular(Constants.IndexLetterBoxSize / 2)),
            ),
            child: new Text(currentLetter,
                style: AppStyles.IndexLetterBoxTextStyle)),
        new Icon(Icons.arrow_right),
        new Space(width: mainSpace * 5),
      ];
      body.add(
        new Container(
          width: winWidth(context),
          height: winHeight(context),
          child:
              new Row(mainAxisAlignment: MainAxisAlignment.end, children: row),
        ),
      );
    }
    return new Scaffold(
      backgroundColor: appBarColor,
      appBar: appBar,
      // appBar: new ComMomBar(
      //   title: '联系人',
      // ),
      body: new Stack(children: body),
    );
  }
}
