# Deep Interview Spec: caj2pdf 跨平台编译重构

## Metadata
- Interview ID: caj2pdf-cross-platform
- Rounds: 5
- Final Ambiguity Score: 13.75%
- Type: brownfield
- Generated: 2026-05-02
- Threshold: 0.2
- Status: PASSED

## Clarity Breakdown

| Dimension | Score | Weight | Weighted |
|-----------|-------|--------|----------|
| Goal Clarity | 0.85 | 0.35 | 0.298 |
| Constraint Clarity | 0.85 | 0.25 | 0.213 |
| Success Criteria | 0.90 | 0.25 | 0.225 |
| Context Clarity | 0.85 | 0.15 | 0.128 |
| **Total Clarity** | | | **0.863** |
| **Ambiguity** | | | **13.75%** |

## Goal

为 caj2pdf 项目的 native C/C++ 库添加 CMakeLists.txt 和 Makefile 构建系统，使 Linux 用户可以用 `cmake` / `make` 一键编译出 `libjbigdec.so` 和 `libjbig2codec.so`，并支持从 Linux 交叉编译 Windows `.dll`。

## Constraints

- **仅 Linux + Windows**：不处理 macOS（`.dylib`）支持
- **离线编译**：编译过程不依赖 pip/npm 等网络包管理器。系统包管理器（apt）安装的库（如 libpoppler-dev, libjbig2dec-dev）视为已满足
- **mutool 不变**：mutool 通过系统包管理器安装，不走项目编译
- **只改构建系统**：不重构 Python 代码、不修复 temp 文件、不修 error handling。只加 CMakeLists.txt / Makefile
- **两种 JBIG2 后端**：libpoppler 和 libjbig2dec 至少支持一种，两种都支持更好

## Non-Goals

- macOS `.dylib` 支持
- Python 代码重构（temp 文件、错误处理、文件句柄泄漏等）
- mutool 替代或打包
- pip installable package
- CI/CD 配置
- 自动化测试脚本

## Acceptance Criteria

- [ ] Linux 上运行 `cmake -B build && cmake --build build`（或等效的 `make`）能编译出 `libjbigdec.so` 和 `libjbig2codec.so`
- [ ] 支持从 Linux 交叉编译 Windows `.dll`（MinGW-w64 交叉工具链）
- [ ] 编译产物能被现有的 Python 代码（`jbigdec.py`、`jbig2dec.py`）通过 ctypes 加载
- [ ] README 或 lib/ 下有清晰的编译说明

## Assumptions Exposed & Resolved

| Assumption | Challenge | Resolution |
|------------|-----------|------------|
| "全流程" 指整个 Python 转换流程 | "只加 CMakeLists.txt，其他不管是不是够了？" | 只需编译 native 库，其他不动 |
| "跨平台" 含 macOS | "macOS 是必须的吗？" | 明确排除 macOS |
| "离线" = 所有依赖打包 | "mutool 怎么处理？" | 系统包管理器安装的依赖算"已满足" |
| 重构包含修复代码问题 | "只加 CMakeLists.txt 够吗？" | "能编译就算成功" |

## Technical Context

### 源代码文件

| 文件 | 用途 | 依赖 |
|------|------|------|
| `lib/jbigdec.cc` | JBIG 解码器入口 + `jbigDecode()` ctypes 导出 | `lib/JBigDecode.cc`, `lib/JBigDecode.h` |
| `lib/JBigDecode.cc` | JBIG 算术解码器实现（自包含） | `lib/JBigDecode.h` |
| `lib/JBigDecode.h` | JBigCodec 类声明 | 无 |
| `lib/decode_jbig2data.cc` | JBIG2 解码（libpoppler 后端） | `JBIG2Stream.h`（来自 libpoppler-dev） |
| `lib/decode_jbig2data_x.cc` | JBIG2 解码（libjbig2dec 后端） | `jbig2.h`（来自 libjbig2dec-dev） |

### 现有编译命令（来自源码注释）

```
# libjbigdec.so
cc -Wall -fPIC --shared -o libjbigdec.so jbigdec.cc JBigDecode.cc

# libjbig2codec.so (libpoppler 后端)
cc -Wall `pkg-config --cflags poppler` -fPIC -shared -o libjbig2codec.so decode_jbig2data.cc `pkg-config --libs poppler`

# libjbig2codec.so (libjbig2dec 后端)
cc -Wall `pkg-config --cflags jbig2dec` -fPIC -shared -o libjbig2codec.so decode_jbig2data_x.cc `pkg-config --libs jbig2dec`
```

### 已知技术点

- `lib/jbigdec.cc:84` — `calloc(0x8040, 1)` 硬编码为 Linux x86_64 的 `JBigCodec` 大小。交叉编译到 Windows 32-bit 或 ARM 时可能需要调整
- `jbig2dec.py` 和 `jbigdec.py` 用 `platform.architecture()` 判断加载 `.dll` 还是 `.so`，路径相对于 CWD
- Windows 预编译 DLL 放在 `lib/bin/`，Linux `.so` 放在 `lib/`（项目根目录）

## Ontology (Key Entities)

| Entity | Type | Fields | Relationships |
|--------|------|--------|---------------|
| NativeLibrary | core domain | name, source_files, dependencies, output_path | NativeLibrary compiled_from SourceFiles |
| BuildSystem | supporting | type (cmake/make), targets, flags | BuildSystem produces NativeLibrary |
| SourceFile | supporting | path, language (C++), required_headers | SourceFile belongs_to NativeLibrary |
| Linux | platform | arch (x86_64) | Linux hosts BuildSystem |
| Windows | platform | arch (32/64) | Windows receives CrossCompiledLibrary |
| CrossCompiler | supporting | toolchain (MinGW-w64), target_arch | CrossCompiler runs_on Linux, produces_for Windows |
| Mutool | external system | installed_via (apt/brew) | Mutool used_by PythonCode |
| SystemPackageManager | external system | packages (libpoppler-dev, libjbig2dec-dev) | SystemPackageManager provides dependencies |

## Ontology Convergence

| Round | Entity Count | New | Changed | Stable | Stability Ratio |
|-------|-------------|-----|---------|--------|----------------|
| 1 | 5 | 5 | - | - | N/A |
| 2 | 7 | 1 | 2 | 4 | 85.7% |
| 3 | 9 | 2 | 0 | 7 | 77.8% |
| 4 | 9 | 0 | 0 | 9 | 100% |
| 5 | 8 | 0 | 0 | 8 | 100% |

Ontology converged at round 4 and remained stable through round 5.

## Interview Transcript

<details>
<summary>Full Q&A (5 rounds)</summary>

### Round 1
**Q:** "一次跑通全流程" 最接近哪一种？单命令转换 / 零依赖安装 / 全自动批量 / 全部都要？
**A:** 主要是使用 make 和 cmake 等工具简化编译过程
**Ambiguity:** 68.7% (Goal: 0.35, Constraints: 0.15, Criteria: 0.10, Context: 0.85)

### Round 2
**Q:** 哪些平台必须支持？Linux / macOS / Windows / 无网络？
**A:** Linux 一键编译+转换, 无网络也能用, linux为windows编译
**Ambiguity:** 52.3% (Goal: 0.50, Constraints: 0.30, Criteria: 0.40, Context: 0.85)

### Round 3
**Q:** mutool（MuPDF 命令行工具）在离线约束下怎么处理？
**A:** 假设系统已有 mutool（通过 apt 等系统包管理器安装）
**Ambiguity:** 44.3% (Goal: 0.55, Constraints: 0.50, Criteria: 0.45, Context: 0.85)

### Round 4 (Contrarian)
**Q:** 只加 CMakeLists.txt，不修代码问题，够用吗？
**A:** 不需要考虑 macOS 平台支持，优先考虑 Linux 和 Windows
**Ambiguity:** 34.5% (Goal: 0.65, Constraints: 0.70, Criteria: 0.50, Context: 0.85)

### Round 5
**Q:** 验收标准：能编译 / 至少两个样本通过 / 所有样本通过 / 自动化脚本？
**A:** 能编译就算成功
**Ambiguity:** 13.75% (Goal: 0.85, Constraints: 0.85, Criteria: 0.90, Context: 0.85)

</details>
