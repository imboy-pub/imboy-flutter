import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/repository/message_fts_repo.dart';

void main() {
  group('MessageFtsRepo.extractTextContent', () {
    test('text 消息提取 payload.text', () {
      expect(
        MessageFtsRepo.extractTextContent('text', {'text': '你好世界'}),
        '你好世界',
      );
    });

    test('quote 消息提取 payload.quote_text', () {
      expect(
        MessageFtsRepo.extractTextContent('quote', {'quote_text': '引用内容'}),
        '引用内容',
      );
    });

    test('location 消息拼接 title + address', () {
      expect(
        MessageFtsRepo.extractTextContent('location', {
          'title': '天安门',
          'address': '北京市东城区',
        }),
        '天安门 北京市东城区',
      );
    });

    test('location 仅 title', () {
      expect(
        MessageFtsRepo.extractTextContent('location', {'title': '故宫'}),
        '故宫',
      );
    });

    test('image 消息返回空', () {
      expect(
        MessageFtsRepo.extractTextContent('image', {'url': 'http://...'}),
        '',
      );
    });

    test('video 消息返回空', () {
      expect(
        MessageFtsRepo.extractTextContent('video', {'url': 'http://...'}),
        '',
      );
    });

    test('voice 消息返回空', () {
      expect(
        MessageFtsRepo.extractTextContent('voice', {'duration': 5}),
        '',
      );
    });

    test('file 消息返回空', () {
      expect(
        MessageFtsRepo.extractTextContent('file', {'filename': 'doc.pdf'}),
        '',
      );
    });

    test('null msgType 返回空', () {
      expect(
        MessageFtsRepo.extractTextContent(null, {'text': 'hello'}),
        '',
      );
    });

    test('空 text 返回空', () {
      expect(
        MessageFtsRepo.extractTextContent('text', {'text': '  '}),
        '',
      );
    });

    test('text 内容去除前后空白', () {
      expect(
        MessageFtsRepo.extractTextContent('text', {'text': '  hello  '}),
        'hello',
      );
    });
  });

  group('FtsSearchResult', () {
    test('构造正确', () {
      final result = FtsSearchResult(
        id: 'msg1',
        conversationUk3: 'C2C_a_b',
        snippet: '搜索<b>关键词</b>',
        rank: -1.5,
      );
      expect(result.id, 'msg1');
      expect(result.conversationUk3, 'C2C_a_b');
      expect(result.snippet, '搜索<b>关键词</b>');
      expect(result.rank, -1.5);
    });
  });
}
