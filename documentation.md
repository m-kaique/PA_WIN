# Documentação Técnica do Expert Advisor PA_WIN

## Sumário
1. [Visão Geral](#1-visão-geral)
2. [Arquitetura e Fluxo de Execução](#2-arquitetura-e-fluxo-de-execução)
3. [Descrição dos Arquivos](#3-descrição-dos-arquivos)
4. [Referência de Funções e Classes](#4-referência-de-funções-e-classes)
5. [Parâmetros de Entrada](#5-parâmetros-de-entrada)
6. [Dependências Externas](#6-dependências-externas)
7. [Exemplos de Configuração e Uso](#7-exemplos-de-configuração-e-uso)
8. [Changelog / Registro de Versões](#8-changelog--registro-de-versões)




## 1. Visão Geral

- **Nome do EA**: PA_WIN
- **Objetivo principal**: O Expert Advisor PA_WIN é projetado para automatizar operações de negociação, utilizando um sistema de gerenciamento de configuração flexível baseado em arquivos JSON. Ele monitora novos candles em um timeframe especificado e executa lógicas de negociação baseadas em médias móveis configuradas para diferentes símbolos e timeframes.
- **Plataformas suportadas**: MetaTrader 5 (MQL5)




## 2. Arquitetura e Fluxo de Execução

O Expert Advisor PA_WIN opera com uma arquitetura modular, centrada em um `CConfigManager` que gerencia as configurações carregadas de um arquivo JSON (`config.json`). Este gerenciador é responsável por inicializar e manter múltiplos contextos de timeframe (`TF_CTX`), cada um associado a um símbolo e timeframe específicos, e configurado com médias móveis (`CMovingAverages`).

### Fluxo de Execução Simplificado:

1.  **Inicialização (`OnInit`):**
    *   O EA cria uma instância global de `CConfigManager`.
    *   Tenta carregar a configuração do arquivo `config.json` especificado pelo parâmetro de entrada `JsonConfigFile`.
    *   Se o carregamento for bem-sucedido, o `CConfigManager` parseia o JSON e cria instâncias de `TF_CTX` para cada símbolo e timeframe habilitado na configuração.
    *   Cada `TF_CTX` inicializa suas próprias instâncias de `CMovingAverages` com base nas configurações de médias móveis definidas no JSON.
    *   Define o timeframe de controle inicial para detecção de novos candles (padrão D1).

2.  **Processamento de Tick (`OnTick`):**
    *   A cada tick, o EA verifica se um novo candle foi formado no timeframe de controle (`m_control_tf`).
    *   Se um novo candle for detectado (`IsNewBar` retorna `true`), a função `ExecuteOnNewBar` é chamada.

3.  **Lógica em Novo Candle (`ExecuteOnNewBar`):**
    *   Esta função é o coração da lógica de execução do EA em cada novo candle.
    *   Atualmente, ela obtém o contexto `TF_CTX` para o símbolo fixo "WIN$N" no timeframe D1.
     *   Chama o método `Update()` no contexto D1, o qual percorre todos os indicadores e executa `Update()` em cada um (herdado de `CIndicatorBase` ou sobrescrito), garantindo que fiquem sincronizados.
    *   Exibe os valores das EMAs 9 e 21 para o candle atual (shift 1) e o anterior (shift 0) para fins de depuração.
    *   A lógica de negociação real seria implementada aqui, utilizando os dados fornecidos pelos objetos `TF_CTX`.

4.  **Desinicialização (`OnDeinit`):**
    *   Quando o EA é removido do gráfico ou o terminal é fechado, o destrutor do `CConfigManager` é chamado, liberando todos os recursos alocados (instâncias de `TF_CTX` e `CMovingAverages`).

### Diagrama Simplificado do Fluxo:

```mermaid
graph TD
    A[Início EA] --> B{OnInit()};
    B --> C{Carregar config.json via CConfigManager};
    C -- Sucesso --> D{Criar TF_CTX e CMovingAverages};
    C -- Falha --> E[Erro e Sair];
    D --> F[Loop OnTick()];
    F --> G{IsNewBar(m_control_tf)?};
    G -- Não --> F;
    G -- Sim --> H{ExecuteOnNewBar()};
    H --> I{Obter TF_CTX para WIN$N/D1};
    I --> J{Atualizar TF_CTX (D1_ctx.Update())};
    J --> K[Executar Lógica de Negociação (ex: ler EMAs)];
    K --> F;
    F --> L{OnDeinit()};
    L --> M[Limpar recursos e Sair];
```




## 3. Descrição dos Arquivos

Esta seção detalha cada arquivo que compõe o Expert Advisor, explicando seu propósito e função dentro do projeto.

- **`PA_WIN.mq5`**: Este é o arquivo principal do Expert Advisor. Ele contém as funções de inicialização (`OnInit`), desinicialização (`OnDeinit`) e processamento de ticks (`OnTick`), além da lógica central para detecção de novos candles e execução da estratégia de negociação. É o ponto de entrada para o EA.

- **`config.json`**: Arquivo de configuração em JSON que define os parâmetros para os símbolos e timeframes monitorados. A partir da versão 2.0, os indicadores são declarados em uma lista genérica (`indicators`), permitindo adicionar ou remover indicadores sem alterar o código MQL5.

- **`JAson.mqh` (ou `JAson_utf8.mqh`)**: Uma biblioteca MQL5 para manipulação de dados JSON. Ela fornece funcionalidades para serializar e desserializar strings JSON em objetos MQL5 (`CJAVal`), permitindo que o EA leia e interprete o arquivo `config.json`.

- **`config_manager.mqh`**: Este arquivo define a classe `CConfigManager`, responsável por carregar, parsear e gerenciar a configuração do EA a partir do arquivo `config.json`. Ele cria e mantém os contextos de timeframe (`TF_CTX`) para cada símbolo e timeframe configurado, atuando como a camada de abstração entre a configuração JSON e a lógica de negociação.

- **`config_types.mqh`**: Define as estruturas de dados utilizadas para tipificar a configuração lida do JSON. Nesta versão são utilizadas `SIndicatorConfig` (configuração de um indicador genérico) e `STimeframeConfig`, que possui um array de `SIndicatorConfig` para cada timeframe.

- **`tf_ctx.mqh`**: Define a classe `TF_CTX` (TimeFrame Context). Cada instância mantém uma lista de indicadores derivados de `CIndicatorBase`, criados dinamicamente conforme a configuração. Fornece métodos genéricos para acessar valores e atualizar o contexto. Seu método `Update()` percorre essa lista e chama `Update()` em cada indicador, mantendo todos sincronizados.
- **`indicator_base.mqh`**: Declara a classe abstrata `CIndicatorBase`, utilizada como interface para os diversos tipos de indicadores. Nela está definido o método virtual `Update()`, que por padrão apenas verifica `IsReady()`. Indicadores mais complexos podem sobrescrever esse método para recalcular seus dados.

- **`moving_averages.mqh`**: Implementa a classe `CMovingAverages`, derivada de `CIndicatorBase`, responsável por criar e gerenciar indicadores de média móvel.
- **`stochastic.mqh`**: Implementa a classe `CStochastic`, derivada de `CIndicatorBase`, responsável pelo cálculo do indicador Estocástico.
- **`volume.mqh`**: Implementa a classe `CVolume`, derivada de `CIndicatorBase`, responsável por acessar valores de volume.
- **`bollinger.mqh`**: Implementa a classe `CBollinger`, derivada de `CIndicatorBase`, responsável pelo cálculo das Bandas de Bollinger.
 - **`vwap.mqh`**: Implementa a classe `CVWAP`, derivada de `CIndicatorBase`, agora baseada no indicador `vwap_indicator.mq5` para cálculo do VWAP, delegando a exibição exclusivamente a esse indicador.
- **`vwap_indicator.mq5`**: Indicador personalizado chamado via `iCustom` que desenha a linha de VWAP automaticamente.
- **`fibonacci.mqh`**: Implementa o indicador `CFibonacci`, capaz de desenhar níveis de retração e extensões de Fibonacci com total customização via JSON.
- **Arquivos `*_defs.mqh`**: Cada indicador possui agora um arquivo de definições
  específico (ex.: `ma_defs.mqh`, `stochastic_defs.mqh`, `bollinger_defs.mqh`) contendo as
  enumerações relacionadas a suas opções, padronizando a organização das
  constantes assim como já ocorria com `vwap_defs.mqh`.




## 4. Referência de Funções e Classes

Esta seção detalha as principais funções e classes encontradas no código do Expert Advisor, incluindo suas assinaturas, descrições, parâmetros e valores de retorno.

### PA_WIN.mq5

#### Funções Globais

- **`OnInit()`**
  - **Assinatura**: `int OnInit()`
  - **Descrição simplificada**: Função de inicialização do Expert Advisor. É chamada uma vez quando o EA é anexado a um gráfico. Responsável por criar e inicializar o gerenciador de configuração (`CConfigManager`) e carregar as configurações do arquivo JSON.
  - **Parâmetros**: Nenhum.
  - **Valor de retorno**: `int` - Retorna `INIT_SUCCEEDED` se a inicialização for bem-sucedida, ou `INIT_FAILED` em caso de erro.

- **`OnDeinit(const int reason)`**
  - **Assinatura**: `void OnDeinit(const int reason)`
  - **Descrição simplificada**: Função de desinicialização do Expert Advisor. É chamada quando o EA é removido do gráfico, o terminal é fechado ou ocorre uma recompilação. Responsável por liberar os recursos alocados, como o gerenciador de configuração.
  - **Parâmetros**:
    - `reason` (`const int`): Código da razão pela qual o EA foi desinicializado.
  - **Valor de retorno**: Nenhum.

- **`OnTick()`**
  - **Assinatura**: `void OnTick()`
  - **Descrição simplificada**: Função principal de processamento de ticks. É chamada a cada novo tick recebido pelo terminal. Verifica se um novo candle foi formado no timeframe de controle e, se sim, executa a lógica definida em `ExecuteOnNewBar()`.
  - **Parâmetros**: Nenhum.
  - **Valor de retorno**: Nenhum.

- **`IsNewBar(ENUM_TIMEFRAMES timeframe)`**
  - **Assinatura**: `bool IsNewBar(ENUM_TIMEFRAMES timeframe)`
  - **Descrição simplificada**: Verifica se um novo candle foi formado no timeframe especificado. Utiliza `m_last_bar_time` para controlar o tempo do último candle processado.
  - **Parâmetros**:
    - `timeframe` (`ENUM_TIMEFRAMES`): O timeframe a ser verificado para a formação de um novo candle.
  - **Valor de retorno**: `bool` - Retorna `true` se um novo candle foi formado, `false` caso contrário.

- **`ExecuteOnNewBar()`**
  - **Assinatura**: `void ExecuteOnNewBar()`
  - **Descrição simplificada**: Contém a lógica a ser executada quando um novo candle é detectado. Agora os contextos configurados no JSON para o símbolo "WIN$N" são obtidos de forma dinâmica. Cada contexto é atualizado automaticamente e são impressas informações específicas, como as EMAs no timeframe D1 ou a linha de tendência do H1.
  - **Parâmetros**: Nenhum.
  - **Valor de retorno**: Nenhum.

- **`SetControlTimeframe(ENUM_TIMEFRAMES new_timeframe)`**
  - **Assinatura**: `void SetControlTimeframe(ENUM_TIMEFRAMES new_timeframe)`
  - **Descrição simplificada**: Altera o timeframe utilizado para o controle de novos candles. Reseta `m_last_bar_time` para forçar a execução da lógica no próximo tick.
  - **Parâmetros**:
    - `new_timeframe` (`ENUM_TIMEFRAMES`): O novo timeframe a ser usado para controle.
  - **Valor de retorno**: Nenhum.

- **`ReloadConfig()`**
  - **Assinatura**: `bool ReloadConfig()`
  - **Descrição simplificada**: Recarrega a configuração do EA a partir do arquivo JSON. Útil para desenvolvimento e testes, permitindo aplicar mudanças na configuração sem reiniciar o EA.
  - **Parâmetros**: Nenhum.
  - **Valor de retorno**: `bool` - Retorna `true` se a configuração foi recarregada com sucesso, `false` em caso de falha.

- **`OnTesterDeinit()`**
  - **Assinatura**: `void OnTesterDeinit()`
  - **Descrição simplificada**: Função de desinicialização específica para o testador de estratégia. Atualmente, não contém lógica implementada.
  - **Parâmetros**: Nenhum.
  - **Valor de retorno**: Nenhum.

### JAson_utf8.mqh

#### Enumerações

- **`enJAType`**
  - **Descrição simplificada**: Enumeração que define os tipos de dados suportados pela biblioteca JSON (Undefined, Null, Boolean, Integer, Double, String, Array, Object).

#### Classes

- **`CJAVal`**
  - **Descrição simplificada**: Classe fundamental para representar um valor JSON (objeto, array, string, número, booleano ou nulo). Permite a manipulação e serialização/desserialização de estruturas JSON.
  - **Métodos**:
    - **`CJAVal()`**
      - **Assinatura**: `CJAVal()`
      - **Descrição simplificada**: Construtor padrão. Inicializa um objeto `CJAVal` com tipo indefinido e valores padrão.
      - **Parâmetros**: Nenhum.
      - **Valor de retorno**: Objeto `CJAVal`.
    - **`CJAVal(CJAVal* a_parent, enJAType a_type)`**
      - **Assinatura**: `CJAVal(CJAVal* a_parent, enJAType a_type)`
      - **Descrição simplificada**: Construtor que inicializa um objeto `CJAVal` com um pai e um tipo específico.
      - **Parâmetros**:
        - `a_parent` (`CJAVal*`): Ponteiro para o objeto `CJAVal` pai.
        - `a_type` (`enJAType`): O tipo do valor JSON.
      - **Valor de retorno**: Objeto `CJAVal`.
    - **`CJAVal(enJAType t, string str)`**
      - **Assinatura**: `CJAVal(enJAType t, string str)`
      - **Descrição simplificada**: Construtor que inicializa um objeto `CJAVal` a partir de um tipo e uma string, convertendo a string para o tipo de dado apropriado.
      - **Parâmetros**:
        - `t` (`enJAType`): O tipo do valor JSON.
        - `str` (`string`): A string a ser convertida.
      - **Valor de retorno**: Objeto `CJAVal`.
    - **`CJAVal(const int v)`**
      - **Assinatura**: `CJAVal(const int v)`
      - **Descrição simplificada**: Construtor que inicializa um objeto `CJAVal` a partir de um valor inteiro.
      - **Parâmetros**:
        - `v` (`const int`): O valor inteiro.
      - **Valor de retorno**: Objeto `CJAVal`.
    - **`CJAVal(const long v)`**
      - **Assinatura**: `CJAVal(const long v)`
      - **Descrição simplificada**: Construtor que inicializa um objeto `CJAVal` a partir de um valor long.
      - **Parâmetros**:
        - `v` (`const long`): O valor long.
      - **Valor de retorno**: Objeto `CJAVal`.
    - **`CJAVal(const double v, int precision=-100)`**
      - **Assinatura**: `CJAVal(const double v, int precision=-100)`
      - **Descrição simplificada**: Construtor que inicializa um objeto `CJAVal` a partir de um valor double, com precisão opcional.
      - **Parâmetros**:
        - `v` (`const double`): O valor double.
        - `precision` (`int`, opcional, padrão: -100): A precisão para o valor double.
      - **Valor de retorno**: Objeto `CJAVal`.
    - **`CJAVal(const bool v)`**
      - **Assinatura**: `CJAVal(const bool v)`
      - **Descrição simplificada**: Construtor que inicializa um objeto `CJAVal` a partir de um valor booleano.
      - **Parâmetros**:
        - `v` (`const bool`): O valor booleano.
      - **Valor de retorno**: Objeto `CJAVal`.
    - **`CJAVal(const CJAVal& a)`**
      - **Assinatura**: `CJAVal(const CJAVal& a)`
      - **Descrição simplificada**: Construtor de cópia. Inicializa um novo objeto `CJAVal` copiando o conteúdo de outro objeto `CJAVal`.
      - **Parâmetros**:
        - `a` (`const CJAVal&`): O objeto `CJAVal` a ser copiado.
      - **Valor de retorno**: Objeto `CJAVal`.
    - **`~CJAVal()`**
      - **Assinatura**: `~CJAVal()`
      - **Descrição simplificada**: Destrutor. Libera os recursos alocados pelo objeto `CJAVal`.
      - **Parâmetros**: Nenhum.
      - **Valor de retorno**: Nenhum.
    - **`Size()`**
      - **Assinatura**: `int Size()`
      - **Descrição simplificada**: Retorna o número de filhos (elementos) se o `CJAVal` for um array ou objeto.
      - **Parâmetros**: Nenhum.
      - **Valor de retorno**: `int` - O número de filhos.
    - **`IsNumeric()`**
      - **Assinatura**: `virtual bool IsNumeric()`
      - **Descrição simplificada**: Verifica se o tipo do `CJAVal` é numérico (inteiro ou double).
      - **Parâmetros**: Nenhum.
      - **Valor de retorno**: `bool` - `true` se for numérico, `false` caso contrário.
    - **`Clear(enJAType jt=jtUNDEF, bool save_key=false)`**
      - **Assinatura**: `virtual void Clear(enJAType jt=jtUNDEF, bool save_key=false)`
      - **Descrição simplificada**: Limpa o conteúdo do objeto `CJAVal`, redefinindo seu tipo e valores. Pode opcionalmente manter a chave.
      - **Parâmetros**:
        - `jt` (`enJAType`, opcional, padrão: `jtUNDEF`): O tipo para o qual o objeto será redefinido.
        - `save_key` (`bool`, opcional, padrão: `false`): Se `true`, a chave do objeto é preservada.
      - **Valor de retorno**: Nenhum.
    - **`Copy(const CJAVal &a)`**
      - **Assinatura**: `virtual bool Copy(const CJAVal &a)`
      - **Descrição simplificada**: Copia o conteúdo de outro objeto `CJAVal` para o objeto atual.
      - **Parâmetros**:
        - `a` (`const CJAVal &`): O objeto `CJAVal` a ser copiado.
      - **Valor de retorno**: `bool` - `true` se a cópia foi bem-sucedida.
    - **`CopyData(const CJAVal& a)`**
      - **Assinatura**: `virtual void CopyData(const CJAVal& a)`
      - **Descrição simplificada**: Copia os dados internos (tipo, valores) de outro objeto `CJAVal`.
      - **Parâmetros**:
        - `a` (`const CJAVal&`): O objeto `CJAVal` de origem.
      - **Valor de retorno**: Nenhum.
    - **`CopyArr(const CJAVal& a)`**
      - **Assinatura**: `virtual void CopyArr(const CJAVal& a)`
      - **Descrição simplificada**: Copia os elementos filhos (array ou objeto) de outro `CJAVal`.
      - **Parâmetros**:
        - `a` (`const CJAVal&`): O objeto `CJAVal` de origem.
      - **Valor de retorno**: Nenhum.
    - **`FindKey(string a_key)`**
      - **Assinatura**: `virtual CJAVal* FindKey(string a_key)`
      - **Descrição simplificada**: Procura um filho com a chave especificada.
      - **Parâmetros**:
        - `a_key` (`string`): A chave a ser procurada.
      - **Valor de retorno**: `CJAVal*` - Ponteiro para o objeto `CJAVal` encontrado, ou `NULL` se não for encontrado.
    - **`HasKey(string a_key, enJAType a_type=jtUNDEF)`**
      - **Assinatura**: `virtual bool HasKey(string a_key, enJAType a_type=jtUNDEF)`
      - **Descrição simplificada**: Verifica se o objeto possui uma chave específica, opcionalmente com um tipo de dado específico.
      - **Parâmetros**:
        - `a_key` (`string`): A chave a ser verificada.
        - `a_type` (`enJAType`, opcional, padrão: `jtUNDEF`): O tipo de dado esperado para a chave.
      - **Valor de retorno**: `bool` - `true` se a chave existir e corresponder ao tipo (se especificado), `false` caso contrário.
    - **`operator[](string a_key)`**
      - **Assinatura**: `virtual CJAVal* operator[](string a_key)`
      - **Descrição simplificada**: Sobrecarga do operador `[]` para acesso a elementos de objeto por chave. Se a chave não existir, um novo elemento é criado.
      - **Parâmetros**:
        - `a_key` (`string`): A chave do elemento.
      - **Valor de retorno**: `CJAVal*` - Ponteiro para o objeto `CJAVal` correspondente à chave.
    - **`operator[](int i)`**
      - **Assinatura**: `virtual CJAVal* operator[](int i)`
      - **Descrição simplificada**: Sobrecarga do operador `[]` para acesso a elementos de array por índice. Se o índice estiver fora dos limites, novos elementos são adicionados até o índice ser válido.
      - **Parâmetros**:
        - `i` (`int`): O índice do elemento.
      - **Valor de retorno**: `CJAVal*` - Ponteiro para o objeto `CJAVal` correspondente ao índice.
    - **`operator=(const CJAVal &a)`**
      - **Assinatura**: `void operator=(const CJAVal &a)`
      - **Descrição simplificada**: Sobrecarga do operador de atribuição para copiar um objeto `CJAVal`.
      - **Parâmetros**:
        - `a` (`const CJAVal &`): O objeto `CJAVal` a ser atribuído.
      - **Valor de retorno**: Nenhum.
    - **`operator=(const int v)`**
      - **Assinatura**: `void operator=(const int v)`
      - **Descrição simplificada**: Sobrecarga do operador de atribuição para atribuir um valor inteiro.
      - **Parâmetros**:
        - `v` (`const int`): O valor inteiro.
      - **Valor de retorno**: Nenhum.
    - **`operator=(const long v)`**
      - **Assinatura**: `void operator=(const long v)`
      - **Descrição simplificada**: Sobrecarga do operador de atribuição para atribuir um valor long.
      - **Parâmetros**:
        - `v` (`const long`): O valor long.
      - **Valor de retorno**: Nenhum.
    - **`operator=(const double v)`**
      - **Assinatura**: `void operator=(const double v)`
      - **Descrição simplificada**: Sobrecarga do operador de atribuição para atribuir um valor double.
      - **Parâmetros**:
        - `v` (`const double`): O valor double.
      - **Valor de retorno**: Nenhum.
    - **`operator=(const bool v)`**
      - **Assinatura**: `void operator=(const bool v)`
      - **Descrição simplificada**: Sobrecarga do operador de atribuição para atribuir um valor booleano.
      - **Parâmetros**:
        - `v` (`const bool`): O valor booleano.
      - **Valor de retorno**: Nenhum.
    - **`operator=(string v)`**
      - **Assinatura**: `void operator=(string v)`
      - **Descrição simplificada**: Sobrecarga do operador de atribuição para atribuir um valor string.
      - **Parâmetros**:
        - `v` (`string`): O valor string.
      - **Valor de retorno**: Nenhum.
    - **`operator==(const int v)`**
      - **Assinatura**: `bool operator==(const int v)`
      - **Descrição simplificada**: Sobrecarga do operador de igualdade para comparação com um inteiro.
      - **Parâmetros**:
        - `v` (`const int`): O valor inteiro para comparação.
      - **Valor de retorno**: `bool` - `true` se forem iguais, `false` caso contrário.
    - **`operator==(const long v)`**
      - **Assinatura**: `bool operator==(const long v)`
      - **Descrição simplificada**: Sobrecarga do operador de igualdade para comparação com um long.
      - **Parâmetros**:
        - `v` (`const long`): O valor long para comparação.
      - **Valor de retorno**: `bool` - `true` se forem iguais, `false` caso contrário.
    - **`operator==(const double v)`**
      - **Assinatura**: `bool operator==(const double v)`
      - **Descrição simplificada**: Sobrecarga do operador de igualdade para comparação com um double.
      - **Parâmetros**:
        - `v` (`const double`): O valor double para comparação.
      - **Valor de retorno**: `bool` - `true` se forem iguais, `false` caso contrário.
    - **`operator==(const bool v)`**
      - **Assinatura**: `bool operator==(const bool v)`
      - **Descrição simplificada**: Sobrecarga do operador de igualdade para comparação com um booleano.
      - **Parâmetros**:
        - `v` (`const bool`): O valor booleano para comparação.
      - **Valor de retorno**: `bool` - `true` se forem iguais, `false` caso contrário.
    - **`operator==(string v)`**
      - **Assinatura**: `bool operator==(string v)`
      - **Descrição simplificada**: Sobrecarga do operador de igualdade para comparação com uma string.
      - **Parâmetros**:
        - `v` (`string`): O valor string para comparação.
      - **Valor de retorno**: `bool` - `true` se forem iguais, `false` caso contrário.
    - **`operator!=(const int v)`**
      - **Assinatura**: `bool operator!=(const int v)`
      - **Descrição simplificada**: Sobrecarga do operador de diferença para comparação com um inteiro.
      - **Parâmetros**:
        - `v` (`const int`): O valor inteiro para comparação.
      - **Valor de retorno**: `bool` - `true` se forem diferentes, `false` caso contrário.
    - **`operator!=(const long v)`**
      - **Assinatura**: `bool operator!=(const long v)`
      - **Descrição simplificada**: Sobrecarga do operador de diferença para comparação com um long.
      - **Parâmetros**:
        - `v` (`const long`): O valor long para comparação.
      - **Valor de retorno**: `bool` - `true` se forem diferentes, `false` caso contrário.
    - **`operator!=(const double v)`**
      - **Assinatura**: `bool operator!=(const double v)`
      - **Descrição simplificada**: Sobrecarga do operador de diferença para comparação com um double.
      - **Parâmetros**:
        - `v` (`const double`): O valor double para comparação.
      - **Valor de retorno**: `bool` - `true` se forem diferentes, `false` caso contrário.
    - **`operator!=(const bool v)`**
      - **Assinatura**: `bool operator!=(const bool v)`
      - **Descrição simplificada**: Sobrecarga do operador de diferença para comparação com um booleano.
      - **Parâmetros**:
        - `v` (`const bool`): O valor booleano para comparação.
      - **Valor de retorno**: `bool` - `true` se forem diferentes, `false` caso contrário.
    - **`operator!=(string v)`**
      - **Assinatura**: `bool operator!=(string v)`
      - **Descrição simplificada**: Sobrecarga do operador de diferença para comparação com uma string.
      - **Parâmetros**:
        - `v` (`string`): O valor string para comparação.
      - **Valor de retorno**: `bool` - `true` se forem diferentes, `false` caso contrário.
    - **`ToInt()`**
      - **Assinatura**: `long ToInt() const`
      - **Descrição simplificada**: Converte o valor do objeto `CJAVal` para um inteiro (long).
      - **Parâmetros**: Nenhum.
      - **Valor de retorno**: `long` - O valor inteiro.
    - **`ToDbl()`**
      - **Assinatura**: `double ToDbl() const`
      - **Descrição simplificada**: Converte o valor do objeto `CJAVal` para um double.
      - **Parâmetros**: Nenhum.
      - **Valor de retorno**: `double` - O valor double.
    - **`ToBool()`**
      - **Assinatura**: `bool ToBool() const`
      - **Descrição simplificada**: Converte o valor do objeto `CJAVal` para um booleano.
      - **Parâmetros**: Nenhum.
      - **Valor de retorno**: `bool` - O valor booleano.
    - **`ToStr()`**
      - **Assinatura**: `string ToStr()`
      - **Descrição simplificada**: Converte o valor do objeto `CJAVal` para uma string.
      - **Parâmetros**: Nenhum.
      - **Valor de retorno**: `string` - O valor em formato de string.
    - **`FromStr(enJAType t, string str)`**
      - **Assinatura**: `virtual void FromStr(enJAType t, string str)`
      - **Descrição simplificada**: Define o valor do objeto `CJAVal` a partir de uma string e um tipo específico.
      - **Parâmetros**:
        - `t` (`enJAType`): O tipo de dado para o qual a string será convertida.
        - `str` (`string`): A string de origem.
      - **Valor de retorno**: Nenhum.
    - **`GetStr(char& json[], int i, int len)`**
      - **Assinatura**: `virtual string GetStr(char& json[], int i, int len)`
      - **Descrição simplificada**: Extrai uma substring de um array de caracteres JSON.
      - **Parâmetros**:
        - `json` (`char&`): O array de caracteres JSON.
        - `i` (`int`): O índice inicial.
        - `len` (`int`): O comprimento da substring.
      - **Valor de retorno**: `string` - A substring extraída.
    - **`Set(const CJAVal& a)`**
      - **Assinatura**: `virtual void Set(const CJAVal& a)`
      - **Descrição simplificada**: Define o conteúdo do objeto `CJAVal` copiando outro `CJAVal`.
      - **Parâmetros**:
        - `a` (`const CJAVal&`): O objeto `CJAVal` de origem.
      - **Valor de retorno**: Nenhum.
    - **`Set(const CJAVal& list[])`**
      - **Assinatura**: `virtual void Set(const CJAVal& list[])`
      - **Descrição simplificada**: Define o conteúdo do objeto `CJAVal` como um array de outros objetos `CJAVal`.
      - **Parâmetros**:
        - `list` (`const CJAVal&[]`): Um array de objetos `CJAVal`.
      - **Valor de retorno**: Nenhum.
    - **`Add(const CJAVal& item)`**
      - **Assinatura**: `virtual CJAVal* Add(const CJAVal& item)`
      - **Descrição simplificada**: Adiciona um item `CJAVal` como filho do objeto atual (se for um array ou objeto).
      - **Parâmetros**:
        - `item` (`const CJAVal&`): O item `CJAVal` a ser adicionado.
      - **Valor de retorno**: `CJAVal*` - Ponteiro para o item adicionado.
    - **`Add(const int v)`**
      - **Assinatura**: `virtual CJAVal* Add(const int v)`
      - **Descrição simplificada**: Adiciona um valor inteiro como filho do objeto atual.
      - **Parâmetros**:
        - `v` (`const int`): O valor inteiro a ser adicionado.
      - **Valor de retorno**: `CJAVal*` - Ponteiro para o item adicionado.
    - **`Add(const long v)`**
      - **Assinatura**: `virtual CJAVal* Add(const long v)`
      - **Descrição simplificada**: Adiciona um valor long como filho do objeto atual.
      - **Parâmetros**:
        - `v` (`const long`): O valor long a ser adicionado.
      - **Valor de retorno**: `CJAVal*` - Ponteiro para o item adicionado.
    - **`Add(const double v, int precision=-2)`**
      - **Assinatura**: `virtual CJAVal* Add(const double v, int precision=-2)`
      - **Descrição simplificada**: Adiciona um valor double como filho do objeto atual, com precisão opcional.
      - **Parâmetros**:
        - `v` (`const double`): O valor double a ser adicionado.
        - `precision` (`int`, opcional, padrão: -2): A precisão para o valor double.
      - **Valor de retorno**: `CJAVal*` - Ponteiro para o item adicionado.
    - **`Add(const bool v)`**
      - **Assinatura**: `virtual CJAVal* Add(const bool v)`
      - **Descrição simplificada**: Adiciona um valor booleano como filho do objeto atual.
      - **Parâmetros**:
        - `v` (`const bool`): O valor booleano a ser adicionado.
      - **Valor de retorno**: `CJAVal*` - Ponteiro para o item adicionado.
    - **`Add(string v)`**
      - **Assinatura**: `virtual CJAVal* Add(string v)`
      - **Descrição simplificada**: Adiciona um valor string como filho do objeto atual.
      - **Parâmetros**:
        - `v` (`string`): O valor string a ser adicionado.
      - **Valor de retorno**: `CJAVal*` - Ponteiro para o item adicionado.
    - **`AddBase(const CJAVal &item)`**
      - **Assinatura**: `virtual CJAVal* AddBase(const CJAVal &item)`
      - **Descrição simplificada**: Método auxiliar para adicionar um item `CJAVal` como filho.
      - **Parâmetros**:
        - `item` (`const CJAVal &`): O item `CJAVal` a ser adicionado.
      - **Valor de retorno**: `CJAVal*` - Ponteiro para o item adicionado.
    - **`New()`**
      - **Assinatura**: `virtual CJAVal* New()`
      - **Descrição simplificada**: Cria um novo item filho e o adiciona ao objeto atual.
      - **Parâmetros**: Nenhum.
      - **Valor de retorno**: `CJAVal*` - Ponteiro para o novo item.
    - **`NewBase()`**
      - **Assinatura**: `virtual CJAVal* NewBase()`
      - **Descrição simplificada**: Método auxiliar para criar e adicionar um novo item filho.
      - **Parâmetros**: Nenhum.
      - **Valor de retorno**: `CJAVal*` - Ponteiro para o novo item.
    - **`Escape(string v)`**
      - **Assinatura**: `virtual string Escape(string v)`
      - **Descrição simplificada**: Escapa caracteres especiais em uma string para formato JSON.
      - **Parâmetros**:
        - `v` (`string`): A string a ser escapada.
      - **Valor de retorno**: `string` - A string com caracteres escapados.
    - **`Unescape(string v)`**
      - **Assinatura**: `virtual string Unescape(string v)`
      - **Descrição simplificada**: Desescapa caracteres especiais em uma string JSON.
      - **Parâmetros**:
        - `v` (`string`): A string a ser desescapada.
      - **Valor de retorno**: `string` - A string com caracteres desescapados.
    - **`Serialize(string &json, bool is_key=false, bool use_comma=false)`**
      - **Assinatura**: `virtual void Serialize(string &json, bool is_key=false, bool use_comma=false)`
      - **Descrição simplificada**: Serializa o objeto `CJAVal` para uma string JSON.
      - **Parâmetros**:
        - `json` (`string &`): A string onde o JSON serializado será anexado.
        - `is_key` (`bool`, opcional, padrão: `false`): Indica se o objeto está sendo serializado como uma chave.
        - `use_comma` (`bool`, opcional, padrão: `false`): Indica se uma vírgula deve ser adicionada antes da serialização.
      - **Valor de retorno**: Nenhum.
    - **`Serialize()`**
      - **Assinatura**: `virtual string Serialize()`
      - **Descrição simplificada**: Serializa o objeto `CJAVal` para uma string JSON e a retorna.
      - **Parâmetros**: Nenhum.
      - **Valor de retorno**: `string` - A string JSON serializada.
    - **`Deserialize(char& json[], int len, int &i)`**
      - **Assinatura**: `virtual bool Deserialize(char& json[], int len, int &i)`
      - **Descrição simplificada**: Desserializa um array de caracteres JSON para o objeto `CJAVal`.
      - **Parâmetros**:
        - `json` (`char&`): O array de caracteres JSON.
        - `len` (`int`): O comprimento do array.
        - `i` (`int &`): O índice atual no array, que será atualizado durante a desserialização.
      - **Valor de retorno**: `bool` - `true` se a desserialização foi bem-sucedida, `false` caso contrário.
    - **`ExtrStr(char& json[], int len, int &i)`**
      - **Assinatura**: `virtual bool ExtrStr(char& json[], int len, int &i)`
      - **Descrição simplificada**: Extrai uma string de um array de caracteres JSON, tratando aspas e caracteres de escape.
      - **Parâmetros**:
        - `json` (`char&`): O array de caracteres JSON.
        - `len` (`int`): O comprimento do array.
        - `i` (`int &`): O índice atual no array, que será atualizado.
      - **Valor de retorno**: `bool` - `true` se a extração foi bem-sucedida, `false` caso contrário.
    - **`Deserialize(string json, int acp=CP_ACP)`**
      - **Assinatura**: `virtual bool Deserialize(string json, int acp=CP_ACP)`
      - **Descrição simplificada**: Desserializa uma string JSON para o objeto `CJAVal`.
      - **Parâmetros**:
        - `json` (`string`): A string JSON a ser desserializada.
        - `acp` (`int`, opcional, padrão: `CP_ACP`): A página de código a ser usada.
      - **Valor de retorno**: `bool` - `true` se a desserialização foi bem-sucedida, `false` caso contrário.
    - **`Deserialize(char& json[], int acp=CP_ACP)`**
      - **Assinatura**: `virtual bool Deserialize(char& json[], int acp=CP_ACP)`
      - **Descrição simplificada**: Desserializa um array de caracteres JSON para o objeto `CJAVal`.
      - **Parâmetros**:
        - `json` (`char&`): O array de caracteres JSON.
        - `acp` (`int`, opcional, padrão: `CP_ACP`): A página de código a ser usada.
      - **Valor de retorno**: `bool` - `true` se a desserialização foi bem-sucedida, `false` caso contrário.

### config_manager.mqh

#### Classes

- **`CConfigManager`**
  - **Descrição simplificada**: Gerencia o carregamento, parsing e acesso às configurações do Expert Advisor a partir de um arquivo JSON. Responsável por criar e manter os contextos de timeframe (`TF_CTX`).
  - **Membros Privados**:
    - `m_config` (`CJAVal`): Objeto `CJAVal` que armazena a configuração JSON parseada.
    - `m_symbols[]` (`string`): Array de strings contendo os símbolos configurados.
    - `m_contexts[]` (`TF_CTX*`): Array de ponteiros para objetos `TF_CTX`, representando os contextos de timeframe criados.
    - `m_context_keys[]` (`string`): Array de strings contendo as chaves únicas para cada contexto (símbolo + timeframe).
    - `m_initialized` (`bool`): Flag que indica se o gerenciador de configuração foi inicializado com sucesso.
  - **Métodos Privados**:
    - **`LoadConfig(string json_content)`**
      - **Assinatura**: `bool LoadConfig(string json_content)`
      - **Descrição simplificada**: Carrega a configuração a partir de uma string JSON. Realiza o parsing do JSON e extrai os símbolos configurados.
      - **Parâmetros**:
        - `json_content` (`string`): A string contendo o conteúdo JSON.
      - **Valor de retorno**: `bool` - `true` se o carregamento e parsing forem bem-sucedidos, `false` caso contrário.
    - **`LoadConfigFromFile(string file_path)`**
      - **Assinatura**: `bool LoadConfigFromFile(string file_path)`
      - **Descrição simplificada**: Tenta carregar o conteúdo JSON de um arquivo, verificando diferentes caminhos e codificações (ANSI, UTF-8).
      - **Parâmetros**:
        - `file_path` (`string`): O caminho do arquivo JSON.
      - **Valor de retorno**: `bool` - `true` se o arquivo for lido e a configuração carregada com sucesso, `false` caso contrário.
    - **`CreateContexts()`**
      - **Assinatura**: `bool CreateContexts()`
      - **Descrição simplificada**: Itera sobre os símbolos e timeframes configurados no JSON, parseia as configurações de cada um e cria as instâncias correspondentes de `TF_CTX`.
      - **Parâmetros**: Nenhum.
      - **Valor de retorno**: `bool` - `true` se todos os contextos forem criados com sucesso, `false` caso contrário.
    - **`TimeframeToString(ENUM_TIMEFRAMES tf)`**
      - **Assinatura**: `string TimeframeToString(ENUM_TIMEFRAMES tf)`
      - **Descrição simplificada**: Converte um valor `ENUM_TIMEFRAMES` para sua representação em string (ex: `PERIOD_D1` para "D1").
      - **Parâmetros**:
        - `tf` (`ENUM_TIMEFRAMES`): O timeframe a ser convertido.
      - **Valor de retorno**: `string` - A representação em string do timeframe.
    - **`StringToTimeframe(string tf_str)`**
      - **Assinatura**: `ENUM_TIMEFRAMES StringToTimeframe(string tf_str)`
      - **Descrição simplificada**: Converte uma string de timeframe (ex: "D1") para o valor `ENUM_TIMEFRAMES` correspondente.
      - **Parâmetros**:
        - `tf_str` (`string`): A string do timeframe.
      - **Valor de retorno**: `ENUM_TIMEFRAMES` - O valor `ENUM_TIMEFRAMES` correspondente.
    - **`StringToMAMethod(string method_str)`**
      - **Assinatura**: `ENUM_MA_METHOD StringToMAMethod(string method_str)`
      - **Descrição simplificada**: Converte uma string de método de média móvel (ex: "EMA") para o valor `ENUM_MA_METHOD` correspondente.
      - **Parâmetros**:
        - `method_str` (`string`): A string do método da média móvel.
      - **Valor de retorno**: `ENUM_MA_METHOD` - O valor `ENUM_MA_METHOD` correspondente.
    - **`ParseTimeframeConfig(CJAVal *tf_config)`**
      - **Assinatura**: `STimeframeConfig ParseTimeframeConfig(CJAVal *tf_config)`
      - **Descrição simplificada**: Parseia um objeto `CJAVal` que representa a configuração de um timeframe e o converte para a estrutura `STimeframeConfig`.
      - **Parâmetros**:
        - `tf_config` (`CJAVal *`): Ponteiro para o objeto `CJAVal` contendo a configuração do timeframe.
      - **Valor de retorno**: `STimeframeConfig` - A estrutura de configuração do timeframe parseada.
    - **`CreateContextKey(string symbol, ENUM_TIMEFRAMES tf)`**
      - **Assinatura**: `string CreateContextKey(string symbol, ENUM_TIMEFRAMES tf)`
      - **Descrição simplificada**: Cria uma chave única para um contexto de timeframe, combinando o símbolo e o timeframe.
      - **Parâmetros**:
        - `symbol` (`string`): O símbolo.
        - `tf` (`ENUM_TIMEFRAMES`): O timeframe.
      - **Valor de retorno**: `string` - A chave do contexto.
    - **`TestJSONParsing()`**
      - **Assinatura**: `bool TestJSONParsing()`
      - **Descrição simplificada**: Realiza um teste básico de parsing JSON para verificar a funcionalidade da biblioteca `JAson`.
      - **Parâmetros**: Nenhum.
      - **Valor de retorno**: `bool` - `true` se o teste for bem-sucedido, `false` caso contrário.
  - **Construtor e Destrutor**:
    - **`CConfigManager()`**
      - **Assinatura**: `CConfigManager()`
      - **Descrição simplificada**: Construtor padrão. Inicializa o gerenciador de configuração, definindo `m_initialized` como `false` e redimensionando os arrays internos para zero.
      - **Parâmetros**: Nenhum.
      - **Valor de retorno**: Objeto `CConfigManager`.
    - **`~CConfigManager()`**
      - **Assinatura**: `~CConfigManager()`
      - **Descrição simplificada**: Destrutor. Chama o método `Cleanup()` para liberar todos os recursos alocados.
      - **Parâmetros**: Nenhum.
      - **Valor de retorno**: Nenhum.
  - **Métodos Públicos**:
    - **`InitFromFile(string file_path)`**
      - **Assinatura**: `bool InitFromFile(string file_path)`
      - **Descrição simplificada**: Inicializa o gerenciador de configuração carregando o conteúdo de um arquivo JSON. Este é o método principal de inicialização usado pelo EA.
      - **Parâmetros**:
        - `file_path` (`string`): O caminho do arquivo JSON.
      - **Valor de retorno**: `bool` - `true` se a inicialização for bem-sucedida, `false` caso contrário.
    - **`GetContext(string symbol, ENUM_TIMEFRAMES timeframe)`**
      - **Assinatura**: `TF_CTX *GetContext(string symbol, ENUM_TIMEFRAMES timeframe)`
      - **Descrição simplificada**: Retorna um ponteiro para o objeto `TF_CTX` correspondente ao símbolo e timeframe especificados, se existir.
      - **Parâmetros**:
        - `symbol` (`string`): O símbolo do ativo.
        - `timeframe` (`ENUM_TIMEFRAMES`): O timeframe desejado.
      - **Valor de retorno**: `TF_CTX *` - Ponteiro para o `TF_CTX` encontrado, ou `NULL` se não for encontrado.
    - **`IsContextEnabled(string symbol, ENUM_TIMEFRAMES timeframe)`**
      - **Assinatura**: `bool IsContextEnabled(string symbol, ENUM_TIMEFRAMES timeframe)`
      - **Descrição simplificada**: Verifica se um contexto específico (símbolo e timeframe) está habilitado na configuração.
      - **Parâmetros**:
        - `symbol` (`string`): O símbolo do ativo.
        - `timeframe` (`ENUM_TIMEFRAMES`): O timeframe desejado.
      - **Valor de retorno**: `bool` - `true` se o contexto estiver habilitado, `false` caso contrário.
    - **`GetConfiguredSymbols(string &symbols[])`**
      - **Assinatura**: `void GetConfiguredSymbols(string &symbols[])`
      - **Descrição simplificada**: Preenche um array de strings com todos os símbolos que foram configurados no arquivo JSON.
      - **Parâmetros**:
        - `symbols[]` (`string &`): Um array de strings passado por referência para ser preenchido com os símbolos.
      - **Valor de retorno**: Nenhum.
    - **`Cleanup()`**
      - **Assinatura**: `void Cleanup()`
      - **Descrição simplificada**: Libera todos os recursos alocados pelo gerenciador de configuração, incluindo as instâncias de `TF_CTX` e limpa a configuração JSON.
      - **Parâmetros**: Nenhum.
      - **Valor de retorno**: Nenhum.
    - **`IsInitialized() const`**
      - **Assinatura**: `bool IsInitialized() const`
      - **Descrição simplificada**: Retorna o status de inicialização do gerenciador de configuração.
      - **Parâmetros**: Nenhum.
      - **Valor de retorno**: `bool` - `true` se o gerenciador foi inicializado com sucesso, `false` caso contrário.

### config_types.mqh

#### Estruturas

- **`SIndicatorConfig`**
  - **Descrição simplificada**: Estrutura que define a configuração de um indicador genérico.
  - **Membros**:
    - `name` (`string`): Nome do indicador.
    - `type` (`string`): Tipo do indicador (ex: `MA`).
    - `period` (`int`): Período principal (por exemplo, %K no Estocástico).
    - `method` (`ENUM_MA_METHOD`): Método aplicado (para médias ou suavização).
    - `dperiod` (`int`): Período da linha %D (apenas para Estocástico).
    - `slowing` (`int`): Valor de `slowing` (apenas para Estocástico).
    - `shift` (`int`): Deslocamento base para indicadores que utilizam série de preços (ex: Volume).
    - `price_field` (`ENUM_STO_PRICE`): Campo de preço utilizado.
    - `vwap_calc_mode`, `vwap_session_tf`, `vwap_price_type`, `vwap_start_time`, `vwap_color`: Parâmetros específicos do indicador VWAP.
    - `enabled` (`bool`): Indica se o indicador está habilitado.
    - `level_1` a `level_6` (`double`): Valores dos níveis de retração de Fibonacci.
    - `levels_color`, `levels_style`, `levels_width`: Aparência das linhas de retração.
    - `ext_1` a `ext_3` (`double`): Valores das extensões (ex.: 127, 161.8).
    - `extensions_color`, `extensions_style`, `extensions_width`: Aparência das extensões.
    - `parallel_color`, `parallel_style`, `parallel_width`: Linha principal do objeto.
    - `show_labels` (`bool`): Habilita rótulos de preço/percentual.
    - `labels_color`, `labels_font_size`, `labels_font`: Aparência dos textos.

- **`STimeframeConfig`**
  - **Descrição simplificada**: Configuração para um timeframe específico contendo uma lista de indicadores.
  - **Membros**:
    - `enabled` (`bool`): Indica se este timeframe está habilitado.
    - `num_candles` (`int`): Número de candles a considerar.
    - `indicators[]` (`SIndicatorConfig[]`): Array de configurações de indicadores.

### tf_ctx.mqh

#### Classes

- **`TF_CTX`**
  - **Descrição simplificada**: Classe que representa um contexto para um símbolo e timeframe, mantendo uma lista de indicadores.
  - **Membros Privados**:
    - `m_timeframe` (`ENUM_TIMEFRAMES`): Timeframe analisado.
    - `m_num_candles` (`int`): Número de candles considerados.
    - `m_symbol` (`string`): Símbolo associado.
    - `m_initialized` (`bool`): Indica se o contexto foi inicializado.
    - `m_cfg[]` (`SIndicatorConfig[]`): Configurações dos indicadores.
    - `m_indicators[]` (`CIndicatorBase*[]`): Instâncias dos indicadores.
  - **Métodos Privados**:
    - **`ValidateParameters()`**: Valida os parâmetros de construção.
    - **`CleanUp()`**: Libera recursos.
  - **Construtor e Destrutor**:
    - **`TF_CTX(ENUM_TIMEFRAMES timeframe, int num_candles, SIndicatorConfig &cfg[])`**: Cria o contexto usando a lista de indicadores.
    - **`~TF_CTX()`**: Libera recursos.
  - **Métodos Públicos**:
    - **`Init()`**: Inicializa o contexto criando os indicadores.
    - **`Update()`**: Percorre a lista `m_indicators` e chama `Update()` em cada objeto. Essa chamada utiliza o método da classe base `CIndicatorBase`, que por padrão apenas verifica `IsReady()`, mas pode ser sobrescrito por indicadores específicos (ex.: `CFibonacci`). Retorna `true` se todos estiverem prontos.
    - **`GetIndicatorValue(string name, int shift = 0)`**: Obtém o valor de um indicador pelo nome.
    - **`CopyIndicatorValues(string name, int shift, int count, double &buffer[])`**: Copia múltiplos valores.
    - **`IsInitialized() const`**, **`GetTimeframe() const`**, **`GetNumCandles() const`**, **`GetSymbol() const`**: Acessores.
### moving_averages.mqh

#### Classes

- **`CMovingAverages`**
  - **Descrição simplificada**: Classe responsável por criar e gerenciar um indicador de média móvel específico (EMA, SMA, etc.) para um dado símbolo e timeframe, e fornecer acesso aos seus valores.
  - **Membros Privados**:
    - `m_symbol` (`string`): O símbolo do ativo para o qual a média móvel é calculada.
    - `m_timeframe` (`ENUM_TIMEFRAMES`): O timeframe da média móvel.
    - `m_period` (`int`): O período da média móvel.
    - `m_method` (`ENUM_MA_METHOD`): O método da média móvel (ex: `MODE_SMA`, `MODE_EMA`).
    - `m_handle` (`int`): O handle do indicador MQL5, usado para acessar os dados do indicador.
  - **Métodos Privados**:
    - **`CreateIndicatorHandles()`**
      - **Assinatura**: `bool CreateIndicatorHandles()`
      - **Descrição simplificada**: Cria o handle do indicador de média móvel usando a função `iMA()` do MQL5 com os parâmetros configurados.
      - **Parâmetros**: Nenhum.
      - **Valor de retorno**: `bool` - `true` se o handle foi criado com sucesso, `false` caso contrário.
    - **`ReleaseIndicatorHandles()`**
      - **Assinatura**: `void ReleaseIndicatorHandles()`
      - **Descrição simplificada**: Libera o handle do indicador, liberando os recursos associados no MetaTrader 5.
      - **Parâmetros**: Nenhum.
      - **Valor de retorno**: Nenhum.
    - **`GetIndicatorValue(int handle, int shift = 0)`**
      - **Assinatura**: `double GetIndicatorValue(int handle, int shift = 0)`
      - **Descrição simplificada**: Obtém o valor de um indicador MQL5 para um determinado handle e shift. É um método auxiliar interno.
      - **Parâmetros**:
        - `handle` (`int`): O handle do indicador.
        - `shift` (`int`, opcional, padrão: 0): O deslocamento do candle.
      - **Valor de retorno**: `double` - O valor do indicador.
  - **Construtor e Destrutor**:
    - **`CMovingAverages()`**
      - **Assinatura**: `CMovingAverages()`
      - **Descrição simplificada**: Construtor padrão. Inicializa os membros da classe com valores padrão e o handle do indicador como inválido.
      - **Parâmetros**: Nenhum.
      - **Valor de retorno**: Objeto `CMovingAverages`.
    - **`~CMovingAverages()`**
      - **Assinatura**: `~CMovingAverages()`
      - **Descrição simplificada**: Destrutor. Chama `ReleaseIndicatorHandles()` para garantir que o handle do indicador seja liberado.
      - **Parâmetros**: Nenhum.
      - **Valor de retorno**: Nenhum.
  - **Métodos Públicos**:
    - **`Init(string symbol, ENUM_TIMEFRAMES timeframe, int period, ENUM_MA_METHOD method)`**
      - **Assinatura**: `bool Init(string symbol, ENUM_TIMEFRAMES timeframe, int period, ENUM_MA_METHOD method)`
      - **Descrição simplificada**: Inicializa a instância da média móvel com os parâmetros fornecidos e cria o handle do indicador.
      - **Parâmetros**:
        - `symbol` (`string`): O símbolo do ativo.
        - `timeframe` (`ENUM_TIMEFRAMES`): O timeframe.
        - `period` (`int`): O período da média móvel.
        - `method` (`ENUM_MA_METHOD`): O método da média móvel.
      - **Valor de retorno**: `bool` - `true` se a inicialização for bem-sucedida, `false` caso contrário.
    - **`GetValue(int shift = 0)`**
      - **Assinatura**: `double GetValue(int shift = 0)`
      - **Descrição simplificada**: Retorna o valor da média móvel para o candle especificado pelo `shift`.
      - **Parâmetros**:
        - `shift` (`int`, opcional, padrão: 0): O deslocamento do candle.
      - **Valor de retorno**: `double` - O valor da média móvel.
    - **`CopyValues(int shift, int count, double &buffer[])`**
      - **Assinatura**: `bool CopyValues(int shift, int count, double &buffer[])`
      - **Descrição simplificada**: Copia múltiplos valores da média móvel para um array fornecido, a partir de um `shift` e por um `count` de candles.
      - **Parâmetros**:
        - `shift` (`int`): O deslocamento inicial do candle.
        - `count` (`int`): O número de valores a serem copiados.
        - `buffer[]` (`double &`): O array para onde os valores serão copiados.
      - **Valor de retorno**: `bool` - `true` se a cópia foi bem-sucedida, `false` caso contrário.
    - **`IsReady()`**
      - **Assinatura**: `bool IsReady()`
      - **Descrição simplificada**: Verifica se o indicador de média móvel está pronto (se já calculou barras suficientes).
      - **Parâmetros**: Nenhum.
      - **Valor de retorno**: `bool` - `true` se o indicador estiver pronto, `false` caso contrário.




## 5. Parâmetros de Entrada

O Expert Advisor PA_WIN possui o seguinte parâmetro de entrada configurável pelo usuário:

| Nome             | Tipo     | Valor Padrão  | Descrição                                  | Restrições |
| :--------------- | :------- | :------------ | :----------------------------------------- | :--------- |
| `JsonConfigFile` | `string` | `config.json` | Nome do arquivo JSON que contém a configuração detalhada do Expert Advisor, incluindo símbolos, timeframes e médias móveis a serem monitoradas. Este arquivo deve estar localizado na pasta `MQL5/Files` ou `Common/Files` do terminal MetaTrader 5. | Deve ser um nome de arquivo válido e acessível. |




## 6. Dependências Externas

O Expert Advisor PA_WIN utiliza as seguintes dependências externas para seu funcionamento:

- **Bibliotecas MQL5 Customizadas**: 
    - `JAson.mqh`: Biblioteca para parsing e manipulação de JSON. Essencial para ler o arquivo de configuração `config.json`.
    - `config_manager.mqh`: Gerencia o carregamento e a criação de contextos a partir da configuração JSON.
    - `config_types.mqh`: Define as estruturas de dados para a configuração de timeframes e médias móveis.
    - `tf_ctx.mqh`: Gerencia o contexto de dados para um símbolo e timeframe específicos, incluindo o acesso às médias móveis.
    - `moving_averages.mqh`: Implementa a lógica para a criação e obtenção de valores de médias móveis.

- **Indicadores Integrados do MetaTrader 5**: 
    - `iMA()`: Função MQL5 para obter o handle de um indicador de média móvel. Utilizado pela classe `CMovingAverages` para calcular as médias móveis.

- **Arquivos de Configuração**: 
    - `config.json`: Arquivo JSON externo que armazena toda a configuração dinâmica do Expert Advisor, permitindo flexibilidade na definição de símbolos, timeframes e parâmetros de médias móveis sem a necessidade de recompilação do código MQL5.




## 7. Exemplos de Configuração e Uso

### Exemplo de `config.json`

O arquivo `config.json` é o coração da flexibilidade do PA_WIN. Abaixo está um exemplo de como ele pode ser estruturado para configurar o EA para monitorar o símbolo `WIN$N` no timeframe `D1` com EMA9 e EMA21 habilitadas:

```json
{
   "WIN$N": {
      "D1": {
         "enabled": true,
         "num_candles": 4,
           "indicators": [
            {"name":"ema9","type":"MA","period":9,"method":"EMA","enabled":true},
            {"name":"ema21","type":"MA","period":21,"method":"EMA","enabled":true},
            {"name":"ema50","type":"MA","period":50,"method":"EMA","enabled":false},
            {"name":"sma200","type":"MA","period":200,"method":"SMA","enabled":false}
           ]
      }
   }
}
```

**Explicação da Estrutura:**

-   **Chave de Nível Superior (`"WIN$N"`):** Representa o símbolo do ativo a ser monitorado. Você pode adicionar múltiplos símbolos como chaves separadas.
-   **Chave de Timeframe (`"D1"`):** Dentro de cada símbolo, você define os timeframes que deseja monitorar. Os nomes são lidos diretamente do arquivo `config.json`, permitindo incluir novos timeframes sem ajustes no código-fonte.
    -   `"enabled"`: Booleano que indica se este timeframe específico para o símbolo está ativo (`true`) ou desativado (`false`).
    -   `"indicators"`: Lista com a configuração dos indicadores associados a este timeframe.
        -   Cada objeto possui os campos `name`, `type`, `period`, `method` e `enabled`.
        -   Exemplo de indicador:
            -   `"period"`: Inteiro que define o período do indicador (ex: 9 para EMA9, 21 para EMA21).
            -   `"method"`: String que especifica o método do indicador (ex: "EMA" para Média Móvel Exponencial, "SMA" para Média Móvel Simples). Deve corresponder aos métodos suportados pelo MQL5.
         -   `"enabled"`: Booleano que indica se este indicador específica está habilitada (`true`) ou desativada (`false`) para este timeframe.

### Paleta de Cores Disponível

Os campos `LevelsColor`, `ExtensionsColor`, `ParallelColor`, `LabelsColor` e `Color` utilizam nomes de cores em formato de string. As cores reconhecidas atualmente são:

- `Red`
- `Blue`
- `Yellow`
- `Green`
- `Orange`
- `White`
- `Black`

### Cenários Típicos de Uso

1.  **Configuração para Múltiplos Símbolos e Timeframes:**
    Para monitorar `WIN$N` em `D1` e `PETR4` em `H4`, você ajustaria o `config.json` da seguinte forma:

    ```json
    {
       "WIN$N": {
          "D1": {
             "enabled": true,
             "num_candles": 4,
             "indicators": {
                "ema9": {"period": 9, "method": "EMA", "enabled": true},
                "ema21": {"period": 21, "method": "EMA", "enabled": true}
             }
          }
       },
       "PETR4": {
          "H4": {
             "enabled": true,
             "num_candles": 10,
               "indicators": [
                  {"name":"sma200","type":"MA","period":200,"method":"SMA","enabled":true}
               ]
          }
       }
    }
    ```

2.  **Habilitando/Desabilitando Indicadores:**
    Se você quiser desabilitar a EMA9 para `WIN$N` no `D1` e habilitar a EMA50, basta alterar o valor de `"enabled"` para `false` na `ema9` e para `true` na `ema50` no `config.json`.

3.  **Recarregando a Configuração em Tempo de Execução (Apenas para Desenvolvimento/Testes):**
    Durante o desenvolvimento, se você fizer alterações no `config.json`, pode chamar a função `ReloadConfig()` (se exposta no EA, como é o caso do PA_WIN) para que o EA recarregue a nova configuração sem precisar ser removido e adicionado novamente ao gráfico. Isso é feito internamente pelo EA chamando `g_config_manager.Cleanup()` e `g_config_manager.InitFromFile(JsonConfigFile)`.

4.  **Configuração Completa da VWAP:**
    O trecho abaixo demonstra como incluir o indicador VWAP com todos os parâmetros disponíveis:

    ```json
    {
       "name": "vwap_session",
       "type": "VWAP",
       "period": 14,
       "calc_mode": "PERIODIC",
       "session_tf": "D1",
       "price_type": "HLC3",
       "start_time": "2025-01-01 09:00:00",
       "Color": "Blue",
       "Style": "SOLID",
       "Width": 2,
       "enabled": true
    }
    ```
    - `calc_mode`: define se o cálculo será por um número fixo de barras (`BAR`), reiniciado a cada sessão (`PERIODIC`) ou a partir de uma data específica (`FROM_DATE`).
    - `session_tf`: timeframe utilizado para detectar o início das sessões (por exemplo, `D1` ou `W1`).
    - `price_type`: forma de cálculo do preço típico, como `OPEN`, `CLOSE`, `HL2`, `HLC3` ou `OHLC4`.
    - `start_time`: usado apenas no modo `FROM_DATE` para indicar a data/hora inicial.
    - `Color`: define a cor da linha de VWAP.
    - `Style`: estilo de linha (ex. `SOLID`, `DASH`).
    - `Width`: espessura da linha em pixels.

Exemplo de configuração para cálculo **PERIODIC**, sessão diária, com preço
    de **média financeira**:

    ```json
    {
       "name": "vwap_diario_fin",
       "type": "VWAP",
       "period": 14,
       "calc_mode": "PERIODIC",
       "session_tf": "D1",
       "price_type": "FINANCIAL_AVERAGE",
       "Color": "Blue",
       "enabled": true
    }
    ```

5.  **Exemplo de Bandas de Bollinger:**
    Inclusão das Bandas de Bollinger com parâmetros básicos:

    ```json
    {
       "name": "boll20",
       "type": "BOLL",
       "period": 20,
       "shift": 0,
       "deviation": 2.0,
       "applied_price": "CLOSE",
       "enabled": true
    }
    ```
    - `period`: período utilizado para a média central.
    - `shift`: deslocamento das bandas.
    - `deviation`: multiplicador de desvio padrão.
    - `applied_price`: preço base (ex.: `CLOSE`, `OPEN`, `HIGH`, `LOW`, `MEDIAN`, `TYPICAL`, `WEIGHTED`).

**Observação Importante:** Para que o EA leia o `config.json`, o arquivo deve ser salvo na pasta `MQL5/Files` ou `Common/Files` do seu terminal MetaTrader 5. O parâmetro de entrada `JsonConfigFile` no EA deve corresponder ao nome do arquivo (ex: `config.json`).




## 8. Changelog / Registro de Versões

Esta seção registra as principais alterações e versões dos componentes do Expert Advisor PA_WIN.

### PA_WIN.mq5

-   **Versão 2.00 (22.06.2025)**: Atualizado para integrar o `ConfigManager` para gerenciamento de configurações externas via JSON.

### JAson.mqh

-   **Versão 1.13**: Versão da biblioteca JAson utilizada para desserialização e serialização de dados JSON.

### config_manager.mqh

-   **Versão 2.00**: Versão atual do gerenciador de configurações, responsável por carregar e gerenciar as configurações do EA a partir de arquivos JSON.

### tf_ctx.mqh

-   **Versão 2.00**: Suporte a lista dinâmica de indicadores baseada em `CIndicatorBase`.

### indicator_base.mqh

-   **Versão 1.00**: Interface abstrata para criação de novos tipos de indicadores.

### moving_averages.mqh

-   **Versão 1.01**: Implementa indicadores de média móvel derivados de `CIndicatorBase`.
-   **Versão 1.02**: Inclui método `Update()` para recriar o handle se necessário.




### stochastic.mqh

-   **Versao 1.00**: Implementa o indicador Estocastico derivado de `CIndicatorBase`.
-   **Versao 1.01**: Adiciona método `Update()` para validação do handle.

### volume.mqh

-   **Versao 1.00**: Implementa o indicador de Volume derivado de `CIndicatorBase`.
-   **Versao 1.01**: Implementa `Update()` para compatibilidade com a interface.

### bollinger.mqh

-   **Versao 1.00**: Implementa o indicador de Bandas de Bollinger derivado de `CIndicatorBase`.
-   **Versao 1.01**: Adiciona método `Update()` que recria o handle quando inválido.

### vwap.mqh

-   **Versao 1.00**: Implementa o indicador VWAP (Volume Weighted Average Price) derivado de `CIndicatorBase`.
-   **Versao 2.00**: Adiciona desenho da linha de VWAP no gráfico.
-   **Versao 3.00**: Reescrita completa com cálculo acumulado por sessão, modos de cálculo e suporte a diferentes tipos de preço.
-   **Versao 4.00**: Corrige o cálculo por barras, inclui métodos de configuração e atualização incremental.
-   **Versao 5.00**: Melhora a detecção de sessões e o cálculo da barra atual.
-   **Versao 6.00**: Permite definir a cor da linha VWAP via JSON.
-   **Versao 7.00**: Suporte a estilo e largura de linha configuráveis via JSON.
-   **Versao 8.00**: `Update()` recalcula e redesenha a linha VWAP.
-   **Versao 9.00**: Remove o desenho manual da linha; a exibição fica a cargo do indicador `vwap_indicator.mq5`.

### vwap_indicator.mq5

-   **Versao 1.00**: Indicador customizado de VWAP utilizado via `iCustom`, permitindo que o MetaTrader desenhe a linha automaticamente.

### fibonacci.mqh

-   **Versao 1.00**: Implementa o indicador de retração de Fibonacci derivado de `CIndicatorBase`.
-   **Versao 2.00**: Suporte a extensões, estilos configuráveis e rótulos personalizados via JSON.
