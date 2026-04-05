import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/helper/func.dart';

void main() {
  group('strEmpty', () {
    test('returns true for null', () {
      expect(strEmpty(null), isTrue);
    });

    test('returns true for empty string', () {
      expect(strEmpty(''), isTrue);
    });

    test('returns true for whitespace-only string', () {
      expect(strEmpty('   '), isTrue);
      expect(strEmpty('\t\n'), isTrue);
    });

    test('returns false for non-empty string', () {
      expect(strEmpty('hello'), isFalse);
      expect(strEmpty(' a '), isFalse);
    });
  });

  group('strNoEmpty', () {
    test('is inverse of strEmpty', () {
      expect(strNoEmpty(null), isFalse);
      expect(strNoEmpty(''), isFalse);
      expect(strNoEmpty('hello'), isTrue);
      expect(strNoEmpty('   '), isFalse);
    });
  });

  group('mapNoEmpty', () {
    test('returns false for null', () {
      expect(mapNoEmpty(null), isFalse);
    });

    test('returns false for empty map', () {
      expect(mapNoEmpty({}), isFalse);
    });

    test('returns true for non-empty map', () {
      expect(mapNoEmpty({'key': 'value'}), isTrue);
    });
  });

  group('listEmpty', () {
    test('returns true for null', () {
      expect(listEmpty(null), isTrue);
    });

    test('returns true for empty list', () {
      expect(listEmpty([]), isTrue);
    });

    test('returns false for non-empty list', () {
      expect(listEmpty([1, 2, 3]), isFalse);
    });
  });

  group('listNoEmpty', () {
    test('returns false for null', () {
      expect(listNoEmpty(null), isFalse);
    });

    test('returns false for empty list', () {
      expect(listNoEmpty([]), isFalse);
    });

    test('returns true for non-empty list', () {
      expect(listNoEmpty([1]), isTrue);
    });
  });

  group('isUrl', () {
    test('returns true for valid URLs', () {
      expect(isUrl('http://example.com'), isTrue);
      expect(isUrl('https://example.com/path'), isTrue);
      expect(isUrl('ftp://files.example.com'), isTrue);
      expect(isUrl('rtsp://stream.example.com'), isTrue);
    });

    test('returns false for non-URLs', () {
      expect(isUrl('example.com'), isFalse);
      expect(isUrl('hello world'), isFalse);
      expect(isUrl(''), isFalse);
    });
  });

  group('isNetWorkImg', () {
    test('returns true for http/https URLs', () {
      expect(isNetWorkImg('http://example.com/img.png'), isTrue);
      expect(isNetWorkImg('https://example.com/img.png'), isTrue);
    });

    test('returns false for non-network paths', () {
      expect(isNetWorkImg('assets/img.png'), isFalse);
      expect(isNetWorkImg('/local/path.png'), isFalse);
      expect(isNetWorkImg(null), isFalse);
    });
  });

  group('isAssetsImg', () {
    test('returns true for asset paths', () {
      expect(isAssetsImg('assets/images/logo.png'), isTrue);
      expect(isAssetsImg('asset/icon.png'), isTrue);
    });

    test('returns false for non-asset paths', () {
      expect(isAssetsImg('http://example.com/img.png'), isFalse);
      expect(isAssetsImg('/local/path.png'), isFalse);
      expect(isAssetsImg(null), isFalse);
    });
  });

  group('isEmail', () {
    test('returns true for valid emails', () {
      expect(isEmail('user@example.com'), isTrue);
      expect(isEmail('test.user@domain.co'), isTrue);
      expect(isEmail('ab@bc.cc'), isTrue);
    });

    test('returns false for invalid emails', () {
      expect(isEmail(''), isFalse);
      expect(isEmail('notanemail'), isFalse);
      expect(isEmail('@domain.com'), isFalse);
      expect(isEmail('user@'), isFalse);
    });
  });

  group('formatBytes', () {
    test('returns "0 B" for zero or negative', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(-1), '0 B');
    });

    test('formats bytes correctly', () {
      expect(formatBytes(500), '500.00 B');
      expect(formatBytes(1024), '1.00 kB');
      expect(formatBytes(1048576), '1.00 MB');
      expect(formatBytes(1073741824), '1.00 GB');
    });

    test('respects fractionDigits parameter', () {
      expect(formatBytes(1536, fractionDigits: 1), '1.5 kB');
      expect(formatBytes(1536, fractionDigits: 0), '2 kB');
    });

    test('formats with num=1000 (SI units)', () {
      expect(formatBytes(1000, num: 1000), '1.00 kB');
      expect(formatBytes(1000000, num: 1000), '1.00 MB');
    });
  });
}
