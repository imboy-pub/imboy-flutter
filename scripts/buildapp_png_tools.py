#!/usr/bin/env python3
"""buildapp_png_tools.py — portable PNG size probe + resize (sips fallback).

macOS builds keep using sips (Lanczos resample, the verified delivery path);
Linux CI has no sips, so buildapp.sh falls back to this pure-stdlib tool:
  size   <png>            -> prints "<width> <height>" (IHDR only)
  resize <src> <dst> <w> <h> -> nearest-neighbor resample, 8-bit RGB/RGBA
Restrictions (die loudly on anything else): non-interlaced, bit depth 8,
color type 2 (RGB) or 6 (RGBA). Icons in this repo/fixtures are RGBA-8.
"""

import struct
import sys
import zlib

PNG_SIG = b"\x89PNG\r\n\x1a\n"


def die(msg):
    sys.stderr.write("buildapp_png_tools: %s\n" % msg)
    sys.exit(1)


def read_png(path):
    with open(path, "rb") as fh:
        data = fh.read()
    if not data.startswith(PNG_SIG):
        die("not a PNG: %s" % path)
    pos = 8
    ihdr = None
    idat = bytearray()
    while pos + 8 <= len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        ctype = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + length]
        (crc,) = struct.unpack(">I", data[pos + 8 + length:pos + 12 + length])
        if zlib.crc32(ctype + chunk) & 0xFFFFFFFF != crc:
            die("CRC mismatch in %s (corrupt PNG?)" % path)
        if ctype == b"IHDR":
            ihdr = struct.unpack(">IIBBBBB", chunk)
        elif ctype == b"IDAT":
            idat.extend(chunk)
        elif ctype == b"IEND":
            break
        pos += 12 + length
    if ihdr is None or not idat:
        die("missing IHDR/IDAT in %s" % path)
    width, height, depth, color, comp, filt, interlace = ihdr
    if depth != 8 or color not in (2, 6):
        die("unsupported PNG (bit depth %d, color type %d): %s" % (depth, color, path))
    if comp != 0 or filt != 0 or interlace != 0:
        die("unsupported PNG (compression/filter/interlace): %s" % path)
    return width, height, color, zlib.decompress(bytes(idat))


def unfilter(width, height, bpp, raw):
    stride = width * bpp
    out = bytearray(height * stride)
    prev = bytearray(stride)
    pos = 0
    for y in range(height):
        f = raw[pos]
        pos += 1
        line = bytearray(raw[pos:pos + stride])
        pos += stride
        if f == 0:
            pass
        elif f == 1:  # Sub
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 0xFF
        elif f == 2:  # Up
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif f == 3:  # Average
            for i in range(stride):
                left = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((left + prev[i]) >> 1)) & 0xFF
        elif f == 4:  # Paeth
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pred) & 0xFF
        else:
            die("bad filter type %d" % f)
        out[y * stride:(y + 1) * stride] = line
        prev = line
    return out


def refilter(width, height, bpp, pixels):
    stride = width * bpp
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        raw.extend(pixels[y * stride:(y + 1) * stride])
    return zlib.compress(bytes(raw), 9)


def write_png(path, width, height, color, zdata):
    def chunk(ctype, payload):
        crc = zlib.crc32(ctype + payload) & 0xFFFFFFFF
        return struct.pack(">I", len(payload)) + ctype + payload + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, color, 0, 0, 0)
    with open(path, "wb") as fh:
        fh.write(PNG_SIG)
        fh.write(chunk(b"IHDR", ihdr))
        fh.write(chunk(b"IDAT", zdata))
        fh.write(chunk(b"IEND", b""))


def cmd_size(path):
    width, height, _color, _raw = read_png(path)
    print("%d %d" % (width, height))


def cmd_resize(src, dst, w, h):
    w, h = int(w), int(h)
    if w <= 0 or h <= 0:
        die("target size must be positive")
    sw, sh, color, raw = read_png(src)
    bpp = 4 if color == 6 else 3
    pixels = unfilter(sw, sh, bpp, raw)

    def px(x, y):
        o = (y * sw + x) * bpp
        return pixels[o:o + bpp]

    out = bytearray(w * h * bpp)
    for dy in range(h):
        sy = min(sh - 1, int((dy + 0.5) * sh / h))
        for dx in range(w):
            sx = min(sw - 1, int((dx + 0.5) * sw / w))
            out[(dy * w + dx) * bpp:(dy * w + dx) * bpp + bpp] = px(sx, sy)
    write_png(dst, w, h, color, refilter(w, h, bpp, out))
    gw, gh, _c, _r = read_png(dst)
    if (gw, gh) != (w, h):
        die("round-trip size check failed: want %dx%d got %dx%d" % (w, h, gw, gh))


def main(argv):
    if len(argv) == 3 and argv[1] == "size":
        cmd_size(argv[2])
    elif len(argv) == 6 and argv[1] == "resize":
        cmd_resize(argv[2], argv[3], argv[4], argv[5])
    else:
        sys.stderr.write(__doc__)
        return 64
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
