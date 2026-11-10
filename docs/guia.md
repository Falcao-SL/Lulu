# Guia do Lulu

## Biblioteca e downloads

O Lulu procura modelos MLX em `~/models/mlx` e GGUF em `~/models/gguf`. Use **Atualizar** após adicionar arquivos manualmente. Um arquivo isolado de pesos MLX não substitui a configuração e o tokenizer do repositório.

A fila permite pausar e continuar. Arquivos parciais usam a extensão `.incomplete`; remover um download também remove seus arquivos incompletos. Downloads concluídos permanecem na biblioteca. Apagar um modelo exige confirmação; pare o servidor ou pause o download correspondente antes.

A chave opcional do Hugging Face fica em **Modelos**. Use **Guardar chave** para gravá-la no Keychain e **Apagar chave** para removê-la. Se houver token no ambiente, ele ainda pode ser usado após apagar a chave guardada.

## Servidor

Escolha um modelo antes de iniciar. O Lulu verifica se o motor correspondente está instalado e direciona à tela Motores quando necessário. Modelo, contexto e porta ficam bloqueados enquanto o servidor está iniciando ou disponível; pare-o para alterar a configuração.

O llama.cpp usa flash attention, camadas na GPU e threads dos núcleos de desempenho. No MLX, o limite de KV depende do motor e dos metadados disponíveis. Contextos maiores podem consumir mais memória; comece com 4K ou 8K e acompanhe o uso.

O status disponível indica que a verificação HTTP respondeu. Consulte os logs se o motor falhar ao carregar o modelo. Copiar o endpoint não configura automaticamente seu aplicativo cliente.

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
