# Apuração Assistida da CBS (RSB_Apur_Assistida)

Uma extensão AL para o Business Central que integra com a API de **Apuração Assistida da
CBS** da Receita Federal, coleta automaticamente os dados de débitos de CBS e os concilia
com o histórico fiscal próprio da empresa (NF-e emitidas).

> **CBS** (Contribuição sobre Bens e Serviços) é o novo tributo brasileiro sobre bens e
> serviços criado pela reforma tributária de 2023. A "Apuração Assistida" é o serviço
> oficial da Receita Federal que pré-calcula a CBS devida por um contribuinte, com base
> nas NF-e já emitidas, disponibilizando esse cálculo por meio de uma API REST.

**Plataforma alvo:** Business Central 29 (release wave 2 de 2026), runtime AL 18.0,
exclusivamente SaaS. **Idioma de origem do código:** `en-US` (a tradução pt-BR acompanha o
app — ver seção 7).

---

## 1. O que esta extensão faz

1. **Coleta** os dados de débito junto à API da Receita Federal em um cronograma, usando a
   Job Queue padrão do Business Central (ou sob demanda, com **Executar Coleta Agora**).
2. **Importa** o JSON devolvido pela API em tabelas normalizadas e auditáveis.
3. **Publica** cada lote de forma atômica — um lote só fica visível depois que toda a
   importação termina sem erros, garantindo que o painel nunca exiba dados parciais.
4. **Concilia** cada débito importado com o histórico fiscal próprio da empresa (as NF-e
   realmente emitidas), classificando conciliações, divergências e exceções.
5. **Apresenta** o resultado em um painel filtrável por competência, com navegação para
   todos os registros de apoio (solicitações, arquivos, lotes, log de eventos).

---

## 2. ⚠️ Antes da primeira execução: duas configurações obrigatórias

Ambas são **configuração de ambiente**, não código — a extensão não consegue fazer nenhuma
das duas por você.

### 2.1 Permitir requisições HTTP (Allow HttpClient Requests)

Chamadas HTTP de saída são **bloqueadas por padrão** para toda extensão no Business
Central. Sem essa marcação o conector reporta falha de rede mesmo com credencial e DNS
corretos.

1. Abra **Gerenciamento de Extensões**.
2. Selecione **CBS Assisted Assessment** → **Configurar**.
3. Em **Configurações da Extensão**, marque **Permitir Requisições HttpClient**.

> A cópia de um ambiente redefine essa marcação para `false`. Confira novamente depois de
> qualquer cópia ou restauração de ambiente.

### 2.2 Atribuir um conjunto de permissões

O app entrega três conjuntos de permissões e **não exige SUPER**:

| Conjunto | Perfil | Pode |
|---|---|---|
| **CBS Leitura** | Diretoria, auditoria | Ler tudo; executar o exportador |
| **CBS Operacao** | Usuário fiscal | Coletar, conciliar, consulta inversa, exportar — não altera Configuração nem Credencial |
| **CBS Admin** | TI | Configurar Setup e Credencial, expurgar, reconstruir cobertura |

Atribua um deles (ou a combinação) a cada usuário que precise do app.

---

## 3. Escopo (MVP)

| Área | Status |
|---|---|
| Serviço de **Débitos** da CBS (`/debitos`) | ✅ Implementado |
| Serviços de Créditos, Pagamentos, Recolhimentos | 🔲 Previstos (valores do enum existem, sem lógica de coleta) |
| Autenticação OAuth2 Client Credentials | ✅ Implementada — segredo em Isolated Storage, token em cache e invalidado em 401 |
| Coleta automática via Job Queue | ✅ Implementada (máquina de estados com repetição/backoff) |
| Coleta manual (**Executar Coleta Agora**) | ✅ Implementada — mesmo caminho de código da Job Queue |
| Publicação atômica de lotes e idempotência por hash do arquivo | ✅ Implementada |
| Painel de débitos por competência | ✅ Implementado — lê **apenas lotes publicados** |
| Conciliação com o histórico fiscal | ✅ Motor implementado e ligado à interface. Entrega apenas o adaptador *Sem Vínculo*: uma extensão parceira precisa implementar `ICbsFiscalHistory` para a fonte real de NF-e |
| Consulta inversa (notas emitidas sem débito correspondente) | ✅ Implementada (ação no painel e na lista de conciliação) |
| Exportação do resultado da conciliação (CSV) | ✅ Implementada |
| Laudo de cobertura (última coleta + quantidade de débitos por competência) | ✅ Implementado — ação **Reconstruir Cobertura** no Setup |
| Expurgo do JSON original por retenção | ✅ Implementado — ação **Expurgar JSON Vencido** no Setup |
| Log de auditoria/telemetria | ✅ Implementado (`CBS Log Entry`) — nunca grava tokens, segredos, URLs assinadas ou conteúdo de documentos |
| Testes automatizados | 🟡 11 casos (6 de conciliação + 5 de importação). Para executá-los é preciso instalar a extensão **Test Runner** no sandbox |

Tudo é tratado por **uma empresa por vez** (aproveita-se o isolamento nativo de dados por
empresa do Business Central, em vez de um campo "Empresa" customizado em cada tabela).

### Fora do escopo do MVP

- Créditos, pagamentos e recolhimentos (os valores do enum e os caminhos de endpoint
  existem, sem uso).
- A composição do saldo consolidado do portal.
- Lançamentos contábeis e escrituração — a conciliação é consultiva.
- Carga histórica retroativa.
- Múltiplas matrizes ou filiais além de uma matriz por configuração.
- DFe diferente da NF-e modelo 55. Um débito de CT-e ou NFS-e é importado, mas classificado
  como **Não Aplicável**, nunca como um falso "débito sem nota".

---

## 4. Arquitetura da solução (visão geral)

```
Job Queue ──▶ CBS Job Queue Dispatcher ──▶ CBS Collection Orchestrator ──▶ ICbsHttpClient
  ou botão              │                                                        │
    na tela             │                                        CBS Tax Authority Connector
                        │                                                        │
                        │                                                  CBS File (JSON bruto)
                        │                                                        │
                        │                                               CBS Batch Publisher
                        │                                                        │
                        │                                               CBS JSON Importer
                        │                                                        │
                        │                                                  CBS Debt (lançamentos)
                        │                                                        │
                        └────────────────▶ CBS Reconciliation Engine ──▶ ICbsFiscalHistory
                                                        │                          │
                                               CBS Reconciliation        CBS Default Adapter
                                                                        (parceiro fornece o real)
```

Principais decisões de design:

- **Dois pontos de extensibilidade.** `ICbsHttpClient` troca o conector real por um mock em
  testes; `ICbsFiscalHistory` troca o adaptador vazio por um que leia NF-e reais. Ambos são
  `Access = Public` para que um **app separado, de outro publisher**, possa implementá-los —
  é exatamente o objetivo do ponto de extensão.
- **Segredos nunca tocam um campo de tabela.** O segredo do cliente OAuth2 fica apenas em
  Isolated Storage e é lido como `SecretText`.
- **Visibilidade só do que foi publicado (ADR-04).** `CBS Batch.Published` é gravado em uma
  única transação final, e `CBS Debt.Published` é marcado nessa mesma transação. O painel
  filtra `Published = true`, então uma importação que falhou é invisível.
- **Detecção de colisão de chave natural.** Uma nova coleta nunca sobrescreve silenciosamente
  um `CBS Debt` existente: o original é preservado e a colisão é registrada. A substituição
  só ocorre por um lote explícito de republicação.

---

## 5. Referência de objetos

| Tipo | ID | Nome | Finalidade |
|---|---|---|---|
| Tabela | 50100 | `CBS Setup` | Registro único de configuração por empresa |
| Tabela | 50101 | `CBS Credential` | Credenciais OAuth2 Client Credentials por ambiente |
| Tabela | 50102 | `CBS Request` | Uma linha por ciclo de coleta (tíquete, máquina de estados) |
| Tabela | 50103 | `CBS File` | JSON bruto baixado da Receita Federal |
| Tabela | 50104 | `CBS Debt` | Lançamentos normalizados de débito (o dado principal) |
| Tabela | 50105 | `CBS Reconciliation` | Avaliações de conciliação (uma linha por avaliação = trilha de auditoria) |
| Tabela | 50106 | `CBS Batch` | Controle de publicação atômica |
| Tabela | 50107 | `CBS Coverage` | Cobertura/lacunas de coleta por competência |
| Tabela | 50108 | `CBS Log Entry` | Log de eventos de auditoria/telemetria |
| Tabela | 50130 | `CBS Fiscal History Buffer` | Buffer temporário usado por `ICbsFiscalHistory` |
| Enum | 50111 | `CBS Fiscal History Adapter` | Seletor extensível do adaptador (público) |
| Enum | 50117 | `CBS Environment Type` | Produção / Produção Restrita |
| Enum | 50119 | `CBS Document Type` | Códigos de modelo DFe (55 NF-e, 57 CT-e, 91 NFS-e, …) |
| Interface | — | `ICbsHttpClient` | Abstração HTTP para a API da Receita Federal |
| Interface | — | `ICbsFiscalHistory` | Abstração sobre o histórico fiscal da empresa (pública) |
| Codeunit | 50133 | `CBS Tax Authority Connector` | Implementação HTTP real |
| Codeunit | 50138 | `CBS Job Queue Dispatcher` | Ponto de entrada único da Job Queue |
| Codeunit | 50141 | `CBS Maintenance` | Expurgo do JSON + reconstrução da cobertura |
| Página | 50150 | `CBS Setup Card` | Configuração + ações de manutenção |
| Página | 50151 | `CBS Debt List` | Todos os débitos importados |
| Página | 50152 | `CBS Request List` | Histórico dos ciclos + **Executar Coleta Agora** |
| Página | 50153 | `CBS Reconciliation List` | Trilha de conciliação + ações |
| Página | 50154 | `CBS Panel` | Painel principal por competência + ações |
| Página | 50159/50160 | `CBS Credential List` / `CBS Credential Card` | Gestão de credenciais |
| Página | 50100 | `CBS Reverse Lookup Request` | Diálogo do intervalo de emissão |

As páginas principais também aparecem agrupadas em **CBS Assisted Assessment** no Role
Center *Order Processor*.

---

## 6. Passo a passo: configuração inicial

### Passo 1 — Criar uma credencial (`CBS Credential List` → `CBS Credential Card`)

1. Abra **Credenciais CBS** (ou a ação *Credenciais* na página de Configuração).
2. Crie um registro: `Código`, `Descrição`, `Ambiente` (Produção ou Produção Restrita),
   `Client Id`, `URL do Token` e `Escopo (scope)` conforme registrado na Receita Federal.
3. No campo mascarado **Segredo do Cliente**, digite o segredo uma vez e saia do campo —
   ele é gravado direto em Isolated Storage e limpo da tela. O indicador **Segredo
   Configurado** confirma o armazenamento.
4. Marque **Ativo** = Sim.

### Passo 2 — Configurar a empresa (`CBS Setup Card`)

| Grupo na página | O que preencher |
|---|---|
| **Configuration** | `Ambiente`, `CNPJ Base` (8 dígitos), `CNPJ Contribuinte` (14 dígitos), `Credencial`, `Serviço Ativo` (apenas *Débitos* está implementado), `Coleta Bloqueada` |
| **Reconciliation** | `Adaptador de Histórico Fiscal` (deixe *Sem Vínculo* até existir um adaptador parceiro) e `Tolerância de Conciliação` |
| **Default Panel Filters** | `Competência Inicial` / `Competência Final` padrão ao abrir o painel |
| **Operation** | `Janela Incremental (Dias)` (8), `Retenção do JSON Original (Dias)` (180), `Cota de Aberturas por Dia` (4) |

> `Janela Incremental (Dias)` documenta a regra da Receita (consultas recentes limitadas
> aos últimos 8 dias); a janela em si é decidida pela API, não por este campo.

### Passo 3 — Agendar a coleta automática

Crie uma **Job Queue Entry**:

- *Object Type to Run* = Codeunit
- *Object ID to Run* = `CBS Job Queue Dispatcher` (50138)
- Recorrência: a cada 15–30 minutos
- Categoria de Job Queue: uma dedicada (ex.: `CBS-COLETA`), para não competir com as
  rotinas do cliente

Cada execução avança qualquer solicitação em andamento e só abre uma nova se não houver
nenhuma pendente **e** a cota diária permitir. Para testar sem esperar, use **Executar
Coleta Agora** em *Solicitações CBS* ou no cartão de Configuração.

### Passo 4 — Acompanhar o progresso (`CBS Request List`)

Mostra cada ciclo com `Estado Local` (nossa máquina de estados), `Estado Remoto` (última
informação da API), contadores de tentativas e datas/horas. O campo `Detalhe do Estado
Remoto` traz a última mensagem de erro. É a primeira página a consultar quando uma
solicitação parece travada.

### Passo 5 — Revisar os débitos importados (`CBS Debt List`)

Cada débito normalizado: competência, tipo de documento, chave de acesso da NF-e, origem e
o detalhamento de cada valor de CBS. O campo `Publicado` indica se a linha já aparece no
painel.

### Passo 6 — Conciliar e revisar os resultados

No **Painel CBS** ou na **Lista de Conciliação CBS**:

- **Conciliar Débitos Pendentes** — avalia todo débito que ainda não tem avaliação.
- **Consulta Inversa** — pede um intervalo de emissão e aponta notas emitidas no período
  sem débito correspondente.
- **Exportar Conciliação para CSV** — baixa a trilha para o Excel.

Classificações: *Conciliada*, *Divergente*, *Ajuste* (divergência interna item × total),
*Nota sem Débito Localizado*, *Débito sem Nota Localizada*, *Nota Vinculada sem CBS
Declarada*, *Sem Adaptador de Histórico Fiscal Vinculado*, *Não Aplicável* (documento não é
NF-e).

### Passo 7 — Acompanhamento diário (`CBS Panel`)

Abre pré-filtrado pelo intervalo padrão e exibe os débitos publicados com os totais de
**Total CBS Apurado** e **Total Saldo Devedor**. Altere os filtros para qualquer outra
competência, ambiente ou NI.

### Passo 8 — Manutenção (`CBS Setup Card`)

- **Expurgar JSON Vencido** — limpa o JSON bruto após `Retenção do JSON Original (Dias)`.
  A linha e o hash são mantidos, então idempotência e auditoria sobrevivem.
- **Reconstruir Cobertura** — reconstrói `CBS Coverage` (última coleta e quantidade de
  débitos por competência) a partir dos dados publicados.
- **Carregar Dados de Demonstração** — ver seção 9.

---

## 7. Traduções

O recurso `TranslationFile` está habilitado e o idioma de origem é `en-US`. A tradução para
português do Brasil está em
[`Translations/RSB_Apur_Assistida.pt-BR.xlf`](./Translations/RSB_Apur_Assistida.pt-BR.xlf).

> ⚠️ **Lacuna conhecida:** o arquivo pt-BR hoje não tem caracteres acentuados
> (`Configuracao`, `debito`, `conciliacao`) e não tem o atributo `state="translated"`, então
> uma regeneração do XLF pode descartar o trabalho. Os dois pontos precisam ser corrigidos
> antes da submissão ao AppSource.

Identificadores que vêm direto do contrato JSON da Receita (`pa`, `cbs`, `chave`,
`tiqueteSolicitacao`) são mantidos como estão — renomeá-los quebraria a integração.

Para adicionar outro idioma, execute `createLanguageXlf` sobre
`Translations/RSB_Apur_Assistida.g.xlf` e traduza o resultado.

---

## 8. Segurança e proteção de dados

- O segredo do cliente OAuth2 **nunca** fica em campo de tabela, nunca é registrado em log
  e nunca é convertido para `Text` simples — circula apenas como `SecretText` / Isolated
  Storage.
- O token de acesso é mantido em **cache** em Isolated Storage com margem de segurança de
  5 minutos e é descartado em qualquer HTTP 401, para que um token revogado não fique preso.
- A URL assinada de download é um segredo temporário: é usada em requisição **sem** header
  `Authorization` e nunca é registrada em log.
- A telemetria e o `CBS Log Entry` guardam apenas metadados técnicos (códigos, contadores,
  durações) — nunca um CNPJ, uma chave de NF-e, um token, um segredo ou uma URL assinada.
- `DataClassification` é declarado em todo campo. CNPJ/NI são
  `EndUserIdentifiableInformation`; valores fiscais são `CustomerContent`.
- Todas as tabelas de dados são `Access = Internal`; apenas as páginas as expõem ao
  usuário, e somente através dos conjuntos de permissões da seção 2.2.

---

## 9. Dados de demonstração

**Carregar Dados de Demonstração** (no `CBS Setup Card`) cria um cenário coerente e
autossuficiente para demonstrar a extensão sem qualquer conexão com a Receita Federal:

| O que | Conteúdo |
|---|---|
| Configuração | CNPJ base/contribuinte fictícios, Produção Restrita, tolerância 1,00 — **só preenche o que está vazio**, nunca altera um ambiente já configurado |
| Credencial | `DEMO`, client id/segredo falsos, sem uso real |
| Ciclos de coleta | 3 `CBS Request` já **Publicadas**, uma por competência |
| Lotes | 3 `CBS Batch` Publicados, um por competência (a linhagem do lote fica visível) |
| Débitos | 8 linhas em 3 competências (ver abaixo) |
| Conciliações | 6 avaliações cobrindo 6 classificações |
| Cobertura | Reconstruída a partir dos débitos de demonstração |

Os 8 débitos foram desenhados para exercitar todas as classificações:

| # | Competência | Documento | Origem | Valor | Resultado esperado |
|---|---|---|---|---|---|
| 000001 | -2 | NF-e | Normal | 1.250,75 | **Conciliada** |
| 000002 | -2 | NF-e | Devolução por PCONT | 430,10 | **Divergente** (declarado 500,00) |
| 000003 | -1 | NF-e | Normal | 980,00 | **Débito sem Nota Localizada** |
| 000004 | -1 | NF-e | Normal | 2.100,55 | **Nota Vinculada sem CBS Declarada** |
| 000005 | atual | NF-e | Normal | 310,40 | *deixado pendente* |
| 000006 | atual | NF-e | Cancelamento de Crédito | 75,20 | *deixado pendente* |
| 000007 | atual | NF-e | Normal | 190,00 | **Ajuste** (itens 170,00 × total 190,00) |
| 000008 | atual | CT-e | Normal | 120,00 | **Não Aplicável** (não é NF-e) |

Os dois débitos pendentes existem de propósito: são o que **Conciliar Débitos Pendentes**
vai processar no primeiro clique, permitindo demonstrar a ação e a trilha gerada ao vivo.

Pode ser executado mais de uma vez — registros de demonstração existentes são reaproveitados,
nunca duplicados, e nenhum registro fora do conjunto de demonstração é alterado ou excluído.

---

## 10. Pendências / marcações `[VALIDAR]`

Detalhes de integração marcados com `[VALIDATE]` no código precisam ser confirmados na
documentação oficial da Receita Federal antes de ir para produção. Pesquise por `[VALIDATE]`
no código-fonte:

| Item | Onde | Situação |
|---|---|---|
| Endpoint e escopo do token (Receita Integra) | `CBS Credential`, `CBS Tax Authority Connector` | Não publicado na documentação da API CBS — vem do Receita Integra |
| URL base de Produção Restrita (`api-prr…`) | `CBS Url Helper` | Suposição, não confirmada |
| Formato exato de `urlAssinadaExpiraEm` | `CBS Tax Authority Connector` | Convertido defensivamente (`[TryFunction]`), nunca aborta o ciclo |
| Comportamento do Isolated Storage em sessão de Job Queue | `CBS Credential` | Usado para o segredo e para o cache do token |
| Se a localização brasileira expõe `vCBS`/`gCBS` em tabela ou só no XML | Adaptador `ICbsFiscalHistory` | Define se o adaptador do parceiro lê tabela ou faz parse do XML |

Todos os demais detalhes de integração já estão confirmados no contrato oficial
(`docs.receitafederal.gov.br/apuracao-cbs/debito.html` e `guiaapiassincrona.html`):
`POST /apuracao-cbs/v2/debitos/{cnpj}` com CNPJ base de 8 dígitos, `Authorization: Bearer
<token>`, corpo `{"urlRetorno":""}`, HTTP 201 com `tiqueteSolicitacao` / `tEASegundos`,
situações `PENDENTE` / `EM_PROCESSAMENTO` / `CONCLUIDA` / `ERRO` / `EXPIRADA`, limite de 240
minutos de processamento, 4 aberturas por dia por API, URL assinada válida por 48 horas e
baixável sem token, e `documento` como o **código do modelo DFe** (55 = NF-e).

---

## 11. Compilar e testar

```bash
# na raiz do projeto
AL: Download Symbols      # ou: dotnet build / alc via AL-Go
```

- Compila contra os symbols do **BC 29** (`System Application`, `Base Application`,
  `Business Foundation` 29.0).
- Os 11 testes automatizados estão em `src/Test/`. Eles **compilam sem dependência extra**
  (as asserções são locais, deliberadamente sem `Library Assert`). Para *executá-los*,
  instale a extensão **Test Runner** no sandbox e use o AL Test Tool.
- `schemaUpdateMode: ForceSync` está definido no `.vscode/launch.json` para os sandboxes
  Dev e UAT.

### Atualizando a partir de uma versão anterior a 11/11

`CBS Debt.Document` passou de `Integer` para `Enum` e o campo `CBS Debt.Published` foi
adicionado. Linhas importadas por uma versão anterior ficam com `Published = false` e
portanto fora do painel. Em sandbox, recarregue os dados de demonstração ou rode
**Reconstruir Cobertura**; em base real, é preciso um codeunit de upgrade que marque
`Published = true` onde o lote está publicado.
