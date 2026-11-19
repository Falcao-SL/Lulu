# Status — Lulu

> Atualizado em 2026-11-18.

| Campo | Valor |
|---|---|
| **O que é** | Seu espaço de IA local para Mac. Controla motores de inferência (MLX e llama.cpp), serve endpoints compatíveis com OpenAI e monitora memória e desempenho. |
| **Estágio** | **Em desenvolvimento** — Versão 2.0 com suporte a MLX (Apple Silicon) e llama.cpp (Apple Silicon / Intel). |
| **Plataformas** | macOS 14+ (Apple Silicon e Intel x86_64) |
| **Stack** | Swift, AppKit/SwiftUI, llama.cpp, mlx-lm, mlx-vlm, Python/uv, Homebrew |
| **Site** | https://github.com/Falcao-SL/Lulu |
| **Licença** | MIT. Público. |
| **Monetização** | **100% Gratuito** e código aberto |
| **Próximo marco** | Suporte ampliado a modelos de visão (VLM) e refinamento de interface para múltiplos servidores |
| **Data-alvo** | A definir |

## O que já está pronto

- Suporte completo a Apple Silicon (MLX e GGUF via llama.cpp) e Intel (GGUF via llama.cpp).
- Busca e download direto de modelos do Hugging Face para `~/models/mlx` e `~/models/gguf`.
- Integração e instalação de motores automatizada (MLX via `uv`, llama.cpp via Homebrew).
- Servidor local OpenAI-compatible na porta configurável com endpoint `/v1`.
- Configuração com um clique em clientes como OpenCode, Cursor, Codex, Claude Code, Antigravity, Aider e Zed.
- Monitoramento em tempo real de memória de processo, pesos, cache KV, contexto e tokens por segundo.
- Recurso de Purge de memória inativa no macOS.
- Pipeline de release com empacotamento em DMG e ZIP com suporte universal (arm64 e x86_64).

## O que falta

- Ampliar testes de estabilidade sob carga pesada e contextos longos.
- Finalizar suporte completo a rotas avançadas exigidas por alguns clientes.
- Documentação expandida e tradução completa do guia de uso.
