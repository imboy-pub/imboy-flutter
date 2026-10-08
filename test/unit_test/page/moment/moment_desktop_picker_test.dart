import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/upload/batch_upload_controller.dart';
import 'package:imboy/page/moment/moment_desktop_picker.dart';
import 'package:imboy/page/moment/moment_interactions.dart';

void main() {
  PlatformFile media(String name) => _MediaFile(name);

  test('desktop accepts nine images but rejects ten', () {
    expect(
      validateMomentFiles([], List.generate(9, (_) => media('a.jpg'))).ok,
      isTrue,
    );
    expect(
      validateMomentFiles([], List.generate(10, (_) => media('a.jpg'))).error,
      momentMediaErrorTooManyImages,
    );
  });

  test('desktop video extension matching ignores case', () {
    expect(momentFileIsVideo(media('clip.MOV')), isTrue);
    expect(momentFileIsVideo(media('photo.jpg')), isFalse);
  });

  test('desktop rejects mixed images and video and multiple videos', () {
    expect(
      validateMomentFiles([], [media('a.jpg'), media('v.mp4')]).error,
      momentMediaErrorMixed,
    );
    expect(
      validateMomentFiles([], [media('a.mp4'), media('b.mov')]).error,
      momentMediaErrorTooManyVideos,
    );
  });

  test('failed or pending existing video still excludes selected images', () {
    final existing = [
      UploadItem<Map<String, dynamic>>(id: 1, isVideoFile: true),
    ];
    expect(
      validateMomentFiles(existing, [media('a.jpg')]).error,
      momentMediaErrorMixed,
    );
  });
}

final class _MediaFile extends PlatformFile {
  _MediaFile(this.name);
  @override
  final String name;
  @override
  String get extension => name.split('.').last;
  @override
  String get path => '/tmp/$name';
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Only media name, extension and path are used');
}
