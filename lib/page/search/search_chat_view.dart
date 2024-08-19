import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:highlight_text/highlight_text.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/page/chat/chat/chat_view.dart';
import 'package:niku/namespace.dart' as n;

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/component/ui/search_field.dart';

import 'search_logic.dart';
import 'search_state.dart';

class SearchChatPage extends StatefulWidget {
  final String conversationUk3;
  final String type; // [C2C | C2G | C2S]
  final String peerId; // 用户ID | GroupId | SID
  final String peerAvatar;
  final String peerTitle;
  final String peerSign;

  const SearchChatPage({
    super.key,
    required this.conversationUk3,
    required this.type,
    required this.peerId,
    required this.peerTitle,
    required this.peerAvatar,
    required this.peerSign,
  });

  @override
  // ignore: library_private_types_in_public_api
  _SearchChatPageState createState() => _SearchChatPageState();
}

class _SearchChatPageState extends State<SearchChatPage> {
  final logic = Get.put(SearchLogic());
  final SearchState state = Get.find<SearchLogic>().state;

  final TextEditingController _searchC = TextEditingController();

  List items = [];
  Map<String, HighlightedWord> words = {};

  Widget wordView(item) {
    final msg = item as types.Message;
    String subtitle = msg.metadata?['text'] ?? '';
    return InkWell(
      child: Container(
        width: Get.width,
        alignment: Alignment.center,
        color: Theme.of(context).colorScheme.onSecondary,
        margin: const EdgeInsets.only(top: 10),
        child: n.ListTile(
          leading: Avatar(imgUri: msg.author.imageUrl ?? ''),
          title: n.Row([
            Flexible(
              child: Text(
                msg.author.firstName ?? '',
              ),
            ),
            Text(
              DateTimeHelper.lastTimeFmt(msg.createdAt!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                // color: AppColors.MainTextColor,
                fontSize: 14.0,
              ),
            )
          ])
            // 两端对齐
            ..mainAxisAlignment = MainAxisAlignment.spaceBetween,
          subtitle: TextHighlight(
              text: subtitle,
              // You need to pass the string you want the highlights
              words: words,
              // Your dictionary words
              matchCase: true // will highlight only exactly the same string
              ),
        ),
      ),
      onTap: () {
        if (widget.type == 'C2C' || widget.type == 'C2G' || widget.type == 'S2C') {
          Get.to(
            () => ChatPage(
              peerId: widget.peerId,
              peerTitle: widget.peerTitle,
              peerAvatar: widget.peerAvatar,
              peerSign: widget.peerSign,
              type: widget.type,
              msgId: msg.id,
            ),
            transition: Transition.rightToLeft,
            popGesture: true, // 右滑，返回上一页
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: SearchField(
          top: 30,
          left: 10,
          controller: _searchC,
          onSubmitted: (txt) async {
            if (txt.isNotEmpty) {
              words = {
                txt: HighlightedWord(
                  onTap: () {
                    // print("Flutter");
                  },
                  textStyle: const TextStyle(color: Colors.green, fontSize: 18),
                ),
              };
              items = await logic.search(
                kwd: txt,
                type: widget.type,
                conversationUk3: widget.conversationUk3,
              );
              setState(() {});
            }
          },
          onChanged: (txt) async {
            setState(() {});
          },
          onClear: () {
            items = [];
            setState(() {});
          },
        ),
        body: SingleChildScrollView(
          child: n.Column([
            if (items.isEmpty)
              n.Padding(
                left: 30,
                right: 30,
                top: 20,
                child: _searchC.text.isEmpty
                    ? const SizedBox.square()
                    : n.Row([
                        Expanded(
                            child: Text(
                          "${'search'.tr}: ${_searchC.text}",
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 16,
                          ),
                        )),
                        HorizontalLine(height: Get.isDarkMode ? 0.5 : 1.0)
                      ]),
              ),
            Wrap(
              children: items.map(wordView).toList(),
            )
          ])
            ..crossAxisAlignment = CrossAxisAlignment.center,
        ));
  }

  @override
  void dispose() {
    Get.delete<SearchLogic>();
    super.dispose();
  }
}
