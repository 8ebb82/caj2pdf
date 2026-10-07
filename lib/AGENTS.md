<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-05-02 | Updated: 2026-05-02 -->

# lib

## Purpose
Container for native compiled shared libraries used by the JBIG and JBIG2 image decoders.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `bin/` | Pre-built Windows DLLs for JBIG/JBIG2 decoding (see `bin/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- On Linux/macOS, native libraries (`libjbigdec.so`, `libjbig2codec.so`) must be compiled from source and placed here (not in `bin/`)
- Windows DLLs go in `bin/` subdirectory
- Library loading in `jbigdec.py` and `jbig2dec.py` checks `platform.architecture()` to decide between `./lib/bin/*.dll` (Windows) and `./libjbigdec.so` (Unix)

<!-- MANUAL: -->
