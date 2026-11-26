import 'dart:async';
import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/gaiji.dart';

/// 端末内にのみ保存する外字リポジトリ。
///
/// - Hive の Box に Map として保存（画像は Uint8List のまま）
/// - 通信は一切行わない（オフライン完結）
/// - 一覧は provider 側でキャッシュし、ここは I/O に専念する
class GaijiRepository {
  GaijiRepository(this._box);

  final Box _box;

  static const boxName = 'gaiji_box';

  static Future<GaijiRepository> open() async {
    await Hive.initFlutter();
    final box = await Hive.openBox(boxName);
    return GaijiRepository(box);
  }

  /// 全件（新しい順）
  List<Gaiji> loadAll() {
    final items = <Gaiji>[];
    for (final key in _box.keys) {
      final raw = _box.get(key);
      if (raw is Map) {
        try {
          items.add(Gaiji.fromMap(raw));
        } catch (_) {
          // 壊れたレコードは飛ばす（アプリ全体を止めない）
        }
      }
    }
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Future<void> save(Gaiji g) async {
    await _box.put(g.id, g.toMap());
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  int get count => _box.length;

  /// すべて削除（確認ダイアログの後で使う）
  Future<void> clear() async {
    await _box.clear();
  }
}

/// 画像処理など重い処理を UI スレッドから逃がすための小さなヘルパ。
///
/// 大きな写真でも固まらないよう、必ず `await deferToNextFrame()` を挟んで
/// 「写真を読み込んでいます…」を描画させてから処理に入る。
Future<void> deferToNextFrame() {
  final completer = Completer<void>();
  scheduleMicrotask(() {
    Future<void>.delayed(Duration.zero, completer.complete);
  });
  return completer.future;
}

/// 画像バイト列から安全にコピーを作る（Hive 保存後に書き換わらないように）
Uint8List freezeBytes(Uint8List src) => Uint8List.fromList(src);
