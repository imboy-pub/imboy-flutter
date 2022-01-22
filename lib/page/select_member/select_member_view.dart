import 'dart:convert';

import 'package:azlistview/azlistview.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/commom_button.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/helper/func.dart';
import 'package:lpinyin/lpinyin.dart';

import 'select_member_logic.dart';
import 'select_member_state.dart';

class SelectMemberPage extends StatefulWidget {
  @override
  _SelectMemberPageState createState() => _SelectMemberPageState();
}

class _SelectMemberPageState extends State<SelectMemberPage> {
  final logic = Get.find<SelectMemberLogic>();
  final SelectMemberState state = Get.find<SelectMemberLogic>().state;

  List<ContactInfoModel> _contacts = [];

  int _suspensionHeight = 30;
  int _itemHeight = 60;
  double _headHeight = 60;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  List selects = [];

  void loadData() async {
    //加载联系人列表
    rootBundle.loadString('assets/data/contacts.json').then((value) {
      List list = json.decode(value);
      list.forEach((value) {
        _contacts.add(ContactInfoModel(name: value['name']));
      });
      _handleList(_contacts);
      setState(() {});
    });
  }

  void _handleList(List<ContactInfoModel> list) {
    if (list == null || list.isEmpty) return;
    for (int i = 0, length = list.length; i < length; i++) {
      String pinyin = PinyinHelper.getPinyinE(list[i].name!);
      String tag = PinyinHelper.getFirstWordPinyin(pinyin).toUpperCase();
      list[i].namePinyin = pinyin;
      if (RegExp("[A-Z]").hasMatch(tag)) {
        list[i].tagIndex = tag;
      } else {
        list[i].tagIndex = "#";
      }
    }
    //根据A-Z排序
    SuspensionUtil.sortListBySuspensionTag(list);
  }

  Widget _buildSusWidget(String susTag) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15.0),
      height: _suspensionHeight.toDouble(),
      width: double.infinity,
      alignment: Alignment.centerLeft,
      color: AppColors.AppBarColor,
      child: Text(
        '$susTag',
        textScaleFactor: 1.2,
        style: TextStyle(
          color: Color(0xff333333),
          fontSize: 12.0,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildListItem(ContactInfoModel model) {
    String uFace = '';
    String susTag = model.getSuspensionTag();
    return Column(
      children: <Widget>[
        Offstage(
          offstage: model.isSelect != true,
          child: _buildSusWidget(susTag),
        ),
        SizedBox(
          height: _itemHeight.toDouble(),
          child: new InkWell(
            child: new Row(
              children: <Widget>[
                new Padding(
                  padding: EdgeInsets.symmetric(horizontal: mainSpace * 1.5),
                  child: new Icon(
                    model.isSelect!
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.check_mark_circled,
                    color: model.isSelect! ? Colors.green : Colors.grey,
                  ),
                ),
                new ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(5)),
                  child: !strNoEmpty(uFace)
                      ? new Image(
                          image: AssetImage(defIcon),
                          height: 48.0,
                          width: 48.0,
                          fit: BoxFit.cover,
                        )
                      : CachedNetworkImage(
                          imageUrl: uFace,
                          height: 48.0,
                          width: 48.0,
                          cacheManager: cacheManager,
                          fit: BoxFit.cover,
                        ),
                ),
                new Space(),
                new Expanded(
                  child: new Container(
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.only(right: 30),
                    height: _itemHeight.toDouble(),
                    decoration: BoxDecoration(
                      border: Border(
                          top: BorderSide(
                              color: AppColors.LineColor, width: 0.2)),
                    ),
                    child: new Text(
                      model.name!,
                      style: TextStyle(fontSize: 14.0),
                    ),
                  ),
                ),
              ],
            ),
            onTap: () {
              model.isSelect = model.isSelect;
              if (model.isSelect!) {
                selects.insert(0, model);
              } else {
                selects.remove(model);
              }
              setState(() {});
            },
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new PageAppBar(
        title: '选择联系人',
        rightDMActions: <Widget>[
          new ComMomButton(
            margin: EdgeInsets.symmetric(vertical: 7, horizontal: 5),
            onTap: () {
              if (!listNoEmpty(selects)) {
                Get.snackbar('', '请选择要添加的成员');
              }
            },
            text: '确定',
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: AzListView(
        data: _contacts,
        itemCount: _contacts.length,
        itemBuilder: (context, i) => _buildListItem(_contacts[i]),
      ),
    );
  }

  @override
  void dispose() {
    Get.delete<SelectMemberLogic>();
    super.dispose();
  }
}

class ContactInfoModel extends ISuspensionBean {
  String? name;
  String? tagIndex;
  String? namePinyin;
  bool? isSelect;

  ContactInfoModel({
    this.name = 'aTest',
    this.tagIndex = 'A',
    this.namePinyin = 'A',
    this.isSelect = false,
  });

  ContactInfoModel.fromJson(Map<String, dynamic> json)
      : name = json['name'] == null ? "" : json['name'];

  Map<String, dynamic> toJson() => {
        'name': name,
        'tagIndex': tagIndex,
        'namePinyin': namePinyin,
        'isSelect': isSelect,
      };

  @override
  String getSuspensionTag() => tagIndex!;

  @override
  String toString() => "CityBean {" + " \"name\":\"" + name! + "\"" + '}';
}
