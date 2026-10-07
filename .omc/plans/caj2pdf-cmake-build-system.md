# Plan: Add CMake Build System for caj2pdf Native Libraries

**Plan saved to:** `.omc/plans/caj2pdf-cmake-build-system.md`

**Date:** 2026-05-02
**Type:** New build infrastructure (brownfield)
**Estimated complexity:** MEDIUM

---

## Context

caj2pdf needs native C/C++ shared libraries (`libjbigdec.so` and `libjbig2codec.so`) loaded via Python ctypes. Currently these must be compiled by hand with raw `cc` invocations. This plan adds a CMake build system with:

- **Native Linux build** producing `.so` files in the project root
- **Cross-compilation to Windows** via MinGW-w64 producing `.dll` files in `lib/bin/`
- **Dual JBIG2 backend selection** (libpoppler or libjbig2dec)

---

## RALPLAN-DR Summary

### Principles
1. **Minimal change to existing code** -- zero modifications to Python `.py` files or C/C++ source files. Only add build files.
2. **Output-compatibility first** -- build artifacts must have exactly the names and locations the existing Python `ctypes` calls expect.
3. **One-command native build** -- `cmake -B build && cmake --build build` must produce working `.so` files on a stock Ubuntu/Debian system with dev packages installed.
4. **Explicit backend choice** -- the JBIG2 backend selection (poppler vs jbig2dec) is a configure-time decision since both produce the same SONAME.

### Decision Drivers (top 3)
1. **Output path fidelity** -- Linux `.so` goes to project root, Windows `.dll` goes to `lib/bin/`. These are hard-coded in Python ctypes calls and cannot be changed.
2. **Cross-compilation simplicity** -- MinGW cross-compilation for the JBIG2 backend is constrained because `libpoppler-dev` targets are not always available in MinGW repos. The jbig2dec backend is lighter for cross-builds.
3. **Backend mutual exclusivity** -- both JBIG2 backends compile to `libjbig2codec.so`, making a single binary target with a choice variable (`JBIG2_BACKEND`) the cleanest approach.

### Options Considered

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| **A. Single CMakeLists.txt + presets** (recommended) | One `CMakeLists.txt` at project root, two `CMakePresets.json` entries (native + cross), one backend choice variable | Single source of truth; CMake presets make build commands trivial; no duplicated logic | Slightly more complex preset config for MinGW |
| **B. Two separate CMakeLists.txt** | One in `lib/` for native, one in `lib/cross/` for Windows | Physically separate; clear which is which | Duplicated target definitions; harder to maintain |
| **C. Makefile-only** | Pure Makefile, no CMake | Zero new dependencies (make is universal) | No cross-compile toolchain integration; harder to express conditional logic; no pkg-config integration |

**Why A was chosen:** CMake is the de-facto standard for C/C++ projects, handles pkg-config natively, has first-class cross-compilation support via toolchain files and presets. Option B duplicates logic. Option C loses toolchain abstraction and pkg-config integration.

**Alternatives invalidated:** B (duplicated targets, harder maintenance); C (no pkg-config, no cross-compile abstraction).

---

## Work Objectives

1. Create `CMakeLists.txt` with two shared library targets and JBIG2 backend selection
2. Create MinGW-w64 toolchain files for 64-bit (and optionally 32-bit) cross-compilation
3. Add `CMakePresets.json` for one-command builds
4. Document build instructions

## Guardrails

### Must Have
- Native `cmake -B build && cmake --build build` produces `libjbigdec.so` + `libjbig2codec.so` in project root
- MinGW cross build produces DLLs in `lib/bin/` with names matching Python ctypes expectations
- JBIG2 backend selection works for both poppler and jbig2dec backends
- `gcc -fPIC` position-independent code for shared libraries
- Build is offline (system packages via apt are OK, no pip/network)

### Must NOT Have
- No changes to `.py` files
- No changes to `.cc` or `.h` source files
- No macOS support
- No mutool build/package
- No CI/CD configuration

---

## Task Flow

### Step 1: Create root `CMakeLists.txt`

**Action:** Create `/home/cc/repo/caj2pdf/CMakeLists.txt`

**Rationale:** Single entry point for both native and cross builds. Defines two shared library targets with conditional output paths.

**Structure outline:**
```
cmake_minimum_required(VERSION 3.19)
project(caj2pdf-native LANGUAGES C CXX)

# JBIG2 backend selection (default: poppler)
set(JBIG2_BACKEND "poppler" CACHE STRING "JBIG2 backend: poppler or jbig2dec")
set_property(CACHE JBIG2_BACKEND PROPERTY STRINGS poppler jbig2dec)

# --- libjbigdec target ---
add_library(jbigdec SHARED lib/jbigdec.cc lib/JBigDecode.cc)
set_target_properties(jbigdec PROPERTIES POSITION_INDEPENDENT_CODE ON)

if(WIN32)
  # Cross-compile: DLL in lib/bin/ with lib prefix + -w{64,32} suffix
  math(EXPR BITNESS "8 * ${CMAKE_SIZEOF_VOID_P}")
  set_target_properties(jbigdec PROPERTIES
    PREFIX "lib"
    OUTPUT_NAME "jbigdec-w${BITNESS}"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/lib/bin"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/lib/bin")
else()
  # Native Linux: libjbigdec.so in project root
  set_target_properties(jbigdec PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}")
endif()

# --- libjbig2codec target --- (backend selected at configure time)
find_package(PkgConfig REQUIRED)

if(JBIG2_BACKEND STREQUAL "poppler")
  pkg_check_modules(POPPLER REQUIRED poppler)
  add_library(jbig2codec SHARED lib/decode_jbig2data.cc)
  target_include_directories(jbig2codec PRIVATE ${POPPLER_INCLUDE_DIRS})
  target_link_libraries(jbig2codec PRIVATE ${POPPLER_LIBRARIES})
  target_compile_options(jbig2codec PRIVATE ${POPPLER_CFLAGS_OTHER})
elseif(JBIG2_BACKEND STREQUAL "jbig2dec")
  pkg_check_modules(JBIG2DEC REQUIRED jbig2dec)
  add_library(jbig2codec SHARED lib/decode_jbig2data_x.cc)
  target_include_directories(jbig2codec PRIVATE ${JBIG2DEC_INCLUDE_DIRS})
  target_link_libraries(jbig2codec PRIVATE ${JBIG2DEC_LIBRARIES})
  target_compile_options(jbig2codec PRIVATE ${JBIG2DEC_CFLAGS_OTHER})
endif()

set_target_properties(jbig2codec PROPERTIES POSITION_INDEPENDENT_CODE ON)

if(WIN32)
  math(EXPR BITNESS "8 * ${CMAKE_SIZEOF_VOID_P}")
  set_target_properties(jbig2codec PROPERTIES
    PREFIX "lib"
    OUTPUT_NAME "jbig2codec-w${BITNESS}"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/lib/bin"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/lib/bin")
else()
  set_target_properties(jbig2codec PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}")
endif()
```

**Acceptance criteria:**
- `cmake -B build -DJBIG2_BACKEND=poppler && cmake --build build` succeeds on a system with `libpoppler-dev` installed
- `cmake -B build -DJBIG2_BACKEND=jbig2dec && cmake --build build` succeeds on a system with `libjbig2dec-dev` installed
- `ls ./libjbigdec.so ./libjbig2codec.so` shows both libraries in project root
- `file libjbigdec.so` shows "ELF 64-bit LSB shared object, x86-64"
- Python `cdll.LoadLibrary("./libjbigdec.so")` and `cdll.LoadLibrary("./libjbig2codec.so")` load without error

### Step 2: Create MinGW-w64 cross-compilation toolchain file

**Action:** Create `/home/cc/repo/caj2pdf/cmake/toolchain-mingw-w64-x86_64.cmake`

**Rationale:** CMake requires a toolchain file for cross-compilation. This file sets `CMAKE_SYSTEM_NAME=Windows`, selects the MinGW-w64 compiler, and configures `CMAKE_FIND_ROOT_PATH` to point at the MinGW sysroot.

**Structure outline:**
```cmake
# Toolchain for x86_64 MinGW-w64 cross-compilation
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)
set(CMAKE_C_COMPILER x86_64-w64-mingw32-gcc)
set(CMAKE_CXX_COMPILER x86_64-w64-mingw32-g++)
set(CMAKE_FIND_ROOT_PATH /usr/x86_64-w64-mingw32)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# pkg-config must search the MinGW sysroot, not the host
set(ENV{PKG_CONFIG_LIBDIR} /usr/x86_64-w64-mingw32/lib/pkgconfig)
set(ENV{PKG_CONFIG_SYSROOT_DIR} /usr/x86_64-w64-mingw32)
```

Optionally create `/home/cc/repo/caj2pdf/cmake/toolchain-mingw-w64-i686.cmake` for 32-bit.

**Acceptance criteria:**
- `cmake -B build-win -DCMAKE_TOOLCHAIN_FILE=cmake/toolchain-mingw-w64-x86_64.cmake -DJBIG2_BACKEND=jbig2dec && cmake --build build-win` succeeds
- `ls lib/bin/libjbigdec-w64.dll lib/bin/libjbig2codec-w64.dll` shows both DLLs
- `file lib/bin/libjbigdec-w64.dll` shows "PE32+ executable (DLL) (console) x86-64, for MS Windows"

### Step 3: Add CMakePresets.json for one-command builds

**Action:** Create `/home/cc/repo/caj2pdf/CMakePresets.json`

**Rationale:** CMake presets provide discoverable, named build configurations. Users run `cmake --preset <name>` instead of remembering toolchain file paths and option flags.

**Structure outline:**
```json
{
  "version": 1,
  "configurePresets": [
    {
      "name": "native-poppler",
      "displayName": "Native Linux (poppler backend)",
      "description": "Build libjbigdec.so + libjbig2codec.so (poppler)",
      "binaryDir": "${sourceDir}/build",
      "cacheVariables": {
        "JBIG2_BACKEND": "poppler"
      }
    },
    {
      "name": "native-jbig2dec",
      "displayName": "Native Linux (jbig2dec backend)",
      "description": "Build libjbigdec.so + libjbig2codec.so (jbig2dec)",
      "binaryDir": "${sourceDir}/build",
      "cacheVariables": {
        "JBIG2_BACKEND": "jbig2dec"
      }
    },
    {
      "name": "cross-win64-jbig2dec",
      "displayName": "Cross-compile Windows x86_64 (jbig2dec backend)",
      "description": "Build DLLs for Windows via MinGW-w64",
      "binaryDir": "${sourceDir}/build-win64",
      "toolchainFile": "${sourceDir}/cmake/toolchain-mingw-w64-x86_64.cmake",
      "cacheVariables": {
        "JBIG2_BACKEND": "jbig2dec"
      }
    }
  ]
}
```

**Acceptance criteria:**
- `cmake --preset native-poppler && cmake --build build` produces `.so` files
- `cmake --preset cross-win64-jbig2dec && cmake --build build-win64` produces DLLs
- No manual flag passing needed for standard builds

### Step 4: Document build instructions

**Action:** Update `/home/cc/repo/caj2pdf/README.md` with system dependencies and build steps

**Rationale:** Users need to know which system packages to install and which commands to run.

**Content to add:**
- System dependencies section listing `build-essential`, `cmake`, `pkg-config`, `libpoppler-dev` (or `libjbig2dec-dev`), and optionally `mingw-w64`
- Native build: `cmake --preset native-poppler && cmake --build build`
- Cross-compile: `cmake --preset cross-win64-jbig2dec && cmake --build build-win64`
- Quick troubleshooting (missing packages, pkg-config failures)

**NOTE:** Only the build instructions section of README.md is modified. No Python or C/C++ source changes.

**Acceptance criteria:**
- README.md contains a "Building Native Libraries" section with clear numbered steps
- All commands shown have been verified to work

### Step 5: Create `.gitignore` entries for build artifacts

**Action:** Update `/home/cc/repo/caj2pdf/.gitignore` (create if not exist)

**Rationale:** CMake build directories (`build/`, `build-win*/`) should not be tracked by git.

**Entries to add (if not already present):**
```
build/
build-*/
CMakeUserPresets.json
lib/bin/libjbigdec-w*.dll
lib/bin/libjbig2codec-w*.dll
```

**Acceptance criteria:**
- `git status` after a build shows no build directory artifacts

---

## ADR (Architecture Decision Record)

| Field | Value |
|-------|-------|
| **Decision** | Single `CMakeLists.txt` at project root + per-platform output path logic |
| **Drivers** | (1) Output path must match Python ctypes expectations; (2) JBIG2 backends are mutually exclusive; (3) One-command build simplicity |
| **Alternatives considered** | Two CMakeLists.txt (rejected: duplicated targets); Pure Makefile (rejected: no pkg-config/toolchain abstraction) |
| **Why chosen** | CMake provides native pkg-config integration, first-class cross-compilation support via toolchain files, and presets for discoverable build commands |
| **Consequences** | (Positive) Single source of truth for build logic; discoverable via `--preset`; (Negative) Must handle platform conditionals in one file |
| **Follow-ups** | Verify Windows DLL loading from Python ctypes if a Windows test environment is available; consider adding `FindPoppler.cmake` if `pkg_check_modules` is insufficient for version-sensitive poppler API |

---

## Risk Items

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `calloc(0x8040, 1)` on jbigdec.cc:84 is Linux x86_64-specific | Runtime crash on non-Linux or non-x86_64 | Low (Windows DLLs already ship) | Document as known issue; fix via `sizeof(JBigCodec)` if problems surface |
| `JBIG2Stream.h` is an internal poppler header, may not be in public include path | Build failure for poppler backend | Medium | Verify on target distro; fall back to jbig2dec backend if needed |
| MinGW-w64 cross-compile packages not available for libpoppler | Cannot cross-compile poppler-backend JBIG2 DLL | Medium | Default to jbig2dec backend for cross-compile (simpler dep); document this |
| `pkg-config` not available on minimal systems | CMake configure fails | Low | Document `pkg-config` as prerequisite in README |
| Poppler API changes across versions | Compile error for poppler backend | Low-Medium | Test against Ubuntu LTS and Debian stable; document known-compatible versions |

---

## Success Criteria

- [ ] `cmake --preset native-poppler && cmake --build build` produces `libjbigdec.so` + `libjbig2codec.so` in project root
- [ ] Python `cdll.LoadLibrary("./libjbigdec.so")` and `cdll.LoadLibrary("./libjbig2codec.so")` succeed
- [ ] `cmake --preset cross-win64-jbig2dec && cmake --build build-win64` produces `lib/bin/libjbigdec-w64.dll` + `lib/bin/libjbig2codec-w64.dll`
- [ ] README.md has clear build instructions
- [ ] No Python or C/C++ source files were modified

---

## Open Questions

None. All ambiguities were resolved in the deep interview (13.75% remaining ambiguity, primarily around exact poppler header paths which will be verified during Step 1).
