import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/gaiji.dart';
import '../services/export_service.dart';
import '../services/image_pipeline.dart';
import '../services/photo_source.dart';
import '../state/album_store.dart';
import '../theme/app_theme.dart';
import 'album_screen.dart';
import 'crop_screen.dart';
import 'register_screen.dart';

/// 詳細画面。字形を大きく表示し、書き出し・共有・編集・削除を行う。
class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.gaijiId});

  final String gaijiId;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool _busy = false;
  String _busyMessage = '';

  String _formatDate(DateTime d) =>
      '${d.year}年${d.month}月${d.day}日 ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _share(Gaiji g) async {
    setState(() {
      _busy = true;
      _busyMessage = 'PNG を書き出しています…';
    });
    await Future<void>.delayed(const Duration(milliseconds: 40));
    try {
      await ExportService.sharePng(g.glyphPng, name: g.name);
      if (!mounted) return;
      setState(() => _busy = false);
    } on ImagePipelineException catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail('PNG の書き出しに失敗しました。もう一度お試しください。');
    }
  }

  Future<void> _savePng(Gaiji g) async {
    setState(() {
      _busy = true;
      _busyMessage = 'PNG を書き出しています…';
    });
    await Future<void>.delayed(const Duration(milliseconds: 40));
    try {
      final path = await ExportService.savePng(g.glyphPng, name: g.name);
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PNG を書き出しました：$path', style: const TextStyle(fontSize: 15)),
          duration: const Duration(seconds: 4),
        ),
      );
    } on ImagePipelineException catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail('PNG を書き出せませんでした。端末の空き容量を確認してください。');
    }
  }

  void _fail(String message) {
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

  /// 字形だけを差し替える（名称・メモなどは保つ）
  Future<void> _replaceGlyph(Gaiji g) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 22, 22, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '字形を編集する',
                  style: TextStyle(
                    fontFamily: AppText.serif,
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
              child: Text(
                '名称・読み・分類・出典・メモはそのまま残ります。',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.6,
                  color: AppColors.ink.withValues(alpha: 0.6),
                ),
              ),
            ),
            _sheetAction(
              icon: Icons.crop_rotate,
              label: g.originalJpg != null ? '元の写真から枠を引き直す' : '切り取り枠を引き直す（元写真なし）',
              enabled: g.originalJpg != null,
              onTap: () => Navigator.of(context).pop('original'),
            ),
            _sheetAction(
              icon: Icons.photo_camera_outlined,
              label: '別の写真から撮り直す',
              onTap: () => Navigator.of(context).pop('camera'),
            ),
            _sheetAction(
              icon: Icons.photo_library_outlined,
              label: '別の写真を読み込む',
              onTap: () => Navigator.of(context).pop('gallery'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    Uint8List? photoBytes;
    try {
      if (choice == 'original') {
        photoBytes = g.originalJpg;
        if (photoBytes == null) {
          _fail('元の写真が保存されていません。別の写真から選んでください。');
          return;
        }
      } else if (choice == 'camera') {
        setState(() {
          _busy = true;
          _busyMessage = 'カメラを準備しています…';
        });
        final photo = await PhotoSource.fromCamera();
        if (!mounted) return;
        setState(() => _busy = false);
        if (photo.bytes.isEmpty) return;
        photoBytes = photo.bytes;
      } else {
        setState(() {
          _busy = true;
          _busyMessage = '写真を開いています…';
        });
        final photo = await PhotoSource.fromGallery();
        if (!mounted) return;
        setState(() => _busy = false);
        if (photo.bytes.isEmpty) return;
        photoBytes = photo.bytes;
      }
    } on ImagePipelineException catch (e) {
      _fail(e.message);
      return;
    } catch (e) {
      _fail('写真を読み込めませんでした。もう一度お試しください。');
      return;
    }

    if (!mounted) return;
    final crop = await Navigator.of(context).push<CropResult>(
      MaterialPageRoute(
        builder: (_) => CropScreen(
          photoBytes: photoBytes!,
          appBarTitle: '一字を囲み直す',
        ),
      ),
    );
    if (crop == null || !mounted) return;

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RegisterScreen(
          glyphPng: crop.glyphPng,
          originalJpg: crop.originalJpg,
          existing: g,
        ),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('字形を差し替えました', style: TextStyle(fontSize: 16)),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _sheetAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: enabled
                  ? AppColors.ink.withValues(alpha: 0.75)
                  : AppColors.ink.withValues(alpha: 0.25),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: enabled
                      ? AppColors.ink
                      : AppColors.ink.withValues(alpha: 0.32),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editRecord(Gaiji g) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RegisterScreen(
          glyphPng: g.glyphPng,
          originalJpg: g.originalJpg,
          existing: g,
        ),
      ),
    );
  }

  Future<void> _delete(Gaiji g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: const Text(
          'この外字を削除しますか',
          style: TextStyle(fontFamily: AppText.serif, fontSize: 19),
        ),
        content: Text(
          '「${g.name}」の字形と記録を削除します。\nこの操作は取り消せません。',
          style: const TextStyle(fontSize: 16, height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.ink.withValues(alpha: 0.7),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            child: const Text('やめる', style: TextStyle(fontSize: 16)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.caution,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            child: const Text('削除する', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await context.read<AlbumStore>().remove(g.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('削除しました', style: TextStyle(fontSize: 16)),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AlbumStore>();
    final g = store.byId(widget.gaijiId);

    if (g == null) {
      return Scaffold(
        backgroundColor: AppColors.paper,
        appBar: AppBar(
          backgroundColor: AppColors.paper,
          foregroundColor: AppColors.ink,
          elevation: 0,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Text(
              'この外字は削除されました。',
              style: TextStyle(fontSize: 17, color: AppColors.ink),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        elevation: 0,
        title: const Text(
          '外字の記録',
          style: TextStyle(
            fontFamily: AppText.serif,
            fontSize: 19,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '記録を編集',
            onPressed: () => _editRecord(g),
            icon: const Icon(Icons.edit_outlined, size: 24),
          ),
          IconButton(
            tooltip: '削除',
            onPressed: () => _delete(g),
            icon: const Icon(Icons.delete_outline, size: 24),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _buildGlyphPanel(g),
                const SizedBox(height: 22),
                _buildNameBlock(g),
                const SizedBox(height: 22),
                _buildActionRow(g),
                const SizedBox(height: 26),
                _buildInfoTable(g),
                if (g.memo.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _buildMemo(g),
                ],
                const SizedBox(height: 26),
                _buildTimestamp(g),
              ],
            ),
            if (_busy)
              Positioned.fill(
                child: ColoredBox(
                  color: AppColors.paper.withValues(alpha: 0.92),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.gold,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          _busyMessage,
                          style: const TextStyle(
                            fontSize: 17,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlyphPanel(Gaiji g) {
    // 字形は大きく。透過の有無が分かるよう市松（薄い和紙）の地に置くなかで
    // 落ち着かせるため、淡い和紙色の単色地にする。
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.all(20),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          color: const Color(0xFFFAF7F0),
          padding: const EdgeInsets.all(14),
          child: GaijiImage(bytes: g.glyphPng),
        ),
      ),
    );
  }

  Widget _buildNameBlock(Gaiji g) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          g.name,
          style: const TextStyle(
            fontFamily: AppText.serif,
            fontSize: 27,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
            height: 1.4,
            letterSpacing: 1,
          ),
        ),
        if (g.reading.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            g.reading,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.ink.withValues(alpha: 0.55),
              letterSpacing: 1.5,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionRow(Gaiji g) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _actionButton(
                icon: Icons.ios_share,
                label: '共有',
                onTap: () => _share(g),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionButton(
                icon: Icons.download_outlined,
                label: 'PNG書き出し',
                onTap: () => _savePng(g),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _actionButton(
          icon: Icons.crop_rotate,
          label: '画像を編集（切り取り枠を引き直す）',
          onTap: () => _replaceGlyph(g),
          wide: true,
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool wide = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 21, color: AppColors.ink.withValues(alpha: 0.75)),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: wide ? 15 : 16,
                  color: AppColors.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTable(Gaiji g) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        children: [
          _infoRow('分類', g.category.label),
          if (g.source.isNotEmpty) _infoRow('出典', g.source),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.ink.withValues(alpha: 0.5),
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16.5,
                height: 1.6,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemo(Gaiji g) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.paperDeep.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'メモ',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.ink.withValues(alpha: 0.5),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            g.memo,
            style: const TextStyle(
              fontSize: 16,
              height: 1.9,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimestamp(Gaiji g) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '記録日時　${_formatDate(g.createdAt)}',
          style: TextStyle(
            fontSize: 12.5,
            color: AppColors.ink.withValues(alpha: 0.4),
          ),
        ),
        if (g.updatedAt.difference(g.createdAt).inSeconds.abs() > 1)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '更新日時　${_formatDate(g.updatedAt)}',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.ink.withValues(alpha: 0.4),
              ),
            ),
          ),
      ],
    );
  }
}
