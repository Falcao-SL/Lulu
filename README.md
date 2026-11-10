# Lulu

<img src="docs/assets/lulu-icon.png" width="112" alt="Lulu's green cat icon" />

**Your local AI workspace for Mac.** Lulu manages inference engines and models, starts local servers with an OpenAI-compatible API, and shows memory and performance information in a native macOS app.

Lulu requires macOS 14 or later. Apple Silicon supports MLX and GGUF; Intel Macs use GGUF models with llama.cpp. Engines and models are installed separately.

## What you can do

- Find and download models from Hugging Face, inspect available metadata, and manage local MLX and GGUF files.
- Install and manage the integrated mlx-lm, mlx-vlm and llama.cpp engines. MLX requires Apple Silicon.
- Start and stop a local model server, choose a context and port, and copy the API endpoint.
- Configure supported clients, including OpenCode, Cursor, Codex, Claude Code, Aider and Zed. Client protocol support depends on the selected engine.
- Monitor process and system memory, model weights, KV cache, context and generation speed when reported by the engine.
- Purge memory: Lulu stops its server and asks macOS to release inactive memory.

## Getting started

1. Download the appropriate DMG from [the latest release](https://github.com/Falcao-SL/Lulu/releases/latest). Check the release notes for signing and installation details.
2. In **Engines**, install an engine compatible with your Mac and model. MLX uses `uv`; llama.cpp uses Homebrew.
3. In **Models**, search for a model or enter its Hugging Face repository and download its required files. MLX models need weights, configuration and tokenizer; GGUF models may also need a multimodal projector.
4. In **Server**, select the model, set a context and start the server. The default endpoint is `http://127.0.0.1:8000/v1` and listens only on this Mac.
5. Copy the endpoint or configure a supported client. For example, mlx-lm does not provide the `/v1/responses` or `/v1/messages` routes required by some clients.

The [user guide](docs/guia.md) contains additional details on downloads, memory and troubleshooting. Its translation is in progress.

## Build and distribution

Install the Xcode Command Line Tools and macOS SDK, then run `make build`. The app is written to `build/Lulu.app`. `make package` creates a DMG and ZIP; set `ARCH=x86_64` for Intel or `ARCH=arm64` for Apple Silicon.

Each push to `main` starts the macOS release workflow, which builds and publishes both architectures, versioned ZIP and DMG files, stable DMG names and SHA-256 checksums. The release pipeline requires Developer ID signing and Apple notarization credentials; local builds use ad hoc signing by default.

## Data and privacy

Models are stored in `~/models/mlx` and `~/models/gguf`; session data and logs are in `~/.lulu/`. A Hugging Face token can be saved in macOS Keychain or supplied through the environment. Inference runs locally; searching, downloading and installing engines use the network.
