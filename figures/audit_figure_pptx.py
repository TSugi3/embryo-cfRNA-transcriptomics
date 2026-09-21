#!/usr/bin/env python3
"""Audit figure PPTX files for page count, size and raster distortion.

The report is intended as a publication-output check. It does not replace visual
inspection, but it catches accidental non-proportional image scaling and slide
dimensions above the Nature figure limits.
"""

from __future__ import annotations

import argparse
import csv
import io
from pathlib import Path

from PIL import Image
from pptx import Presentation
from pptx.enum.shapes import MSO_SHAPE_TYPE


MM_PER_INCH = 25.4
EMU_PER_INCH = 914400


def emu_to_mm(value: int) -> float:
    return value / EMU_PER_INCH * MM_PER_INCH


def image_properties(blob: bytes) -> tuple[int, int, float | None, float | None]:
    with Image.open(io.BytesIO(blob)) as image:
        width_px, height_px = image.size
        dpi = image.info.get("dpi")
        if dpi and len(dpi) >= 2 and dpi[0] > 0 and dpi[1] > 0:
            return width_px, height_px, float(dpi[0]), float(dpi[1])
        return width_px, height_px, None, None


def audit_pptx(path: Path, max_width_mm: float, max_height_mm: float) -> list[dict[str, object]]:
    presentation = Presentation(path)
    slide_width_mm = emu_to_mm(presentation.slide_width)
    slide_height_mm = emu_to_mm(presentation.slide_height)
    page_scale = min(1.0, max_width_mm / slide_width_mm, max_height_mm / slide_height_mm)
    rows: list[dict[str, object]] = []

    for slide_number, slide in enumerate(presentation.slides, start=1):
        for shape_number, shape in enumerate(slide.shapes, start=1):
            if shape.shape_type != MSO_SHAPE_TYPE.PICTURE:
                continue

            width_px, height_px, dpi_x, dpi_y = image_properties(shape.image.blob)
            source_aspect = width_px / height_px
            placed_aspect = shape.width / shape.height
            distortion_percent = 100.0 * (placed_aspect / source_aspect - 1.0)

            placement_scale = None
            effective_scale = None
            if dpi_x is not None:
                source_width_mm = width_px / dpi_x * MM_PER_INCH
                placement_scale = emu_to_mm(shape.width) / source_width_mm
                effective_scale = placement_scale * page_scale

            rows.append(
                {
                    "file": path.name,
                    "slides": len(presentation.slides),
                    "slide": slide_number,
                    "shape": shape_number,
                    "image_filename": shape.image.filename,
                    "slide_width_mm": round(slide_width_mm, 2),
                    "slide_height_mm": round(slide_height_mm, 2),
                    "page_scale": round(page_scale, 4),
                    "rendered_width_mm": round(slide_width_mm * page_scale, 2),
                    "rendered_height_mm": round(slide_height_mm * page_scale, 2),
                    "image_width_px": width_px,
                    "image_height_px": height_px,
                    "placed_width_mm": round(emu_to_mm(shape.width), 2),
                    "placed_height_mm": round(emu_to_mm(shape.height), 2),
                    "aspect_distortion_percent": round(distortion_percent, 3),
                    "placement_scale": "" if placement_scale is None else round(placement_scale, 4),
                    "effective_scale": "" if effective_scale is None else round(effective_scale, 4),
                }
            )
    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("figure_dir", type=Path, help="Directory containing *_editable.pptx files")
    parser.add_argument("--output", type=Path, default=Path("figure_pptx_audit.csv"))
    parser.add_argument("--max-width-mm", type=float, default=180.0)
    parser.add_argument("--max-height-mm", type=float, default=200.0)
    parser.add_argument("--distortion-tolerance-percent", type=float, default=1.0)
    args = parser.parse_args()

    pptx_files = sorted(args.figure_dir.glob("*_editable.pptx"))
    if not pptx_files:
        raise SystemExit(f"No *_editable.pptx files found in {args.figure_dir}")

    rows: list[dict[str, object]] = []
    for pptx_file in pptx_files:
        rows.extend(audit_pptx(pptx_file, args.max_width_mm, args.max_height_mm))

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)

    bad_pages = sorted({row["file"] for row in rows if row["slides"] != 1})
    bad_sizes = sorted(
        {
            row["file"]
            for row in rows
            if row["rendered_width_mm"] > args.max_width_mm + 0.01
            or row["rendered_height_mm"] > args.max_height_mm + 0.01
        }
    )
    distorted = [
        row
        for row in rows
        if abs(float(row["aspect_distortion_percent"])) > args.distortion_tolerance_percent
    ]

    print(f"Audited {len(pptx_files)} PPTX files and {len(rows)} embedded images")
    print(f"Multi-page files: {len(bad_pages)}")
    print(f"Slides exceeding {args.max_width_mm:g} x {args.max_height_mm:g} mm: {len(bad_sizes)}")
    print(f"Images with >{args.distortion_tolerance_percent:g}% aspect distortion: {len(distorted)}")
    print(args.output)

    if bad_pages or bad_sizes or distorted:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
