#!/usr/bin/env bash
# ============================================================
#  Vercel 用ビルドスクリプト
#
#  Flutter Web を「オフラインで動く」状態のまま配信するための
#  ビルド手順をまとめたもの。Vercel のビルド環境でそのまま実行される。
#
#  ポイント:
#   - --no-web-resources-cdn で CanvasKit をアプリに同梱（CDN 非依存）
#   - 和文フォントは assets/fonts/ にコミット済み（追加取得なし）
#   - 失敗したら日本語で理由を出して異常終了する（無反応にしない）
# ============================================================
set -euo pipefail

log() { printf '\n[外字アルバム] %s\n' "$1"; }

fail() {
  printf '\n[外字アルバム] ビルドに失敗しました: %s\n' "$1" >&2
  case "$1" in
    *flutter*)
      printf '[外字アルバム] Flutter SDK が見つかりません。Vercel の環境に Flutter を用意してください。\n' >&2
      ;;
    *dependencies*|*pub*)
      printf '[外字アルバム] 依存パッケージを取得できませんでした。pubspec.yaml を確認してください。\n' >&2
      ;;
    *)
      printf '[外字アルバム] 上のログにエラーの詳細が出ています。\n' >&2
      ;;
  esac
  exit 1
}

# ------------------------------------------------------------
# 1. Flutter SDK の場所を決める
# ------------------------------------------------------------
FLUTTER_BIN=""

if command -v flutter >/dev/null 2>&1; then
  FLUTTER_BIN="$(command -v flutter)"
elif [ -x "/opt/flutter/bin/flutter" ]; then
  FLUTTER_BIN="/opt/flutter/bin/flutter"
  export PATH="/opt/flutter/bin:$PATH"
fi

if [ -z "$FLUTTER_BIN" ]; then
  fail "flutter コマンドが見つかりません"
fi

log "Flutter: $FLUTTER_BIN"
"$FLUTTER_BIN" --version || fail "flutter の実行に失敗しました"

# ------------------------------------------------------------
# 2. 依存パッケージの取得
# ------------------------------------------------------------
log "依存パッケージを取得しています…"
"$FLUTTER_BIN" pub get || fail "dependencies の取得に失敗しました"

# ------------------------------------------------------------
# 3. Web ビルド（CanvasKit 同梱 / CDN 不使用）
# ------------------------------------------------------------
log "Web をビルドしています（CanvasKit 同梱・CDN 不使用）…"
"$FLUTTER_BIN" build web \
  --release \
  --no-web-resources-cdn \
  --dart-define=flutter.inspector.structuredErrors=false \
  || fail "flutter build web に失敗しました"

# ------------------------------------------------------------
# 4. ビルド結果の確認
# ------------------------------------------------------------
if [ ! -f "build/web/index.html" ]; then
  fail "ビルド成果物 build/web/index.html が見つかりません"
fi

if [ ! -f "build/web/canvaskit/canvaskit.wasm" ]; then
  fail "CanvasKit が同梱されていません（--no-web-resources-cdn を確認してください）"
fi

log "ビルド完了: $(du -sh build/web | cut -f1)"
