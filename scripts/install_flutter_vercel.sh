#!/usr/bin/env bash
# ============================================================
#  Vercel 用：Flutter SDK のインストール（キャッシュ利用）
#
#  Vercel のビルド環境には Flutter が入っていないため、
#  指定バージョンの SDK を取得する。2 回目以降は
#  /vercel/.cache 配下のキャッシュを使うので数十秒で終わる。
#
#  ⚠️ バージョンは 3.35.4 / Dart 3.9.2 で固定（変更しない）
# ============================================================
set -euo pipefail

FLUTTER_VERSION="3.35.4"
CACHE_DIR="${FLUTTER_CACHE_DIR:-/vercel/.cache/flutter-sdk}"
SDK_DIR="${CACHE_DIR}/flutter"
ARCHIVE="${CACHE_DIR}/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

log() { printf '\n[外字アルバム] %s\n' "$1"; }

# すでにキャッシュがあれば再利用
if [ -x "${SDK_DIR}/bin/flutter" ]; then
  log "キャッシュ済みの Flutter ${FLUTTER_VERSION} を使います: ${SDK_DIR}"
else
  log "Flutter ${FLUTTER_VERSION} を取得しています（初回のみ・約1.4GB）…"
  mkdir -p "${CACHE_DIR}"

  if [ ! -f "${ARCHIVE}" ]; then
    if command -v curl >/dev/null 2>&1; then
      curl -fL --retry 3 --retry-delay 5 -o "${ARCHIVE}" "${URL}"
    else
      wget -q -O "${ARCHIVE}" "${URL}"
    fi
  fi

  if [ ! -s "${ARCHIVE}" ]; then
    printf '[外字アルバム] Flutter SDK をダウンロードできませんでした。\n' >&2
    exit 1
  fi

  log "展開しています…"
  rm -rf "${SDK_DIR}"
  if tar -xJf "${ARCHIVE}" -C "${CACHE_DIR}"; then
    :
  else
    printf '[外字アルバム] SDK の展開に失敗しました（xz 非対応の可能性）。\n' >&2
    exit 1
  fi

  # 展開後のアーカイブは消してキャッシュを軽くする
  rm -f "${ARCHIVE}"
fi

# PATH に追加（以降のスクリプトから flutter を呼べるようにする）
export PATH="${SDK_DIR}/bin:${PATH}"

# Flutter は git 管理されたリポジトリ内で動くため、所有権の警告を避ける
git config --global --add safe.directory "${SDK_DIR}" 2>/dev/null || true

log "Flutter の初期設定を行っています…"
# 解析レポートの送信は行わない（オフライン方針に合わせる）
"${SDK_DIR}/bin/flutter" --disable-analytics >/dev/null 2>&1 || true
"${SDK_DIR}/bin/flutter" config --no-analytics >/dev/null 2>&1 || true
"${SDK_DIR}/bin/flutter" config --enable-web >/dev/null 2>&1 || true
"${SDK_DIR}/bin/flutter" precache --web >/dev/null 2>&1 || true

"${SDK_DIR}/bin/flutter" --version

log "Flutter SDK の準備ができました: ${SDK_DIR}"
