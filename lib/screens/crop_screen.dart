import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../services/glyph_engine.dart';
import '../services/image_pipeline.dart';
import '../theme/app_theme.dart';

/// 切り取り結果
class CropResult {
  const CropResult({
    required this.glyphPng,
    required this.originalJpg,
    required this.options,
  });

  final Uint8List glyphPng;
  final Uint8List originalJpg;
  final GlyphExtractOptions options;
}

/// 写真の上で漢字一字を指で囲む画面。
///
/// - 墨の濃さから字を自動検出して最初から候補枠を出す
/// - 四隅と辺をドラッグして調整できる
/// - 用紙の背景の透過／余白の自動調整を選べる
/// - ページはスクロールさせない（iOS でタップ位置がずれるのを防ぐ）
class CropScreen extends StatefulWidget {
  const CropScreen({
    super.key,
    required this.photoBytes,
    this.appBarTitle = '一字を囲む',
  });

  final Uint8List photoBytes;
  final String appBarTitle;

  @override
  State<CropScreen> createState() => _CropScreenState();
}

enum _Handle {
  none,
  move,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  top,
  bottom,
  left,
  right,
}

class _CropScreenState extends State<CropScreen> {
  img.Image? _image;
  ui.Image? _display;
  String? _loadError;
  bool _loading = true;
  bool _busy = false;
  String _busyMessage = '';

  PixelRect? _rect;
  GlyphExtractOptions _options = const GlyphExtractOptions();

  _Handle _active = _Handle.none;
  PixelRect? _rectAtDragStart;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _display?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final decoded = await ImagePipeline.decodeAsync(widget.photoBytes);
      // 重い処理の前に一度描画させる（「読み込んでいます…」を見せる）
      await Future<void>.delayed(Duration.zero);

      PixelRect? guess;
      try {
        guess = InkDetector.detectFromImage(decoded);
      } catch (_) {
        guess = null;
      }
      guess ??= PixelRect(
        decoded.width * 0.18,
        decoded.height * 0.18,
        decoded.width * 0.82,
        decoded.height * 0.82,
      );

      // 画面表示用の縮小画像（描画を軽くする）
      final preview = await ImagePipeline.downscaleAsync(decoded, maxSide: 1400);
      await Future<void>.delayed(Duration.zero);
      final display = await _toUiImage(preview);

      if (!mounted) {
        display.dispose();
        return;
      }
      _display?.dispose();
      setState(() {
        _image = decoded;
        _display = display;
        _rect = guess!.clampTo(decoded.width, decoded.height);
        _loading = false;
      });
    } on ImagePipelineException catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail('写真を読み込めませんでした。もう一度お試しください。');
    }
  }

  Future<ui.Image> _toUiImage(img.Image source) async {
    final png = await ImagePipeline.pngFromImageAsync(source);
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _loadError = message;
      _loading = false;
      _busy = false;
    });
  }

  Future<void> _confirm() async {
    final image = _image;
    final rect = _rect;
    if (image == null || rect == null) return;

    setState(() {
      _busy = true;
      _busyMessage = '字形を切り取っています…';
    });
    await Future<void>.delayed(const Duration(milliseconds: 60));

    try {
      final result = await GlyphExtractorAsync.extract(
        image,
        rect,
        options: _options,
      );
      final originalJpg = await ImagePipeline.encodeOriginalAsync(image);
      if (!mounted) return;
      Navigator.of(context).pop(
        CropResult(
          glyphPng: result.png,
          originalJpg: originalJpg,
          options: _options,
        ),
      );
    } on ImagePipelineException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('字形を切り取れませんでした。端末の空き容量を確認して、もう一度お試しください。');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 16)),
        backgroundColor: AppColors.caution,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141210),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141210),
        foregroundColor: AppColors.paper,
        elevation: 0,
        title: Text(
          widget.appBarTitle,
          style: const TextStyle(
            fontFamily: AppText.serif,
            fontSize: 20,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(child: _buildCanvas()),
                _buildControls(),
              ],
            ),
            if (_busy) _buildBusyOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    if (_loading) return _buildLoading('写真を読み込んでいます…');
    if (_loadError != null) return _buildErrorState(_loadError!);
    final image = _image;
    final display = _display;
    if (image == null || display == null) {
      return _buildErrorState('写真を表示できませんでした。');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final geo = _Geometry(
          imageWidth: image.width,
          imageHeight: image.height,
          area: Size(constraints.maxWidth, constraints.maxHeight),
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _onPanStart(d.localPosition, geo),
          onPanUpdate: (d) => _onPanUpdate(d.delta, geo),
          onPanEnd: (_) => _onPanEnd(),
          onPanCancel: _onPanEnd,
          child: Stack(
            children: [
              Positioned.fill(
                child: RawImage(
                  image: display,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _CropPainter(
                    geometry: geo,
                    rect: _rect,
                    activeHandle: _active,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoading(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 42,
            height: 42,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.paper,
              fontSize: 17,
              fontFamily: AppText.sans,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined, size: 52, color: AppColors.gold),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.paper,
                fontSize: 17,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.paper,
                    side: const BorderSide(color: AppColors.gold),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                  ),
                  child: const Text('戻る', style: TextStyle(fontSize: 17)),
                ),
                const SizedBox(width: 14),
                FilledButton(
                  onPressed: _load,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                  ),
                  child: const Text('もう一度読み込む', style: TextStyle(fontSize: 17)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusyOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xCC141210),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 46,
                height: 46,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _busyMessage,
                style: const TextStyle(
                  color: AppColors.paper,
                  fontSize: 18,
                  fontFamily: AppText.sans,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    final ready = _image != null && !_loading && _loadError == null;
    return Container(
      width: double.infinity,
      color: const Color(0xFF1B1815),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ready) ...[
            Text(
              '枠の四隅と辺をドラッグして、漢字一字を囲んでください。',
              style: TextStyle(
                color: AppColors.paper.withValues(alpha: 0.72),
                fontSize: 14,
                height: 1.5,
                fontFamily: AppText.sans,
              ),
            ),
            const SizedBox(height: 10),
            _ToggleRow(
              label: '用紙の背景を透過する',
              value: _options.makeTransparent,
              onChanged: (v) => setState(() {
                _options = _options.copyWith(makeTransparent: v);
              }),
            ),
            _ToggleRow(
              label: '余白を自動調整する',
              value: _options.autoTrim,
              onChanged: (v) => setState(() {
                _options = _options.copyWith(autoTrim: v);
              }),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 58,
              child: FilledButton(
                onPressed: _busy ? null : _confirm,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  'この範囲で切り取る',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ] else
            const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ---- ドラッグ操作 ----

  void _onPanStart(Offset local, _Geometry geo) {
    final rect = _rect;
    if (rect == null) return;
    setState(() {
      _active = _hitTest(local, geo, rect);
      _rectAtDragStart = rect;
    });
  }

  _Handle _hitTest(Offset local, _Geometry geo, PixelRect rect) {
    final r = geo.toDisplayRect(rect);
    const grab = 44.0; // タップ範囲は広めに

    _Handle best = _Handle.none;
    double bestDist = grab + 12;

    final corners = <_Handle, Offset>{
      _Handle.topLeft: r.topLeft,
      _Handle.topRight: r.topRight,
      _Handle.bottomLeft: r.bottomLeft,
      _Handle.bottomRight: r.bottomRight,
    };
    corners.forEach((handle, point) {
      final d = (point - local).distance;
      if (d < bestDist) {
        bestDist = d;
        best = handle;
      }
    });
    if (best != _Handle.none) return best;

    final edges = <_Handle, Offset>{
      _Handle.top: Offset(r.center.dx, r.top),
      _Handle.bottom: Offset(r.center.dx, r.bottom),
      _Handle.left: Offset(r.left, r.center.dy),
      _Handle.right: Offset(r.right, r.center.dy),
    };
    bestDist = grab + 12;
    edges.forEach((handle, point) {
      final d = (point - local).distance;
      if (d < bestDist) {
        bestDist = d;
        best = handle;
      }
    });
    if (best != _Handle.none) return best;

    if (r.contains(local)) return _Handle.move;
    return _Handle.none;
  }

  void _onPanUpdate(Offset delta, _Geometry geo) {
    final start = _rectAtDragStart;
    if (start == null || _active == _Handle.none) return;

    final d = geo.toImageDelta(delta);
    double l = start.left, t = start.top, r = start.right, b = start.bottom;

    switch (_active) {
      case _Handle.move:
        final w = r - l;
        final h = b - t;
        l = (l + d.dx).clamp(0, math.max(0, geo.imageWidth - w));
        t = (t + d.dy).clamp(0, math.max(0, geo.imageHeight - h));
        r = l + w;
        b = t + h;
        break;
      case _Handle.topLeft:
        l += d.dx;
        t += d.dy;
        break;
      case _Handle.topRight:
        r += d.dx;
        t += d.dy;
        break;
      case _Handle.bottomLeft:
        l += d.dx;
        b += d.dy;
        break;
      case _Handle.bottomRight:
        r += d.dx;
        b += d.dy;
        break;
      case _Handle.top:
        t += d.dy;
        break;
      case _Handle.bottom:
        b += d.dy;
        break;
      case _Handle.left:
        l += d.dx;
        break;
      case _Handle.right:
        r += d.dx;
        break;
      case _Handle.none:
        return;
    }

    const minSize = 12.0;
    if (r - l < minSize) {
      if (_active == _Handle.left ||
          _active == _Handle.topLeft ||
          _active == _Handle.bottomLeft) {
        l = r - minSize;
      } else {
        r = l + minSize;
      }
    }
    if (b - t < minSize) {
      if (_active == _Handle.top ||
          _active == _Handle.topLeft ||
          _active == _Handle.topRight) {
        t = b - minSize;
      } else {
        b = t + minSize;
      }
    }

    setState(() {
      _rect = PixelRect(l, t, r, b).clampTo(geo.imageWidth, geo.imageHeight);
    });
  }

  void _onPanEnd() {
    setState(() {
      _active = _Handle.none;
      _rectAtDragStart = null;
    });
  }
}

/// 画像と表示領域の対応（BoxFit.contain と同じ計算）
class _Geometry {
  _Geometry({
    required this.imageWidth,
    required this.imageHeight,
    required this.area,
  }) {
    scale = math.min(area.width / imageWidth, area.height / imageHeight);
    final w = imageWidth * scale;
    final h = imageHeight * scale;
    origin = Offset((area.width - w) / 2, (area.height - h) / 2);
  }

  final int imageWidth;
  final int imageHeight;
  final Size area;
  late final double scale;
  late final Offset origin;

  Rect toDisplayRect(PixelRect r) => Rect.fromLTRB(
        origin.dx + r.left * scale,
        origin.dy + r.top * scale,
        origin.dx + r.right * scale,
        origin.dy + r.bottom * scale,
      );

  Offset toImageDelta(Offset displayDelta) =>
      Offset(displayDelta.dx / scale, displayDelta.dy / scale);
}

class _CropPainter extends CustomPainter {
  _CropPainter({
    required this.geometry,
    required this.rect,
    required this.activeHandle,
  });

  final _Geometry geometry;
  final PixelRect? rect;
  final _Handle activeHandle;

  @override
  void paint(Canvas canvas, Size size) {
    final r = rect;
    if (r == null) return;

    final imageRect = Rect.fromLTWH(
      geometry.origin.dx,
      geometry.origin.dy,
      geometry.imageWidth * geometry.scale,
      geometry.imageHeight * geometry.scale,
    );
    final box = geometry.toDisplayRect(r);

    // 枠の外を暗くする
    final overlay = Path()
      ..addRect(imageRect)
      ..addRect(box)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(overlay, Paint()..color = const Color(0x99000000));

    // 枠線
    canvas.drawRect(
      box,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = AppColors.goldPale,
    );

    // 三分割の補助線
    final guide = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = AppColors.paper.withValues(alpha: 0.30);
    for (int i = 1; i < 3; i++) {
      final dx = box.left + box.width * i / 3;
      final dy = box.top + box.height * i / 3;
      canvas.drawLine(Offset(dx, box.top), Offset(dx, box.bottom), guide);
      canvas.drawLine(Offset(box.left, dy), Offset(box.right, dy), guide);
    }

    // 四隅の L 字
    final cornerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.square
      ..color = AppColors.goldPale;
    final len = math.min(26.0, math.min(box.width, box.height) / 3.2);
    void corner(Offset p, double sx, double sy) {
      canvas.drawLine(p, p + Offset(sx * len, 0), cornerPaint);
      canvas.drawLine(p, p + Offset(0, sy * len), cornerPaint);
    }

    corner(box.topLeft, 1, 1);
    corner(box.topRight, -1, 1);
    corner(box.bottomLeft, 1, -1);
    corner(box.bottomRight, -1, -1);

    // 辺の中央ハンドル
    final handleFill = Paint()..color = AppColors.paper;
    final handleRim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppColors.inkDeep;
    final sideHandles = <Offset>[
      Offset(box.center.dx, box.top),
      Offset(box.center.dx, box.bottom),
      Offset(box.left, box.center.dy),
      Offset(box.right, box.center.dy),
    ];
    for (final p in sideHandles) {
      canvas.drawCircle(p, 4.5, handleFill);
      canvas.drawCircle(p, 4.5, handleRim);
    }

    // ドラッグ中のハンドルを強調
    final highlight = _handlePoint(box, activeHandle);
    if (highlight != null) {
      canvas.drawCircle(
        highlight,
        16,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.paper.withValues(alpha: 0.75),
      );
    }
  }

  Offset? _handlePoint(Rect box, _Handle h) {
    switch (h) {
      case _Handle.topLeft:
        return box.topLeft;
      case _Handle.topRight:
        return box.topRight;
      case _Handle.bottomLeft:
        return box.bottomLeft;
      case _Handle.bottomRight:
        return box.bottomRight;
      case _Handle.top:
        return Offset(box.center.dx, box.top);
      case _Handle.bottom:
        return Offset(box.center.dx, box.bottom);
      case _Handle.left:
        return Offset(box.left, box.center.dy);
      case _Handle.right:
        return Offset(box.right, box.center.dy);
      case _Handle.move:
      case _Handle.none:
        return null;
    }
  }

  @override
  bool shouldRepaint(covariant _CropPainter old) =>
      old.rect != rect || old.activeHandle != activeHandle;
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.paper.withValues(alpha: 0.92),
                  fontSize: 16,
                  fontFamily: AppText.sans,
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.gold,
              inactiveThumbColor: AppColors.paperDeep,
              inactiveTrackColor: const Color(0xFF3A342E),
            ),
          ],
        ),
      ),
    );
  }
}
