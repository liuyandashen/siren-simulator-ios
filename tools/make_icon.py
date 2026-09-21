"""纯标准库生成 App 图标（1024x1024 PNG），不依赖 Pillow。

用法： python3 tools/make_icon.py
输出： SirenSimulator/Assets.xcassets/AppIcon.appiconset/AppIcon.png
"""

import math
import os
import struct
import zlib

S = 1024
OUT = "SirenSimulator/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

img = bytearray(S * S * 3)


def paint(x, y, color, alpha=1.0):
    if not (0 <= x < S and 0 <= y < S):
        return
    i = (y * S + x) * 3
    if alpha >= 1.0:
        img[i] = color[0]
        img[i + 1] = color[1]
        img[i + 2] = color[2]
    else:
        ia = 1.0 - alpha
        img[i] = int(img[i] * ia + color[0] * alpha)
        img[i + 1] = int(img[i + 1] * ia + color[1] * alpha)
        img[i + 2] = int(img[i + 2] * ia + color[2] * alpha)


def lerp(a, b, t):
    return a + (b - a) * t


# ---------- 背景：竖向渐变 ----------
for y in range(S):
    t = y / (S - 1)
    r = int(lerp(9, 23, t))
    g = int(lerp(12, 24, t))
    b = int(lerp(22, 44, t))
    img[y * S * 3:(y + 1) * S * 3] = bytes((r, g, b)) * S


# ---------- 形状工具 ----------
def rounded_rect(x0, y0, x1, y1, radius, color, alpha=1.0):
    r2 = radius * radius
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            cx = min(max(x, x0 + radius), x1 - radius)
            cy = min(max(y, y0 + radius), y1 - radius)
            dx = x - cx
            dy = y - cy
            if dx * dx + dy * dy <= r2:
                paint(x, y, color, alpha)


def circle(cx, cy, radius, color, alpha=1.0):
    r2 = radius * radius
    for y in range(int(cy - radius), int(cy + radius) + 1):
        dy = y - cy
        for x in range(int(cx - radius), int(cx + radius) + 1):
            dx = x - cx
            if dx * dx + dy * dy <= r2:
                paint(x, y, color, alpha)


def arc(cx, cy, radius, width, a0, a1, color, alpha=1.0):
    inner = radius - width

    # 只遍历该角度扇区的包围盒，避免全圆扫描
    xs, ys = [], []
    for i in range(65):
        ang = math.radians(a0 + (a1 - a0) * i / 64.0)
        ca, sa = math.cos(ang), math.sin(ang)
        xs += [ca * radius, ca * inner]
        ys += [sa * radius, sa * inner]
    x0, x1 = int(cx + min(xs)), int(cx + max(xs))
    y0, y1 = int(cy + min(ys)), int(cy + max(ys))

    for y in range(max(0, y0), min(S - 1, y1) + 1):
        dy = y - cy
        for x in range(max(0, x0), min(S - 1, x1) + 1):
            dx = x - cx
            d = math.hypot(dx, dy)
            if d < inner or d > radius:
                continue
            ang = math.degrees(math.atan2(dy, dx)) % 360.0
            if a0 <= a1:
                inside = a0 <= ang <= a1
            else:
                inside = ang >= a0 or ang <= a1
            if inside:
                paint(x, y, color, alpha)


# ---------- 顶部警灯条 ----------
BAR = [
    (255, 150, 20),
    (255, 255, 255),
    (255, 255, 255),
    (255, 150, 20),
    (255, 60, 60),
    (255, 60, 60),
]
margin, gap = 116, 18
bw = (S - margin * 2 - gap * (len(BAR) - 1)) / len(BAR)
by0, by1 = 180, 292

for i, c in enumerate(BAR):
    x0 = margin + i * (bw + gap)
    x1 = x0 + bw
    rounded_rect(x0 - 24, by0 - 24, x1 + 24, by1 + 24, 44, c, 0.16)   # 光晕
    rounded_rect(x0, by0, x1, by1, 18, c, 1.0)                        # 灯块

# ---------- 警报器主体 ----------
CX, CY, R = S // 2, 660, 168
circle(CX, CY, R, (236, 241, 251), 1.0)                  # 顶灯
rounded_rect(CX - 228, CY - 12, CX + 228, CY + 88, 26, (54, 62, 78), 1.0)   # 底座
rounded_rect(CX - 148, CY + 68, CX + 148, CY + 122, 20, (32, 38, 50), 1.0)  # 脚座

# ---------- 两侧声波 ----------
for radius, alpha in ((296, 0.30), (372, 0.22)):
    for a0, a1 in ((-42, 42), (138, 222)):
        arc(CX, CY, radius + 10, 34, a0, a1, (255, 140, 40), alpha * 0.5)  # 外发光
        arc(CX, CY, radius, 26, a0, a1, (255, 150, 40), alpha + 0.55)      # 弧线

# ---------- 写 PNG ----------
raw = bytearray()
for y in range(S):
    raw.append(0)  # filter type 0
    raw += img[y * S * 3:(y + 1) * S * 3]


def chunk(tag, data):
    return (struct.pack(">I", len(data)) + tag + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))


png = b"\x89PNG\r\n\x1a\n"
png += chunk(b"IHDR", struct.pack(">IIBBBBB", S, S, 8, 2, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
png += chunk(b"IEND", b"")

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "wb") as f:
    f.write(png)
print("icon written:", OUT, len(png), "bytes")
