import 'dart:convert';

import 'package:azlistview/azlistview.dart';
import 'package:flutter/material.dart';

typedef OnAdd = void Function(String v);
typedef OnCancel = void Function(String v);

class ContactItem extends ISuspensionBean {
  final String identifier;
  final String avatar;
  final String account;
  final String title; // nickname or title
  final String? groupTitle;
  final bool isLine;

  // final ClickType type;
  final OnAdd? add;
  final OnCancel? cancel;

  //
  final String? tagIndex;
  final String? namePinyin;
  final Color? bgColor;
  final IconData? iconData;
  final String? firstLetter;

  //

  ContactItem({
    required this.identifier,
    required this.avatar,
    required this.title,
    required this.account,
    this.isLine = true,
    this.groupTitle,
    // this.type = ClickType.open,
    this.add,
    this.cancel,
    this.tagIndex,
    this.namePinyin,
    this.bgColor,
    this.iconData,
    this.firstLetter,
  });

  @override
  String getSuspensionTag() => tagIndex!;

  @override
  String toString() => json.encode(this);
}
