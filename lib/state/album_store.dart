import 'package:flutter/foundation.dart';

import '../data/gaiji_repository.dart';
import '../models/gaiji.dart';

/// アルバムの状態（provider）。
///
/// 一覧・検索語・分類の絞り込みを保持し、画面はこれを watch するだけにする。
class AlbumStore extends ChangeNotifier {
  AlbumStore(this._repository) : _items = _repository.loadAll();

  final GaijiRepository _repository;

  List<Gaiji> _items;
  String _query = '';
  GaijiCategory? _filter;

  bool _ready = true;

  /// 全件（新しい順）
  List<Gaiji> get all => List.unmodifiable(_items);

  int get total => _items.length;

  bool get ready => _ready;

  String get query => _query;

  GaijiCategory? get filter => _filter;

  bool get isEmpty => _items.isEmpty;

  /// 絞り込み後の一覧
  List<Gaiji> get visible {
    final q = _query.trim().toLowerCase();
    Iterable<Gaiji> list = _items;
    if (_filter != null) {
      list = list.where((g) => g.category == _filter);
    }
    if (q.isNotEmpty) {
      list = list.where((g) => g.searchIndex.contains(q));
    }
    return list.toList(growable: false);
  }

  /// 分類ごとの件数（絞り込みチップに表示）
  Map<GaijiCategory, int> get counts {
    final map = <GaijiCategory, int>{for (final c in GaijiCategory.values) c: 0};
    for (final g in _items) {
      map[g.category] = (map[g.category] ?? 0) + 1;
    }
    return map;
  }

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }

  void toggleFilter(GaijiCategory? category) {
    _filter = (_filter == category) ? null : category;
    notifyListeners();
  }

  void clearFilters() {
    if (_query.isEmpty && _filter == null) return;
    _query = '';
    _filter = null;
    notifyListeners();
  }

  Gaiji? byId(String id) {
    for (final g in _items) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// 新規登録
  Future<Gaiji> add({
    required String name,
    required String reading,
    required GaijiCategory category,
    required String source,
    required String memo,
    required Uint8List glyphPng,
    Uint8List? originalJpg,
  }) async {
    final now = DateTime.now();
    final gaiji = Gaiji(
      id: '${now.microsecondsSinceEpoch}_${_items.length}',
      name: name.trim(),
      reading: reading.trim(),
      category: category,
      source: source.trim(),
      memo: memo.trim(),
      glyphPng: freezeBytes(glyphPng),
      originalJpg: originalJpg == null ? null : freezeBytes(originalJpg),
      createdAt: now,
      updatedAt: now,
    );
    await _repository.save(gaiji);
    _items = _repository.loadAll();
    notifyListeners();
    return gaiji;
  }

  /// 更新（名称やメモの編集、字形の差し替えの両方に使う）
  Future<void> update(Gaiji updated) async {
    final fixed = updated.copyWith(
      glyphPng: freezeBytes(updated.glyphPng),
      originalJpg: updated.originalJpg == null
          ? null
          : freezeBytes(updated.originalJpg!),
      updatedAt: DateTime.now(),
    );
    await _repository.save(fixed);
    _items = _repository.loadAll();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await _repository.delete(id);
    _items = _repository.loadAll();
    notifyListeners();
  }

  Future<void> reload() async {
    _ready = false;
    notifyListeners();
    _items = _repository.loadAll();
    _ready = true;
    notifyListeners();
  }
}
