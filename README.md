# Lulu

<img src="docs/assets/lulu-icon.png" width="112" alt="Ícone do Lulu: gato verde profundo sobre fundo menta" />

**Sua IA, neste Mac.** Um app nativo para organizar modelos, executar servidores locais e acompanhar memória e desempenho, sem alternar entre terminais.

O Lulu usa SwiftUI e requer **macOS 14 ou posterior**, em Apple Silicon ou Intel. Os motores são instalados separadamente: MLX via `uv` (somente Apple Silicon) e llama.cpp via Homebrew (inclusive Intel, com modelos GGUF).

## Um painel para começar

| Área | O que você encontra |
| --- | --- |
| **Visão geral** | Status do servidor, modelo ativo, memória disponível, geração em tokens/s, modelos locais e downloads ativos. Atalhos mostram os próximos passos. |
| **Motores** | Instalação integrada de mlx-lm, mlx-vlm e llama.cpp. O catálogo também instala Nativ, Ollama, LM Studio, Jan, Llama, GPT4All e vLLM Metal, e aponta o download de KoboldCpp, Strata e Colibri. |
| **Modelos** | Busca com filtros de formato/publicador e ordenação, metadados de origem e quantização, seleção de arquivos, downloads e biblioteca local. |
| **Servidor** | Seleção do modelo, contexto, porta, início/parada, endpoint, configuração do OpenCode e logs. |
| **Desempenho** | Memória do processo, pesos, KV cache, contexto e memória do sistema. |

## Primeiro uso

1. Em **Motores**, instale o motor compatível com seu modelo. É necessário ter `uv` para MLX ou Homebrew para llama.cpp disponíveis no Mac.
2. Em **Modelos**, busque um nome ou informe `organização/repositório`. Selecione os arquivos e baixe. Para MLX, inclua pesos, configuração e tokenizer; para GGUF, escolha a quantização desejada e o projetor multimodal quando necessário.
3. Em **Servidor**, selecione o modelo, ajuste contexto e porta e clique em **Iniciar servidor**.
4. Aguarde o status disponível. Copie o endpoint ou toque no ícone do programa em **Usar neste Mac**.

O endereço padrão é `http://127.0.0.1:8000/v1`. O servidor escuta apenas neste Mac. Os ícones configuram OpenCode, Codex, Antigravity, Cursor, Claude Code, OpenClaude, DeepSeek Harness, Aider e Zed sem apagar os outros provedores.

Consulte o [guia de uso e diagnóstico](docs/guia.md) para arquivos locais, downloads e interpretação das métricas.

## Compilar

Com as Command Line Tools do Xcode e o SDK do macOS instalados:

```bash
make build
open build/Lulu.app
```

O bundle fica em `build/Lulu.app`. `make install` compila e substitui `/Applications/Lulu.app`. `make package` gera ZIP e DMG em `dist/`.

O ícone é desenhado com Core Graphics em todos os tamanhos pelo script `Scripts/render-icon.swift`. A mesma geometria vetorial do gato aparece no app; não há dependência de imagens remotas.

## Dados e privacidade

- Modelos: `~/models/mlx` e `~/models/gguf`.
- Sessão e log: `~/.lulu/session.json` e `~/.lulu/engine.log`.
- Token do Hugging Face: Keychain do macOS; também aceita `HF_TOKEN` ou `HUGGING_FACE_HUB_TOKEN` do ambiente.
- Modelos públicos podem ser baixados sem token. Modelos restritos exigem acesso concedido no Hugging Face.
- Busca, download e instalação de motores usam a rede. A inferência acontece no servidor local.

## Distribuição

Cada push na `main` aciona `.github/workflows/release-macos.yml` no runner da organização (`self-hosted`, `macOS`, `ARM64`). O fluxo compila para arm64 e x86_64, assina ad hoc e publica a release `v2.0.<número do job>` com ZIP e DMG para cada arquitetura e `SHA256SUMS`. A assinatura ad hoc não equivale à notarização da Apple.

`VERSION` registra a versão de marketing; o pipeline usa o número do job como terceiro componente e `CFBundleVersion`.

## Estrutura

- `LuluApp.swift`: navegação e telas de operação.
- `OverviewPane.swift`: painel inicial.
- `DesignSystem.swift`: tokens e componentes visuais compartilhados.
- `DesignSystemGuide.swift`: galeria interativa no menu Ajuda.
- `AppModel.swift`: estado, operações e acompanhamento do servidor.
- `Downloads.swift`, `Engines.swift`: transferências e motores.
- `Memory.swift`, `Architecture.swift`: métricas e metadados.
- `CatGeometry.swift`: marca vetorial compartilhada.

Licença [MIT](LICENSE).

## Design system

O [guia do design system](docs/design-system.md) documenta paleta clara e escura, tipografia, espaçamentos, estados e componentes. No app, abra **Ajuda → Guia visual do Lulu** para explorar as amostras.

Os ícones de interface usam vetores [Lucide](https://github.com/lucide-icons/lucide) incorporados ao executável, com licença incluída em ThirdParty/Lucide.
