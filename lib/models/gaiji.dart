import 'dart:typed_data';

/// 外字の分類。
///
/// 外字は文字コードで表せないため「字形（かたち）」を画像として保存する。
/// この分類は「意味」を添えるための最小限の軸。
enum GaijiCategory {
  itaiji('異体字', '本来の字とは別の字形で書かれたもの'),
  koji('古字', '古い時代の字体・古写本に見える字形'),
  bonji('梵字', '梵字（悉曇）・種子字'),
  inei('印影', '印章・印影の字'),
  sonota('その他', 'くずし字・版木・不明など');

  const GaijiCategory(this.label, this.description);

  final String label;
  final String description;

  static GaijiCategory fromName(String? name) {
    for (final c in GaijiCategory.values) {
      if (c.name == name) return c;
    }
    return GaijiCategory.sonota;
  }
}

/// 外字 1 件の記録。
///
/// 字形画像 `glyphPng` が本体。名称・読み・分類・出典・メモが「意味」を与える。
class Gaiji {
  Gaiji({
    required this.id,
    required this.name,
    this.reading = '',
    this.category = GaijiCategory.sonota,
    this.source = '',
    this.memo = '',
    required this.glyphPng,
    this.originalJpg,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 一意な ID（作成時刻 + 乱数）
  final String id;

  /// 名称（必須）
  final String name;

  /// 読み（任意）
  final String reading;

  /// 分類
  final GaijiCategory category;

  /// 出典（任意）: 『大正蔵』第12巻、〇〇寺 過去帳、版木 など
  final String source;

  /// メモ（任意）: 用例、法話で使う場面など
  final String memo;

  /// 字形画像（透過／余白調整済みの PNG バイト列）。これが記録の中心。
  final Uint8List glyphPng;

  /// 元写真（JPEG に縮小して保存。切り取り枠の引き直しに使う）
  final Uint8List? originalJpg;

  final DateTime createdAt;
  final DateTime updatedAt;

  Gaiji copyWith({
    String? name,
    String? reading,
    GaijiCategory? category,
    String? source,
    String? memo,
    Uint8List? glyphPng,
    Uint8List? originalJpg,
    DateTime? updatedAt,
  }) {
    return Gaiji(
      id: id,
      name: name ?? this.name,
      reading: reading ?? this.reading,
      category: category ?? this.category,
      source: source ?? this.source,
      memo: memo ?? this.memo,
      glyphPng: glyphPng ?? this.glyphPng,
      originalJpg: originalJpg ?? this.originalJpg,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Hive へ保存するための Map。
  /// 画像は Uint8List のまま保持する（base64 にしない＝容量・速度で有利）。
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'reading': reading,
        'category': category.name,
        'source': source,
        'memo': memo,
        'glyph': glyphPng,
        'original': originalJpg,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  /// 壊れた／古いデータでも落ちないよう、型を確かめながら復元する。
  static Gaiji fromMap(Map<dynamic, dynamic> map) {
    Uint8List? asBytes(dynamic v) {
      if (v is Uint8List) return v;
      if (v is List<int>) return Uint8List.fromList(v);
      if (v is List) {
        return Uint8List.fromList(v.map((e) => (e as num).toInt()).toList());
      }
      return null;
    }

    int asMillis(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return DateTime.now().millisecondsSinceEpoch;
    }

    return Gaiji(
      id: (map['id'] as String?) ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: (map['name'] as String?) ?? '（名称なし）',
      reading: (map['reading'] as String?) ?? '',
      category: GaijiCategory.fromName(map['category'] as String?),
      source: (map['source'] as String?) ?? '',
      memo: (map['memo'] as String?) ?? '',
      glyphPng: asBytes(map['glyph']) ?? Uint8List(0),
      originalJpg: asBytes(map['original']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(asMillis(map['createdAt'])),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(asMillis(map['updatedAt'])),
    );
  }

  /// 検索用の文字列（名称・読み・出典・メモ・分類）
  String get searchIndex =>
      '$name $reading ${category.label} $source $memo'.toLowerCase();
}
