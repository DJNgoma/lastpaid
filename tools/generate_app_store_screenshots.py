#!/usr/bin/env python3

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageColor, ImageDraw, ImageFont


WIDTH = 1284
HEIGHT = 2778
OUT_DIR = Path("appstore/screenshots/en-US/iphone65")
ASSET_DIR = Path("HowMuch/Assets.xcassets/BrandMark.imageset")

BG_TOP = "#0A5C67"
BG_BOTTOM = "#0CB5A2"
BG_WARM = "#F4E3B2"
CARD = "#F7FBFB"
CARD_ALT = "#FFFFFF"
INK = "#0C1F24"
MUTED = "#60737B"
ACCENT = "#13A899"
ACCENT_DARK = "#0C7E74"
ACCENT_SOFT = "#DDF6F1"
PRICE_UP = "#FF8F4D"
PRICE_DOWN = "#0EA96E"
PHONE = "#101417"


@dataclass(frozen=True)
class Slide:
    filename: str
    verb: str
    benefit: str
    kind: str


SLIDES = [
    Slide("01-scan-every-barcode.png", "SCAN", "EVERY BARCODE", "home"),
    Slide("02-save-what-you-paid.png", "SAVE", "WHAT YOU PAID", "capture"),
    Slide("03-check-the-last-price-fast.png", "CHECK", "THE LAST PRICE FAST", "detail"),
    Slide("04-compare-stores-over-time.png", "COMPARE", "STORES OVER TIME", "history"),
]


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size=size)


FONT_BLACK = "/System/Library/Fonts/Supplemental/Arial Black.ttf"
FONT_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_REGULAR = "/System/Library/Fonts/HelveticaNeue.ttc"

VERB_FONT = font(FONT_BLACK, 132)
BENEFIT_FONT = font(FONT_BLACK, 74)
SECTION_FONT = font(FONT_BOLD, 28)
BODY_FONT = font(FONT_REGULAR, 28)
BODY_BOLD = font(FONT_BOLD, 32)
SMALL_FONT = font(FONT_REGULAR, 24)
SMALL_BOLD = font(FONT_BOLD, 24)
PRICE_FONT = font(FONT_BLACK, 88)
TITLE_FONT = font(FONT_BLACK, 54)


def hex_rgba(value: str, alpha: int = 255) -> tuple[int, int, int, int]:
    r, g, b = ImageColor.getrgb(value)
    return (r, g, b, alpha)


def lerp(a: int, b: int, t: float) -> int:
    return round(a + (b - a) * t)


def vertical_gradient(width: int, height: int, top: str, bottom: str) -> Image.Image:
    start = ImageColor.getrgb(top)
    end = ImageColor.getrgb(bottom)
    image = Image.new("RGB", (width, height))
    pixels = image.load()
    for y in range(height):
        t = y / max(height - 1, 1)
        row = tuple(lerp(start[i], end[i], t) for i in range(3))
        for x in range(width):
            pixels[x, y] = row
    return image


def add_soft_glow(base: Image.Image, bounds: tuple[int, int, int, int], color: str, alpha: int) -> None:
    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    draw.ellipse(bounds, fill=hex_rgba(color, alpha))
    blurred = overlay.filter(ImageFilter.GaussianBlur(80))
    base.alpha_composite(blurred)


def draw_centered(draw: ImageDraw.ImageDraw, text: str, y: int, font_obj: ImageFont.FreeTypeFont, fill: str) -> None:
    bbox = draw.textbbox((0, 0), text, font=font_obj)
    x = (WIDTH - (bbox[2] - bbox[0])) / 2
    draw.text((x, y), text, font=font_obj, fill=fill)


def draw_rounded(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], radius: int, fill: str, outline: str | None = None, width: int = 1) -> None:
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def draw_phone_shell(canvas: Image.Image, x: int, y: int, w: int, h: int) -> tuple[Image.Image, tuple[int, int]]:
    draw = ImageDraw.Draw(canvas)
    draw_rounded(draw, (x, y, x + w, y + h), 94, PHONE)
    draw_rounded(draw, (x + 20, y + 20, x + w - 20, y + h - 20), 78, "#F5FAF9")
    draw.rounded_rectangle((x + (w // 2) - 120, y + 32, x + (w // 2) + 120, y + 86), radius=28, fill=PHONE)

    screen = Image.new("RGBA", (w - 40, h - 40), "#F5FAF9")
    return screen, (x + 20, y + 20)


def paste_screen(canvas: Image.Image, screen: Image.Image, origin: tuple[int, int]) -> None:
    canvas.alpha_composite(screen, origin)


def draw_status_bar(draw: ImageDraw.ImageDraw, width: int) -> None:
    draw.text((44, 34), "9:41", font=BODY_BOLD, fill=INK)
    draw.rounded_rectangle((width - 132, 42, width - 44, 72), radius=14, outline=INK, width=4)
    draw.rounded_rectangle((width - 124, 50, width - 56, 64), radius=8, fill=INK)


def draw_primary_button(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], label: str) -> None:
    draw_rounded(draw, box, 26, ACCENT)
    bbox = draw.textbbox((0, 0), label, font=BODY_BOLD)
    tx = box[0] + ((box[2] - box[0]) - (bbox[2] - bbox[0])) / 2
    ty = box[1] + ((box[3] - box[1]) - (bbox[3] - bbox[1])) / 2 - 2
    draw.text((tx, ty), label, font=BODY_BOLD, fill=CARD_ALT)


def draw_secondary_button(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], label: str) -> None:
    draw_rounded(draw, box, 24, ACCENT_SOFT)
    bbox = draw.textbbox((0, 0), label, font=SMALL_BOLD)
    tx = box[0] + ((box[2] - box[0]) - (bbox[2] - bbox[0])) / 2
    ty = box[1] + ((box[3] - box[1]) - (bbox[3] - bbox[1])) / 2 - 2
    draw.text((tx, ty), label, font=SMALL_BOLD, fill=ACCENT_DARK)


def draw_list_row(draw: ImageDraw.ImageDraw, top: int, name: str, place: str, price: str, delta: str, tint: str) -> None:
    draw_rounded(draw, (44, top, 680, top + 148), 24, CARD_ALT, outline="#E4EEEE")
    draw.text((78, top + 28), name, font=BODY_BOLD, fill=INK)
    draw.text((78, top + 74), place, font=SMALL_FONT, fill=MUTED)
    price_bbox = draw.textbbox((0, 0), price, font=BODY_BOLD)
    price_x = 652 - (price_bbox[2] - price_bbox[0])
    draw.text((price_x, top + 30), price, font=BODY_BOLD, fill=INK)
    draw_rounded(draw, (price_x - 8, top + 80, price_x + 136, top + 120), 20, tint)
    draw.text((price_x + 14, top + 88), delta, font=SMALL_BOLD, fill=CARD_ALT)


def draw_home(screen: Image.Image) -> None:
    draw = ImageDraw.Draw(screen)
    draw_status_bar(draw, screen.width)
    draw.text((44, 118), "Last Paid", font=TITLE_FONT, fill=INK)
    draw.text((46, 184), "Your recent saved prices", font=BODY_FONT, fill=MUTED)

    draw_primary_button(draw, (44, 248, screen.width - 44, 364), "Scan Barcode")
    draw_secondary_button(draw, (44, 388, screen.width - 44, 480), "Enter Barcode Manually")

    draw.text((44, 542), "Recent", font=SECTION_FONT, fill=INK)
    draw_list_row(draw, 594, "Full Cream Milk", "Checkers · Apr 19", "R49.99", "DOWN R3.00", PRICE_DOWN)
    draw_list_row(draw, 758, "Corn Flakes", "Woolworths · Apr 18", "R59.99", "UP R2.00", PRICE_UP)
    draw_list_row(draw, 922, "Peanut Butter", "Spar · Apr 16", "R89.99", "SAME", ACCENT_DARK)


def field(draw: ImageDraw.ImageDraw, top: int, label: str, value: str) -> None:
    draw.text((50, top), label.upper(), font=SMALL_BOLD, fill=ACCENT_DARK)
    draw_rounded(draw, (44, top + 34, 680, top + 124), 22, CARD_ALT, outline="#DCE7E9")
    draw.text((70, top + 64), value, font=BODY_FONT, fill=INK)


def draw_capture(screen: Image.Image) -> None:
    draw = ImageDraw.Draw(screen)
    draw_status_bar(draw, screen.width)
    draw.text((44, 118), "Save Item", font=TITLE_FONT, fill=INK)
    draw.text((46, 184), "Capture price, store, and date in one place", font=BODY_FONT, fill=MUTED)

    field(draw, 264, "Product name", "Full Cream Milk")
    field(draw, 416, "Price paid", "R49.99")
    field(draw, 568, "Store", "Checkers")
    field(draw, 720, "Purchase date", "19 Apr 2026")
    field(draw, 872, "Location", "Optional location tag")

    draw.text((50, 1036), "RECENT STORES", font=SMALL_BOLD, fill=ACCENT_DARK)
    for idx, store in enumerate(["Checkers", "Woolworths", "Spar"]):
        left = 44 + idx * 212
        draw_secondary_button(draw, (left, 1078, left + 188, 1148), store)

    draw_primary_button(draw, (44, 1218, screen.width - 44, 1334), "Save")


def draw_detail(screen: Image.Image) -> None:
    draw = ImageDraw.Draw(screen)
    draw_status_bar(draw, screen.width)
    draw.text((44, 118), "Full Cream Milk", font=TITLE_FONT, fill=INK)
    draw.text((46, 184), "Latest price and previous comparison", font=BODY_FONT, fill=MUTED)

    draw_rounded(draw, (44, 258, 680, 670), 34, CARD_ALT)
    draw.text((72, 308), "LATEST PRICE", font=SMALL_BOLD, fill=ACCENT_DARK)
    draw.text((72, 362), "R49.99", font=PRICE_FONT, fill=INK)
    draw.text((74, 472), "Checkers · 2L carton", font=BODY_FONT, fill=MUTED)
    draw_rounded(draw, (72, 526, 250, 584), 22, hex_rgba(PRICE_DOWN, 255))
    draw.text((98, 540), "DOWN R3.00", font=SMALL_BOLD, fill=CARD_ALT)
    draw.text((72, 614), "Previous: R52.99 on 5 Apr", font=BODY_FONT, fill=MUTED)

    draw.text((44, 732), "History", font=SECTION_FONT, fill=INK)
    draw_list_row(draw, 784, "Checkers", "19 Apr · tagged Sandton", "R49.99", "LATEST", ACCENT_DARK)
    draw_list_row(draw, 948, "Woolworths", "05 Apr · 2L carton", "R52.99", "OLDER", "#94AAA7")
    draw_list_row(draw, 1112, "Pick n Pay", "16 Mar · 2L carton", "R47.99", "OLDER", "#94AAA7")


def draw_history(screen: Image.Image) -> None:
    draw = ImageDraw.Draw(screen)
    draw_status_bar(draw, screen.width)
    draw.text((44, 118), "Price History", font=TITLE_FONT, fill=INK)
    draw.text((46, 184), "See which store was cheaper over time", font=BODY_FONT, fill=MUTED)

    draw_rounded(draw, (44, 260, 680, 680), 34, CARD_ALT)
    draw.text((70, 302), "STORE COMPARISON", font=SMALL_BOLD, fill=ACCENT_DARK)

    points = [(112, 604), (230, 514), (348, 562), (466, 428), (584, 486)]
    draw.line(points, fill=ACCENT, width=10, joint="curve")
    for px, py in points:
        draw.ellipse((px - 14, py - 14, px + 14, py + 14), fill=CARD_ALT, outline=ACCENT, width=7)
    for idx, label in enumerate(["Mar", "Apr", "May", "Jun", "Jul"]):
        draw.text((88 + idx * 118, 622), label, font=SMALL_FONT, fill=MUTED)

    for idx, (store, price, note) in enumerate([
        ("Checkers", "R49.99", "Lowest recent price"),
        ("Woolworths", "R52.99", "Premium shelf price"),
        ("Pick n Pay", "R47.99", "Best historical deal"),
    ]):
        top = 760 + idx * 168
        draw_rounded(draw, (44, top, 680, top + 140), 26, CARD_ALT, outline="#E4EEEE")
        draw.text((74, top + 26), store, font=BODY_BOLD, fill=INK)
        draw.text((74, top + 76), note, font=SMALL_FONT, fill=MUTED)
        price_bbox = draw.textbbox((0, 0), price, font=BODY_BOLD)
        draw.text((640 - (price_bbox[2] - price_bbox[0]), top + 38), price, font=BODY_BOLD, fill=INK)


def draw_brand_badge(canvas: Image.Image) -> None:
    mark = ASSET_DIR / "brandmark@3x.png"
    if not mark.exists():
        return
    badge = Image.open(mark).convert("RGBA").resize((144, 144))
    card = Image.new("RGBA", (176, 176), (255, 255, 255, 0))
    draw = ImageDraw.Draw(card)
    draw.rounded_rectangle((0, 0, 176, 176), radius=44, fill=hex_rgba("#FFFFFF", 210))
    card.alpha_composite(badge, (16, 16))
    canvas.alpha_composite(card, (96, 136))


def make_slide(slide: Slide) -> Image.Image:
    bg = vertical_gradient(WIDTH, HEIGHT, BG_TOP, BG_BOTTOM).convert("RGBA")
    overlay = Image.new("RGBA", bg.size, (0, 0, 0, 0))
    glow = ImageDraw.Draw(overlay)
    glow.ellipse((720, -120, 1420, 600), fill=hex_rgba(BG_WARM, 180))
    glow.ellipse((-180, 1640, 560, 2440), fill=hex_rgba("#C8FFF5", 90))
    overlay = overlay.filter(ImageFilter.GaussianBlur(80))
    bg.alpha_composite(overlay)

    draw = ImageDraw.Draw(bg)
    draw_brand_badge(bg)
    draw_centered(draw, slide.verb, 328, VERB_FONT, "#FFFFFF")
    draw_centered(draw, slide.benefit, 462, BENEFIT_FONT, "#F4FFF8")

    screen, origin = draw_phone_shell(bg, 252, 742, 780, 1692)
    if slide.kind == "home":
        draw_home(screen)
    elif slide.kind == "capture":
        draw_capture(screen)
    elif slide.kind == "detail":
        draw_detail(screen)
    else:
        draw_history(screen)
    paste_screen(bg, screen, origin)

    return bg.convert("RGB")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for slide in SLIDES:
        image = make_slide(slide)
        image.save(OUT_DIR / slide.filename, format="PNG")
        print(OUT_DIR / slide.filename)


if __name__ == "__main__":
    from PIL import ImageFilter

    main()
