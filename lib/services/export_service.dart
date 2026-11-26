import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'image_pipeline.dart';

/// PNG の書き出しと共有。
///
/// 失敗は必ず日本語の理由にして返す（無反応にしない）。
class ExportService {
  ExportService._();

  /// 表示用のファイル名を作る（例: 外字_𠮷_20260118.png）
  static String fileNameFor(String name, {String ext = 'png'}) {
    final safe = name
        .replaceAll(RegExp(r'[\\/:*?"<>|\s]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final now = DateTime.now();
    final stamp = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final base = safe.isEmpty ? '外字' : safe;
    return '外字_${base}_$stamp.$ext';
  }

  /// 端末の共有シートで PNG を共有する。戻り値は保存先パス（Web では null）。
  static Future<String?> sharePng(Uint8List png, {required String name}) async {
    final fileName = fileNameFor(name);

    if (kIsWeb) {
      // Web では share_plus がダウンロードへフォールバックする
      try {
        await Share.shareXFiles(
          [XFile.fromData(png, name: fileName, mimeType: 'image/png')],
          subject: '外字 $name',
          text: '外字アルバムより書き出した字形です。',
          fileNameOverrides: [fileName],
        );
        return null;
      } catch (e) {
        throw ImagePipelineException(
          'PNG の共有に失敗しました。ブラウザのダウンロード設定をご確認ください。',
          detail: '$e',
        );
      }
    }

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(png, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png', name: fileName)],
        subject: '外字 $name',
        text: '外字アルバムより書き出した字形です。',
        fileNameOverrides: [fileName],
      );
      return file.path;
    } on ImagePipelineException {
      rethrow;
    } catch (e) {
      throw ImagePipelineException(
        'PNG の共有に失敗しました。端末の空き容量を確認して、もう一度お試しください。',
        detail: '$e',
      );
    }
  }

  /// PNG を端末（アプリの書類フォルダ）へ保存する。
  static Future<String> savePng(Uint8List png, {required String name}) async {
    final fileName = fileNameFor(name);
    if (kIsWeb) {
      // Web では共有（＝ダウンロード）に委ねる
      await sharePng(png, name: name);
      return fileName;
    }
    try {
      Directory? dir = await getApplicationDocumentsDirectory();
      final out = Directory('${dir.path}/exports');
      if (!await out.exists()) {
        await out.create(recursive: true);
      }
      final file = File('${out.path}/$fileName');
      await file.writeAsBytes(png, flush: true);
      return file.path;
    } catch (e) {
      throw ImagePipelineException(
        'PNG を保存できませんでした。端末の空き容量を確認してください。',
        detail: '$e',
      );
    }
  }
}
