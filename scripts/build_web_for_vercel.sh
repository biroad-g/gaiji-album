#!/usr/bin/env bash
# ============================================================
#  Vercel 用ビルドスクリプト
#
#  Flutter Web を「オフラインで動く」状態のまま配信するための
#  ビルド手順をまとめたもの。
#
#  ポイント:
#   - installCommand と buildCommand は別プロセスで PATH が
#     引き継がれないため、SDK の場所をファイルから解決する
#   - それでも見つからない場合は、この場で SDK を用意する
#     （installCommand が走らなかった場合の保険）
#   - --no-web-resources-cdn で CanvasKit をアプリに同梱（CDN 非依存）
#   - 失敗したら日本語で理由を出して異常終了する（無反応にしない）
# ============================================================
set -euo pipefail

log() { printf '\n[外字アルバム] %s\n' "$1"; }
fail() {
  printf '\n[外字アルバム] ビルドに失敗しました: %s\n' "$1" >&2
  exit 1
}

# ------------------------------------------------------------
# 1. Flutter SDK の場所を解決する
# ------------------------------------------------------------
resolve_flutter() {
  # (a) すでに PATH にある
  if command -v flutter >/dev/null 2>&1; then
    command -v flutter
    return 0
  fi

  # (b) インストールスクリプトが書き出した場所
  local candidate
  for candidate in \
    "$(cat /vercel/.cache/flutter-sdk/sdk_path.txt 2>/dev/null || true)" \
    "$(cat "${FLUTTER_CACHE_DIR:-/vercel/.cache/flutter-sdk}/sdk_path.txt" 2>/dev/null || true)" \
    "$(cat .flutter_sdk_path 2>/dev/null || true)" \
    "/vercel/.cache/flutter-sdk/flutter" \
    "${FLUTTER_CACHE_DIR:-/vercel/.cache/flutter-sdk}/flutter" \
    "/opt/flutter" \
    "${HOME}/flutter"
  do
    if [ -n "${candidate}" ] && [ -x "${candidate}/bin/flutter" ]; then
      printf '%s\n' "${candidate}/bin/flutter"
      return 0
    fi
  done

  # (c) キャッシュ領域を総なめ（配置が変わっても拾う）
  local found
  found="$(find /vercel/.cache "${HOME}" -maxdepth 4 -type f -path "*/bin/flutter" 2>/dev/null | head -n 1 || true)"
  if [ -n "${found}" ] && [ -x "${found}" ]; then
    printf '%s\n' "${found}"
    return 0
  fi

  return 1
}

FLUTTER_BIN="$(resolve_flutter || true)"

# 見つからない場合はこの場で用意する（保険）
if [ -z "${FLUTTER_BIN}" ]; then
  log "Flutter SDK が見つからないため、この場で用意します…"
  bash scripts/install_flutter_vercel.sh || fail "Flutter SDK を用意できませんでした。"
  FLUTTER_BIN="$(resolve_flutter || true)"
fi

[ -n "${FLUTTER_BIN}" ] || fail "flutter コマンドが見つかりません。"

export PATH="$(dirname "${FLUTTER_BIN}"):${PATH}"
log "Flutter: ${FLUTTER_BIN}"
"${FLUTTER_BIN}" --version || fail "flutter の実行に失敗しました。"

# root 実行時の git 所有権警告を抑止
git config --global --add safe.directory "*" 2>/dev/null || true

# ------------------------------------------------------------
# 2. 依存パッケージの取得
# ------------------------------------------------------------
log "依存パッケージを取得しています…"
"${FLUTTER_BIN}" config --enable-web >/dev/null 2>&1 || true
"${FLUTTER_BIN}" pub get || fail "依存パッケージ（pub）の取得に失敗しました。"

# ------------------------------------------------------------
# 3. Web ビルド（CanvasKit 同梱 / CDN 不使用）
# ------------------------------------------------------------
log "Web をビルドしています（CanvasKit 同梱・CDN 不使用）…"
"${FLUTTER_BIN}" build web \
  --release \
  --no-web-resources-cdn \
  --dart-define=flutter.inspector.structuredErrors=false \
  || fail "flutter build web に失敗しました。"

# ------------------------------------------------------------
# 4. ビルド結果の確認
# ------------------------------------------------------------
if [ ! -f "build/web/index.html" ]; then
  fail "ビルド成果物 build/web/index.html が見つかりません。"
fi

if [ ! -f "build/web/canvaskit/canvaskit.wasm" ]; then
  fail "CanvasKit が同梱されていません（--no-web-resources-cdn を確認してください）。"
fi

log "ビルド完了: $(du -sh build/web | cut -f1)"
