#!/usr/bin/env bash
# ============================================================
#  Vercel へ「ビルド済みの成果物だけ」を送るデプロイスクリプト
#
#  この方式の利点:
#   - Vercel 側に Flutter SDK を用意しなくてよい（ビルド時間 0 分）
#   - 手元と同じ Flutter 3.35.4 / Dart 3.9.2 で作った成果物をそのまま配信
#
#  使い方:
#   1) Vercel のアクセストークンを用意
#        https://vercel.com/account/tokens
#   2) 実行
#        VERCEL_TOKEN=xxxxx bash scripts/deploy_vercel_prebuilt.sh
#
#  初回はプロジェクトの紐付けが必要:
#        VERCEL_TOKEN=xxxxx bash scripts/deploy_vercel_prebuilt.sh --link
# ============================================================
set -euo pipefail

VERCEL_CLI="npx --yes vercel@48"

log() { printf '\n[外字アルバム] %s\n' "$1"; }
fail() {
  printf '\n[外字アルバム] デプロイを中止しました: %s\n' "$1" >&2
  case "$1" in
    *token*|*トークン*)
      printf '[外字アルバム] Vercel のアクセストークンを環境変数 VERCEL_TOKEN に設定してください。\n' >&2
      printf '[外字アルバム] 取得先: https://vercel.com/account/tokens\n' >&2
      ;;
    *link*|*紐付け*)
      printf '[外字アルバム] 先に --link を付けて一度実行し、プロジェクトを紐付けてください。\n' >&2
      ;;
  esac
  exit 1
}

if [ -z "${VERCEL_TOKEN:-}" ]; then
  fail "token が設定されていません"
fi
export VERCEL_TOKEN

# ------------------------------------------------------------
# 1. Web をビルド（CanvasKit 同梱）
# ------------------------------------------------------------
log "Web をビルドしています…"
bash scripts/build_web_for_vercel.sh || fail "ビルドに失敗しました"

# ------------------------------------------------------------
# 2. プロジェクトの紐付け（初回のみ）
# ------------------------------------------------------------
if [ ! -f ".vercel/project.json" ]; then
  log "Vercel プロジェクトを作成・紐付けしています（初回のみ）…"
  $VERCEL_CLI link --yes \
    --project gaiji-album \
    --scope "${VERCEL_SCOPE:-}" \
    || fail "link に失敗しました（プロジェクトの紐付け）"
fi

# ------------------------------------------------------------
# 3. Vercel の形式でローカルビルドしてから、成果物だけを送信
# ------------------------------------------------------------
log "Vercel 形式でローカルビルドしています…"
$VERCEL_CLI build --yes || fail "vercel build に失敗しました"

log "成果物をアップロードしています…"
$VERCEL_CLI deploy --prebuilt --prod --yes || fail "deploy に失敗しました"

log "デプロイが完了しました。上の URL を開いて動作をご確認ください。"
