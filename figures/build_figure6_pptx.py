#!/usr/bin/env python3
"""Build Figure 6 as a editable PowerPoint file from assembled panels."""

from __future__ import annotations

from pathlib import Path

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.util import Inches, Pt


from path_config import BASE_DIR, FIG_DIR
OUT_PPTX = FIG_DIR / "Figure6_editable.pptx"


def add_textbox(slide, text: str, left: float, top: float, width: float, height: float,
                size_pt: float, bold: bool = False) -> None:
    box = slide.shapes.add_textbox(Inches(left), Inches(top), Inches(width), Inches(height))
    tf = box.text_frame
    tf.clear()
    tf.word_wrap = False
    tf.margin_left = Inches(0.0)
    tf.margin_right = Inches(0.0)
    tf.margin_top = Inches(0.0)
    tf.margin_bottom = Inches(0.0)
    run = tf.paragraphs[0].add_run()
    run.text = text
    run.font.name = "Arial"
    run.font.size = Pt(size_pt)
    run.font.bold = bold
    run.font.color.rgb = RGBColor(0, 0, 0)


def add_picture(slide, filename: str, left: float, top: float, width: float, height: float) -> None:
    path = FIG_DIR / filename
    if not path.exists():
        raise FileNotFoundError(path)
    slide.shapes.add_picture(str(path), Inches(left), Inches(top),
                             width=Inches(width), height=Inches(height))


def main() -> None:
    prs = Presentation()
    prs.slide_width = Inches(7.5)
    prs.slide_height = Inches(7.2)

    slide = prs.slides.add_slide(prs.slide_layouts[6])
    add_textbox(slide, "Figure 6", 0.0, 0.005, 1.0, 0.24, 9)
    add_picture(slide, "Figure6A_CQ_GSEA_dotplot.png", 0.05, 0.32, 3.72, 2.95)
    add_picture(slide, "Figure6B_CQ_WE_gene_boxplot.png", 3.78, 0.32, 3.65, 2.13)
    add_picture(slide, "Figure6C_CQ_SM_release_barplot.png", 0.23, 3.72, 3.45, 1.78)
    add_picture(slide, "Figure6D_CB_GSEA_dotplot.png", 3.78, 3.02, 3.72, 2.95)

    prs.save(str(OUT_PPTX))
    print(OUT_PPTX)


if __name__ == "__main__":
    main()
