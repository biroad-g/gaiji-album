import 'package:flutter/material.dart';

import '../services/image_pipeline.dart';
import '../services/photo_source.dart';
import '../theme/app_theme.dart';
import 'crop_screen.dart';
import 'register_screen.dart';

/// 撮影モード選択 → 一字を囲む → 登録、までを一続きに進める画面。
///
/// 「カメラで撮影する」「端末の写真から読み込む」の 2 つから選ぶ。
class CaptureSheet extends StatefulWidget {
  const CaptureSheet({super.key});

  @override
  State<CaptureSheet> createState() => _CaptureSheetState();
}

class _CaptureSheetState extends State<CaptureSheet> {
  bool _busy = false;
  String _busyMessage = '';

  Future<void> _pick(bool fromCamera) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _busyMessage = fromCamera ? 'カメラを準備しています…' : '写真を開いています…';
    });

    try {
      final photo =
          fromCamera ? await PhotoSource.fromCamera() : await PhotoSource.fromGallery();

      if (!mounted) return;

      if (photo.bytes.isEmpty) {
        // 利用者が選ばずに戻っただけなので、静かに元へ戻す
        setState(() => _busy = false);
        return;
      }

      setState(() => _busyMessage = '写真を読み込んでいます…');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      if (!mounted) return;

      final crop = await Navigator.of(context).push<CropResult>(
        MaterialPageRoute(
          builder: (_) => CropScreen(photoBytes: photo.bytes),
        ),
      );
      if (!mounted) return;
      setState(() => _busy = false);

      if (crop == null) return; // 切り取りをやめた

      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => RegisterScreen(
            glyphPng: crop.glyphPng,
            originalJpg: crop.originalJpg,
          ),
        ),
      );
      if (!mounted) return;
      if (saved == true) {
        Navigator.of(context).pop(true);
      }
    } on ImagePipelineException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('写真を読み込めませんでした。もう一度お試しください。');
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
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '外字を撮影する',
          style: TextStyle(
            fontFamily: AppText.serif,
            fontSize: 20,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 30),
              children: [
                Text(
                  '写真から、漢字一字を囲んで切り取ります。\n'
                  '拡大して撮ると字形がよく残ります。',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.8,
                    color: AppColors.ink.withValues(alpha: 0.62),
                  ),
                ),
                const SizedBox(height: 28),
                _SourceButton(
                  icon: Icons.photo_camera_outlined,
                  title: 'カメラで撮影する',
                  subtitle: '扁額・過去帳・石塔などをその場で撮る',
                  primary: true,
                  onTap: _busy ? null : () => _pick(true),
                ),
                const SizedBox(height: 14),
                _SourceButton(
                  icon: Icons.photo_library_outlined,
                  title: '端末の写真から読み込む',
                  subtitle: 'すでに撮ってある写真から選ぶ',
                  onTap: _busy ? null : () => _pick(false),
                ),
                const SizedBox(height: 34),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.paperDeep,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 18,
                        color: AppColors.ink.withValues(alpha: 0.45),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '撮影した写真と記録は、この端末の中だけに保存されます。'
                          '外部へ送信することはありません。',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.7,
                            color: AppColors.ink.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_busy)
              Positioned.fill(
                child: ColoredBox(
                  color: AppColors.paper.withValues(alpha: 0.94),
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
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final bg = primary ? AppColors.ink : Colors.white;
    final fg = primary ? AppColors.paper : AppColors.ink;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        constraints: const BoxConstraints(minHeight: 92),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: primary ? AppColors.ink : AppColors.line),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(icon, size: 30, color: fg),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: fg,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: fg.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: fg.withValues(alpha: 0.45),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
