#!/usr/bin/env python3
"""生成 CueBox 应用图标：蓝色圆角盒子 + 白色内盒 + 蓝色播放三角（极简扁平）。

无第三方依赖，直接输出各平台所需 PNG/ICO。
"""

import json
import math
import os
import struct
import zlib

BLUE = (30, 111, 232)  # #1E6FE8
WHITE = (255, 255, 255)


def clamp(v, lo=0.0, hi=1.0):
    return lo if v < lo else (hi if v > hi else v)


def sd_rounded_rect(x, y, cx, cy, hw, hh, r):
    qx = abs(x - cx) - (hw - r)
    qy = abs(y - cy) - (hh - r)
    ax = max(qx, 0.0)
    ay = max(qy, 0.0)
    return math.hypot(ax, ay) - r + min(max(qx, qy), 0.0)


def sd_play_triangle(x, y, s):
    """右侧播放三角的带符号距离（内部为负）。"""
    lx = 0.37 * s
    rx = 0.63 * s
    top = 0.35 * s
    bottom = 0.65 * s
    cy = 0.5 * s

    if x < lx:
        if y < top:
            return math.hypot(lx - x, top - y)
        if y > bottom:
            return math.hypot(lx - x, y - bottom)
        return lx - x
    if x > rx:
        return math.hypot(x - rx, y - cy)

    half_h = (bottom - top) / 2.0
    w = rx - lx
    length = math.hypot(w, half_h)
    line_top = top + half_h * (x - lx) / w
    line_bottom = bottom - half_h * (x - lx) / w
    if y < line_top:
        return (half_h * (x - lx) - w * (y - top)) / length
    if y > line_bottom:
        return (w * (y - bottom) + half_h * (x - lx)) / length

    d_top = (w * (y - top) - half_h * (x - lx)) / length
    d_bottom = (w * (bottom - y) - half_h * (x - lx)) / length
    return -min(d_top, d_bottom, x - lx)


def render(size):
    """渲染指定尺寸的 RGBA 字节流。"""
    buf = bytearray(size * size * 4)
    half = size / 2.0
    outer_r = 0.22 * size
    inner_half = half - 0.155 * size
    inner_r = 0.115 * size
    for y in range(size):
        for x in range(size):
            px = x + 0.5
            py = y + 0.5
            a_outer = clamp(0.5 - sd_rounded_rect(px, py, half, half, half, half, outer_r))
            if a_outer <= 0:
                continue
            r, g, b = BLUE
            a_inner = clamp(0.5 - sd_rounded_rect(px, py, half, half, inner_half, inner_half, inner_r))
            if a_inner > 0:
                r += (WHITE[0] - r) * a_inner
                g += (WHITE[1] - g) * a_inner
                b += (WHITE[2] - b) * a_inner
            a_tri = clamp(0.5 - sd_play_triangle(px, py, size))
            if a_tri > 0:
                r += (BLUE[0] - r) * a_tri
                g += (BLUE[1] - g) * a_tri
                b += (BLUE[2] - b) * a_tri
            idx = (y * size + x) * 4
            buf[idx] = int(round(r))
            buf[idx + 1] = int(round(g))
            buf[idx + 2] = int(round(b))
            buf[idx + 3] = int(round(a_outer * 255))
    return bytes(buf)


def write_png(path, size, rgba):
    raw = bytearray()
    for y in range(size):
        raw.append(0)
        raw.extend(rgba[y * size * 4 : (y + 1) * size * 4])

    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def _bmp_icon_entry(size, rgba):
    """小尺寸用 BMP DIB 数据（Windows 资源编译器要求，不能全用 PNG）。"""
    xor = bytearray()
    for y in range(size - 1, -1, -1):
        xor.extend(rgba[y * size * 4 : (y + 1) * size * 4])
    mask_row_bytes = ((size + 31) // 32) * 4
    mask = bytearray(mask_row_bytes * size)
    header = struct.pack(
        "<IiiHHIIiiII",
        40,
        size,
        size * 2,
        1,
        32,
        0,
        size * size * 4 + len(mask),
        0,
        0,
        0,
        0,
    )
    return bytes(header) + bytes(xor) + bytes(mask)


def write_ico(path):
    """全部尺寸用 BMP DIB，兼容 Windows 资源编译器 rc.exe。"""
    entries = [
        (size, _bmp_icon_entry(size, render(size)))
        for size in (16, 32, 48, 256)
    ]
    header = struct.pack("<HHH", 0, 1, len(entries))
    offset = 6 + 16 * len(entries)
    dir_data = b""
    blobs = b""
    for size, data in entries:
        b = 0 if size >= 256 else size
        dir_data += struct.pack("<BBBBHHII", b, b, 0, 0, 1, 32, len(data), offset)
        offset += len(data)
        blobs += data
    with open(path, "wb") as f:
        f.write(header + dir_data + blobs)


def parse_icon_set(contents_path, out_dir):
    with open(contents_path) as f:
        data = json.load(f)
    for img in data["images"]:
        if "filename" not in img:
            continue
        w, h = (float(v) for v in img["size"].split("x"))
        scale = int(img["scale"].rstrip("x")) if img["scale"] != "1x" else 1
        pixel = int(round(w * scale))
        out = os.path.join(out_dir, img["filename"])
        write_png(out, pixel, render(pixel))
        print(f"  {out} ({pixel}x{pixel})")


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    print("macOS AppIcon:")
    parse_icon_set(
        os.path.join(root, "macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json"),
        os.path.join(root, "macos/Runner/Assets.xcassets/AppIcon.appiconset"),
    )
    print("iOS AppIcon:")
    parse_icon_set(
        os.path.join(root, "ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json"),
        os.path.join(root, "ios/Runner/Assets.xcassets/AppIcon.appiconset"),
    )
    print("Android mipmaps:")
    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in android_sizes.items():
        path = os.path.join(root, "android/app/src/main/res", folder, "ic_launcher.png")
        write_png(path, size, render(size))
        print(f"  {path} ({size}x{size})")

    print("Windows ICO:")
    ico_path = os.path.join(root, "windows/runner/resources/app_icon.ico")
    write_ico(ico_path)
    print(f"  {ico_path}")

    master = os.path.join(root, "tool/app_icon_master.png")
    write_png(master, 1024, render(1024))
    print(f"Master: {master}")


if __name__ == "__main__":
    main()
