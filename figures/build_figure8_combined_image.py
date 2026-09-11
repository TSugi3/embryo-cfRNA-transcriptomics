#!/usr/bin/env python3
"""Compose final Figure 8 panels into a high-resolution raster image."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


from path_config import BASE_DIR, FIG_DIR

# Publication guide maximum page dimensions are 180 mm wide by 170 mm tall.
# At 600 dpi this corresponds approximately to 4252 x 4016 px.
CANVAS_IN = (180 / 25.4, 170 / 25.4)
DPI = 600
CANVAS_PX = (int(CANVAS_IN[0] * DPI), int(CANVAS_IN[1] * DPI))


def paste_fit(canvas: Image.Image, filename: str, left_in: float, top_in: float,
              width_in: float, height_in: float) -> None:
    img = Image.open(FIG_DIR / filename).convert("RGBA")
    target = (int(width_in * DPI), int(height_in * DPI))
    img = img.resize(target, Image.Resampling.LANCZOS)
    canvas.alpha_composite(img, (int(left_in * DPI), int(top_in * DPI)))


def main() -> None:
    canvas = Image.new("RGBA", CANVAS_PX, "white")
    draw = ImageDraw.Draw(canvas)
    try:
        font = ImageFont.truetype("/Library/Fonts/Arial.ttf", 9 * DPI // 72)
    except OSError:
        font = ImageFont.load_default()
    draw.text((0, 0), "Figure 8", fill="black", font=font)

    paste_fit(canvas, "Figure8A_CQ_GSEA_dotplot.png", 0.05, 0.30, 3.50, 2.78)
    paste_fit(canvas, "Figure8B_CQ_WE_gene_boxplot.png", 3.58, 0.30, 3.37, 1.96)
    paste_fit(canvas, "Figure8C_CQ_SM_release_barplot.png", 0.20, 3.48, 3.27, 1.68)
    paste_fit(canvas, "Figure8D_CB_GSEA_dotplot.png", 3.58, 2.85, 3.50, 2.78)

    rgb = canvas.convert("RGB")
    rgb.save(FIG_DIR / "Figure8_MouseValidation_Combined.png", dpi=(DPI, DPI))
    rgb.save(FIG_DIR / "Figure8_MouseValidation_Combined.tiff", compression="tiff_lzw", dpi=(DPI, DPI))
    print(FIG_DIR / "Figure8_MouseValidation_Combined.png")


if __name__ == "__main__":
    main()
