# Font Assets

This directory contains Chinese font files required by `PdfBookExporter`
(Requirements 4.2, 4.3).

## Required File

| File | Purpose |
|------|---------|
| `NotoSansSC-Regular.ttf` | Noto Sans Simplified Chinese — embedded in generated PDFs to ensure correct CJK rendering |

## Automatic Download

Run the provided script from the repository root:

```bash
python backend/assets/fonts/download_fonts.py
```

The script downloads the NotoSans SC variable TTF from the official
[noto-cjk](https://github.com/googlefonts/noto-cjk) repository on GitHub
and saves it as `NotoSansSC-Regular.ttf`.

## Manual Download

If the script fails (e.g., no internet access), download the font manually:

1. Go to: https://github.com/googlefonts/noto-cjk/tree/main/Sans/Variable/TTF/Subset
2. Download `NotoSansSC-VF.ttf`
3. Rename it to `NotoSansSC-Regular.ttf`
4. Place it in this directory (`backend/assets/fonts/`)

Alternatively, any CJK-compatible `.ttf` or `.otf` font placed at
`backend/assets/fonts/NotoSansSC-Regular.ttf` will work.

## System Font Fallback

If `NotoSansSC-Regular.ttf` is not present, `PdfBookExporter` automatically
scans `/usr/share/fonts/` (Linux/macOS) for fonts whose filenames contain
`cjk`, `noto`, `wenquanyi`, `sourcehan`, or `source han`.

On Windows, `/usr/share/fonts/` does not exist, so the bundled font file is
required.

If no CJK font is found by either method, the exporter raises:

```
RuntimeError: 中文字体不可用，无法生成 PDF
```

and the API returns HTTP 500.
