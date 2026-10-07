<!-- Generated: 2026-05-02 | Updated: 2026-05-02 -->

# caj2pdf

## Purpose
Convert CNKI (中国知网) CAJ format academic papers to PDF, extracting both text and document outlines. Handles multiple internal CAJ sub-formats (CAJ, HN, C8, KDH, PDF) with native image decoding for JBIG and JBIG2 compressed page images.

## Key Files

| File | Description |
|------|-------------|
| `caj2pdf` | CLI entry point — subcommands: `show`, `convert`, `outlines`, `parse`, `text-extract` |
| `cajparser.py` | Core parser and converter — detects file format, dispatches to format-specific conversion routines |
| `HNParsePage.py` | Parses HN-format page binary data into text characters and figure bounding boxes |
| `jbig2dec.py` | JBIG2 image decoder via ctypes — wraps a native C shared library (libpoppler or libjbig2dec) |
| `jbigdec.py` | JBIG image decoder via ctypes — wraps a native C shared library (libreaderex) |
| `pdfwutils.py` | PDF writing utilities adapted from img2pdf — converts image lists to valid PDF byte streams |
| `utils.py` | PDF outline/TOC builder using binary tree, byte-level search helpers (fnd, fnd_all, fnd_rvrs), PyPDF2 wrappers |
| `requirements.txt` | Python dependencies: `imagesize` and `PyPDF2` |
| `batch-convert.sh` | Bash helper to batch-convert all `.caj` files in `cajs/` to `pdfs/` |
| `LICENSE` | GLWTPL (Good Luck With That Public License) |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `cajs/` | Sample CAJ test files (Chinese sugarcane research papers) |
| `lib/` | Native shared library container (see `lib/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- This is a Python 3.3+ project with no setup.py — run scripts directly from the repo root
- The `caj2pdf` script uses a shebang line; invoke as `./caj2pdf` or `python3 caj2pdf`
- Native libraries (`libjbigdec.so`, `libjbig2codec.so`) must be compiled separately for Linux/macOS. Windows DLLs are pre-built in `lib/bin/`
- External dependency: `mutool` (from MuPDF) must be installed on the system PATH for CAJ and KDH format repair

### Testing Requirements
- Test with sample CAJ files in `cajs/` directory
- `./caj2pdf show <file>` to inspect file type and page count
- `./caj2pdf convert <file> -o output.pdf` for full conversion
- `./caj2pdf outlines <file> -o printed.pdf` to add outline/TOC to an existing PDF

### Common Patterns
- File format detection reads the first 4 bytes and matches against known magic sequences
- Format-specific conversion methods are prefixed `_convert_<format>` in CAJParser
- Image data is decoded via ctypes calls into native C shared libraries, then assembled into PDFs
- TOC/outline data is stored in a binary tree (BTree/Node classes) and serialized to PDF outline objects via PyPDF2

## Dependencies

### Internal
- `cajparser.py` imports from `HNParsePage.py`, `jbigdec.py`, `jbig2dec.py`, `pdfwutils.py`, `utils.py`
- `utils.py` uses PyPDF2 for PDF manipulation

### External
- PyPDF2 (PDF reading/writing)
- imagesize (JPEG dimension detection)
- mutool (MuPDF command-line tool, external binary)
- Pillow (optional, for JPEG dimension fallback)
- Native C libraries: libjbigdec, libjbig2codec (must be compiled from source on Linux/macOS)

<!-- MANUAL: -->
