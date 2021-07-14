import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/view/image_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/helper/constant.dart';
import 'package:imboy/page/contact_detail/contact_detail_view.dart';
import 'package:imboy/page/group_list/group_list_view.dart';
import 'package:imboy/page/new_friend/new_friend_view.dart';

import 'contact_view.dart';

typedef OnAdd = void Function(String v);
typedef OnCancel = void Function(String v);

class ContactItem extends StatefulWidget {
  final String identifier;
  final String avatar;
  final String account;
  final String title; // nickname or title
  final String groupTitle;
  final bool isLine;
  final ClickType type;
  final OnAdd add;
  final OnCancel cancel;

  ContactItem({
    @required this.identifier,
    @required this.avatar,
    @required this.title,
    @required this.account,
    this.isLine = true,
    this.groupTitle,
    this.type = ClickType.open,
    this.add,
    this.cancel,
  });

  ContactItemState createState() => ContactItemState();
}

class ContactItemState extends State<ContactItem> {
  // ‘添加好友’ 横纵间距
  static const double MARGIN_VERTICAL = 6.0;
  static const double MARGIN_HORIZONTAL = 16.0;

  // ‘ABC...’ 高度
  static const double GROUP_TITLE_HEIGHT = 34.0;

  // items的高度 纵向高度*2+头像高度+分割线高度
  static double heightItem(bool hasGroupTitle) {
    final _buttonHeight = MARGIN_VERTICAL * 2 +
        Constants.ContactAvatarSize +
        Constants.DividerWidth;
    if (hasGroupTitle) return _buttonHeight + GROUP_TITLE_HEIGHT;

    return _buttonHeight;
  }

  bool isSelect = false;

  Map<String, dynamic> mapData;

  bool isLine() {
    if (widget.isLine) {
      if (widget.title != '公众号') {
        return true;
      } else {
        return false;
      }
    } else {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    /// 定义左边图标Widget
    Widget _avatarIcon = new ImageView(
      img: widget.avatar,
      width: Constants.ContactAvatarSize,
      height: Constants.ContactAvatarSize,
      fit: BoxFit.cover,
    );

    /// 头像圆角
    _avatarIcon = _avatarIcon;

    var content = [
      _avatarIcon,

      ///  头像离名字的距离
      new Space(width: 15.0),
      new Expanded(
        child: new Container(
          padding: const EdgeInsets.only(right: MARGIN_HORIZONTAL),
          height: heightItem(false),

          /// 名字的显示位置
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            border: !isLine()
                ? null
                : Border(
                    bottom: BorderSide(

                        /// 下划线粗细及颜色
                        width: Constants.DividerWidth,
                        color: lineColor),
                  ),
          ),

          /// 姓名
          child: new Text(widget.title,
              style: TextStyle(fontWeight: FontWeight.w400), maxLines: 1),
        ),
      ),
      widget.type == ClickType.select
          ? new InkWell(
              child: new Image(
                image: AssetImage(
                    'assets/images/login/${isSelect ? 'ic_select_have.webp' : 'ic_select_no.png'}'),
                width: 25.0,
                height: 25.0,
                fit: BoxFit.cover,
              ),
              onTap: () {
                setState(() => isSelect = !isSelect);
                if (isSelect) widget.add(widget.identifier);
                if (!isSelect) widget.cancel(widget.identifier);
              },
            )
          : new Container()
    ];

    /// 列表项主体部分
    Widget button = new FlatButton(
      color: Colors.white,
      onPressed: () {
        if (widget.type == ClickType.select) {
          setState(() => isSelect = !isSelect);
          if (isSelect) widget.add(widget.identifier);
          if (!isSelect) widget.cancel(widget.identifier);
          return;
        }
        if (widget.title == '新的朋友') {
          Get.to(NewFriendPage());
        } else if (widget.title == '群聊') {
          Get.to(GroupListPage());
          // } else if (widget.title == '标签') {
          //   Get.to(AllLabelPage());
          // } else if (widget.title == '公众号') {
          //   Get.to(PublicPage());
        } else {
          Get.to(ContactDetailPage(
            id: widget.identifier,
            avatar: widget.avatar,
            nickname: widget.title,
            account: widget.account,
          ));
        }
      },
      child: new Row(children: content),
    );

    /// 定义分组标签（左边的ABC...）
    Widget itemBody;
    if (widget.groupTitle != null) {
      itemBody = new Column(
        children: <Widget>[
          new Container(
            height: GROUP_TITLE_HEIGHT,
            padding: EdgeInsets.only(left: 16.0, right: 16.0),
            decoration: BoxDecoration(
              color: Color(AppColors.ContactGroupTitleBg),
              border: Border(
                top: BorderSide(color: lineColor, width: 0.2),
                bottom: BorderSide(color: lineColor, width: 0.2),
              ),
            ),
            alignment: Alignment.centerLeft,
            child: new Text(widget.groupTitle,
                style: AppStyles.GroupTitleItemTextStyle),
          ),
          button,
        ],
      );
    } else {
      itemBody = button;
    }

    return itemBody;
  }
}
