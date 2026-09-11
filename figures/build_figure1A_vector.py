#!/usr/bin/env python3
"""Create a vector/high-resolution replacement for Figure 1A.

The source Figure 1A was embedded in the PowerPoint as a low-resolution
image. This script redraws the same workflow as editable/vector PDF and
high-resolution PNG/TIFF files while preserving the original content and
visual layout.
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from reportlab.lib import colors
from reportlab.pdfbase.pdfmetrics import stringWidth
from reportlab.pdfgen import canvas


from path_config import FIG_DIR

WIDTH_IN = 4.78
HEIGHT_IN = 2.39
DPI = 600
W = 1000.0
H = 500.0

NAVY = "#2D3A57"
TURQ = "#8ED7EE"
SALMON = "#F8B58E"
GREEN = "#9AD37C"
LIGHT_BLUE = "#EAF8FD"
LIGHT_SALMON = "#FFF0E8"
LIGHT_GREY = "#F7F7F7"
ORANGE = "#F4A261"


def pxy(x: float, y: float) -> tuple[int, int]:
    return round(x / W * WIDTH_IN * DPI), round(y / H * HEIGHT_IN * DPI)


def pscale(v: float) -> int:
    return round(v / W * WIDTH_IN * DPI)


def get_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/Library/Fonts/Arial Bold.ttf" if bold else "/Library/Fonts/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for candidate in candidates:
        path = Path(candidate)
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


def wrap_lines(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont, max_width: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        trial = word if not current else f"{current} {word}"
        bbox = draw.textbbox((0, 0), trial, font=font)
        if bbox[2] - bbox[0] <= max_width or not current:
            current = trial
        else:
            lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def draw_centered_text(draw: ImageDraw.ImageDraw, box, text: str, font, fill="black", spacing=2):
    x, y, w, h = box
    max_width = pscale(w * 0.92)
    lines = []
    for part in text.split("\n"):
        lines.extend(wrap_lines(draw, part, font, max_width))
    line_heights = []
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=font)
        line_heights.append(bbox[3] - bbox[1])
    total_h = sum(line_heights) + spacing * max(0, len(lines) - 1)
    top = pxy(x, y)[1] + (pscale(h) - total_h) / 2
    for line, lh in zip(lines, line_heights):
        bbox = draw.textbbox((0, 0), line, font=font)
        tw = bbox[2] - bbox[0]
        left = pxy(x, y)[0] + (pscale(w) - tw) / 2
        draw.text((left, top), line, font=font, fill=fill)
        top += lh + spacing


def draw_arrow_pil(draw, x1, y1, x2, y2, fill=NAVY, width=5):
    p1 = pxy(x1, y1)
    p2 = pxy(x2, y2)
    draw.line([p1, p2], fill=fill, width=width)
    angle = math.atan2(p2[1] - p1[1], p2[0] - p1[0])
    head = 22
    pts = [
        p2,
        (p2[0] - head * math.cos(angle - math.pi / 6), p2[1] - head * math.sin(angle - math.pi / 6)),
        (p2[0] - head * math.cos(angle + math.pi / 6), p2[1] - head * math.sin(angle + math.pi / 6)),
    ]
    draw.polygon(pts, fill=fill)


def draw_box_pil(draw, x, y, w, h, fill="white", outline=NAVY, width=3):
    draw.rectangle([pxy(x, y), pxy(x + w, y + h)], fill=fill, outline=outline, width=width)


def draw_blastocyst_icon(draw, cx, cy, r):
    x, y = pxy(cx, cy)
    rr = pscale(r)
    draw.arc([x - rr, y - rr, x + rr, y + rr], 180, 360, fill=TURQ, width=max(3, rr // 14))
    for i in range(18):
        a = 2 * math.pi * i / 18
        px = x + math.cos(a) * rr * 0.34
        py = y + math.sin(a) * rr * 0.28
        draw.ellipse([px - rr * 0.045, py - rr * 0.045, px + rr * 0.045, py + rr * 0.045],
                     outline=SALMON, width=max(1, rr // 40), fill="#FCE2D4")


def draw_embryo_icon(draw, cx, cy, r):
    x, y = pxy(cx, cy)
    rr = pscale(r)
    for i in range(24):
        a = 2 * math.pi * i / 24
        rad = rr * (0.42 + 0.10 * math.sin(i))
        px = x + math.cos(a) * rad
        py = y + math.sin(a) * rad
        draw.ellipse([px - rr * 0.055, py - rr * 0.055, px + rr * 0.055, py + rr * 0.055],
                     outline=SALMON, width=max(1, rr // 42), fill="#FCE2D4")


def draw_dome_icon(draw, cx, cy, w, h):
    x, y = pxy(cx, cy)
    ww, hh = pscale(w), pscale(h)
    draw.arc([x - ww // 2, y - hh // 2, x + ww // 2, y + hh // 2], 180, 360,
             fill=TURQ, width=max(3, ww // 35))


def draw_cells_icon(draw, cx, cy, r):
    x, y = pxy(cx, cy)
    rr = pscale(r)
    for i in range(7):
        px = x + (i - 3) * rr * 0.38
        py = y + math.sin(i) * rr * 0.12
        draw.ellipse([px - rr * 0.11, py - rr * 0.11, px + rr * 0.11, py + rr * 0.11],
                     fill="#FCE2D4", outline=SALMON, width=max(1, rr // 40))


def draw_dna_icon(draw, cx, cy, scale=1.0, colour=ORANGE):
    x0, y0 = pxy(cx, cy)
    amp = pscale(18 * scale)
    height = pscale(74 * scale)
    steps = 40
    pts1 = []
    pts2 = []
    for i in range(steps):
        t = i / (steps - 1)
        y = y0 - height / 2 + t * height
        x = x0 + math.sin(t * math.pi * 4) * amp
        pts1.append((x, y))
        pts2.append((x0 - math.sin(t * math.pi * 4) * amp, y))
    draw.line(pts1, fill=colour, width=max(2, pscale(2)))
    draw.line(pts2, fill=colour, width=max(2, pscale(2)))
    for i in range(0, steps, 5):
        draw.line([pts1[i], pts2[i]], fill=colour, width=max(1, pscale(1)))


def draw_chart_icon(draw, x, y, w, h):
    x0, y0 = pxy(x, y)
    ww, hh = pscale(w), pscale(h)
    draw.line([(x0, y0 + hh), (x0 + ww * 0.75, y0 + hh)], fill="#999999", width=2)
    draw.line([(x0, y0 + hh), (x0, y0 + hh * 0.10)], fill="#999999", width=2)
    for i in range(7):
        px = x0 + ww * (0.18 + 0.10 * (i % 3))
        py = y0 + hh * (0.20 + 0.12 * i)
        draw.ellipse([px - 7, py - 7, px + 7, py + 7], fill="#8DD7ED")
    for i in range(4):
        draw.rectangle([x0 + ww * 0.08, y0 + hh * (0.58 + 0.10 * i),
                        x0 + ww * (0.70 - 0.08 * i), y0 + hh * (0.64 + 0.10 * i)],
                       fill=GREEN)


def build_raster(out_png: Path, out_tiff: Path) -> None:
    img = Image.new("RGB", (round(WIDTH_IN * DPI), round(HEIGHT_IN * DPI)), "white")
    draw = ImageDraw.Draw(img)
    title_font = get_font(34, True)
    header_font = get_font(27, True)
    label_font = get_font(25, False)
    small_font = get_font(22, False)
    bold_small = get_font(22, True)

    draw.text(pxy(18, 8), "Experimental workflow for cfRNA profiling from embryos and spent media.",
              font=title_font, fill="black")

    # Left sample column
    draw_box_pil(draw, 20, 72, 150, 92)
    draw_blastocyst_icon(draw, 95, 110, 42)
    draw_centered_text(draw, (20, 126, 150, 36), "Culture\nZona-free\nblastocyst", label_font)

    draw_box_pil(draw, 20, 215, 150, 92)
    draw_embryo_icon(draw, 95, 250, 48)
    draw_centered_text(draw, (20, 270, 150, 32), "Whole Embryo", label_font)

    draw_box_pil(draw, 20, 350, 150, 92)
    draw_dome_icon(draw, 95, 385, 95, 58)
    draw_centered_text(draw, (20, 407, 150, 28), "Spent Media", label_font)

    draw_arrow_pil(draw, 95, 165, 95, 205)

    # Top CNV row
    draw_arrow_pil(draw, 200, 118, 240, 118)
    draw_box_pil(draw, 270, 72, 150, 92)
    draw_cells_icon(draw, 345, 110, 50)
    draw_centered_text(draw, (270, 125, 150, 30), "Trophectoderm\nbiopsied", label_font)
    draw_arrow_pil(draw, 450, 118, 490, 118)
    draw.text(pxy(497, 126), "WGA", font=small_font, fill="black")
    draw_box_pil(draw, 515, 72, 465, 92)
    draw_dna_icon(draw, 585, 110, 0.75, colour="#6D8CC3")
    draw.text(pxy(620, 121), "DNA", font=small_font, fill="black")
    draw.text(pxy(750, 94), "CNV analysis", font=header_font, fill="black")
    draw.text(pxy(742, 132), "Ploidy determination", font=small_font, fill="black")
    draw.text(pxy(515, 171), "Mosaic and Polyploid samples were excluded.", font=small_font, fill="black")

    # RNA-seq rows
    draw_arrow_pil(draw, 185, 250, 230, 250)
    draw.text(pxy(193, 272), "RNA\nExtraction", font=small_font, fill="black")
    draw_box_pil(draw, 275, 215, 490, 92)
    draw.text(pxy(285, 204), "Used RamDA-seq for library preparation", font=bold_small, fill="black")
    draw_dna_icon(draw, 375, 250, 0.70, colour=ORANGE)
    draw_centered_text(draw, (315, 268, 135, 32), "Total RNA\nfrom Whole Embryo", small_font)
    draw.text(pxy(600, 232), "RNA-seq", font=header_font, fill="black")
    draw.text(pxy(500, 270), "Euploid Whole Embryo : EWE", font=small_font, fill="black")
    draw.text(pxy(500, 296), "Aneuploid Whole Embryo : AWE", font=small_font, fill="black")

    draw_arrow_pil(draw, 185, 385, 230, 385)
    draw.text(pxy(195, 407), "RNA\nPurification", font=small_font, fill="black")
    draw_box_pil(draw, 275, 350, 490, 92)
    draw_dna_icon(draw, 375, 385, 0.70, colour=ORANGE)
    draw_centered_text(draw, (315, 404, 135, 32), "Total RNA\nfrom Spent Media", small_font)
    draw.text(pxy(600, 367), "RNA-seq", font=header_font, fill="black")
    draw.text(pxy(510, 405), "Euploid Spent Media : ESM", font=small_font, fill="black")
    draw.text(pxy(510, 430), "Aneuploid Spent Media : ASM", font=small_font, fill="black")

    # Downstream analysis
    draw_arrow_pil(draw, 790, 285, 830, 285)
    draw_arrow_pil(draw, 790, 400, 830, 400)
    draw_box_pil(draw, 850, 215, 130, 227)
    draw.text(pxy(858, 230), "Downstream", font=header_font, fill="black")
    draw.text(pxy(875, 262), "analysis", font=header_font, fill="black")
    draw_chart_icon(draw, 885, 305, 85, 105)

    out_png.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_png, dpi=(DPI, DPI))
    img.save(out_tiff, dpi=(DPI, DPI), compression="tiff_lzw")


def pdf_xy(x: float, y: float) -> tuple[float, float]:
    return x / W * WIDTH_IN * 72, HEIGHT_IN * 72 - y / H * HEIGHT_IN * 72


def pdf_box(c: canvas.Canvas, x, y, w, h, fill=colors.white):
    px, py = pdf_xy(x, y + h)
    c.setStrokeColor(colors.HexColor(NAVY))
    c.setFillColor(fill)
    c.setLineWidth(0.8)
    c.rect(px, py, w / W * WIDTH_IN * 72, h / H * HEIGHT_IN * 72, stroke=1, fill=1)


def pdf_text(c, x, y, text, size=7, bold=False, center=False):
    font = "Helvetica-Bold" if bold else "Helvetica"
    c.setFont(font, size)
    c.setFillColor(colors.black)
    px, py = pdf_xy(x, y)
    if center:
        px -= stringWidth(text, font, size) / 2
    c.drawString(px, py, text)


def pdf_arrow(c, x1, y1, x2, y2):
    p1 = pdf_xy(x1, y1)
    p2 = pdf_xy(x2, y2)
    c.setStrokeColor(colors.HexColor(NAVY))
    c.setFillColor(colors.HexColor(NAVY))
    c.setLineWidth(1.0)
    c.line(*p1, *p2)
    angle = math.atan2(p2[1] - p1[1], p2[0] - p1[0])
    head = 5
    pts = [
        p2,
        (p2[0] - head * math.cos(angle - math.pi / 6), p2[1] - head * math.sin(angle - math.pi / 6)),
        (p2[0] - head * math.cos(angle + math.pi / 6), p2[1] - head * math.sin(angle + math.pi / 6)),
    ]
    path = c.beginPath()
    path.moveTo(*pts[0])
    path.lineTo(*pts[1])
    path.lineTo(*pts[2])
    path.close()
    c.drawPath(path, stroke=0, fill=1)


def build_pdf(out_pdf: Path) -> None:
    out_pdf.parent.mkdir(parents=True, exist_ok=True)
    c = canvas.Canvas(str(out_pdf), pagesize=(WIDTH_IN * 72, HEIGHT_IN * 72))
    pdf_text(c, 18, 28, "Experimental workflow for cfRNA profiling from embryos and spent media.", 8.8, True)

    # Vector schematic approximating the raster output.
    for x, y, w, h in [
        (20, 72, 150, 92), (20, 215, 150, 92), (20, 350, 150, 92),
        (270, 72, 150, 92), (515, 72, 465, 92),
        (275, 215, 490, 92), (275, 350, 490, 92), (850, 215, 130, 227)
    ]:
        pdf_box(c, x, y, w, h)
    pdf_arrow(c, 95, 165, 95, 205)
    pdf_arrow(c, 200, 118, 240, 118)
    pdf_arrow(c, 450, 118, 490, 118)
    pdf_arrow(c, 185, 250, 230, 250)
    pdf_arrow(c, 185, 385, 230, 385)
    pdf_arrow(c, 790, 285, 830, 285)
    pdf_arrow(c, 790, 400, 830, 400)

    # Text-only vector layer. Icons are schematic but simple vector marks.
    labels = [
        (95, 146, "Culture", 6, True), (95, 160, "Zona-free", 6, True), (95, 174, "blastocyst", 6, True),
        (345, 145, "Trophectoderm", 6, False), (345, 160, "biopsied", 6, False),
        (750, 100, "CNV analysis", 8, True), (742, 137, "Ploidy determination", 6.4, False),
        (515, 179, "Mosaic and Polyploid samples were excluded.", 6.4, False),
        (95, 288, "Whole Embryo", 6.5, False), (95, 425, "Spent Media", 6.5, False),
        (285, 210, "Used RamDA-seq for library preparation", 6.5, True),
        (600, 238, "RNA-seq", 8, True), (500, 276, "Euploid Whole Embryo : EWE", 6.4, False),
        (500, 302, "Aneuploid Whole Embryo : AWE", 6.4, False),
        (600, 373, "RNA-seq", 8, True), (510, 411, "Euploid Spent Media : ESM", 6.4, False),
        (510, 436, "Aneuploid Spent Media : ASM", 6.4, False),
        (858, 238, "Downstream", 8, True), (875, 270, "analysis", 8, True),
        (497, 132, "WGA", 6.4, False), (620, 127, "DNA", 6.4, False),
    ]
    for x, y, text, size, bold in labels:
        pdf_text(c, x, y, text, size, bold, center=False)

    # Simple vector icons.
    c.setStrokeColor(colors.HexColor(TURQ))
    c.setLineWidth(1.0)
    for cx, cy in [(95, 110), (95, 385)]:
        px, py = pdf_xy(cx - 38, cy + 18)
        c.arc(px, py, px + 76 / W * WIDTH_IN * 72, py + 40 / H * HEIGHT_IN * 72, 0, 180)
    c.setFillColor(colors.HexColor("#FCE2D4"))
    c.setStrokeColor(colors.HexColor(SALMON))
    for i in range(18):
        a = 2 * math.pi * i / 18
        x = 95 + math.cos(a) * 16
        y = 110 + math.sin(a) * 12
        px, py = pdf_xy(x, y)
        c.circle(px, py, 1.5, stroke=1, fill=1)
    for i in range(24):
        a = 2 * math.pi * i / 24
        x = 95 + math.cos(a) * 25
        y = 250 + math.sin(a) * 22
        px, py = pdf_xy(x, y)
        c.circle(px, py, 1.5, stroke=1, fill=1)
    c.showPage()
    c.save()


def main() -> None:
    FIG_DIR.mkdir(parents=True, exist_ok=True)
    out_png = FIG_DIR / "Figure1A_Workflow_vector.png"
    out_tiff = FIG_DIR / "Figure1A_Workflow_vector.tiff"
    out_pdf = FIG_DIR / "Figure1A_Workflow_vector.pdf"
    build_raster(out_png, out_tiff)
    build_pdf(out_pdf)
    print(out_pdf)
    print(out_png)
    print(out_tiff)


if __name__ == "__main__":
    main()

