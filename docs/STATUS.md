# Status — Lulu

> Atualizado em 2026-11-27.

| Campo | Valor |
|---|---|
| **O que é** | Seu espaço de IA local para Mac. Gerencia motores e modelos, serve endpoints compatíveis com OpenAI, integra chat web nativo com streaming e opera em segundo plano via barra de menus (Tray Glass). |
| **Estágio** | **Ativo / Em produção** — Versão 2.0 modularizada com suporte a Apple Silicon (MLX/GGUF) e Intel (GGUF), Web Chat integrado e Glass Tray. |
| **Plataformas** | macOS 14+ (Apple Silicon e Intel x86_64) |
| **Stack** | Swift, AppKit/SwiftUI, llama.cpp, mlx-lm, mlx-vlm, Python/uv, Homebrew, SQLite, HyperFrames |
| **Site** | https://github.com/Falcao-SL/Lulu |
| **Licença** | MIT. Público. |
| **Monetização** | **100% Gratuito** e código aberto |
| **Próximo marco** | Otimização de latência em contextos longos e expansão do suporte a novos modelos multimodais de visão e áudio |
| **Data-alvo** | A definir |

## O que já está pronto

- Suporte completo a Apple Silicon (MLX e GGUF via llama.cpp) e Intel (GGUF via llama.cpp).
- Modo bandeja (Menu Bar / Tray Glass) nativo para macOS: execução em segundo plano, popover translúcido, status em tempo real e controle rápido de modelos e servidor.
- Web Chat local embutido (`/chat`): interface web nativa com streaming de respostas, suporte a Markdown, anexos multimídia (PNG, JPEG, WAV, MP3, FLAC) e histórico persistente em SQLite (`~/.lulu/chats.sqlite3`) com exportação para Markdown.
- Catálogo de recomendações inteligentes de modelos: sugestões calibradas com base no perfil de hardware do Mac (Apple Silicon vs Intel, quantidade de memória RAM unificada).
- Busca e gerenciamento avançado de downloads do Hugging Face para `~/models/mlx` e `~/models/gguf`, com fila assíncrona, pausa/retomada e limpeza automática de arquivos parciais (`.incomplete`).
- Integração e instalação automatizada de motores de inferência (MLX via `uv`, llama.cpp via Homebrew ou compilado).
- Servidor local OpenAI-compatible na porta configurável com endpoint `/v1` e chave de acesso gerada no Keychain.
- Configuração com um clique em clientes locais de IA: OpenCode, Codex, Claude Code, Aider, Zed, Pi e OpenBot Desktop.
- Monitoramento em tempo real de memória (processo, pesos, cache KV, contexto) e velocidade de geração (tokens por segundo via `/metrics`).
- Recurso de Purge de memória inativa no macOS com liberação do sistema.
- Seletor de aparência persistente (Claro, Escuro e Sistema) alinhado ao Design System Lulu (identidade visual verde/menta/marfim).
- Landing page e documentação em inglês, com vídeos de demonstração interativos (HyperFrames: getting-started, tour, tour-dark).
- Pipeline automatizado de release com empacotamento universal (arm64 e x86_64), assinaturas, notarização da Apple e distribuição via DMG e ZIP.
- Arquitetura Swift modularizada por recursos (`App`, `Features`, `Infrastructure`, `Shared`).

## O que falta

- Ampliar testes de estabilidade sob carga concorrente pesada e contextos ultralongos.
- Refinar suporte completo a rotas avançadas específicas exigidas por ferramentas de terceiros.
- Finalizar traduções complementares da documentação técnica e guias de uso.
