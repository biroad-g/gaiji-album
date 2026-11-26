#!/usr/bin/env python3
"""アプリアイコンを Android / Web へ組み込む（案A 金箔・截金用）。

案Aは「金の円環」が画面の端近くまで来ているため、単純に縮小するだけだと
Android のアダプティブアイコンで円環が欠けてしまう。

アダプティブアイコンの決まりごと:
  * 前景画像は 108dp 角。このうち中央 72dp の円（＝セーフゾーン）だけが
    必ず表示される。外周 18dp はずれ・機種差で切られる。
  * つまり前景全体の 約66%（72/108）の内側に主役を収める必要がある。

そこでこのスクリプトは:
  1. 元画像から「円環を含む正方形」を切り出す
  2. 前景用は、円環が 66% の内側に収まるまで縮小して中央に置く
     （地の黒で周囲を埋めるので、切られても違和感が出ない）
  3. 背景色は画像から採取した地の黒をそのまま使う
  4. 旧式の ic_launcher.png / ic_launcher_round.png は全画面版を出力
  5. Web 用アイコンと favicon も同じ意匠で出力
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent

# 元画像はリポジトリ内の assets/icon/app_icon.png を正本とする。
# （リポジトリ外の作業用コピーしか無い場合だけそちらを使う）
_CANDIDATES = [
    ROOT / "assets" / "icon" / "app_icon.png",
    ROOT.parent / "assets" / "icons" / "app_icon.png",
]
SOURCE = next((p for p in _CANDIDATES if p.exists()), _CANDIDATES[0])
RES = ROOT / "android" / "app" / "src" / "main" / "res"
WEB = ROOT / "web"

# アダプティブアイコンの前景サイズ（dp に対する px の倍率）
FOREGROUND = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}

# 旧式アイコン（アダプティブ非対応端末・ストア表示用）
LEGACY = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# セーフゾーン: 前景 108dp のうち中央 72dp が必ず見える → 0.667
SAFE_RATIO = 72.0 / 108.0

# 円環は「セーフゾーンの 96%」までに収める（端に触れると欠けて見えるため）
TARGET_SPAN = SAFE_RATIO * 0.96

# 最外周にある細い金の枠線は、丸く切られると汚く見えるので取り除く
BORDER_CROP = 0.022


def background_color(img: Image.Image) -> tuple[int, int, int]:
    """地の黒を決める。

    四隅は金箔や外周の枠線が乗っていることがあるため、最も多い暗い色を採る。
    """
    w, h = img.size
    counter: dict[tuple[int, int, int], int] = {}
    for y in range(int(h * 0.05), int(h * 0.95), 3):
        for x in range(int(w * 0.05), int(w * 0.95), 3):
            p = img.getpixel((x, y))
            lum = 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]
            if lum > 70:
                continue  # 金の部分は除く
            key = (p[0] // 4 * 4, p[1] // 4 * 4, p[2] // 4 * 4)
            counter[key] = counter.get(key, 0) + 1
    if not counter:
        return (12, 10, 4)
    return max(counter.items(), key=lambda kv: kv[1])[0]


def square_crop(img: Image.Image) -> Image.Image:
    side = min(img.size)
    left = (img.width - side) // 2
    top = (img.height - side) // 2
    cropped = img.crop((left, top, left + side, top + side))
    # 外周の細い枠線を落とす
    margin = int(cropped.width * BORDER_CROP)
    return cropped.crop(
        (margin, margin, cropped.width - margin, cropped.height - margin)
    )


def art_span(img: Image.Image) -> float:
    """金色の意匠（円環）が画面のどれだけを占めているかを 0〜1 で返す。

    暗い地を除いた「明るい画素」の外接矩形の長辺を、画像の一辺で割る。
    ただし金箔の飛沫のような孤立した点は無視したいので、
    「その行（列）の 2% 以上が明るい」ものだけを意匠の範囲とみなす。
    こうしておけば、元画像の構図が変わっても適切な縮小率を自動で決められる。
    """
    n = 160
    small = img.resize((n, n), Image.Resampling.BILINEAR)
    px = small.load()
    rows = [0] * n
    cols = [0] * n
    for y in range(n):
        for x in range(n):
            p = px[x, y]
            lum = 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]
            if lum > 90:
                rows[y] += 1
                cols[x] += 1
    need = max(2, int(n * 0.02))
    ys = [i for i, c in enumerate(rows) if c >= need]
    xs = [i for i, c in enumerate(cols) if c >= need]
    if not ys or not xs:
        return 1.0
    span = max(xs[-1] - xs[0] + 1, ys[-1] - ys[0] + 1) / n
    return min(1.0, span)


def make_foreground(
    src: Image.Image,
    size: int,
    bg: tuple[int, int, int],
    span: float,
) -> Image.Image:
    """セーフゾーン内に主役が収まる前景画像を作る。

    span は元画像における意匠の占有率。これを TARGET_SPAN まで縮める。
    """
    canvas = Image.new("RGB", (size, size), bg)
    ratio = min(1.0, TARGET_SPAN / max(span, 1e-6))
    inner = max(1, int(round(size * ratio)))
    art = src.resize((inner, inner), Image.Resampling.LANCZOS)
    offset = (size - inner) // 2
    canvas.paste(art, (offset, offset))
    return canvas


def make_full_bleed(src: Image.Image, size: int, rounded: bool) -> Image.Image:
    """全画面のアイコン（角丸にする場合は円形マスク）。"""
    art = src.resize((size, size), Image.Resampling.LANCZOS)
    if not rounded:
        return art
    mask = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size * 4 - 1, size * 4 - 1), fill=255)
    mask = mask.resize((size, size), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(art, (0, 0), mask)
    return out


def main() -> int:
    if not SOURCE.exists():
        print(f"[icon] 元画像が見つかりません: {SOURCE}", flush=True)
        return 1

    src = square_crop(Image.open(SOURCE).convert("RGB"))
    bg = background_color(src)
    span = art_span(src)
    print(
        f"[icon] 元画像: {src.size} / 地の色: {bg} / 意匠の占有率: {span:.3f}"
        f" → セーフゾーン目標: {TARGET_SPAN:.3f}",
        flush=True,
    )

    # --- Android アダプティブ前景 ---
    for folder, size in FOREGROUND.items():
        path = RES / folder / "ic_launcher_foreground.png"
        make_foreground(src, size, bg, span).save(path, optimize=True)
        print(f"[icon] {folder}/ic_launcher_foreground.png ({size}px)")

    # --- Android 旧式アイコン ---
    for folder, size in LEGACY.items():
        art = make_full_bleed(src, size, rounded=False)
        art.save(RES / folder / "ic_launcher.png", optimize=True)
        make_full_bleed(src, size, rounded=True).save(
            RES / folder / "ic_launcher_round.png", optimize=True
        )
        print(f"[icon] {folder}/ic_launcher.png + round ({size}px)")

    # --- 背景色を地の色に合わせる（アダプティブ前景の縁と一致させる） ---
    colors_xml = RES / "values" / "colors.xml"
    hex_color = "#%02X%02X%02X" % bg
    colors_xml.write_text(
        "<resources>\n"
        f'    <color name="ic_launcher_background">{hex_color}</color>\n'
        "</resources>\n",
        encoding="utf-8",
    )
    print(f"[icon] ic_launcher_background = {hex_color}")

    # --- Web ---
    WEB.mkdir(parents=True, exist_ok=True)
    (WEB / "icons").mkdir(exist_ok=True)
    make_full_bleed(src, 512, rounded=False).save(WEB / "icons" / "Icon-512.png", optimize=True)
    make_full_bleed(src, 192, rounded=False).save(WEB / "icons" / "Icon-192.png", optimize=True)

    # マスカブル: 外周が切られても主役が残るよう、少し内側に寄せる
    make_foreground(src, 512, bg, span).save(
        WEB / "icons" / "Icon-maskable-512.png", optimize=True
    )
    make_foreground(src, 192, bg, span).save(
        WEB / "icons" / "Icon-maskable-192.png", optimize=True
    )

    make_full_bleed(src, 64, rounded=False).save(WEB / "favicon.png", optimize=True)
    print("[icon] Web アイコン（192 / 512 / maskable / favicon）")

    # --- 確認用 ---
    preview = make_foreground(src, 432, bg, span)
    preview.resize((216, 216), Image.Resampling.LANCZOS).save(
        Path("/tmp/icon_preview_foreground.png"), optimize=True
    )
    print("[icon] 完了", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
