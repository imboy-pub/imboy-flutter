part of 'protected_frame_v3.dart';

// RFC 8949 §4.2.1: preserve the value using the shortest exact float width.
class _CborFloat {
  static Uint8List encode(double value) {
    if (!value.isFinite) throw CborParseException('non-finite float');
    final single = ByteData(4)..setFloat32(0, value);
    if (_same(single.getFloat32(0), value)) {
      final half = _halfBits(single.getUint32(0));
      if (half != null && _same(_decodeHalf(half), value)) {
        return Uint8List.fromList([0xf9, half >> 8, half & 0xff]);
      }
      return Uint8List.fromList([0xfa, ...single.buffer.asUint8List()]);
    }
    final full = ByteData(8)..setFloat64(0, value);
    return Uint8List.fromList([0xfb, ...full.buffer.asUint8List()]);
  }

  static bool _same(double a, double b) =>
      a == b && a.isNegative == b.isNegative;

  static int? _halfBits(int single) {
    final sign = (single >> 16) & 0x8000;
    final exponent = (single >> 23) & 0xff;
    final fraction = single & 0x7fffff;
    if (exponent == 0 && fraction == 0) return sign;
    if (exponent >= 113 && exponent <= 142) {
      return sign | ((exponent - 112) << 10) | (fraction >> 13);
    }
    if (exponent >= 103 && exponent < 113) {
      return sign | ((fraction | 0x800000) >> (126 - exponent));
    }
    return null;
  }

  static double _decodeHalf(int bits) {
    final exponent = (bits >> 10) & 0x1f;
    final fraction = bits & 0x3ff;
    if (exponent == 31) throw CborParseException('non-finite float');
    final magnitude = exponent == 0
        ? fraction * 5.960464477539063e-8
        : (1024 + fraction) * math.pow(2, exponent - 25).toDouble();
    return (bits & 0x8000) == 0 ? magnitude : -magnitude;
  }

  static double decode(Uint8List bytes, {required bool strict}) {
    final data = ByteData.sublistView(bytes);
    final value = switch (bytes.length) {
      2 => _decodeHalf(data.getUint16(0)),
      4 => data.getFloat32(0),
      8 => data.getFloat64(0),
      _ => throw CborParseException('invalid float width'),
    };
    if (!value.isFinite) throw CborParseException('non-finite float');
    if (strict && encode(value).length != bytes.length + 1) {
      throw CborParseException('non-shortest float encoding');
    }
    return value;
  }
}
