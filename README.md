# Local LLM Manager

A lightweight, native macOS (Swift / SwiftUI) controller to run and monitor local LLM inference engines on Apple Silicon.

Designed specifically for developers who want a clean, zero-bloat alternative to heavy Electron apps. It automatically manages **`mlx-lm`** / **`mlx-vlm`** (Apple MLX) and **`llama.cpp`** (GGUF), with real-time Unified Memory diagnostics.

---

## ✨ Features

- **Native & Ultra-Lightweight:** Written 100% in Swift & SwiftUI for macOS. No Electron, no Python runtime overhead for the GUI.
- **Model Discovery:** Automatically discovers models placed in `~/models/mlx` and `~/models/gguf`.
- **Intelligent Engine Selection:**
  - Standard MLX models $\rightarrow$ `mlx_lm.server`
  - Multimodal/Vision MLX models $\rightarrow$ `mlx_vlm.server`
  - GGUF models $\rightarrow$ `llama-server` (with automatic multimodal projector `--mmproj` detection)
- **Real-Time Memory Diagnostics:**
  - Displays actual resident memory (RSS) consumed by the active engine process (Model weights + KV Cache + activation buffers).
  - Shows total system Unified Memory and currently available RAM.
  - Visual color-coded memory proportion bar.
- **Context Size Control:** Quick presets for context length (2k, 4k, 8k, 16k, 32k, 64k tokens).
- **One-Click OpenAI-Compatible API:** Exposes `http://localhost:8000/v1` for instant use with Cursor, VS Code (Continue/Roo Code), Chatbox, or custom scripts.
- **Instant Engine Lifecycle:** One click to start, switch, or terminate engines, freeing 100% of GPU/Unified Memory.

---

## 📂 Model Directory Structure

Place your models inside `~/models/`:

```text
~/models/
├── mlx/
│   ├── Qwen3.5-9B-MLX-4bit/
│   └── MiniCPM-V-4.7-35B-A3B-OptiQ-4bit-REAP-19B/
└── gguf/
    ├── LFM3-Omni-2B/
    │   ├── LFM3-Omni-2B-Q8_0.gguf
    │   └── mmproj-LFM3-Omni-2B-Q8_0.gguf
    └── model-name.gguf
```

---

## 🛠️ Prerequisites

Ensure your inference backends are installed:

- **MLX (`mlx-lm` / `mlx-vlm`):**
  ```bash
  uv tool install mlx-lm
  uv tool install mlx-vlm
  ```
- **llama.cpp:**
  ```bash
  brew install llama.cpp
  ```

---

## 🚀 Building & Installing

### Quick Install (to `/Applications`)
```bash
make install
```

### Build Only
```bash
make build
# Binary and .app bundle created in build/Local LLM Manager.app
```

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.
