# Apuração Assistida da CBS (RSB_Apur_Assistida)

Uma extensão AL para o Business Central que integra com a API de **Apuração Assistida da
CBS** da Receita Federal, coleta automaticamente os dados de débitos de CBS e os concilia
com o histórico fiscal próprio da empresa (NF-e emitidas).

> **CBS** (Contribuição sobre Bens e Serviços) é o novo tributo brasileiro sobre bens e
> serviços criado pela reforma tributária de 2023. A "Apuração Assistida" é o serviço
> oficial da Receita Federal que pré-calcula a CBS devida por um contribuinte, com base
> nas NF-e já emitidas, disponibilizando esse cálculo por meio de uma API REST.

## 1. O que esta extensão faz

1. **Coleta** os dados de débito junto à API da Receita Federal em um cronograma, usando
   a Job Queue padrão do Business Central.
2. **Importa** o JSON devolvido pela API em tabelas normalizadas e auditáveis.
3. **Publica** cada lote de forma atômica — um lote só fica visível depois que toda a
   importação termina sem erros, garantindo que o painel nunca exiba dados parciais.
4. **Concilia** cada débito importado com o histórico fiscal próprio da empresa (as NF-e
   realmente emitidas), sinalizando conciliações, divergências e lacunas.
5. **Apresenta** o resultado em um painel filtrável por competência, com navegação para
   todos os registros de apoio (solicitações, arquivos, lotes, log de eventos).

## 2. Escopo (MVP)

| Área | Status |
|---|---|
| Serviço de **Débitos** da CBS (`/debitos`) | ✅ Implementado |
| Serviços de Créditos, Pagamentos, Recolhimentos | 🔲 Previstos para uma fase posterior (os valores do enum já existem, mas sem lógica de coleta) |
| Autenticação OAuth2 Client Credentials | ✅ Implementado (segredo gravado apenas em Isolated Storage, nunca em campo de tabela ou em log) |
| Coleta automática via Job Queue | ✅ Implementado (máquina de estados com repetição/backoff) |
| Publicação atômica de lotes e idempotência por hash do arquivo | ✅ Implementado |
| Conciliação com o histórico fiscal | ✅ Implementado por meio de uma interface plugável (`ICbsFiscalHistory`) — a extensão entrega apenas um adaptador padrão "sem vínculo"; uma extensão de localização/parceiro deve fornecer o adaptador real que lê as NF-e da empresa |
| Consulta inversa (notas emitidas sem débito correspondente) | ✅ Implementado |
| Laudo de cobertura/lacunas por competência | ✅ Tabela e exportação prontas; o job que o alimenta fica a cargo do parceiro implementador |
| Exportação em CSV (resultado da conciliação, laudo de cobertura) | ✅ Implementado |
| Log de auditoria/telemetria | ✅ Implementado (`CBS Log Entry`) — nunca grava tokens, segredos, URLs assinadas ou o conteúdo de documentos fiscais |

Tudo é tratado por **uma empresa por vez** (aproveita-se o isolamento nativo de dados por
empresa do Business Central, em vez de um campo "Empresa" customizado em cada tabela).

## 3. Arquitetura da solução (visão geral)

```
Job Queue ──▶ CBS Job Queue Dispatcher ──▶ CBS Collection Orchestrator ──▶ ICbsHttpClient
                                                                              │
                                                              CBS Tax Authority Connector
                                                                              │
                                                                     CBS File (JSON bruto)
                                                                              │
                                                                     CBS Batch Publisher
                                                                              │
                                                                     CBS JSON Importer
                                                                              │
                                                                   CBS Debt (lançamentos)
                                                                              │
                                                              CBS Reconciliation Engine ──▶ ICbsFiscalHistory
                                                                              │                  │
                                                                     CBS Reconciliation    CBS Default Adapter
                                                                                           (parceiro fornece o real)
```

Principais decisões de design:

- **Dois pontos de extensibilidade** mantêm o núcleo independente de qualquer
  localização ou ferramenta de teste específica:
  - `ICbsHttpClient` — permite trocar o `CBS Tax Authority Connector` real por um mock em
    testes.
  - `ICbsFiscalHistory` — permite trocar o adaptador padrão (sem operação) por um que leia
    dados reais de NF-e de qualquer extensão de localização que as administre.
- **Segredos nunca tocam um campo de tabela.** O segredo do cliente OAuth2 fica apenas em
  Isolated Storage e só é lido como `SecretText`.
- **Detecção de colisão de chave natural.** Uma nova coleta nunca sobrescreve
  silenciosamente um registro existente de `CBS Debt`; a substituição só ocorre por meio
  de um lote explícito de republicação.
- **Publicação atômica.** Um lote só é marcado como `Published` depois que toda a
  importação termina sem erro, em uma única transação final.

## 4. Referência de objetos

| Tipo | Nome | Finalidade |
|---|---|---|
| Tabela | `CBS Setup` | Registro único de configuração por empresa |
| Tabela | `CBS Credential` | Credenciais OAuth2 Client Credentials por ambiente |
| Tabela | `CBS Request` | Uma linha por ciclo de coleta (tiquete, máquina de estados) |
| Tabela | `CBS File` | JSON bruto baixado da Receita Federal |
| Tabela | `CBS Debt` | Lançamentos normalizados de débito de CBS (o dado principal) |
| Tabela | `CBS Batch` | Controle de publicação atômica |
| Tabela | `CBS Reconciliation` | Avaliações de conciliação (trilha de auditoria, uma linha por avaliação) |
| Tabela | `CBS Coverage` | Cobertura/lacunas de coleta por competência |
| Tabela | `CBS Log Entry` | Log de eventos de auditoria/telemetria |
| Tabela | `CBS Fiscal History Buffer` | Buffer de transferência temporário usado por `ICbsFiscalHistory` |
| Interface | `ICbsHttpClient` | Abstração HTTP para a API da Receita Federal |
| Interface | `ICbsFiscalHistory` | Abstração sobre o histórico fiscal próprio da empresa |
| Página | `CBS Setup Card` | Configuração |
| Página | `CBS Credential List` / `CBS Credential Card` | Gestão de credenciais |
| Página | `CBS Panel` | Painel principal por competência |
| Página | `CBS Debt List` | Todos os débitos importados |
| Página | `CBS Request List` | Histórico/diagnóstico dos ciclos de coleta |
| Página | `CBS Reconciliation List` | Trilha de auditoria da conciliação |

## 5. Passo a passo: páginas e configuração inicial

### Passo 1 — Criar uma credencial (`CBS Credential List` → `CBS Credential Card`)

1. Abra **Credenciais CBS** (pela busca ou pela ação *Credenciais* da página de Setup).
2. Crie um novo registro: `Código`, `Descrição`, `Ambiente` (Produção ou Produção
   Restrita/homologação), `Client Id`, `URL do Token` e `Escopo (scope)` conforme
   registrado junto à Receita Federal.
3. No campo mascarado **Segredo do Cliente**, digite o segredo uma única vez e saia do
   campo — ele é gravado diretamente em Isolated Storage e o valor digitado é limpo da
   tela imediatamente. O indicador **Segredo Configurado** confirma que foi armazenado.
4. Marque **Ativo** = Sim.

### Passo 2 — Configurar a empresa (`CBS Setup Card`)

1. Abra **CBS Setup**.
2. Em **Configuration**: escolha o `Ambiente`, preencha o `CNPJ Base` (8 dígitos) e o
   `CNPJ Contribuinte` (14 dígitos), selecione a `Credencial` criada no Passo 1 e o
   `Serviço Ativo` (apenas *Débitos* está implementado).
3. Em **Reconciliation**: escolha o `Adaptador de Histórico Fiscal` (requer uma extensão
   parceira que implemente `ICbsFiscalHistory`; deixe em *Sem Vínculo* caso contrário) e
   defina a `Tolerância de Conciliação` (diferença máxima aceita para classificar um
   débito como *Conciliada*).
4. Em **Default panel filters**: defina a `Competência Inicial`/`Competência Final`
   padrão exibidas ao abrir o painel.
5. Em **Operation**: revise a `Janela Incremental (Dias)`, a `Retenção do JSON Original
   (Dias)` e a `Cota de Aberturas por Dia` (valores padrão já vêm preenchidos).
6. Use as ações **Credenciais** e **Painel CBS** para navegar sem sair do fluxo de
   configuração.

### Passo 3 — Agendar a coleta automática

Crie uma **Job Queue Entry** com:
- *Object Type to Run* = Codeunit
- *Object ID to Run* = `CBS Job Queue Dispatcher` (50138)
- Uma recorrência (por exemplo, a cada 15–30 minutos)

Cada execução processa qualquer solicitação ainda em andamento e abre uma nova se não
houver nenhuma pendente e a cota diária permitir. Nenhuma ação manual é necessária depois
disso; o progresso pode ser acompanhado em **Solicitações CBS**.

### Passo 4 — Acompanhar o progresso da coleta (`CBS Request List`)

Abra **Solicitações CBS** para ver cada ciclo de coleta, seu `Estado Local` (a máquina de
estados da própria extensão) e `Estado Remoto` (conforme a última informação da API),
além de contadores de tentativas e datas/horas. Use esta página para diagnosticar uma
solicitação travada ou com falha — o campo `Detalhe do Estado Remoto` traz a última
mensagem de erro.

### Passo 5 — Revisar os débitos importados (`CBS Debt List`)

Abra **Débitos CBS** para ver cada registro de débito normalizado (competência,
documento, chave de acesso da NF-e, origem e o detalhamento de cada valor de CBS). Use a
ação **Conciliações** em uma linha para ir direto ao seu histórico de conciliação.

### Passo 6 — Revisar os resultados da conciliação (`CBS Reconciliation List`)

Abra **Conciliações CBS** para ver cada avaliação, sua `Classificação` (Conciliada,
Divergente, Ajuste, Nota sem Débito Localizado, Débito sem Nota Localizada, Nota
Vinculada sem CBS Declarada, Sem Adaptador de Histórico Fiscal Vinculado), a `Diferença`
calculada e quem/quando avaliou.

### Passo 7 — Usar o painel no acompanhamento do dia a dia (`CBS Panel`)

Abra o **Painel CBS** (também acessível pela página de Setup). Ele abre pré-filtrado pelo
intervalo de competência padrão configurado no Passo 2 e exibe os débitos filtrados junto
com os totais de **Total CBS Apurado** e **Total Saldo Devedor**. Altere os filtros da
página para consultar qualquer outra competência, ambiente ou NI. Use a ação
**Conciliações** para detalhar um débito específico.

## 6. Traduções

A extensão vem com o recurso `TranslationFile` habilitado. Todo o código-fonte AL — nomes
de objetos, campos, procedures, captions, tooltips e mensagens de erro — está escrito em
inglês (`en-US`), que é o idioma base/de origem. Uma tradução completa para o português
do Brasil é fornecida em
[`Translations/RSB_Apur_Assistida.pt-BR.xlf`](./Translations/RSB_Apur_Assistida.pt-BR.xlf),
cobrindo todo caption, tooltip e mensagem exibida ao usuário. Identificadores técnicos que
vêm diretamente do contrato JSON da Receita Federal (por exemplo, `pa`, `cbs`, `chave`,
`tiqueteSolicitacao`) foram deliberadamente mantidos inalterados no código, já que
alterá-los quebraria a integração.

Para adicionar outro idioma, execute `createLanguageXlf` sobre
`Translations/RSB_Apur_Assistida.g.xlf` com o novo código de idioma e traduza o arquivo
resultante.

## 7. Notas de segurança

- O segredo do cliente OAuth2 **nunca** é gravado em campo de tabela, nunca é registrado
  em log e nunca é convertido para `Text` simples — ele circula exclusivamente como
  `SecretText`/Isolated Storage.
- A telemetria e o log de auditoria (`CBS Log Entry`) armazenam apenas metadados técnicos
  (códigos, contadores, durações); nunca armazenam um CNPJ, uma chave de NF-e, um token,
  um segredo ou uma URL assinada.
- `CBS Setup`, `CBS Credential`, `CBS Request`, `CBS File`, `CBS Debt`, `CBS Batch`,
  `CBS Reconciliation`, `CBS Coverage` e `CBS Log Entry` são todos `Access = Internal`;
  apenas as páginas listadas na seção 4 os expõem ao usuário final.

## 8. Pendências / marcações `[VALIDAR]`

Alguns detalhes de integração estão marcados com `[VALIDATE]`/`[VALIDAR]` diretamente no
código-fonte e precisam ser confirmados na documentação oficial da Receita Federal antes
de ir para produção: URLs base oficiais, endpoint de token, escopo OAuth2 exigido e o
formato exato de data-hora de `urlAssinadaExpiraEm`. Pesquise por `[VALIDATE]` no
código-fonte para encontrar cada ocorrência.
