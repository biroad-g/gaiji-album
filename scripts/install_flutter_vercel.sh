#!/usr/bin/env bash
# ============================================================
#  Vercel 用：Flutter SDK のインストール（キャッシュ利用）
#
#  Vercel のビルド環境には Flutter が入っていないため、
#  指定バージョンの SDK を取得する。2 回目以降は
#  /vercel/.cache 配下のキャッシュを使うので数十秒で終わる。
#
#  ⚠️ installCommand と buildCommand は別プロセスなので、
#     PATH は引き継がれない。SDK の場所をファイルに書き出し、
#     後続のビルドスクリプトがそれを読む。
#
#  ⚠️ バージョンは 3.35.4 / Dart 3.9.2 で固定（変更しない）
# ============================================================
set -euo pipefail

FLUTTER_VERSION="3.35.4"
CACHE_DIR="${FLUTTER_CACHE_DIR:-/vercel/.cache/flutter-sdk}"
SDK_DIR="${CACHE_DIR}/flutter"
PATH_FILE="${CACHE_DIR}/sdk_path.txt"
ARCHIVE="${CACHE_DIR}/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

log() { printf '\n[外字アルバム] %s\n' "$1"; }
fail() {
  printf '\n[外字アルバム] %s\n' "$1" >&2
  exit 1
}

# ------------------------------------------------------------
# 1. SDK の取得（キャッシュがあれば再利用）
# ------------------------------------------------------------
if [ -x "${SDK_DIR}/bin/flutter" ]; then
  log "キャッシュ済みの Flutter ${FLUTTER_VERSION} を使います: ${SDK_DIR}"
else
  log "Flutter ${FLUTTER_VERSION} を取得しています（初回のみ・約1.4GB）…"
  mkdir -p "${CACHE_DIR}"

  if [ ! -f "${ARCHIVE}" ]; then
    if command -v curl >/dev/null 2>&1; then
      curl -fL --retry 3 --retry-delay 5 -o "${ARCHIVE}" "${URL}" \
        || fail "Flutter SDK をダウンロードできませんでした。"
    else
      wget -q -O "${ARCHIVE}" "${URL}" \
        || fail "Flutter SDK をダウンロードできませんでした。"
    fi
  fi

  [ -s "${ARCHIVE}" ] || fail "Flutter SDK の取得物が空でした。"

  log "展開しています…"
  rm -rf "${SDK_DIR}"
  tar -xJf "${ARCHIVE}" -C "${CACHE_DIR}" \
    || fail "SDK の展開に失敗しました（xz 非対応の可能性）。"

  rm -f "${ARCHIVE}"
fi

[ -x "${SDK_DIR}/bin/flutter" ] || fail "Flutter の実行ファイルが見つかりません: ${SDK_DIR}/bin/flutter"

# ------------------------------------------------------------
# 2. SDK の場所を後続プロセスへ引き継ぐ
# ------------------------------------------------------------
mkdir -p "${CACHE_DIR}"
printf '%s\n' "${SDK_DIR}" > "${PATH_FILE}"
# リポジトリ直下にも控えを置く（キャッシュ先が変わっても拾えるように）
printf '%s\n' "${SDK_DIR}" > .flutter_sdk_path 2>/dev/null || true

export PATH="${SDK_DIR}/bin:${PATH}"

# Vercel は root でビルドするため、git 所有権の警告を抑止する
git config --global --add safe.directory "${SDK_DIR}" 2>/dev/null || true
git config --global --add safe.directory "*" 2>/dev/null || true

# ------------------------------------------------------------
# 3. 初期設定（解析レポートの送信は行わない＝オフライン方針に合わせる）
# ------------------------------------------------------------
log "Flutter の初期設定を行っています…"
"${SDK_DIR}/bin/flutter" config --no-analytics >/dev/null 2>&1 || true
"${SDK_DIR}/bin/flutter" --disable-analytics >/dev/null 2>&1 || true
"${SDK_DIR}/bin/flutter" config --enable-web >/dev/null 2>&1 || true

# Web 用の成果物をあらかじめ用意（2回目以降はキャッシュ済みで即時）
"${SDK_DIR}/bin/flutter" precache --web >/dev/null 2>&1 || true

"${SDK_DIR}/bin/flutter" --version || fail "flutter の実行に失敗しました。"

log "Flutter SDK の準備ができました: ${SDK_DIR}"
