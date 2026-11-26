import 'dart:async';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 画像の読み込み・縮小・エンコードをまとめて受け持つ。
///
/// 失敗したときは必ず日本語の理由を持つ [ImagePipelineException] を投げる。
/// 呼び出し側は無反応にならず、理由を画面に出す。
class ImagePipelineException implements Exception {
  const ImagePipelineException(this.message, {this.detail});

  /// 利用者にそのまま見せる日本語のメッセージ
  final String message;

  /// 開発時の手がかり（画面には出さない）
  final String? detail;

  @override
  String toString() => message;
}

class ImagePipeline {
  ImagePipeline._();

  /// 長辺の上限（保存用）
  static const int maxOriginalSide = 1800;

  /// 元写真として保存する JPEG の品質
  static const int originalJpegQuality = 82;

  /// 画像バイト列をデコードする（重い処理）。
  static Future<img.Image> decodeAsync(Uint8List bytes) async {
    if (bytes.isEmpty) {
      throw const ImagePipelineException(
        '画像データが空でした。撮影または選択をもう一度お試しください。',
      );
    }
    img.Image? decoded;
    try {
      // decodeImage は同期処理なので、イベントループに一度返してから実行する
      await Future<void>.delayed(Duration.zero);
      decoded = img.decodeImage(bytes);
    } catch (e) {
      throw ImagePipelineException(
        '画像を読み込めませんでした。対応していない形式か、ファイルが壊れている可能性があります。',
        detail: '$e',
      );
    }
    if (decoded == null) {
      throw const ImagePipelineException(
        '画像を読み込めませんでした。対応していない形式か、ファイルが壊れている可能性があります。',
      );
    }
    // スマホ写真の向き（EXIF）を反映して、表示と一致させる
    try {
      return img.bakeOrientation(decoded);
    } catch (_) {
      // 向き情報が壊れていても画像自体は使える
      return decoded;
    }
  }

  /// 長辺が上限を超える場合だけ縮小する（拡大はしない）。
  static Future<img.Image> downscaleAsync(
    img.Image source, {
    int maxSide = maxOriginalSide,
  }) async {
    final longSide = source.width > source.height ? source.width : source.height;
    if (longSide <= maxSide) return source;
    await Future<void>.delayed(Duration.zero);
    final scale = maxSide / longSide;
    return img.copyResize(
      source,
      width: (source.width * scale).round().clamp(1, maxSide),
      height: (source.height * scale).round().clamp(1, maxSide),
      interpolation: img.Interpolation.average,
    );
  }

  /// 元写真を保存用 JPEG に変換する。
  static Future<Uint8List> encodeOriginalAsync(img.Image source) async {
    final small = await downscaleAsync(source);
    await Future<void>.delayed(Duration.zero);
    try {
      return Uint8List.fromList(
        img.encodeJpg(small, quality: originalJpegQuality),
      );
    } catch (e) {
      throw ImagePipelineException(
        '写真を保存用に変換できませんでした。端末の空き容量を確認してください。',
        detail: '$e',
      );
    }
  }

  /// 書き出し用 PNG を作る（等倍）。
  static Future<Uint8List> pngFromImageAsync(img.Image source) async {
    await Future<void>.delayed(Duration.zero);
    try {
      return Uint8List.fromList(img.encodePng(source, level: 6));
    } catch (e) {
      throw ImagePipelineException(
        'PNG を作成できませんでした。端末の空き容量を確認してください。',
        detail: '$e',
      );
    }
  }
}
