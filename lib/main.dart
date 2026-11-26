import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/gaiji_repository.dart';
import 'screens/album_screen.dart';
import 'state/album_store.dart';
import 'theme/app_theme.dart';
import 'theme/theme_builder.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 端末内データベース（Hive）を開く。失敗しても無反応にせず理由を出す。
  GaijiRepository? repository;
  String? startupError;
  try {
    repository = await GaijiRepository.open();
  } catch (e) {
    startupError = '記録を保存する準備ができませんでした。アプリを再起動してください。';
  }

  if (startupError != null || repository == null) {
    runApp(_StartupFailureApp(message: startupError!));
    return;
  }

  runApp(GaijiAlbumApp(repository: repository));
}

class GaijiAlbumApp extends StatelessWidget {
  const GaijiAlbumApp({super.key, required this.repository});

  final GaijiRepository repository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AlbumStore(repository),
      child: MaterialApp(
        title: '外字アルバム',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        locale: const Locale('ja', 'JP'),
        builder: (context, child) {
          // 文字の拡大設定を尊重しつつ、極端な縮小は防ぐ
          final scaler = MediaQuery.textScalerOf(context);
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: scaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.4),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const AlbumScreen(),
      ),
    );
  }
}

/// 起動に失敗したとき、白い画面のままにせず理由を日本語で示す。
class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: Scaffold(
        backgroundColor: AppColors.paper,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 52, color: AppColors.caution),
                  const SizedBox(height: 24),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.8,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    '記録済みのデータは端末内に残っています。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.ink.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
