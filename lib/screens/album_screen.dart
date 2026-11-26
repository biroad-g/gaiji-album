import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/gaiji.dart';
import '../state/album_store.dart';
import '../theme/app_theme.dart';
import 'capture_sheet.dart';
import 'detail_screen.dart';

/// アルバム画面（一覧）。空のときは撮影ボタンを大きく中央に出す。
class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  final _searchController = TextEditingController();
  bool _searchOpen = false;
  bool _initialized = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const CaptureSheet(),
        fullscreenDialog: true,
      ),
    );
    if (created == true && mounted) {
      // 登録完了の手応えを短く返す
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('外字を記録しました', style: TextStyle(fontSize: 16)),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AlbumStore>();
    if (!_initialized) {
      _searchController.text = store.query;
      _initialized = true;
    }

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(store),
            if (!store.isEmpty) _buildSearchAndFilter(store),
            Expanded(
              child: store.isEmpty
                  ? _buildEmptyState()
                  : store.visible.isEmpty
                      ? _buildNoResult(store)
                      : _buildGrid(store),
            ),
          ],
        ),
      ),
      floatingActionButton: store.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _capture,
              backgroundColor: AppColors.ink,
              foregroundColor: AppColors.paper,
              icon: const Icon(Icons.add_a_photo_outlined, size: 22),
              label: const Text(
                '外字を撮影',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
    );
  }

  Widget _buildHeader(AlbumStore store) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '外字アルバム',
                  style: TextStyle(
                    fontFamily: AppText.serif,
                    fontSize: 27,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    letterSpacing: 2.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  store.isEmpty
                      ? '字形を一字ずつ記録します'
                      : '${store.total} 字を記録しています',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.ink.withValues(alpha: 0.55),
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '検索',
            onPressed: () => setState(() => _searchOpen = !_searchOpen),
            icon: Icon(
              _searchOpen ? Icons.close : Icons.search,
              color: AppColors.ink.withValues(alpha: 0.7),
              size: 26,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter(AlbumStore store) {
    return Column(
      children: [
        if (_searchOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: store.setQuery,
              style: const TextStyle(
                fontSize: AppText.field,
                color: AppColors.ink,
              ),
              cursorColor: AppColors.gold,
              decoration: InputDecoration(
                hintText: '名称・読み・出典・メモで探す',
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: AppColors.ink.withValues(alpha: 0.35),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.ink.withValues(alpha: 0.45),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: AppColors.gold, width: 1.4),
                ),
              ),
            ),
          ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _filterChip(
                label: 'すべて',
                count: store.total,
                selected: store.filter == null,
                onTap: () => store.toggleFilter(null),
              ),
              ...GaijiCategory.values.map((c) {
                final count = store.counts[c] ?? 0;
                return _filterChip(
                  label: c.label,
                  count: count,
                  selected: store.filter == c,
                  onTap: () => store.toggleFilter(c),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _filterChip({
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : Colors.transparent,
            border: Border.all(
              color: selected ? AppColors.ink : AppColors.line,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: selected ? AppColors.paper : AppColors.ink,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: selected
                        ? AppColors.paper.withValues(alpha: 0.7)
                        : AppColors.ink.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SealMark(size: 92),
            const SizedBox(height: 30),
            const Text(
              'まだ記録がありません',
              style: TextStyle(
                fontFamily: AppText.serif,
                fontSize: 21,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '扁額、過去帳、版木、石塔、位牌。\n'
              '文字コードのない字も、字形として残せます。\n'
              '一字ずつ、意味を添えて記録しましょう。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.5,
                height: 1.85,
                color: AppColors.ink.withValues(alpha: 0.62),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 74,
              child: FilledButton.icon(
                onPressed: _capture,
                icon: const Icon(Icons.add_a_photo_outlined, size: 26),
                label: const Text(
                  '外字を撮影する',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: AppColors.paper,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '撮影した写真はこの端末の中だけに保存されます',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.ink.withValues(alpha: 0.42),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResult(AlbumStore store) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 46,
              color: AppColors.ink.withValues(alpha: 0.28),
            ),
            const SizedBox(height: 20),
            Text(
              '条件に合う外字が見つかりませんでした。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.7,
                color: AppColors.ink.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 22),
            OutlinedButton(
              onPressed: () {
                _searchController.clear();
                store.clearFilters();
                setState(() => _searchOpen = false);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.line),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
              child: const Text('条件を解除する', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(AlbumStore store) {
    final items = store.visible;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 620
                ? 3
                : 2;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 100),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.78,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final g = items[index];
            return _GaijiCard(
              gaiji: g,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DetailScreen(gaijiId: g.id),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _GaijiCard extends StatelessWidget {
  const _GaijiCard({required this.gaiji, required this.onTap});

  final Gaiji gaiji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: const Color(0xFFFAF7F0),
                padding: const EdgeInsets.all(8),
                child: GaijiImage(bytes: gaiji.glyphPng),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gaiji.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppText.serif,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: AppColors.paperDeep,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          gaiji.category.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.ink.withValues(alpha: 0.66),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (gaiji.reading.isNotEmpty) ...[
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            gaiji.reading,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.ink.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 字形画像を共通の見た目で表示する。
///
/// 透過 PNG でも見やすいよう、薄い和紙色の地の上に置く。
class GaijiImage extends StatelessWidget {
  const GaijiImage({
    super.key,
    required this.bytes,
    this.fit = BoxFit.contain,
    this.onDark = false,
  });

  final Uint8List bytes;
  final BoxFit fit;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Image.memory(
      bytes,
      fit: fit,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stack) => Center(
        child: Text(
          '字形を表示できません',
          style: TextStyle(
            fontSize: 12.5,
            color: onDark ? AppColors.paper : AppColors.caution,
          ),
        ),
      ),
    );
  }
}

/// 空状態に置く印（落款を思わせる抽象的な印）
class _SealMark extends StatelessWidget {
  const _SealMark({this.size = 80});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SealPainter()),
    );
  }
}

class _SealPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(6)),
      paint,
    );
    // 縦の区切りと横の点（「字」を抽象化）
    final inner = rect.deflate(size.width * 0.18);
    canvas.drawLine(
      Offset(inner.center.dx, inner.top),
      Offset(inner.center.dx, inner.bottom),
      paint..strokeWidth = 1.2,
    );
    for (int i = 0; i < 3; i++) {
      final dy = inner.top + inner.height * (i + 1) / 4;
      canvas.drawLine(
        Offset(inner.left, dy),
        Offset(inner.right, dy),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
