import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 切り取り枠（元画像のピクセル座標）
class PixelRect {
  const PixelRect(this.left, this.top, this.right, this.bottom);

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => math.max(1, right - left);
  double get height => math.max(1, bottom - top);

  PixelRect clampTo(int w, int h) {
    double l = left, t = top, r = right, b = bottom;
    if (r < l) {
      final tmp = l;
      l = r;
      r = tmp;
    }
    if (b < t) {
      final tmp = t;
      t = b;
      b = tmp;
    }
    l = l.clamp(0, w.toDouble());
    t = t.clamp(0, h.toDouble());
    r = r.clamp(0, w.toDouble());
    b = b.clamp(0, h.toDouble());
    // 最低 8px は確保
    if (r - l < 8) r = math.min(w.toDouble(), l + 8);
    if (b - t < 8) b = math.min(h.toDouble(), t + 8);
    if (r - l < 8) l = math.max(0, r - 8);
    if (b - t < 8) t = math.max(0, b - 8);
    return PixelRect(l, t, r, b);
  }

  static PixelRect fromLTRB(double l, double t, double r, double b) =>
      PixelRect(l, t, r, b);

  PixelRect copyWith({
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) =>
      PixelRect(
        left ?? this.left,
        top ?? this.top,
        right ?? this.right,
        bottom ?? this.bottom,
      );

  /// 左右・上下が入れ替わった枠を正しい向きに戻す。
  ///
  /// 端を反対側まで引き抜いたときに、幅が負のままにならないようにする。
  PixelRect normalized() => PixelRect(
        math.min(left, right),
        math.min(top, bottom),
        math.max(left, right),
        math.max(top, bottom),
      );

  @override
  String toString() =>
      'PixelRect($left, $top, $right, $bottom)';
}

/// 画像処理の設定
class GlyphExtractOptions {
  const GlyphExtractOptions({
    this.makeTransparent = false,
    this.autoTrim = true,
    this.threshold = 0, // 0 = 自動
  });

  /// 用紙の背景を透過するか（切り抜き）
  final bool makeTransparent;

  /// 余白を自動調整するか
  final bool autoTrim;

  /// 透過の閾値（0 なら自動）
  final int threshold;

  GlyphExtractOptions copyWith({
    bool? makeTransparent,
    bool? autoTrim,
    int? threshold,
  }) =>
      GlyphExtractOptions(
        makeTransparent: makeTransparent ?? this.makeTransparent,
        autoTrim: autoTrim ?? this.autoTrim,
        threshold: threshold ?? this.threshold,
      );
}

/// 字形の抽出結果
class GlyphExtractResult {
  const GlyphExtractResult({required this.png, required this.width, required this.height});

  final Uint8List png;
  final int width;
  final int height;
}

/// 墨（かいがね）の濃さから字の範囲を推定する。
class InkDetector {
  /// 縮小したグレースケールから、墨の塊（＝字）を囲む矩形を返す。
  ///
  /// 大きな写真でも固まらないよう、まず長辺 400px 程度に縮小して走査する。
  static PixelRect? detectFromImage(img.Image source) {
    final src = _toGrayscalePreview(source, maxSide: 400);
    final w = src.width;
    final h = src.height;
    if (w < 8 || h < 8) return null;

    final gray = Uint8List(w * h);
    int sum = 0;
    int countLight = 0;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p = src.getPixel(x, y);
        // 輝度（0=黒, 255=白）
        final g = (p.r.toDouble() * 0.299 + p.g.toDouble() * 0.587 + p.b.toDouble() * 0.114)
            .round()
            .clamp(0, 255);
        gray[y * w + x] = g;
        sum += g;
      }
    }
    final mean = sum / (w * h);

    // 和紙のような明るい地を想定。地の明るさから閾値を決める。
    // 地が暗い（写真が暗い）場合も破綻しないよう範囲を限定する。
    final background = mean.clamp(60.0, 255.0);
    final threshold = (background * 0.72).clamp(40.0, 190.0);

    int minX = w, minY = h, maxX = -1, maxY = -1;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        if (gray[y * w + x] < threshold) {
          countLight++;
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX < 0 || countLight < 12) return null;

    // 極端に小さいノイズは無視（面積比）
    final area = (maxX - minX + 1) * (maxY - minY + 1);
    if (area < 16) return null;

    // プレビュー座標 → 元画像座標
    final scaleX = source.width / w;
    final scaleY = source.height / h;

    // 字の外側に少し余白を付ける（字が切れないように）
    double l = minX * scaleX;
    double t = minY * scaleY;
    double r = (maxX + 1) * scaleX;
    double b = (maxY + 1) * scaleY;
    final padX = (r - l) * 0.10;
    final padY = (b - t) * 0.10;
    l -= padX;
    t -= padY;
    r += padX;
    b += padY;

    return PixelRect(l, t, r, b).clampTo(source.width, source.height);
  }

  static img.Image _toGrayscalePreview(img.Image source, {required int maxSide}) {
    final longSide = math.max(source.width, source.height);
    if (longSide <= maxSide) return source;
    final scale = maxSide / longSide;
    return img.copyResize(
      source,
      width: (source.width * scale).round().clamp(1, maxSide),
      height: (source.height * scale).round().clamp(1, maxSide),
      interpolation: img.Interpolation.average,
    );
  }
}

/// 実際に字形を切り出して PNG を作る。
class GlyphExtractor {
  /// 切り取り →（必要なら）透過 →（必要なら）余白調整 → 縮小 → PNG
  static GlyphExtractResult extract(
    img.Image source,
    PixelRect rect, {
    required GlyphExtractOptions options,
    int maxOutputSide = 900,
  }) {
    final r = rect.clampTo(source.width, source.height);
    final x = r.left.round().clamp(0, math.max(0, source.width - 1)).toInt();
    final y = r.top.round().clamp(0, math.max(0, source.height - 1)).toInt();
    final w = r.width.round().clamp(1, source.width - x).toInt();
    final h = r.height.round().clamp(1, source.height - y).toInt();

    var out = img.copyCrop(source, x: x, y: y, width: w, height: h);

    if (options.makeTransparent) {
      out = _applyTransparency(out, options.threshold);
    }

    if (options.autoTrim) {
      final trimmed = _autoTrim(out);
      if (trimmed != null) out = trimmed;
    }

    // 大きすぎる画像は縮小（保存容量と一覧表示の軽さのため）
    final longSide = math.max(out.width, out.height);
    if (longSide > maxOutputSide) {
      final scale = maxOutputSide / longSide;
      out = img.copyResize(
        out,
        width: math.max(1, (out.width * scale).round()),
        height: math.max(1, (out.height * scale).round()),
        interpolation: img.Interpolation.average,
      );
    }

    final png = img.encodePng(out, level: 6);
    return GlyphExtractResult(png: png, width: out.width, height: out.height);
  }

  /// 用紙の地色を透明に置き換える。
  ///
  /// 墨の濃さに応じてアルファを残すことで、輪郭がぎざぎざにならず、
  /// 薄いかすれも表現できる。
  static img.Image _applyTransparency(img.Image src, int threshold) {
    final w = src.width;
    final h = src.height;

    // 周辺（四辺）の平均輝度を「紙の色」とみなす
    double paperLum = 235;
    {
      int sum = 0, n = 0;
      void scan(int x0, int y0, int x1, int y1) {
        for (int y = y0; y < y1; y++) {
          for (int x = x0; x < x1; x++) {
            final p = src.getPixel(x, y);
            sum += (p.r * 0.299 + p.g * 0.587 + p.b * 0.114).round();
            n++;
          }
        }
      }

      final band = math.max(1, math.min(w, h) ~/ 12);
      scan(0, 0, w, band);
      scan(0, h - band, w, h);
      scan(0, 0, band, h);
      scan(w - band, 0, w, h);
      if (n > 0) paperLum = sum / n;
    }

    // 閾値: 指定があればそれ、なければ紙の明るさから自動決定
    final thr = threshold > 0 ? threshold.toDouble() : (paperLum * 0.86).clamp(60.0, 235.0);
    // ソフトエッジの幅
    final band = math.max(8.0, (255 - thr) * 0.28);

    final out = img.Image(width: w, height: h, numChannels: 4);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p = src.getPixel(x, y);
        final r = p.r.toDouble();
        final g = p.g.toDouble();
        final b = p.b.toDouble();
        final lum = r * 0.299 + g * 0.587 + b * 0.114;

        double alpha;
        if (lum <= thr - band) {
          alpha = 1.0; // 墨
        } else if (lum >= thr + band) {
          alpha = 0.0; // 紙
        } else {
          alpha = (thr + band - lum) / (2 * band); // かすれ
        }

        if (alpha <= 0.01) {
          out.setPixelRgba(x, y, 0, 0, 0, 0);
        } else {
          // 墨の色はそのまま残し、アルファだけを落とす。
          // どの背景に置いても縁が自然に見える（非乗算アルファ）。
          out.setPixelRgba(
            x,
            y,
            r.round().clamp(0, 255).toInt(),
            g.round().clamp(0, 255).toInt(),
            b.round().clamp(0, 255).toInt(),
            (alpha * 255).round().clamp(0, 255).toInt(),
          );
        }
      }
    }
    return out;
  }

  /// 余白を自動調整（周囲の余白を詰める）
  static img.Image? _autoTrim(img.Image src) {
    final w = src.width;
    final h = src.height;
    if (w < 4 || h < 4) return null;

    final hasAlpha = src.numChannels == 4;

    bool isInk(int x, int y) {
      final p = src.getPixel(x, y);
      if (hasAlpha) {
        if (p.a < 24) return false;
        final lum = p.r * 0.299 + p.g * 0.587 + p.b * 0.114;
        return lum < 235;
      }
      final lum = p.r * 0.299 + p.g * 0.587 + p.b * 0.114;
      return lum < 200;
    }

    int minX = w, minY = h, maxX = -1, maxY = -1;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        if (isInk(x, y)) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (maxX < 0) return null;

    // 字の周囲に均等な余白（字の大きさの 6%）を付ける
    final cw = maxX - minX + 1;
    final ch = maxY - minY + 1;
    final pad = math.max(4, (math.max(cw, ch) * 0.06).round());

    final left = (minX - pad).clamp(0, w - 1);
    final top = (minY - pad).clamp(0, h - 1);
    final right = (maxX + pad).clamp(left, w - 1);
    final bottom = (maxY + pad).clamp(top, h - 1);

    if (right - left < 4 || bottom - top < 4) return null;
    return img.copyCrop(
      src,
      x: left,
      y: top,
      width: right - left + 1,
      height: bottom - top + 1,
    );
  }
}

/// 切り取り処理を非同期で行う薄いラッパ。
///
/// 処理の前に 1 フレーム分だけイベントループへ返し、画面に進捗を描かせる。
/// （大きな写真でも「フリーズした」と感じさせないため）
class GlyphExtractorAsync {
  GlyphExtractorAsync._();

  static Future<GlyphExtractResult> extract(
    img.Image source,
    PixelRect rect, {
    required GlyphExtractOptions options,
  }) async {
    await Future<void>.delayed(Duration.zero);
    return GlyphExtractor.extract(source, rect, options: options);
  }
}
