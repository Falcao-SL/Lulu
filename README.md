# Lulu

App nativo de macOS para subir um servidor local compatível com a API da OpenAI e ver o que ele gasta de memória.

## O que faz

- Instala e remove os motores `mlx-lm`, `mlx-vlm` (uv) e `llama.cpp` (Homebrew).
- Lista os modelos em `~/models/mlx` e `~/models/gguf`, e apaga o que você escolher.
- Busca e baixa modelos no Hugging Face. A fila pausa, continua e retoma o arquivo incompleto. A chave `hf_…` fica no Keychain e só sai no pedido ao Hugging Face. Modelo público baixa sem chave.
- Sobe e derruba o servidor em `http://127.0.0.1:8000/v1`. O llama.cpp usa flash attention, as camadas na GPU e os núcleos de desempenho.
- Mostra pesos, KV cache reservado e em uso, contexto, tokens por segundo e a memória unificada. O purge derruba o servidor e pede ao macOS para liberar a memória inativa.

## Build

```bash
make build
make install
make package
```

O app fica em `build/Lulu.app`. `make package` gera o zip e o DMG em `dist/`.

## Distribuição

Cada push na `main` dispara `.github/workflows/release-macos.yml` no runner macOS da org (`self-hosted`, `macOS`, `ARM64`). O job compila o Lulu para Apple Silicon, assina ad hoc e publica uma release `v2.0.<número do job>` com:

- `Lulu-<versão>-macos-arm64.zip`
- `Lulu-<versão>-macos-arm64.dmg`
- `SHA256SUMS`

A versão de marketing está em `VERSION`. O número do job entra como terceiro componente e como `CFBundleVersion`.
