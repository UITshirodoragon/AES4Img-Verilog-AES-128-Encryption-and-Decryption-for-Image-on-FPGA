#!/usr/bin/env python3
"""
Convert image to 320x240 RGB565 HEX and MIF files.
Usage:
  python tools/convert_image_to_rgb565_hex.py input.png --out-prefix image_320x240_rgb565
"""
from __future__ import annotations
import argparse
from pathlib import Path
from PIL import Image


def rgb_to_rgb565(r: int, g: int, b: int) -> int:
    return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("--width", type=int, default=320)
    ap.add_argument("--height", type=int, default=240)
    ap.add_argument("--out-prefix", default="image_320x240_rgb565")
    args = ap.parse_args()

    img = Image.open(args.image).convert("RGB").resize((args.width, args.height), Image.BILINEAR)
    values = []
    for y in range(args.height):
        for x in range(args.width):
            r, g, b = img.getpixel((x, y))
            values.append(rgb_to_rgb565(r, g, b))

    prefix = Path(args.out_prefix)
    hex_path = prefix.with_suffix(".hex")
    mif_path = prefix.with_suffix(".mif")
    hex_path.write_text("\n".join(f"{v:04X}" for v in values) + "\n")

    lines = [
        "WIDTH=16;",
        f"DEPTH={len(values)};",
        "",
        "ADDRESS_RADIX=HEX;",
        "DATA_RADIX=HEX;",
        "",
        "CONTENT BEGIN",
    ]
    for i, v in enumerate(values):
        lines.append(f"    {i:05X} : {v:04X};")
    lines.append("END;")
    mif_path.write_text("\n".join(lines) + "\n")
    print(f"Wrote {hex_path} and {mif_path}")

if __name__ == "__main__":
    main()
