/// アプリ全体で使う色と書体。
///
/// 方針: 寺院の空間にふさわしい落ち着き。金・墨・和紙・若竹。
/// 派手なアニメーションは使わない。
library;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  /// 墨（見出し・本文）
  static const ink = Color(0xFF1E1B18);

  /// 濃い墨（アイコン・強調）
  static const inkDeep = Color(0xFF121010);

  /// 和紙（背景）
  static const paper = Color(0xFFF5F1E8);

  /// 少し濃い和紙（カード地・入力欄）
  static const paperDeep = Color(0xFFEDE7D9);

  /// 線・区切り
  static const line = Color(0xFFD8CFBC);

  /// 金（アクセント）— 多用しない
  static const gold = Color(0xFF8A6A2F);

  /// 金の淡い地
  static const goldPale = Color(0xFFE8DCC0);

  /// 若竹（補助アクセント）
  static const bamboo = Color(0xFF4A6B5A);

  /// 注意・警告（日本語で理由を伝えるとき）
  static const caution = Color(0xFF9B3A2E);
}

class AppText {
  AppText._();

  /// 本文は大きめ。読みやすさを最優先。
  static const body = 17.0;
  static const bodyLarge = 19.0;

  /// 見出し
  static const title = 22.0;
  static const heading = 26.0;

  /// 入力欄は 18px（iOS の自動拡大＝16px 未満で起きるのを確実に防ぐ）
  static const field = 18.0;

  static const serif = 'NotoSerifJP';
  static const sans = 'NotoSansJP';
}
