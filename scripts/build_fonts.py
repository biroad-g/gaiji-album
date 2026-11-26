#!/usr/bin/env python3
"""アプリに同梱する和文フォントのサブセットを作る。

オフラインで動かすため、フォントは端末内に持つしかない。
一方で元の Noto Serif JP / Noto Sans JP は 1 ファイル 16〜25MB あり、
そのまま同梱するとアプリが重くなる。

そこで次の文字だけを残して軽くする。

  * ASCII（英数字・記号）
  * JIS X 0208 の全文字（日本語の漢字・かな・記号）
  * アプリのソースに書かれている文字（画面の文言を確実に含める）
  * 外字記録でよく使う漢字（異体字・梵字・印影などの語彙）

「画面の文言がフォントに無い」とオフライン時に豆腐（□）になるため、
ソースを走査して漏れを防ぐのがこのスクリプトの要点。
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"
FONT_DIR = ROOT / "assets" / "fonts"
SOURCE_FONTS = {
    "serif": Path("/tmp/NotoSerifJP.otf"),
    "sans": Path("/tmp/NotoSansJP.otf"),
}
OUTPUT = {
    "serif": FONT_DIR / "NotoSerifJP-Subset.ttf",
    "sans": FONT_DIR / "NotoSansJP-Subset.ttf",
}

# 外字の記録・寺院の語彙で使う漢字（JIS X 0208 外の異体字は画像で扱うため不要）
EXTRA_WORDS = """
外字 異体字 古字 梵字 印影 その他 扁額 過去帳 版木 石塔 位牌 過去帳
名称 読み 分類 出典 メモ 字形 元写真 作成日時 更新日時 撮影 写真 端末 読込
範囲 切取 余白 透過 調整 保存 詳細 編集 削除 共有 書出 大正蔵 巻 寺院 住職
僧侶 法話 観音 仏教 経典 曼荼羅 種子 悉曇 印章 落款 花押 偏 旁 冠 脚 繞
""".split()


def jis_x_0208_chars() -> set[str]:
    """JIS X 0208 の全文字を EUC-JP 経由で列挙する。"""
    chars: set[str] = set()
    for hi in range(0xA1, 0xFF):
        for lo in range(0xA1, 0xFF):
            try:
                ch = bytes([hi, lo]).decode("euc_jp")
            except UnicodeDecodeError:
                continue
            if len(ch) == 1:
                chars.add(ch)
    return chars


def source_chars() -> set[str]:
    """lib/ 以下の Dart ファイルに現れる文字をすべて集める。"""
    chars: set[str] = set()
    for path in LIB.rglob("*.dart"):
        text = path.read_text(encoding="utf-8")
        # コメントも含めてよい（取りこぼすより安全）
        for ch in text:
            if ord(ch) > 0x7F:
                chars.add(ch)
    return chars


def build_text() -> str:
    chars: set[str] = set()
    chars.update(chr(c) for c in range(0x20, 0x7F))  # ASCII 印字可能
    chars.update("　、。「」『』（）［］｛｝【】〜・…‥ー－―/\\:;,.!?+=*%$#@&_|<>()[]{}")
    chars.update(jis_x_0208_chars())
    chars.update(source_chars())
    for word in EXTRA_WORDS:
        chars.update(word)
    # 全角英数・記号
    chars.update(chr(c) for c in range(0xFF01, 0xFF5F))
    chars.update(chr(c) for c in range(0x3000, 0x303F))
    return "".join(sorted(chars))


def main() -> int:
    missing_src = [str(p) for p in SOURCE_FONTS.values() if not p.exists()]
    if missing_src:
        print(f"[font] 元フォントが見つかりません: {missing_src}", file=sys.stderr)
        print("[font] 先に Noto Sans JP / Noto Serif JP を /tmp に置いてください。", file=sys.stderr)
        return 1

    FONT_DIR.mkdir(parents=True, exist_ok=True)
    text_file = Path("/tmp/glyph_text.txt")
    text = build_text()
    text_file.write_text(text, encoding="utf-8")
    print(f"[font] 収録対象: {len(text)} 文字")

    for kind, src in SOURCE_FONTS.items():
        out = OUTPUT[kind]
        cmd = [
            sys.executable,
            "-m",
            "fontTools.subset",
            str(src),
            f"--text-file={text_file}",
            f"--output-file={out}",
            "--layout-features=*",
            "--glyph-names",
            "--symbol-cmap",
            "--legacy-cmap",
            "--notdef-glyph",
            "--notdef-outline",
            "--recommended-glyphs",
            "--name-IDs=*",
            "--name-legacy",
            "--name-languages=*",
            "--drop-tables+=DSIG",
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"[font] {kind} のサブセット作成に失敗しました", file=sys.stderr)
            print(result.stderr[-2000:], file=sys.stderr)
            return 1
        size_mb = out.stat().st_size / (1024 * 1024)
        print(f"[font] {kind}: {out.name} ({size_mb:.2f} MB)")

    # 検証: 主要な文言がすべて含まれているか
    from fontTools.ttLib import TTFont

    probe = "読分梵別本来名称分類異体字古印影他須任意例吉縁起過去帳版木扁額石塔位牌漢字囲撮影端末写真込範囲切取余白透過調整保存詳細編集削除共有書出元日時作成更新用紙背景自動字形"
    for kind, out in OUTPUT.items():
        font = TTFont(out)
        cmap: set[int] = set()
        for table in font["cmap"].tables:
            cmap |= set(table.cmap.keys())
        missing = sorted({c for c in probe if ord(c) not in cmap})
        if missing:
            print(f"[font] {kind} に不足: {''.join(missing)}", file=sys.stderr)
            return 1
        print(f"[font] {kind} 検証OK（{len(cmap)} 文字）")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
