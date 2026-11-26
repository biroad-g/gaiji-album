#!/usr/bin/env python3
"""ビルド後の flutter_service_worker.js に、オフライン保存の後処理を加える。

Flutter が生成する Service Worker は次の 2 点でオフライン起動に失敗しやすい。

1. `downloadOffline` が全ファイルを保存するだけで、完了したことを
   ページ側へ知らせない（起動直後の保存が終わったか分からない）。
2. 初回インストール時に保存されるのは CORE（main.dart.js など）だけで、
   CanvasKit やフォントは最初のアクセス時にしか保存されない。
   一度も表示していない画面の素材が抜けたままオフラインになることがある。

このスクリプトは上記を補い、初回にオンラインで開いた時点で
アプリ一式が端末へ保存されるようにする。
"""

import sys
from pathlib import Path

SERVICE_WORKER = Path("build/web/flutter_service_worker.js")

# 1. activate 後に、残りの全ファイルを自動で保存する。
ACTIVATE_HOOK = """
// ---- 外字アルバム: オフライン用の追加処理 ----
// activate が終わったら、CORE 以外のファイル（CanvasKit・フォント・アイコン）も
// まとめて保存する。初回にオンラインで開けば、以後はオフラインでも起動できる。
self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      try {
        await downloadOffline();
        self.__offlineReady = true;
        const clients = await self.clients.matchAll({ includeUncontrolled: true });
        for (const client of clients) {
          client.postMessage({ type: "offlineReady" });
        }
      } catch (err) {
        // 保存に失敗してもオンラインでは使えるので、ここでは何もしない
      }
    })()
  );
});
// ---- ここまで ----
"""

# 2. downloadOffline の完了をページへ知らせる。
MESSAGE_HOOK = """
self.addEventListener("message", async (event) => {
  if (event.data === "downloadOffline") {
    try {
      await downloadOffline();
      self.__offlineReady = true;
      if (event.source) {
        event.source.postMessage({ type: "offlineReady" });
      }
    } catch (err) {
      if (event.source) {
        event.source.postMessage({ type: "offlineFailed" });
      }
    }
  }
});
"""


def main() -> int:
    if not SERVICE_WORKER.exists():
        print(f"[precache] {SERVICE_WORKER} が見つかりません", file=sys.stderr)
        return 1

    source = SERVICE_WORKER.read_text(encoding="utf-8")

    if "外字アルバム: オフライン用の追加処理" in source:
        print("[precache] すでに適用済みです")
        return 0

    # activate リスナーの直後に差し込む（既存の activate はそのまま残す）
    marker = 'self.addEventListener("activate",'
    index = source.find(marker)
    if index == -1:
        print("[precache] activate リスナーが見つかりません", file=sys.stderr)
        return 1

    # marker から始まる関数の終わりを探す（"})" で閉じている箇所）
    end = source.find("\n});", index)
    if end == -1:
        print("[precache] activate リスナーの終端を特定できません", file=sys.stderr)
        return 1
    end += len("\n});")

    patched = source[:end] + "\n" + ACTIVATE_HOOK + source[end:]
    patched = patched.rstrip() + "\n" + MESSAGE_HOOK

    SERVICE_WORKER.write_text(patched, encoding="utf-8")

    # 重要ファイルがキャッシュ対象に入っているか確認
    missing = [
        name
        for name in ("canvaskit/canvaskit.wasm", "main.dart.js", "flutter_bootstrap.js")
        if name not in patched
    ]
    if missing:
        print(f"[precache] 警告: キャッシュ対象に無いファイル: {missing}", file=sys.stderr)
        return 1

    size_kb = SERVICE_WORKER.stat().st_size / 1024
    print(f"[precache] オフライン保存の後処理を適用しました ({size_kb:.1f} KB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
