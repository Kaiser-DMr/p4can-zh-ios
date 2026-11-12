#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把一张"玻璃方块 + 字母"的方图做成 iOS App 图标。

    python3 tools/make-icon.py ~/Pictures/qk9WgCu3EB8TmHAR.webp

做三件事：
1. 画面里的玻璃方块四边是奶油白底、圆角 26%，而 iOS 图标的遮罩圆角约 22.4%，
   直接把方图丢进去，四个角会露出浅色底。所以先按方块的圆角做一圈"挖空"，
   再用扩散（反复模糊 + 回填已知像素）把边缘颜色延伸进四个角 —— 相当于把
   玻璃的边框顺着圆角补满，结果是满铺不留白。
2. 输出 1024×1024、无 alpha 的 PNG（iOS 要求）。
3. 顺带出 180/120/60 三个尺寸和两张桌面预览，便于肉眼验收。
"""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# 默认用仓库里自带的那张源图（ios/图标/源图.webp），也可以传参换一张
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "图标", "源图.webp")
ICON_DIR = os.path.join(ROOT, "P4CAN/Assets.xcassets/AppIcon.appiconset")
OUT_DIR = os.path.join(ROOT, "图标")

SIZE = 1024          # 最终尺寸
CORNER = 0.262       # 源图玻璃方块的圆角占边长比例（实测 109/416）
INSET = 3            # 圆角内侧留 3px 当"已知"，把描边的灰边一起吃掉


def load_plate(path):
    """裁出玻璃方块，正中取最大内接正方形，放大到 SIZE。"""
    im = Image.open(path).convert("RGB")
    w, h = im.size
    # 实测边界（源图 512×512）：左 46 / 上 40 / 右 462 / 下 470
    sx, sy = w / 512.0, h / 512.0
    box = (int(46 * sx), int(40 * sy), int(462 * sx), int(470 * sy))
    plate = im.crop(box)
    # 修成正方形（不拉伸画面）：边长取短边，居中裁
    side = min(plate.size)
    left = (plate.size[0] - side) // 2
    top = (plate.size[1] - side) // 2
    plate = plate.crop((left, top, left + side, top + side))
    return plate.resize((SIZE, SIZE), Image.LANCZOS)


def rounded_alpha(size, ratio, inset=0, feather=1.2):
    """圆角矩形遮罩，255=保留。inset 让已知区往里收，避免描边残留。"""
    ss = 4
    big = size * ss
    r = big * ratio - inset * ss
    mask = Image.new("L", (big, big), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle(
        (inset * ss, inset * ss, big - inset * ss - 1, big - inset * ss - 1),
        radius=r, fill=255)
    mask = mask.resize((size, size), Image.LANCZOS)
    if feather:
        mask = mask.filter(ImageFilter.GaussianBlur(feather))
    return np.asarray(mask, dtype=np.float32) / 255.0


def inpaint_corners(img_arr, known, iterations=90, radius=7, steps=3):
    """扩散补全：每次模糊后把已知像素写回，未知道区域最终由周边环绕色填满。"""
    out = img_arr.copy()
    for _ in range(iterations):
        blurred = np.asarray(
            Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))
            .filter(ImageFilter.GaussianBlur(radius)), dtype=np.float32)
        out = np.where(known[..., None] > 0.5, img_arr, blurred)
    # 补全区单独轻微模糊，去掉扩散留下的一丝条纹
    soft = np.asarray(
        Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))
        .filter(ImageFilter.GaussianBlur(1.4)), dtype=np.float32)
    k = (1.0 - known)[..., None]
    return img_arr * known[..., None] + soft * k


def main():
    plate = load_plate(SRC)
    arr = np.asarray(plate, dtype=np.float32)

    known = rounded_alpha(SIZE, CORNER, inset=INSET, feather=2.0)
    filled = inpaint_corners(arr, known)

    # 角落那一圈过渡再压一道极轻的模糊，避免出现描边断头
    edge = np.asarray(
        Image.fromarray((known * 255).astype(np.uint8))
        .filter(ImageFilter.GaussianBlur(9)), dtype=np.float32) / 255.0
    blend = np.clip((1.0 - edge) * 1.6, 0, 1)[..., None]
    smooth = np.asarray(
        Image.fromarray(np.clip(filled, 0, 255).astype(np.uint8))
        .filter(ImageFilter.GaussianBlur(2.0)), dtype=np.float32)
    final = filled * (1 - blend) + smooth * blend

    icon = Image.fromarray(np.clip(final, 0, 255).astype(np.uint8), "RGB")
    icon = icon.filter(ImageFilter.UnsharpMask(radius=2.2, percent=42, threshold=3))

    os.makedirs(ICON_DIR, exist_ok=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    out = os.path.join(ICON_DIR, "icon-1024.png")
    icon.save(out, optimize=True)          # RGB，无 alpha
    icon.save(os.path.join(OUT_DIR, "icon-1024.png"), optimize=True)

    for px in (180, 120, 60, 40):
        icon.resize((px, px), Image.LANCZOS).save(
            os.path.join(OUT_DIR, f"icon-{px}.png"))

    make_previews(icon)
    icns = make_icns(icon)
    print("wrote", out, icon.size, "|", icns)


def squircle_mask(size, ratio=0.2237):
    """近似 iOS 图标遮罩（超椭圆），用于预览裁切。"""
    n = 5.0
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    c = (size - 1) / 2.0
    # 归一化到 [-1,1]，用超椭圆 |x|^n+|y|^n=1；ratio 控制圆角观感
    k = 1.0 / (1.0 - ratio * 0.0)
    nx = np.abs((xx - c) / c) ** n
    ny = np.abs((yy - c) / c) ** n
    inside = (nx + ny) ** (1.0 / n) <= 1.0
    a = (inside * 255).astype(np.uint8)
    m = Image.fromarray(a, "L").filter(ImageFilter.GaussianBlur(size / 512))
    # 使用前把超椭圆整体内缩一点，贴近 Apple 的实际形状
    return np.asarray(m, dtype=np.float32) / 255.0


def _font(size):
    for p in ("/System/Library/Fonts/SFNS.ttf",
              "/System/Library/Fonts/Helvetica.ttc",
              "/Library/Fonts/Arial.ttf"):
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except OSError:
                continue
    return ImageFont.load_default()


def _wallpaper(size, top, bottom, glow_rgb, glow_at=(0.5, 0.28)):
    """从上到下渐变 + 一团柔光，冒充桌面壁纸。"""
    g = Image.new("RGB", (1, size))
    for y in range(size):
        t = y / (size - 1)
        g.putpixel((0, y), tuple(
            int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    canvas = g.resize((size, size), Image.BILINEAR)
    glow = Image.new("RGB", (size, size), (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gr = int(size * 0.55)
    cx, cy = int(size * glow_at[0]), int(size * glow_at[1])
    gd.ellipse((cx - gr, cy - gr, cx + gr, cy + gr), fill=glow_rgb)
    glow = glow.filter(ImageFilter.GaussianBlur(size // 7))
    return Image.blend(canvas, glow, 0.34)


def _paste_icon(canvas, icon, x, y, px, shadow=True):
    tile = icon.resize((px, px), Image.LANCZOS)
    mask = Image.fromarray(
        (squircle_mask(px, 0.2237) * 255).astype(np.uint8), "L")
    if shadow:
        pad = px // 3
        sh = Image.new("L", (px + pad * 2, px + pad * 2), 0)
        sd = ImageDraw.Draw(sh)
        sd.rounded_rectangle((pad, pad + px // 20, pad + px, pad + px + px // 20),
                             radius=int(px * 0.29), fill=110)
        sh = sh.filter(ImageFilter.GaussianBlur(px // 9))
        dark = Image.new("RGB", sh.size, (0, 0, 0))
        canvas.paste(dark, (x - pad, y - pad), sh)
    canvas.paste(tile, (x, y), mask)


def make_previews(icon):
    """桌面预览：深色 / 浅色壁纸上，60pt 图标 + 图标下方的应用名。"""
    S = 1240
    for name, top, bottom, glow, label_rgb in (
        ("预览-深色桌面.png", (10, 12, 20), (26, 30, 52), (58, 62, 140), (232, 236, 245)),
        ("预览-浅色桌面.png", (214, 220, 236), (246, 244, 250), (255, 255, 255), (28, 30, 38)),
    ):
        canvas = _wallpaper(S, top, bottom, glow)
        px = 180                      # 60pt @3x
        x = (S - px) // 2
        y = int(S * 0.30)
        _paste_icon(canvas, icon, x, y, px)

        d = ImageDraw.Draw(canvas)
        f = _font(38)
        tw = d.textlength("P4-CAN", font=f)
        d.text((x + (px - tw) / 2, y + px + 26), "P4-CAN",
               font=f, fill=label_rgb)

        # 小尺寸对照：90 / 60 / 40 px（30/20/13 pt）
        small = [(132, "44pt"), (90, "29pt"), (60, "20pt")]
        total = sum(s for s, _ in small) + 34 * (len(small) - 1)
        sx = (S - total) // 2
        sy = y + px + 150
        for sp, _ in small:
            _paste_icon(canvas, icon, sx, sy, sp, shadow=False)
            sx += sp + 34
        canvas.save(os.path.join(OUT_DIR, name))


def make_icns(icon):
    """macOS 预览包用的 .icns：按 macOS 惯例留 10% 边距 + 自身投影。"""
    S = 1024
    art = int(S * 0.82)
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    mask = Image.fromarray(
        (squircle_mask(art, 0.2237) * 255).astype(np.uint8), "L")
    tile = icon.resize((art, art), Image.LANCZOS).convert("RGBA")
    tile.putalpha(mask)

    sh = Image.new("L", (S, S), 0)
    sd = ImageDraw.Draw(sh)
    off = int(S * 0.012)
    sd.rounded_rectangle(((S - art) // 2, (S - art) // 2 + off,
                          (S + art) // 2, (S + art) // 2 + off),
                         radius=int(art * 0.29), fill=70)
    sh = sh.filter(ImageFilter.GaussianBlur(S // 60))
    canvas.paste(Image.new("RGBA", (S, S), (0, 0, 0, 255)),
                 (0, 0), sh)
    canvas.alpha_composite(tile, ((S - art) // 2, (S - art) // 2))

    iconset = os.path.join(OUT_DIR, "AppIcon.iconset")
    os.makedirs(iconset, exist_ok=True)
    for base in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            px = base * scale
            nm = (f"icon_{base}x{base}.png" if scale == 1
                  else f"icon_{base}x{base}@2x.png")
            canvas.resize((px, px), Image.LANCZOS).save(
                os.path.join(iconset, nm))
    os.system(f'iconutil -c icns "{iconset}" -o "{OUT_DIR}/AppIcon.icns"')
    return os.path.join(OUT_DIR, "AppIcon.icns")


if __name__ == "__main__":
    main()
