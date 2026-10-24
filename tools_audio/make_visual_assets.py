#!/usr/bin/env python3
"""Generate original vector cutout assets for the sample episode.

Everything here is drawn from scratch for this project (CC0 / project-owned).
No third-party photography or trademarks are used.
"""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "projects" / "salt_hypertension" / "assets"
SRC = ROOT / "assets_src"
ASSETS.mkdir(parents=True, exist_ok=True)
SRC.mkdir(parents=True, exist_ok=True)

SALT_SHAKER = r'''<svg xmlns="http://www.w3.org/2000/svg" width="900" height="1300" viewBox="0 0 900 1300">
<defs>
  <linearGradient id="glass" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#dce6ea"/>
    <stop offset="0.28" stop-color="#f8fbfc"/>
    <stop offset="0.6" stop-color="#c9d8de"/>
    <stop offset="1" stop-color="#9fb6c0"/>
  </linearGradient>
  <linearGradient id="salt" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#ffffff"/>
    <stop offset="0.65" stop-color="#f1ede2"/>
    <stop offset="1" stop-color="#d9d4c6"/>
  </linearGradient>
  <linearGradient id="steel" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#7d8e99"/>
    <stop offset="0.22" stop-color="#eef4f6"/>
    <stop offset="0.5" stop-color="#b9c6cc"/>
    <stop offset="0.75" stop-color="#f7fafb"/>
    <stop offset="1" stop-color="#74858f"/>
  </linearGradient>
  <linearGradient id="steelTop" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#f6fafb"/>
    <stop offset="0.45" stop-color="#b7c5cb"/>
    <stop offset="1" stop-color="#687a84"/>
  </linearGradient>
  <radialGradient id="shine" cx="0.32" cy="0.35" r="0.55">
    <stop offset="0" stop-color="#ffffff" stop-opacity="0.95"/>
    <stop offset="0.5" stop-color="#ffffff" stop-opacity="0.25"/>
    <stop offset="1" stop-color="#ffffff" stop-opacity="0"/>
  </radialGradient>
</defs>
<!-- shadow inside artwork is intentionally omitted; renderer adds a real shadow -->
<g>
  <!-- cap -->
  <path d="M288 256 Q288 208 336 202 L564 202 Q612 208 612 256 L612 330 Q612 366 574 372 L326 372 Q288 366 288 330 Z" fill="url(#steel)"/>
  <rect x="276" y="236" width="348" height="64" rx="30" fill="url(#steelTop)"/>
  <ellipse cx="450" cy="236" rx="174" ry="30" fill="#e9f0f3"/>
  <!-- holes -->
  <g fill="#5d6f79">
    <circle cx="392" cy="226" r="13"/><circle cx="450" cy="219" r="13"/><circle cx="508" cy="226" r="13"/>
    <circle cx="368" cy="256" r="11"/><circle cx="426" cy="252" r="11"/><circle cx="474" cy="252" r="11"/><circle cx="532" cy="256" r="11"/>
  </g>
  <!-- neck -->
  <path d="M326 370 L574 370 L594 442 Q594 468 566 476 L334 476 Q306 468 306 442 Z" fill="url(#steel)"/>
  <rect x="306" y="452" width="288" height="34" rx="16" fill="#8fa1ab"/>
  <!-- glass body -->
  <path d="M300 476 Q300 510 330 534 L330 1040 Q330 1148 438 1164 L462 1164 Q570 1148 570 1040 L570 534 Q600 510 600 476 Z" fill="url(#glass)"/>
  <!-- salt inside -->
  <path d="M338 620 L562 620 L562 1036 Q562 1126 460 1142 L440 1142 Q338 1126 338 1036 Z" fill="url(#salt)"/>
  <g fill="#ffffff" opacity="0.85">
    <circle cx="382" cy="690" r="8"/><circle cx="430" cy="742" r="7"/><circle cx="502" cy="700" r="9"/>
    <circle cx="536" cy="790" r="6"/><circle cx="470" cy="820" r="8"/><circle cx="398" cy="870" r="7"/>
    <circle cx="520" cy="920" r="6"/><circle cx="442" cy="980" r="8"/><circle cx="372" cy="940" r="5"/>
    <circle cx="500" cy="1040" r="7"/><circle cx="410" cy="1080" r="6"/>
  </g>
  <!-- glass rim and highlights -->
  <rect x="296" y="470" width="308" height="52" rx="26" fill="#eaf2f5" opacity="0.9"/>
  <path d="M352 540 L352 1024 Q352 1092 414 1112" stroke="#ffffff" stroke-width="34" fill="none" opacity="0.5" stroke-linecap="round"/>
  <path d="M548 548 L548 1016" stroke="#6f8895" stroke-width="20" fill="none" opacity="0.28" stroke-linecap="round"/>
  <ellipse cx="410" cy="760" rx="150" ry="300" fill="url(#shine)"/>
  <path d="M330 500 L570 500" stroke="#ffffff" stroke-width="10" opacity="0.6"/>
  <!-- label band -->
  <rect x="330" y="826" width="240" height="112" fill="#f6f3ec" opacity="0.94"/>
  <rect x="356" y="852" width="188" height="10" fill="#334b60"/>
  <rect x="356" y="880" width="118" height="8" fill="#ff5a36"/>
  <text x="356" y="918" font-family="DejaVu Sans, sans-serif" font-size="26" letter-spacing="6" fill="#334b60">SALT</text>
</g>
</svg>'''

DROPLET = r'''<svg xmlns="http://www.w3.org/2000/svg" width="600" height="700" viewBox="0 0 600 700">
<defs>
  <linearGradient id="water" x1="0.2" y1="0" x2="0.8" y2="1">
    <stop offset="0" stop-color="#cfe8f6"/>
    <stop offset="0.42" stop-color="#7fb9d8"/>
    <stop offset="1" stop-color="#3d7fa6"/>
  </linearGradient>
  <radialGradient id="hi" cx="0.34" cy="0.28" r="0.36">
    <stop offset="0" stop-color="#ffffff" stop-opacity="0.95"/>
    <stop offset="1" stop-color="#ffffff" stop-opacity="0"/>
  </radialGradient>
</defs>
<path d="M300 60 C300 60 96 342 96 460 C96 566 186 646 300 646 C414 646 504 566 504 460 C504 342 300 60 300 60 Z" fill="url(#water)"/>
<ellipse cx="232" cy="414" rx="92" ry="116" fill="url(#hi)"/>
<path d="M180 486 Q202 558 274 576" stroke="#ffffff" stroke-width="14" fill="none" opacity="0.45" stroke-linecap="round"/>
</svg>'''

# A second sticker asset: a small pile of salt crystals / mineral chunk.
SALT_PILE = r'''<svg xmlns="http://www.w3.org/2000/svg" width="800" height="520" viewBox="0 0 800 520">
<defs>
  <linearGradient id="g" x1="0" y1="0" x2="0.8" y2="1">
    <stop offset="0" stop-color="#ffffff"/>
    <stop offset="0.52" stop-color="#f1eee6"/>
    <stop offset="1" stop-color="#c9c3b6"/>
  </linearGradient>
</defs>
<g stroke="#b9b2a4" stroke-width="3">
  <path d="M118 420 L206 358 L292 402 L338 468 L236 490 Z" fill="url(#g)"/>
  <path d="M250 430 L318 330 L420 318 L470 400 L404 470 Z" fill="url(#g)"/>
  <path d="M398 460 L452 380 L560 364 L646 424 L690 482 L560 502 L462 498 Z" fill="url(#g)"/>
  <path d="M196 402 L246 350 L260 424 L222 454 Z" fill="#ffffff" opacity="0.85"/>
  <path d="M340 384 L388 336 L394 404 L356 430 Z" fill="#ffffff" opacity="0.75"/>
  <path d="M500 414 L540 372 L548 432 L516 458 Z" fill="#ffffff" opacity="0.75"/>
</g>
</svg>'''

for name, svg, w in [
    ("salt_shaker", SALT_SHAKER, 900),
    ("water_droplet", DROPLET, 600),
    ("salt_pile", SALT_PILE, 800),
]:
    svg_path = SRC / f"{name}.svg"
    svg_path.write_text(svg)
    out = ASSETS / f"{name}.png"
    subprocess.run(["rsvg-convert", "-w", str(w), "-b", "transparent", "-o", str(out), str(svg_path)], check=True)
    print(f"wrote {out} {out.stat().st_size} bytes")
