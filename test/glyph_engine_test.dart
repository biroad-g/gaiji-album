import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:flutter_app/services/glyph_engine.dart';
import 'package:flutter_app/services/image_pipeline.dart';

/// テスト用: 和紙色の地に黒い四角（＝字の代わり）を描いた画像
img.Image _fakeGlyphPage({int width = 600, int height = 600}) {
  final image = img.Image(width: width, height: height, numChannels: 3);
  img.fill(image, color: img.ColorRgb8(245, 241, 232));
  // 中央に「字」に見立てた黒い塊
  final left = (width * 0.30).round();
  final top = (height * 0.25).round();
  final w = (width * 0.40).round();
  final h = (height * 0.50).round();
  img.fillRect(
    image,
    x1: left,
    y1: top,
    x2: left + w,
    y2: top + h,
    color: img.ColorRgb8(20, 18, 16),
  );
  return image;
}

void main() {
  group('InkDetector', () {
    test('墨の塊を囲む枠を返す', () {
      final page = _fakeGlyphPage();
      final rect = InkDetector.detectFromImage(page);

      expect(rect, isNotNull);
      // 黒い塊（中央 30%〜70% / 25%〜75%）を含んでいること
      expect(rect!.left, lessThan(page.width * 0.35));
      expect(rect.right, greaterThan(page.width * 0.65));
      expect(rect.top, lessThan(page.height * 0.30));
      expect(rect.bottom, greaterThan(page.height * 0.70));
    });

    test('真っ白な画像では検出しない（枠は呼び出し側で既定値を決める）', () {
      final blank = img.Image(width: 300, height: 300, numChannels: 3);
      img.fill(blank, color: img.ColorRgb8(252, 250, 245));
      expect(InkDetector.detectFromImage(blank), isNull);
    });

    test('大きな画像でも処理できる', () {
      final big = _fakeGlyphPage(width: 3000, height: 4000);
      final rect = InkDetector.detectFromImage(big);
      expect(rect, isNotNull);
      expect(rect!.width, greaterThan(0));
    });
  });

  group('GlyphExtractor', () {
    test('切り取ると PNG ができる', () {
      final page = _fakeGlyphPage();
      const rect = PixelRect(150, 120, 450, 480);
      final result = GlyphExtractor.extract(
        page,
        rect,
        options: const GlyphExtractOptions(),
      );

      expect(result.png, isNotEmpty);
      // PNG のシグネチャ
      expect(result.png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      // 元の範囲を超えない
      expect(result.width, lessThanOrEqualTo(300));
      expect(result.height, lessThanOrEqualTo(360));
    });

    test('透過を選ぶとアルファ付き PNG になる', () {
      final page = _fakeGlyphPage();
      const rect = PixelRect(150, 120, 450, 480);
      final result = GlyphExtractor.extract(
        page,
        rect,
        options: const GlyphExtractOptions(
          makeTransparent: true,
          autoTrim: false,
        ),
      );
      final decoded = img.decodePng(result.png);
      expect(decoded, isNotNull);
      expect(decoded!.numChannels, 4);

      // 四隅（紙の部分）は透明
      final corner = decoded.getPixel(1, 1);
      expect(corner.a, 0);
    });

    test('余白の自動調整で周囲が詰められる', () {
      final page = _fakeGlyphPage();
      // 余白を大きく含む枠
      const rect = PixelRect(60, 60, 540, 540);
      final trimmed = GlyphExtractor.extract(
        page,
        rect,
        options: const GlyphExtractOptions(autoTrim: true),
      );
      final kept = GlyphExtractor.extract(
        page,
        rect,
        options: const GlyphExtractOptions(autoTrim: false),
      );

      expect(trimmed.width, lessThan(kept.width));
      expect(trimmed.height, lessThan(kept.height));
    });

    test('枠が画像の外にはみ出しても壊れない', () {
      final page = _fakeGlyphPage();
      const rect = PixelRect(-100, -100, 5000, 5000);
      final result = GlyphExtractor.extract(
        page,
        rect,
        options: const GlyphExtractOptions(),
      );
      expect(result.png, isNotEmpty);
    });

    test('大きすぎる結果は縮小される', () {
      final page = _fakeGlyphPage(width: 2400, height: 2400);
      const rect = PixelRect(0, 0, 2400, 2400);
      final result = GlyphExtractor.extract(
        page,
        rect,
        options: const GlyphExtractOptions(autoTrim: false),
      );
      expect(result.width, lessThanOrEqualTo(900));
      expect(result.height, lessThanOrEqualTo(900));
    });
  });

  group('ImagePipeline', () {
    test('空のデータは日本語の理由つきで失敗する', () async {
      expect(
        () => ImagePipeline.decodeAsync(Uint8List(0)),
        throwsA(
          isA<ImagePipelineException>().having(
            (e) => e.message,
            'message',
            contains('画像データが空でした'),
          ),
        ),
      );
    });

    test('画像でないデータは日本語の理由つきで失敗する', () async {
      expect(
        () => ImagePipeline.decodeAsync(Uint8List.fromList([1, 2, 3, 4, 5])),
        throwsA(
          isA<ImagePipelineException>().having(
            (e) => e.message,
            'message',
            contains('画像を読み込めませんでした'),
          ),
        ),
      );
    });

    test('大きい画像は長辺の上限まで縮小される', () async {
      final large = _fakeGlyphPage(width: 3000, height: 2000);
      final small = await ImagePipeline.downscaleAsync(large, maxSide: 1200);
      expect(small.width, 1200);
      expect(small.height, 800);
    });

    test('上限より小さい画像はそのまま返す', () async {
      final small = _fakeGlyphPage(width: 400, height: 300);
      final same = await ImagePipeline.downscaleAsync(small, maxSide: 1200);
      expect(same.width, 400);
    });
  });
}
