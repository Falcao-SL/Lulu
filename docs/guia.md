# Guia do Lulu

## Biblioteca e downloads

O Lulu procura modelos MLX em `~/models/mlx` e GGUF em `~/models/gguf`. Use **Atualizar** após adicionar arquivos manualmente. Um arquivo isolado de pesos MLX não substitui a configuração e o tokenizer do repositório.

A fila permite pausar e continuar. Arquivos parciais usam a extensão `.incomplete`; remover um download também remove seus arquivos incompletos. Downloads concluídos permanecem na biblioteca. Apagar um modelo exige confirmação; pare o servidor ou pause o download correspondente antes.

A chave opcional do Hugging Face fica em **Modelos**. Use **Guardar chave** para gravá-la no Keychain e **Apagar chave** para removê-la. Se houver token no ambiente, ele ainda pode ser usado após apagar a chave guardada.

## Servidor

Escolha um modelo antes de iniciar. O Lulu verifica se o motor correspondente está instalado e direciona à tela Motores quando necessário. Modelo, contexto e porta ficam bloqueados enquanto o servidor está iniciando ou disponível; pare-o para alterar a configuração.

O llama.cpp usa flash attention, camadas na GPU e threads dos núcleos de desempenho. No MLX, o limite de KV depende do motor e dos metadados disponíveis. Contextos maiores podem consumir mais memória; comece com 4K ou 8K e acompanhe o uso.

O status disponível indica que a verificação HTTP respondeu. Consulte os logs se o motor falhar ao carregar o modelo.

A chave de acesso fica em **Servidor**. O Lulu gera uma chave `lulu_…` no Keychain; **Mostrar**, **Copiar** e **Regenerar** controlam o valor. O llama.cpp exige essa chave (`--api-key`). Os clientes configurados pelo Lulu recebem a mesma chave.

A fileira **Usar neste Mac** grava o servidor local no OpenCode, Codex, Antigravity, Cursor, Claude Code, OpenClaude, DeepSeek Harness, Aider e Zed. Os outros provedores e chaves permanecem. Com o servidor disponível, o identificador é o que `/v1/models` devolve; com o servidor parado, é uma estimativa. Abra o programa de novo depois de configurar. No Cursor, feche o app antes de configurar: o Lulu adiciona o nome do modelo em **Add Custom Model** (`userAddedModels`), aponta o Base URL e pede para colar a chave em OpenAI API Key. O Codex usa `/v1/responses` e o Claude Code usa `/v1/messages`; o mlx-lm não oferece esses caminhos.

## Entender as métricas

| Métrica | Significado |
| --- | --- |
| Disponível | Memória estimada como disponível pelo monitor do sistema. |
| Processo | Footprint do processo servidor. |
| Pesos | Tamanho dos arquivos do modelo; não é uma medição isolada de alocação na GPU. |
| KV reservado | Estimativa baseada na arquitetura e no contexto escolhido. |
| KV em uso | No MLX, estimativa pelo crescimento do processo após carregar os pesos. |
| Contexto | Limite configurado e pico reportado quando disponível. |
| Prompt / geração | Taxas obtidas do endpoint de métricas suportado pelo motor. |

O painel atualiza periodicamente. **—** significa métrica ainda indisponível. A coleta de tokens/s é feita pelo `/metrics` do llama.cpp; outros motores podem não fornecer esses valores. A barra da visão geral representa a memória usada do Mac inteiro, incluindo outros aplicativos.

**Purge de memória** encerra o servidor e solicita ao macOS a liberação de memória inativa, com confirmação e autenticação administrativa. Não há garantia de um volume específico de memória liberada.

## Resolver problemas

- **Motor ausente:** confira a instalação de `uv` ou Homebrew e leia o log na tela Motores.
- **Acesso negado no Hugging Face:** confirme o token e a autorização ao repositório restrito.
- **Modelo não aparece:** confira a pasta, os arquivos necessários e clique em Atualizar na biblioteca.
- **Servidor falhou:** confira o log, a disponibilidade da porta e a compatibilidade entre modelo e motor. Reduza o contexto se faltar memória.
- **Taxas sem valor:** o motor pode não expor `/metrics`; isso não indica necessariamente falha na inferência.

Para relatar um problema, inclua versão do macOS, chip, motor, modelo e trecho relevante do log. Remova tokens e dados pessoais antes de compartilhar.

## Catálogo de motores

MLX-LM, MLX-VLM e llama.cpp têm instalação, remoção e controle de servidor integrados. Os demais são os aplicativos mais usados neste Mac. Cada um continua dono dos próprios modelos e do próprio servidor.

| Opção adicional | Instalação no catálogo | Execução |
| --- | --- | --- |
| Nativ | Botão Instalar via Homebrew; Apple Silicon e macOS 26 ou posterior | Pelo Nativ |
| Ollama | Botão Instalar via Homebrew ou download oficial | Pelo Ollama |
| LM Studio | Botão Instalar via Homebrew ou download oficial | Pelo LM Studio |
| Jan | Botão Instalar via Homebrew | Pelo Jan |
| Llama | Botão Instalar via Homebrew; Apple Silicon e macOS 15 ou posterior | Pelo app de barra de menus |
| GPT4All | O Homebrew baixa o instalador | Pelo GPT4All, depois de concluir o instalador |
| vLLM Metal | Botão Instalar via Homebrew; requer macOS 15 ou posterior | Pelo comando `vllm serve` |
| KoboldCpp | Download da release oficial | Pelo binário baixado |
| Strata | Download da release oficial | Pelo Strata, conforme modelo e hardware |
| Colibri | Download da release oficial | Pelo launcher Colibri e Python 3 |

As instalações Homebrew aparecem em **Atividade de instalação**. Elas não iniciam serviços automaticamente. KoboldCpp, Strata e Colibri seguem seus próprios instaladores; o Lulu não os inicia ou remove. Nenhum motor adicional é instalado apenas ao abrir o catálogo.

Referências oficiais: [Nativ](https://github.com/Blaizzy/nativ), [Ollama no Homebrew](https://formulae.brew.sh/formula/ollama), [LM Studio no Homebrew](https://formulae.brew.sh/cask/lm-studio), [Jan](https://formulae.brew.sh/cask/jan), [Llama](https://formulae.brew.sh/cask/llama-app), [GPT4All](https://formulae.brew.sh/cask/gpt4all), [vLLM Metal](https://docs.vllm.ai/projects/vllm-metal/en/latest/installation/), [KoboldCpp](https://github.com/LostRuins/koboldcpp), [Strata para Mac](https://github.com/Niko1221/Strata/blob/main/docs/MAC.md), [Colibri](https://github.com/JustVugg/colibri).

## Busca com metadados

Busque por nome, organização/repositório ou URL do Hugging Face. Os filtros **Publicador** e **Formato** (MLX/GGUF) são enviados ao Hub; **Ordenar** permite downloads, curtidas ou atualização. Clique em Buscar após ajustar os filtros. A lista retorna até 40 resultados.

Cada resultado distingue o **publicador** do repositório e o **laboratório do modelo base**: este último corresponde à organização no campo `base_model` da model card, quando informado, e não é uma atribuição verificada de autoria. Quantização é uma indicação inferida do nome e das tags; um repositório GGUF pode conter várias quantizações, que aparecem junto aos arquivos. Parâmetros, licença, tarefa e atualização só aparecem quando fornecidos pela API. Ausência de metadados é indicada sem inventar valores.

**Ver arquivos** carrega o repositório para seleção antes de baixar. Uma nova busca descarta respostas anteriores ainda em trânsito. A documentação dos campos está na [API do Hugging Face](https://huggingface.co/docs/huggingface_hub/package_reference/hf_api).

O botão **Purge de memória** também está na Visão geral, dentro do cartão de memória, e usa a mesma confirmação da tela Desempenho.

## Contextos maiores

A tela Servidor oferece de 2.048 até 1.048.576 tokens, incluindo 128K, 256K e 512K. O seletor usa um menu para acomodar as opções. Quando há metadados disponíveis, exibe o contexto informado pelo modelo e a estimativa de KV cache. A escolha de um valor maior depende da capacidade do modelo, do motor e da memória disponível. Pare o servidor para alterar o contexto e inicie novamente para aplicar.

A seleção de contexto mostra o custo estimado de KV em cada opção. Três indicadores comparam o tamanho dos pesos, o cache estimado e o subtotal. O subtotal não inclui buffers, projetor multimodal e outras alocações do motor, e pode diferir do consumo real. Sem metadados de KV, a estimativa aparece como —.

## Limite por modelo

O máximo declarado nos metadados locais aparece em destaque na tela Servidor. O menu filtra valores acima desse máximo e inclui o limite exato, mesmo fora dos presets. Ao trocar de modelo, uma configuração acima do máximo é reduzida automaticamente. A inicialização do servidor também valida o limite. Configurações de uma sessão já em execução continuam visíveis até sua parada. Quando os metadados não informam o contexto máximo, a interface identifica essa ausência e não pode garantir a validação.
