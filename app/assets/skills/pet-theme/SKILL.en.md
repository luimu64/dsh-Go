---
# dsh-go:managed — delete this line to keep your own edits.
name: pet-theme
description: Turn pet artwork into a pet pack dsh-go can import — a clawd-on-desk theme, a GIF/PNG/WebP sticker set, a frame-by-frame folder, an Aseprite export or a single image. Use for 「把这个主题做成宠物」「把表情包做成宠物」「这个能导入吗」 and /pet-theme, or when the person wants their own images shown as the dsh-go pet.
---

# Make a pet

Convert an artwork folder into a pet-pack zip that the person selects in Settings → Pets → Import. The scripts are in scripts/.

Supported (detected from the folder contents; put only one kind in a folder):

- clawd-on-desk theme: theme.json + assets/
- Images: GIF / APNG / WebP / PNG, one animation per file; the filename determines the state
  (idle, thinking, working, error, done, sleep, walk, poke, drag, tickle and their Chinese equivalents)
- Frame folders: walk/01.png, hello_01.png; the folder or prefix is the animation name
- Aseprite export: JSON + an atlas PNG, split into animations by frameTags
- A single image: one static idle pet

Animations that are not recognized go into the idle sideshow automatically, so nothing is wasted.

## Steps

1. Get the artwork folder (git clone --depth 1 when the person gives a link, unzip when they give a zip). If the folder has
   neither theme.json nor images, stop and explain what is supported.
2. Install dependencies only when missing: python3 -m pip install -i https://pypi.tuna.tsinghua.edu.cn/simple Pillow numpy
3. Convert:

       python3 <scripts>/pet_theme_convert.py --input <folder> --out /tmp/pet-pack --id <id> --input-name <name> [--source <link>]

   Pixel art (small images with hard edges) is drawn sharply at its own size automatically; other artwork is drawn
   smoothly on a 144 canvas. Add --crisp to force sharp drawing.
4. Validate; it must PASS:

       python3 <scripts>/pet_pack_check.py /tmp/pet-pack/<id> --compat-reactions

5. Package:

       cd /tmp/pet-pack/<id> && python3 -m zipfile -c <output path>/<id>.zip pack.json *.png

   On a phone, write the output to /sdcard/Download/DSH-Go/.
6. Finish: tell the person where to import it; the author and license appear at the bottom of the pet page. Do only
   personal conversions; do not package third-party artwork (especially CC BY-NC-SA fan work) into a release or the market.

## Boundaries

- A folder is detected as one kind of artwork only; split mixed folders.
- Split a full sprite sheet into frames first, or export Aseprite JSON.
- States are matched by filename; if none is recognized the first image becomes idle and the rest go to the sideshow.
- Do not hand-edit the generated pack.json, do not skip validation, and never upload the person's artwork.
