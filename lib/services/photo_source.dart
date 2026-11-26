import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'image_pipeline.dart';

/// 写真の入手結果
class PickedPhoto {
  const PickedPhoto(this.bytes, {this.fromCamera = false});

  final Uint8List bytes;
  final bool fromCamera;
}

/// カメラ撮影・端末の写真読み込み。
///
/// 失敗は必ず日本語の理由にして返す（無反応にしない）。
class PhotoSource {
  PhotoSource._();

  static final ImagePicker _picker = ImagePicker();

  static Future<PickedPhoto> fromCamera() => _pick(ImageSource.camera, true);

  static Future<PickedPhoto> fromGallery() => _pick(ImageSource.gallery, false);

  static Future<PickedPhoto> _pick(ImageSource source, bool camera) async {
    XFile? file;
    try {
      file = await _picker.pickImage(
        source: source,
        // 大きな写真は最初から縮小して受け取る（端末が固まるのを防ぐ）
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 92,
        preferredCameraDevice: CameraDevice.rear,
      );
    } catch (e) {
      throw ImagePipelineException(
        camera
            ? 'カメラを起動できませんでした。設定でカメラの使用を許可しているかご確認ください。'
            : '写真を開けませんでした。端末の写真へのアクセスを許可しているかご確認ください。',
        detail: '$e',
      );
    }

    if (file == null) {
      // 利用者がキャンセルした場合。空のバイト列で「中止」を伝える。
      return PickedPhoto(Uint8List(0));
    }

    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (e) {
      throw ImagePipelineException(
        '選んだ写真を読み込めませんでした。別の写真でお試しください。',
        detail: '$e',
      );
    }
    if (bytes.isEmpty) {
      throw ImagePipelineException(
        camera
            ? 'カメラの映像を受け取れませんでした。もう一度撮影してください。'
            : '選んだ写真が空でした。別の写真でお試しください。',
      );
    }
    if (kDebugMode) {
      debugPrint('picked photo: ${bytes.length} bytes (camera=$camera)');
    }
    return PickedPhoto(bytes, fromCamera: camera);
  }

  /// カメラが使える端末か（Web では環境により使えないことがある）
  static bool get supportsCamera => true;
}
