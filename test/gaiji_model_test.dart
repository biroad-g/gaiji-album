import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/models/gaiji.dart';

void main() {
  test('Gaiji は Map へ往復できる（型が保たれる）', () {
    final now = DateTime(2026, 1, 18, 9, 30);
    final glyph = Uint8List.fromList([1, 2, 3, 4]);
    final original = Uint8List.fromList([9, 8, 7]);

    final g = Gaiji(
      id: 'abc',
      name: '𠮷',
      reading: 'きち',
      category: GaijiCategory.itaiji,
      source: '『大正蔵』第12巻',
      memo: '過去帳の末尾にあり',
      glyphPng: glyph,
      originalJpg: original,
      createdAt: now,
      updatedAt: now,
    );

    final restored = Gaiji.fromMap(g.toMap());

    expect(restored.id, 'abc');
    expect(restored.name, '𠮷');
    expect(restored.reading, 'きち');
    expect(restored.category, GaijiCategory.itaiji);
    expect(restored.source, '『大正蔵』第12巻');
    expect(restored.memo, '過去帳の末尾にあり');
    expect(restored.glyphPng, glyph);
    expect(restored.originalJpg, original);
    expect(restored.createdAt, now);
  });

  test('壊れたデータでも落ちずに既定値で復元する', () {
    final restored = Gaiji.fromMap(<dynamic, dynamic>{
      'name': null,
      'category': 'unknown',
      'glyph': null,
      'createdAt': null,
    });

    expect(restored.name, '（名称なし）');
    expect(restored.category, GaijiCategory.sonota);
    expect(restored.glyphPng, isEmpty);
    expect(restored.originalJpg, isNull);
  });

  test('検索用の文字列に名称・読み・分類・出典・メモが含まれる', () {
    final g = Gaiji(
      id: 'x',
      name: '梵字',
      reading: 'ぼんじ',
      category: GaijiCategory.bonji,
      source: '版木',
      memo: '法話で使う',
      glyphPng: Uint8List.fromList([0]),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    expect(g.searchIndex.contains('梵字'), isTrue);
    expect(g.searchIndex.contains('ぼんじ'), isTrue);
    expect(g.searchIndex.contains('梵字'), isTrue);
    expect(g.searchIndex.contains('版木'), isTrue);
    expect(g.searchIndex.contains('法話'), isTrue);
  });

  test('カテゴリは 5 種類あり、名前から復元できる', () {
    expect(GaijiCategory.values.length, 5);
    expect(GaijiCategory.fromName('bonji'), GaijiCategory.bonji);
    expect(GaijiCategory.fromName('存在しない'), GaijiCategory.sonota);
  });
}
