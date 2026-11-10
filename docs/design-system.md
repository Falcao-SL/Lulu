# Design system do Lulu

O Lulu combina superfícies discretas, verde de destaque e a marca do gato. A fundação compartilhada está em `Sources/LocalLLMManager/DesignSystem.swift`. O guia interativo fica no menu **Ajuda → Guia visual do Lulu**, com prévias clara e escura e exemplos de componentes.

## Cores

Use os nomes semânticos na interface para que as cores acompanhem a aparência do macOS.

| Token | Claro | Escuro | Uso |
| --- | --- | --- | --- |
| `accent` | #246754 | #91D8BD | Ações, seleção e símbolos |
| `canvas` | #F3F6F2 | #131B1A | Fundo da área de trabalho |
| `surface` | #FDFFFC | #1B2624 | Cartões e painéis |
| `subtle` | #E5F2EB | #243B34 | Destaques suaves e ícones |
| `border` | #CCDAD1 | #354B42 | Contornos e separação |
| Informação | #246754 | #91D8BD | Operação em andamento |
| Atenção | #78490E | #EDC788 | Situação que pede revisão |
| Falha | #943B3F | #F3AAAE | Erro operacional |

Texto principal e secundário usam as cores semânticas do sistema. A marca mantém verde profundo, menta e marfim em ambas as aparências. O contraste calculado do destaque sobre o painel é 6,65:1 no tema claro e 9,46:1 no escuro. Esses valores se referem a esse par de cores, e não a uma auditoria completa de acessibilidade.

## Tipografia e medidas

A tipografia usa a família nativa do macOS. Títulos de página e métricas usam desenho arredondado. Valores numéricos usam dígitos tabulares.

| Token | Estilo |
| --- | --- |
| `TypeStyle.page` | largeTitle, rounded, semibold |
| `TypeStyle.section` | headline |
| `TypeStyle.body` | body |
| `TypeStyle.caption` | caption |
| `TypeStyle.metric` | title, rounded, semibold, monospacedDigit |

A escala de espaçamento é `xs` 4, `sm` 8, `md` 12, `lg` 16, `xl` 24 e `xxl` 32 pontos. Use 24 pontos entre seções, 16 dentro dos painéis e 8 a 12 entre elementos relacionados. Os raios são 8 pontos para superfícies pequenas e 14 para painéis. Controles nativos preservam sua geometria e foco de teclado.

## Componentes

| Componente | Uso |
| --- | --- |
| `LuluPageHeader` | Título e símbolo da tela |
| `LuluSectionHeader` | Identificação de uma seção |
| `LuluIcon` | Símbolo decorativo sobre fundo suave |
| `.luluCard()` | Superfície e contorno, aplicado após o padding |
| `LuluStatusBadge` | Estado com texto, símbolo e cor |
| `LuluMetric` | Rótulo, valor e símbolo em cartão |

```swift
VStack(alignment: .leading, spacing: LuluTheme.Space.md) {
    LuluSectionHeader("Servidor local", symbol: "server.rack")
    LuluStatusBadge("Disponível", tone: .success)
}
.padding(LuluTheme.Space.lg)
.luluCard()
```

Ações principais usam `.borderedProminent`, ações secundárias usam `.bordered` e ações destrutivas usam `Button(role: .destructive)`. Instalar, apagar e purgar devem manter as validações e confirmações de suas operações. Controles desabilitados continuam usando o comportamento nativo.

Estados usam `neutral` para parado, `info` para atividade, `success` para disponível, `warning` para atenção e `danger` para falha. Inclua sempre texto e símbolo para que a cor não seja o único indicador. Um valor indisponível aparece como `—`.

## Composição e acessibilidade

- Organize cada tela com um título, ações e seções de conteúdo relacionadas.
- Use os vetores Lucide incorporados ao Lulu, coerentes com a ação e rótulos visíveis nos controles importantes.
- Preserve leitura e operação por teclado nos controles nativos.
- Use grades adaptativas ou reorganização vertical quando os metadados não couberem na largura disponível.
- A marca do gato aparece na navegação e nos pontos de identidade. Ícones de operação comunicam tarefas.
- Cartões reforçam o contorno quando o macOS solicita contraste aumentado.

O painel, os motores, a biblioteca, os resultados da busca, o servidor e as métricas compartilham a fundação. Alterações na paleta e nas medidas devem começar em `DesignSystem.swift` e ser conferidas nas duas aparências pelo guia visual.

## Assinatura da marca

O componente LuluEmblem reúne o gato em um selo com gradiente menta e marfim, usado na navegação e no cartão de sessão. LuluSignature deriva três traços dos bigodes e assina os cabeçalhos. Ambos são decorativos e ficam ocultos da leitura assistiva. O modificador luluIdentityPanel destaca a sessão com uma transição suave entre seleção e painel. Reserve esses detalhes aos pontos de identidade para preservar a hierarquia das telas.

## Ícones locais e desempenho

Os SVGs Lucide e a licença ISC/MIT estão em ThirdParty/Lucide. A geometria convertida fica em LuluVectorPaths.swift. LuluGlyph desenha esses caminhos locais e compartilha o catálogo em memória. A execução não usa SF Symbols, arquivos SVG nem bibliotecas Python. Scripts/generate-icons.py permite regenerar os caminhos a partir dos SVGs usando fonttools durante o desenvolvimento. A licença também acompanha o bundle distribuído.

O gato usa verde profundo (#123329) no aplicativo e no ícone de distribuição. A navegação desenha sua seleção com o token subtle, independente do destaque escolhido no macOS. Estados informativos também usam verde. Alertas e falhas mantêm seus tons semânticos e símbolos próprios.

O monitoramento usa intervalos de 1 segundo com servidor ativo, 5 segundos em repouso e 10 segundos com a janela inativa. Leituras da árvore de processos para métricas ocorrem na Visão geral e em Desempenho. O log é consultado na tela Servidor. A memória física total e a porta Mach do host são reutilizadas, e snapshots iguais evitam republicações. Esses ajustes reduzem trabalho recorrente, sem estabelecer uma garantia de latência ou consumo em todo hardware.
