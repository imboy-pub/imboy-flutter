// Test-only immutable checkpoint storage. No target file is replaced or deleted.
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

typedef _OpenC = Int32 Function(Pointer<Uint8>, Int32, Uint32);
typedef _OpenD = int Function(Pointer<Uint8>, int, int);
typedef _OpenAtC = Int32 Function(Int32, Pointer<Uint8>, Int32, Uint32);
typedef _OpenAtD = int Function(int, Pointer<Uint8>, int, int);
typedef _RenameAtC = Int32 Function(
  Int32,
  Pointer<Uint8>,
  Int32,
  Pointer<Uint8>,
  Int32,
);
typedef _RenameAtD = int Function(
  int,
  Pointer<Uint8>,
  int,
  Pointer<Uint8>,
  int,
);
typedef _IoC = IntPtr Function(Int32, Pointer<Uint8>, IntPtr);
typedef _IoD = int Function(int, Pointer<Uint8>, int);
typedef _FdC = Int32 Function(Int32);
typedef _FdD = int Function(int);
typedef _ChmodC = Int32 Function(Int32, Uint32);
typedef _ChmodD = int Function(int, int);
typedef _MallocC = Pointer<Uint8> Function(IntPtr);
typedef _MallocD = Pointer<Uint8> Function(int);
typedef _FreeC = Void Function(Pointer<Uint8>);
typedef _FreeD = void Function(Pointer<Uint8>);
typedef _ErrnoC = Pointer<Int32> Function();
typedef _ErrnoD = Pointer<Int32> Function();
typedef _FstatC = Int32 Function(Int32, Pointer<Uint8>);
typedef _FstatD = int Function(int, Pointer<Uint8>);
typedef _GetuidC = Uint32 Function();
typedef _GetuidD = int Function();

/// Uses openat and no-replace rename relative to a no-follow directory descriptor.
/// Android is the supported target. macOS and glibc Linux (x64/arm64) are
/// permitted for isolated unit tests and CI.
class V5CheckpointStore {
  V5CheckpointStore(this.directory) {
    final abi = Abi.current();
    final linux64 =
        Platform.isLinux && (abi == Abi.linuxX64 || abi == Abi.linuxArm64);
    if (!Platform.isAndroid && !Platform.isMacOS && !linux64) {
      throw UnsupportedError(
        'checkpoint syscalls unsupported on this platform',
      );
    }
    if (Platform.isAndroid && abi != Abi.androidArm64) {
      throw UnsupportedError(
        'checkpoint stat ABI unsupported on this Android device',
      );
    }
    _lib = Platform.isAndroid
        ? DynamicLibrary.open('libc.so')
        : DynamicLibrary.process();
    _open = _lib.lookupFunction<_OpenC, _OpenD>('open');
    _openat = _lib.lookupFunction<_OpenAtC, _OpenAtD>('openat');
    // Missing libc support fails closed. Never substitute an overwriting rename.
    try {
      _renameat = _lib.lookupFunction<_RenameAtC, _RenameAtD>(
        Platform.isMacOS ? 'renameatx_np' : 'renameat2',
      );
    } on ArgumentError {
      throw UnsupportedError('atomic no-replace rename is unavailable');
    }
    _read = _lib.lookupFunction<_IoC, _IoD>('read');
    _write = _lib.lookupFunction<_IoC, _IoD>('write');
    _fsync = _lib.lookupFunction<_FdC, _FdD>('fsync');
    _close = _lib.lookupFunction<_FdC, _FdD>('close');
    _fchmod = _lib.lookupFunction<_ChmodC, _ChmodD>('fchmod');
    _malloc = _lib.lookupFunction<_MallocC, _MallocD>('malloc');
    _free = _lib.lookupFunction<_FreeC, _FreeD>('free');
    final errnoSymbol = Platform.isAndroid
        ? '__errno'
        : Platform.isMacOS
        ? '__error'
        : '__errno_location';
    _errno = _lib.lookupFunction<_ErrnoC, _ErrnoD>(errnoSymbol);
    _fstat = _lib.lookupFunction<_FstatC, _FstatD>('fstat');
    _getuid = _lib.lookupFunction<_GetuidC, _GetuidD>('geteuid');
  }

  final Directory directory;

  /// Android's supported native no-replace entry point requires API 30.
  /// This is a capability guard, not proof of a particular filesystem.
  static void requireAndroidApi(int sdkInt) {
    if (sdkInt < 30) {
      throw UnsupportedError(
        'atomic no-replace checkpoint requires Android API 30+',
      );
    }
  }

  late final DynamicLibrary _lib;
  late final _OpenD _open;
  late final _OpenAtD _openat;
  late final _RenameAtD _renameat;
  late final _IoD _read;
  late final _IoD _write;
  late final _FdD _fsync;
  late final _FdD _close;
  late final _ChmodD _fchmod;
  late final _MallocD _malloc;
  late final _FreeD _free;
  late final _ErrnoD _errno;
  late final _FstatD _fstat;
  late final _GetuidD _getuid;

  // Linux (x86_64 and aarch64) and Android share the kernel UAPI flag values;
  // Darwin differs. Unknown platforms never reach this store.
  int get _directoryFlag => Platform.isMacOS ? 0x100000 : 0x10000;
  int get _noFollow => Platform.isMacOS ? 0x100 : 0x20000;
  int get _nonblock => Platform.isMacOS ? 0x4 : 0x800;
  int get _createExclusive => Platform.isMacOS ? 0xa00 : 0xc0;
  int get _renameNoReplace => Platform.isMacOS ? 4 : 1;
  static const int _einval = 22; // EINVAL on Darwin and Linux alike.

  Pointer<Uint8> _cstring(String value) {
    final bytes = utf8.encode(value);
    if (bytes.contains(0)) throw ArgumentError('NUL path');
    final ptr = _malloc(bytes.length + 1);
    if (ptr == nullptr) throw StateError('allocation failed');
    ptr.asTypedList(bytes.length + 1).setAll(0, [...bytes, 0]);
    return ptr;
  }

  void _name(String name) {
    if (!RegExp(r'^[A-Za-z0-9_.-]{1,220}$').hasMatch(name) ||
        name == '.' ||
        name == '..') {
      throw ArgumentError('invalid checkpoint name');
    }
  }

  int _directory() {
    final ptr = _cstring(directory.absolute.path);
    try {
      var fd = _open(ptr, _directoryFlag | _noFollow, 0);
      if (fd < 0 && _errno().value == _einval) {
        // Some kernels reject the O_DIRECTORY bit outright. The directory
        // type is still enforced by _checkFd below, so retry without it.
        fd = _open(ptr, _noFollow, 0);
      }
      if (fd < 0) {
        throw StateError(
          'cannot open checkpoint directory safely '
          '(errno ${_errno().value})',
        );
      }
      try {
        _checkFd(fd, directory: true);
      } catch (_) {
        _close(fd);
        rethrow;
      }
      return fd;
    } finally {
      _free(ptr);
    }
  }

  (int, int) _checkFd(int fd, {required bool directory}) {
    // Restricted to three 64-bit stat layouts, all with st_ino u64 at 8:
    //  Darwin: st_mode u16@4, st_nlink u16@6, st_uid u32@16, st_dev u32@0.
    //  glibc x86_64: st_nlink u64@16, st_mode u32@24, st_uid u32@28, st_dev u64@0.
    //  Kernel asm-generic 64-bit (Android bionic, glibc arm64/riscv64):
    //    st_mode u32@16, st_nlink u32@20, st_uid u32@24, st_dev u64@0.
    // Other ABIs never reach this store (fail closed in the constructor).
    final darwin = Platform.isMacOS;
    final glibcX64 =
        !darwin && !Platform.isAndroid && Abi.current() == Abi.linuxX64;
    final ptr = _malloc(256);
    if (ptr == nullptr) throw StateError('allocation failed');
    try {
      if (_fstat(fd, ptr) != 0) throw StateError('checkpoint fstat failed');
      final view = ByteData.sublistView(ptr.asTypedList(256));
      final mode = darwin
          ? view.getUint16(4, Endian.host)
          : view.getUint32(glibcX64 ? 24 : 16, Endian.host);
      final links = darwin
          ? view.getUint16(6, Endian.host)
          : glibcX64
          ? view.getUint64(16, Endian.host)
          : view.getUint32(20, Endian.host);
      final owner = view.getUint32(
        darwin
            ? 16
            : glibcX64
            ? 28
            : 24,
        Endian.host,
      );
      // Files must be owner-only 0600 (fchmod enforces this before data is
      // written). The root directory is app-provided, so only writable group
      // or other bits are rejected: private app dirs (0700) and POSIX temp
      // dirs (0755) pass, shared writable dirs fail.
      final forbidden = directory
          ? 0x12
          : 0x3f; // 0x12 = group/other write bits
      if (owner != _getuid() ||
          (mode & 0xf000) != (directory ? 0x4000 : 0x8000) ||
          (mode & forbidden) != 0 ||
          (!directory && links != 1)) {
        throw StateError(
          'checkpoint owner, type, permissions or links invalid',
        );
      }
      final dev = darwin
          ? view.getUint32(0, Endian.host)
          : view.getUint64(0, Endian.host);
      return (dev, view.getUint64(8, Endian.host));
    } finally {
      _free(ptr);
    }
  }

  void _checkPathBinding(int dir, Pointer<Uint8> name, int original) {
    final current = _openat(dir, name, _noFollow | _nonblock, 0);
    if (current < 0) throw StateError('checkpoint path changed');
    try {
      if (_checkFd(original, directory: false) !=
          _checkFd(current, directory: false)) {
        throw StateError('checkpoint path inode changed');
      }
    } finally {
      _close(current);
    }
  }

  Uint8List? read(String name, {void Function()? afterReadForTest}) {
    _name(name);
    final dir = _directory();
    final target = _cstring(name);
    try {
      final value = _readTarget(
        dir,
        target,
        afterReadForTest: afterReadForTest,
      );
      if (value != null && _fsync(dir) != 0) {
        throw StateError('checkpoint directory fsync unknown');
      }
      return value;
    } finally {
      _free(target);
      _close(dir);
    }
  }

  /// Atomically create [name], or reconcile an identical existing checkpoint.
  /// An ambiguous failure is surfaced; no pre-existing file is removed.
  void publish(String name, Uint8List bytes) {
    _name(name);
    if (bytes.isEmpty || bytes.length > 65536) {
      throw ArgumentError('checkpoint size');
    }
    final dir = _directory();
    final random = Random.secure();
    final suffix = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final tmp = _cstring('.v5-checkpoint-$suffix.tmp');
    final target = _cstring(name);
    var fd = -1;
    try {
      fd = _openat(dir, tmp, 1 | _createExclusive | _noFollow, 0);
      if (fd < 0) {
        throw StateError('cannot create exclusive checkpoint temporary');
      }
      if (_fchmod(fd, 0x180) != 0) {
        // 0600, before writing any data
        throw StateError('cannot restrict checkpoint permissions');
      }
      _checkFd(fd, directory: false);
      final buf = _malloc(bytes.length);
      if (buf == nullptr) throw StateError('allocation failed');
      try {
        buf.asTypedList(bytes.length).setAll(0, bytes);
        var offset = 0;
        while (offset < bytes.length) {
          final n = _write(fd, buf + offset, bytes.length - offset);
          if (n <= 0) throw StateError('checkpoint write failed');
          offset += n;
        }
      } finally {
        _free(buf);
      }
      if (_fsync(fd) != 0) throw StateError('checkpoint file fsync failed');
      final closeResult = _close(fd);
      fd = -1;
      if (closeResult != 0) throw StateError('checkpoint file close failed');
      if (_renameat(dir, tmp, dir, target, _renameNoReplace) != 0 &&
          _errno().value != 17) {
        // EEXIST: reconciliation only
        throw StateError('checkpoint atomic rename failed or is unsupported');
      }
      // A crash may have occurred after publishing. Only identical bytes
      // reconcile; absent, unsafe or different destinations fail closed.
      final existing = _readTarget(dir, target);
      if (existing == null || !_equal(existing, bytes)) {
        throw StateError('checkpoint publish conflict or unknown outcome');
      }
      if (_fsync(dir) != 0) {
        throw StateError('checkpoint directory fsync unknown');
      }
    } finally {
      if (fd >= 0) _close(fd);
      _free(tmp);
      _free(target);
      _close(dir);
    }
  }

  Uint8List? _readTarget(
    int dir,
    Pointer<Uint8> name, {
    void Function()? afterReadForTest,
  }) {
    final fd = _openat(dir, name, _noFollow | _nonblock, 0);
    if (fd < 0) {
      if (_errno().value == 2) return null; // ENOENT
      throw StateError(
        'cannot open checkpoint safely: errno ${_errno().value}',
      );
    }
    try {
      _checkFd(fd, directory: false);
      _checkPathBinding(dir, name, fd);
    } catch (_) {
      _close(fd);
      rethrow;
    }
    final buf = _malloc(65537);
    if (buf == nullptr) {
      _close(fd);
      throw StateError('allocation failed');
    }
    try {
      var count = 0;
      while (count < 65537) {
        final n = _read(fd, buf + count, 65537 - count);
        if (n < 0) throw StateError('checkpoint reconciliation read failed');
        if (n == 0) break;
        count += n;
      }
      if (count > 65536) throw StateError('checkpoint too large');
      if (_fsync(fd) != 0) throw StateError('checkpoint file fsync unknown');
      afterReadForTest?.call();
      _checkFd(fd, directory: false);
      _checkPathBinding(dir, name, fd);
      return Uint8List.fromList(buf.asTypedList(count));
    } finally {
      _free(buf);
      _close(fd);
    }
  }

  bool _equal(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
