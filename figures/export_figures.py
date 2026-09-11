#!/usr/bin/env python3
"""Export manuscript figure PPTX files to publication PNG/TIFF/PDF deliverables."""

from __future__ import annotations

import argparse
import csv
import io
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from pptx import Presentation
from pptx.enum.shapes import MSO_SHAPE_TYPE
from reportlab.lib.pagesizes import A4
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas


EMU_PER_INCH = 914400
MM_PER_INCH = 25.4


FIGURE_ORDER = [
    ("Figure1", "Figure1_editable.pptx"),
    ("Figure2", "Figure2_editable.pptx"),
    ("Figure3", "Figure3_editable.pptx"),
    ("Figure4", "Figure4_editable.pptx"),
    ("Figure5", "Figure5_editable.pptx"),
    ("Figure6", "Figure6_editable.pptx"),
    ("Figure7", "Figure7_editable.pptx"),
    ("Figure8", "Figure8_editable.pptx"),
    ("ExtendedDataFigure1", "ExtendedDataFigure1_editable.pptx"),
    ("ExtendedDataFigure2", "ExtendedDataFigure2_editable.pptx"),
    ("ExtendedDataFigure3", "ExtendedDataFigure3_editable.pptx"),
    ("ExtendedDataFigure4", "ExtendedDataFigure4_editable.pptx"),
    ("ExtendedDataFigure5", "ExtendedDataFigure5_editable.pptx"),
    ("ExtendedDataFigure6", "ExtendedDataFigure6_editable.pptx"),
    ("ExtendedDataFigure7", "ExtendedDataFigure7_editable.pptx"),
    ("ExtendedDataFigure8", "ExtendedDataFigure8_editable.pptx"),
    ("ExtendedDataFigure9", "ExtendedDataFigure9_editable.pptx"),
]


def pdf_label(fig_name: str, page_count: int, page_idx: int) -> str:
    display = fig_name.replace("ExtendedDataFigure", "Extended Data Figure ").replace("Figure", "Figure ")
    display = " ".join(display.split())
    if page_count == 1:
        return display
    return f"{display} (page {page_idx} of {page_count})"


def shape_text(shape) -> str:
    if not getattr(shape, "has_text_frame", False):
        return ""
    return "\n".join(
        "".join(run.text or "" for run in paragraph.runs)
        for paragraph in shape.text_frame.paragraphs
    ).strip()


def is_figure_page_title(shape) -> bool:
    text = shape_text(shape)
    if not text:
        return False
    # Working PPTX files keep a page-level figure title at the top-left for QA.
    # Individual figure images should not include this title, because
    # panel labels and legends already identify the figure in the manuscript.
    if shape.top > int(0.12 * EMU_PER_INCH):
        return False
    return text.startswith("Figure ") or text.startswith("Extended Data Figure ")


def font_for(size_pt: float, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Supplemental/Helvetica.ttc",
        "/Library/Fonts/Arial.ttf",
    ]
    for path in candidates:
        if path and Path(path).exists():
            try:
                return ImageFont.truetype(path, max(8, int(round(size_pt))))
            except OSError:
                continue
    return ImageFont.load_default()


def render_slide(prs: Presentation, slide, width_mm: float, dpi: int, skip_page_title: bool = False) -> Image.Image:
    out_w = int(round(width_mm / MM_PER_INCH * dpi))
    out_h = int(round(out_w * prs.slide_height / prs.slide_width))
    sx = out_w / prs.slide_width
    sy = out_h / prs.slide_height
    canvas_img = Image.new("RGB", (out_w, out_h), "white")
    draw = ImageDraw.Draw(canvas_img)

    for shape in sorted(slide.shapes, key=lambda s: s.shape_id):
        x = int(round(shape.left * sx))
        y = int(round(shape.top * sy))
        w = int(round(shape.width * sx))
        h = int(round(shape.height * sy))
        if shape.shape_type == MSO_SHAPE_TYPE.PICTURE:
            with Image.open(io.BytesIO(shape.image.blob)) as im:
                im = im.convert("RGBA").resize((w, h), Image.Resampling.LANCZOS)
                canvas_img.paste(im.convert("RGB"), (x, y), im)
        elif getattr(shape, "has_text_frame", False):
            if skip_page_title and is_figure_page_title(shape):
                continue
            yy = y
            for paragraph in shape.text_frame.paragraphs:
                xx = x
                for run in paragraph.runs:
                    if not run.text:
                        continue
                    size_pt = float(run.font.size.pt) if run.font.size is not None else 10.0
                    font = font_for(size_pt * dpi / 72.0, bold=bool(run.font.bold))
                    draw.text((xx, yy), run.text, fill=(0, 0, 0), font=font)
                    bbox = draw.textbbox((xx, yy), run.text, font=font)
                    xx = bbox[2]
                yy += int(round(1.35 * (paragraph.runs[0].font.size.pt if paragraph.runs and paragraph.runs[0].font.size else 10) * dpi / 72.0))
    return canvas_img


def output_stem(fig_name: str, page_count: int, page_idx: int) -> str:
    if page_count == 1:
        return f"{fig_name}_180mm_600dpi"
    return f"{fig_name}_page{page_idx:02d}_180mm_600dpi"


def make_contact_sheet(pngs: list[Path], out_path: Path, thumb_w: int = 560) -> None:
    font = font_for(18)
    thumbs = []
    for path in pngs:
        with Image.open(path) as im:
            im = im.convert("RGB")
            thumb_h = int(im.height * thumb_w / im.width)
            im = im.resize((thumb_w, thumb_h), Image.Resampling.LANCZOS)
            thumbs.append((path, im))
    cols = 3
    gap = 28
    label_h = 34
    row_h = max((im.height + label_h for _, im in thumbs), default=1)
    rows = (len(thumbs) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * thumb_w + (cols + 1) * gap, rows * row_h + (rows + 1) * gap), "white")
    draw = ImageDraw.Draw(sheet)
    for idx, (path, im) in enumerate(thumbs):
        row, col = divmod(idx, cols)
        x = gap + col * (thumb_w + gap)
        y = gap + row * (row_h + gap)
        draw.text((x, y), path.stem, fill=(0, 0, 0), font=font)
        sheet.paste(im, (x, y + label_h))
    sheet.save(out_path)


def make_pdf(pngs_with_labels: list[tuple[Path, str]], out_pdf: Path) -> None:
    c = canvas.Canvas(str(out_pdf), pagesize=A4)
    page_w, page_h = A4
    margin = 28
    label_h = 18
    max_w = page_w - 2 * margin
    max_h = page_h - 2 * margin - label_h
    for png, label in pngs_with_labels:
        with Image.open(png) as im:
            w_px, h_px = im.size
        scale = min(max_w / w_px, max_h / h_px)
        draw_w = w_px * scale
        draw_h = h_px * scale
        x = (page_w - draw_w) / 2
        y = margin
        c.setFont("Helvetica", 10)
        c.drawString(margin, page_h - margin - 4, label)
        c.drawImage(ImageReader(str(png)), x, y, width=draw_w, height=draw_h, preserveAspectRatio=True, mask="auto")
        c.showPage()
    c.save()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--figure-dir", required=True, type=Path)
    parser.add_argument("--out-dir", required=True, type=Path)
    parser.add_argument("--width-mm", type=float, default=180.0)
    parser.add_argument("--dpi", type=int, default=600)
    args = parser.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)
    pngs: list[Path] = []
    pngs_with_labels: list[tuple[Path, str]] = []
    rows: list[dict[str, str]] = []

    for fig_name, pptx_name in FIGURE_ORDER:
        pptx_path = args.figure_dir / pptx_name
        if not pptx_path.exists():
            print(f"Skipping missing editable figure file: {pptx_path}")
            continue
        prs = Presentation(str(pptx_path))
        editable = args.out_dir / f"{fig_name}_editable.pptx"
        shutil.copy2(pptx_path, editable)
        page_count = len(prs.slides)
        for page_idx, slide in enumerate(prs.slides, start=1):
            image = render_slide(prs, slide, args.width_mm, args.dpi, skip_page_title=True)
            stem = output_stem(fig_name, page_count, page_idx)
            png = args.out_dir / f"{stem}.png"
            tif = args.out_dir / f"{stem}.tif"
            image.save(png, dpi=(args.dpi, args.dpi))
            image.save(tif, dpi=(args.dpi, args.dpi), compression="tiff_lzw")
            pngs.append(png)
            pngs_with_labels.append((png, pdf_label(fig_name, page_count, page_idx)))
            rows.append({
                "figure": fig_name,
                "page": str(page_idx),
                "png": png.name,
                "tif": tif.name,
                "editable_pptx": editable.name,
                "width_mm": f"{args.width_mm:g}",
                "dpi": str(args.dpi),
                "pixel_width": str(image.width),
                "pixel_height": str(image.height),
            })

    contact = args.out_dir / "Figure_contact_sheet.png"
    pdf = args.out_dir / "All_Figures.pdf"
    manifest = args.out_dir / "figure_manifest.csv"
    make_contact_sheet(pngs, contact)
    make_pdf(pngs_with_labels, pdf)
    with manifest.open("w", newline="") as handle:
        if not rows:
            raise FileNotFoundError("No editable figure PPTX files were found to export.")
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)
    readme = args.out_dir / "README_figure_exports.txt"
    readme.write_text(
        "Figure exports generated from editable PPTX files.\n"
        "PNG and TIFF files are rendered at 180 mm width with 600 dpi metadata.\n"
        "PNG and TIFF files omit the editable PPTX page-level figure titles.\n"
        "The combined PDF contains one figure page per page with figure labels added for review and no page numbers.\n",
        encoding="utf-8",
    )
    print(f"Exported {len(pngs)} figure pages")
    print(pdf)
    print(contact)


if __name__ == "__main__":
    main()
