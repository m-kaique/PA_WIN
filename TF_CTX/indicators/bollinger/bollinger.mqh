//+------------------------------------------------------------------+
//|                                    indicators/bollinger.mqh      |
//|  Indicador de Bandas de Bollinger derivado de CIndicatorBase     |
//|                                                                  |
//|  DESCRIÇÃO: Este arquivo implementa a classe CBollinger, que     |
//|  calcula e fornece sinais baseados nas Bandas de Bollinger.     |
//|  As Bandas de Bollinger são um indicador técnico que mede a     |
//|  volatilidade do preço, consistindo em uma média móvel (banda   |
//|  central) e duas bandas superior/inferior baseadas no desvio    |
//|  padrão.                                                         |
//+------------------------------------------------------------------+
#ifndef __BOLLINGER_MQH__
#define __BOLLINGER_MQH__

#include "../indicator_base/indicator_base.mqh"  // Classe base para indicadores
#include "../indicators_types.mqh"               // Definições de tipos comuns
#include "bollinger_defs.mqh"                    // Constantes específicas do Bollinger

class CBollinger : public CIndicatorBase
{
private:
    int m_period;              // Período da média móvel (ex: 20 candles)
    int m_shift;               // Deslocamento das bandas (normalmente 0)
    double m_deviation;        // Desvio padrão multiplicador (normalmente 2.0)
    ENUM_APPLIED_PRICE m_price; // Tipo de preço usado (ex: PRICE_CLOSE)
    double width_array[];      // Array para armazenar larguras das bandas

    // Parâmetros configuráveis - ajustáveis pelo usuário
    int m_width_history;       // Quantidade de candles para histórico de largura
    int m_width_lookback;      // Período para análise estatística da largura
    int m_slope_lookback;      // Período para cálculo da inclinação
    int m_percentile_thresholds[4]; // Limites percentuais para classificação de regiões
    double m_weights[3];       // Pesos para: banda, inclinação, largura

    // Threshold adaptativo baseado no ATR passado como parâmetro
    double m_adaptive_threshold_ratio; // Ratio para threshold adaptativo (0.12 = 12%)

   // Otimização do cálculo de largura - evita recálculos desnecessários
   bool m_width_data_dirty;   // Flag indicando se dados precisam ser recalculados
   double m_cached_percentile; // Percentil em cache para performance
   double m_cached_zscore;    // Z-score em cache
   int m_cached_lookback;     // Lookback em cache

  bool CreateHandle();       // Cria o handle do indicador técnico
  void ReleaseHandle();      // Libera o handle do indicador
  double GetBufferValue(int buffer_index, int shift = 0); // Obtém valor de buffer específico
  void CalculateWidths();    // Calcula larguras das bandas para todos os candles
  static double CalculateWidthZScore(const double &width_array[], int length, int lookback); // Calcula Z-score da largura
  static double CalculateWidthPercentile(const double &width_array[], int length, int lookback); // Calcula percentil da largura
  ENUM_WIDTH_REGION ClassifyWidthRegion(double percentile); // Classifica região baseada no percentil
  static ENUM_MARKET_PHASE MapRegionToPhase(ENUM_WIDTH_REGION region); // Mapeia região para fase de mercado
  SSlopeResult CalculateWidthSlopeLinearRegression(double atr, int lookback); // Inclinação por regressão linear
  SSlopeResult CalculateWidthSlopeSimpleDifference(double atr, int lookback); // Inclinação por diferença simples
  SSlopeResult CalculateWidthSlopeDiscreteDerivative(double atr, int lookback); // Inclinação por derivada discreta
  static ENUM_SLOPE_STATE ClassifySlopeState(double slope_value); // Classifica estado da inclinação
  static ENUM_CHANNEL_DIRECTION ClassifyChannelDirection(double upper_slope, double middle_slope, double lower_slope); // Classifica direção coletiva do canal
  virtual bool OnCopyValuesForSlope(int shift, int count, double &buffer[], COPY_METHOD copy_method) override; // Método virtual para cópia de valores

  // Métodos aprimorados para detecção de squeeze
  bool DetectAdvancedSqueeze(); // Detecção avançada de squeeze
  static double CalculateWidthChangeRate(const double &width_array[], int length, int periods); // Taxa de mudança da largura

  // Novos métodos auxiliares para computação aprimorada de sinais
  double CalculatePositionStrength(); // Calcula força da posição do preço
  double GetBandConvergence(); // Obtém fator de convergência das bandas
  double CalculateDirectWidthSlope(int lookback); // Calcula inclinação direta da largura (fallback)
  bool DetectSqueeze(); // Detecta condições de squeeze
  double CalculateWeightedDirectionConsensus(const SSlopeValidation &upper, const SSlopeValidation &middle, const SSlopeValidation &lower); // Consenso específico: BULL(resistência↑+tendência↑), BEAR(suporte↓+tendência↓)
  double CalculateIntegratedConfidence(double direction_score, double slope_strength, double width_modifier, double position_strength, double convergence_factor, bool is_squeeze); // Confiança integrada
  string BuildEnhancedReason(int up_count, int down_count, int neutral_count, ENUM_WIDTH_REGION region, ENUM_SLOPE_STATE slope_state, double position_strength, double convergence_factor, bool is_squeeze, double width_slope_value, ENUM_CHANNEL_DIRECTION channel_direction); // Constrói razão aprimorada

  // Novos métodos auxiliares para refinamento de parâmetros
  void ValidateAndCorrectParameters(); // Valida e corrige parâmetros
  void AdaptParametersToMarket(double atr); // Adapta parâmetros ao mercado atual
  void LoadPresetForSymbol(string symbol); // Carrega predefinições para símbolo específico

  // Novos métodos auxiliares para otimização do cálculo de largura
  bool IsWidthDataValid();   // Verifica se dados de largura são válidos
  int GetOptimalLookback();  // Obtém lookback ótimo
  void CacheWidthStats();    // Armazena estatísticas em cache

  // Novo método auxiliar para calibração de timeframe WIN$N
  void CalibrateForWinIndex(ENUM_TIMEFRAMES timeframe); // Calibra para índice WIN$N

public:
 SCombinedSignal ComputeCombinedSignal(double atr, int lookback = -1); // Computa sinal combinado aprimorado
   virtual double OnGetIndicatorValue(int shift, COPY_METHOD copy_method) override; // Método virtual para obter valor do indicador
   virtual int OnGetSlopeConfigIndex(COPY_METHOD copy_method) override; // Método virtual para índice de configuração de inclinação

public:
   CBollinger();              // Construtor da classe
   ~CBollinger();             // Destrutor da classe

   bool Init(string symbol, ENUM_TIMEFRAMES timeframe, // Inicialização completa com todos os parâmetros
             int period, int shift, double deviation,
             ENUM_APPLIED_PRICE price);

   bool Init(string symbol, ENUM_TIMEFRAMES timeframe, // Inicialização com configuração estruturada
             CBollingerConfig &config);

   // Compatibilidade com interface base - usa padrões para method
   virtual bool Init(string symbol, ENUM_TIMEFRAMES timeframe,
                     int period, ENUM_MA_METHOD method);

   virtual double GetValue(int shift = 0); // Banda média (linha central)
   double GetUpper(int shift = 0);         // Banda superior
   double GetLower(int shift = 0);         // Banda inferior
   double GetNormalizedWidth(double atr, int shift = 0); // Largura normalizada pelo ATR

   virtual bool CopyValues(int shift, int count, double &buffer[]); // Copia valores da banda média
   bool CopyUpper(int shift, int count, double &buffer[]);          // Copia valores da banda superior
   bool CopyLower(int shift, int count, double &buffer[]);          // Copia valores da banda inferior

   virtual bool IsReady();    // Verifica se o indicador está pronto
   virtual bool Update() override; // Atualiza o indicador (recarrega handle se necessário)

   // Define parâmetros configuráveis - permite personalização avançada
   void SetConfigurableParameters(int width_history, int width_lookback, int slope_lookback,
                                  int &percentile_thresholds[], double &weights[]);
};

//+------------------------------------------------------------------+
//| Construtor - Inicializa a classe com valores padrão             |
//+------------------------------------------------------------------+
CBollinger::CBollinger()
{
   // Inicialização dos parâmetros básicos do indicador
   m_symbol = "";             // Símbolo será definido na inicialização
   m_timeframe = PERIOD_CURRENT; // Timeframe padrão
   m_period = 20;             // Período padrão das Bandas de Bollinger
   m_shift = 0;               // Sem deslocamento
   m_deviation = 2.0;         // Desvio padrão padrão
   m_price = PRICE_CLOSE;     // Usa preço de fechamento
   handle = INVALID_HANDLE;   // Handle ainda não criado

   // Inicializa ratio para threshold adaptativo baseado no ATR passado como parâmetro
   m_adaptive_threshold_ratio = 0.12; // 12% do ATR para threshold adaptativo

   // Inicializa parâmetros configuráveis com valores padrão
   m_width_history = WIDTH_HISTORY;
   m_width_lookback = WIDTH_LOOKBACK;
   m_slope_lookback = SLOPE_LOOKBACK;
   m_percentile_thresholds[0] = PERCENTILE_THRESHOLD_VERY_NARROW;
   m_percentile_thresholds[1] = PERCENTILE_THRESHOLD_NARROW;
   m_percentile_thresholds[2] = PERCENTILE_THRESHOLD_NORMAL;
   m_percentile_thresholds[3] = PERCENTILE_THRESHOLD_WIDE;
   m_weights[0] = WEIGHT_BAND;    // Peso para análise das bandas
   m_weights[1] = WEIGHT_SLOPE;   // Peso para análise da inclinação
   m_weights[2] = WEIGHT_WIDTH;   // Peso para análise da largura

   // Inicializa cache de cálculo de largura para otimização
   m_width_data_dirty = true;     // Dados precisam ser calculados
   m_cached_percentile = 0.0;     // Cache vazio
   m_cached_zscore = 0.0;         // Cache vazio
   m_cached_lookback = 0;         // Cache vazio

   // Redimensiona array para armazenar histórico de larguras
   ArrayResize(width_array, m_width_history);
}

//+------------------------------------------------------------------+
//| Destrutor - Libera recursos alocados                            |
//+------------------------------------------------------------------+
CBollinger::~CBollinger()
{
   // Libera o handle do indicador para evitar vazamentos de memória
   ReleaseHandle();
}

//+------------------------------------------------------------------+
//| Inicialização com parâmetros completos                          |
//+------------------------------------------------------------------+
bool CBollinger::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                       int period, int shift, double deviation,
                       ENUM_APPLIED_PRICE price)
{
    // Define todos os parâmetros do indicador
    m_symbol = symbol;        // Símbolo do ativo (ex: "WIN$N")
    m_timeframe = timeframe;  // Timeframe (ex: PERIOD_M3)
    m_period = period;        // Período da média móvel (ex: 20)
    m_shift = shift;          // Deslocamento das bandas (normalmente 0)
    m_deviation = deviation;  // Multiplicador do desvio padrão (ex: 2.0)
    m_price = price;          // Tipo de preço usado (ex: PRICE_CLOSE)

    // Calibração automática para símbolos WIN$N baseada no timeframe
    // WIN$N tem características específicas que exigem ajustes
    if (StringFind(m_symbol, "WIN") >= 0)
        CalibrateForWinIndex(m_timeframe);

    // Libera handle anterior se existir e cria novo
    ReleaseHandle();
    if (!CreateHandle())
        return false;

    // Dados de largura serão calculados na primeira chamada de Update() ou quando necessário
    // Isso evita o warning inicial quando BarsCalculated ainda é 0
    m_width_data_dirty = true;

    return true;
}

//+------------------------------------------------------------------+
//| Implementação da interface base (usa padrões)                    |
//+------------------------------------------------------------------+
bool CBollinger::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                       int period, ENUM_MA_METHOD method)
{
   // Parâmetro method não é usado; usa deslocamento 0, desvio 2.0, PRICE_CLOSE
   // Esta sobrecarga permite compatibilidade com a interface base CIndicatorBase
   return Init(symbol, timeframe, period, 0, 2.0, PRICE_CLOSE);
}

//+------------------------------------------------------------------+
//| Inicialização com configuração estruturada                       |
//+------------------------------------------------------------------+
bool CBollinger::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                       CBollingerConfig &config)
{
    // Copia configurações específicas da estrutura config
    attach_chart = config.attach_chart;           // Se deve anexar ao gráfico
    ArrayCopy(slope_values, config.slope_values); // Valores de inclinação

    // Define parâmetros configuráveis a partir da configuração
    m_width_history = config.width_history;       // Histórico para largura
    m_width_lookback = config.width_lookback;     // Lookback para largura
    m_slope_lookback = config.slope_lookback;     // Lookback para inclinação
    ArrayCopy(m_percentile_thresholds, config.percentile_thresholds); // Limites percentuais
    ArrayCopy(m_weights, config.weights);         // Pesos para cálculo

    // Valida parâmetros e aplica predefinições específicas do símbolo
    ValidateAndCorrectParameters();  // Garante que parâmetros estão dentro dos limites
    LoadPresetForSymbol(symbol);     // Carrega ajustes específicos para WIN$N, etc.

    // Chama inicialização completa com parâmetros da configuração
    return Init(symbol, timeframe, config.period, config.shift,
                config.deviation, config.applied_price);
}

//+------------------------------------------------------------------+
//| Cria o handle do indicador técnico                              |
//+------------------------------------------------------------------+
bool CBollinger::CreateHandle()
{
    // Cria handle para o indicador Bands (Bandas de Bollinger)
    // Parâmetros: símbolo, timeframe, período, deslocamento, desvio, tipo de preço
    handle = iBands(m_symbol, m_timeframe, m_period, m_shift, m_deviation, m_price);
    if (handle == INVALID_HANDLE)
    {
      // Erro crítico: não foi possível criar o indicador
      //Print("ERRO: Falha ao criar handle Bollinger para ", m_symbol);
      return false;
    }

    return true; // Handle criado com sucesso
}

//+------------------------------------------------------------------+
//| Libera o handle do indicador                                    |
//+------------------------------------------------------------------+
void CBollinger::ReleaseHandle()
{
    // Verifica se existe um handle válido antes de liberar
    if (handle != INVALID_HANDLE)
    {
      // Libera recursos do indicador no MetaTrader
      IndicatorRelease(handle);
      handle = INVALID_HANDLE; // Marca como inválido
    }

}

//+------------------------------------------------------------------+
//| Obtém valor de um buffer específico do indicador                |
//+------------------------------------------------------------------+
double CBollinger::GetBufferValue(int buffer_index, int shift)
{
   // Verifica se o handle é válido antes de acessar
   if (handle == INVALID_HANDLE)
     return 0.0; // Retorna valor neutro se inválido

   double buf[];              // Array temporário para receber dados
   ArraySetAsSeries(buf, true); // Define como série (índice 0 = mais recente)
   if (CopyBuffer(handle, buffer_index, shift, 1, buf) <= 0)
     return 0.0; // Falha na cópia retorna valor neutro
   return buf[0]; // Retorna o valor mais recente
}

//+------------------------------------------------------------------+
//| Banda média (buffer 2) - Linha central das Bandas de Bollinger |
//+------------------------------------------------------------------+
double CBollinger::GetValue(int shift)
{
   // BASE_LINE = 2 (constante definida em bollinger_defs.mqh)
   return GetBufferValue(BASE_LINE, shift);
}

//+------------------------------------------------------------------+
//| Banda superior (buffer 0) - Resistência dinâmica               |
//+------------------------------------------------------------------+
double CBollinger::GetUpper(int shift)
{
   // UPPER_BAND = 0 (constante definida em bollinger_defs.mqh)
   return GetBufferValue(UPPER_BAND, shift);
}

//+------------------------------------------------------------------+
//| Banda inferior (buffer 1) - Suporte dinâmico                   |
//+------------------------------------------------------------------+
double CBollinger::GetLower(int shift)
{
    // LOWER_BAND = 1 (constante definida em bollinger_defs.mqh)
    return GetBufferValue(LOWER_BAND, shift);
}

//+------------------------------------------------------------------+
//| Largura normalizada pelo ATR - Medida relativa de volatilidade  |
//+------------------------------------------------------------------+
double CBollinger::GetNormalizedWidth(double atr, int shift)
{
    double width = GetUpper(shift) - GetLower(shift);
    return (atr > 0) ? width / atr : 0.0;
}

//+------------------------------------------------------------------+
//| Copia valores da banda média (múltiplos candles)                |
//+------------------------------------------------------------------+
bool CBollinger::CopyValues(int shift, int count, double &buffer[])
{
   // Verifica validade do handle
   if (handle == INVALID_HANDLE)
     return false;

   // Redimensiona o array de destino para o número solicitado de valores
   ArrayResize(buffer, count);
   ArraySetAsSeries(buffer, true); // Define como série temporal
   return CopyBuffer(handle, BASE_LINE, shift, count, buffer) > 0;
}

//+------------------------------------------------------------------+
//| Copia valores da banda superior (múltiplos candles)             |
//+------------------------------------------------------------------+
bool CBollinger::CopyUpper(int shift, int count, double &buffer[])
{
   // Buffers: 0=UPPER_BAND, 1=LOWER_BAND, 2=BASE_LINE
   if (handle == INVALID_HANDLE)
     return false;
   ArrayResize(buffer, count);
   ArraySetAsSeries(buffer, true);
   return CopyBuffer(handle, UPPER_BAND, shift, count, buffer) > 0;
}

//+------------------------------------------------------------------+
//| Copia valores da banda inferior (múltiplos candles)             |
//+------------------------------------------------------------------+
bool CBollinger::CopyLower(int shift, int count, double &buffer[])
{
   if (handle == INVALID_HANDLE)
     return false;
   ArrayResize(buffer, count);
   ArraySetAsSeries(buffer, true);
   return CopyBuffer(handle, LOWER_BAND, shift, count, buffer) > 0;
}

//+------------------------------------------------------------------+
//| Verifica se o indicador está pronto para uso                     |
//+------------------------------------------------------------------+
bool CBollinger::IsReady()
{
     // Verifica se o indicador calculou pelo menos o período necessário para cálculos básicos
     // Para WIN$N, requer pelo menos o período das bandas + algum buffer
     int min_bars = MathMax(m_period + 5, 20); // Pelo menos período + 5 ou 20 candles mínimo
     return (BarsCalculated(handle) >= min_bars);
}

//+------------------------------------------------------------------+
//| Recria handle se necessário e atualiza cálculos                 |
//+------------------------------------------------------------------+
bool CBollinger::Update()
{
    // Se handle não existe, tenta criar
    if (handle == INVALID_HANDLE)
       return CreateHandle();

    // Verifica se há dados calculados
    if (BarsCalculated(handle) <= 0)
       return false;

    // Marca dados de largura como "sujos" para recálculo com novas barras
    // Isso força o recálculo das estatísticas quando novos dados chegam
    m_width_data_dirty = true;
    CalculateWidths(); // Recalcula larguras das bandas
    return true;
}

//+------------------------------------------------------------------+
//| Implementação do método virtual para copiar valores para cálculo de inclinação |
//+------------------------------------------------------------------+
bool CBollinger::OnCopyValuesForSlope(int shift, int count, double &buffer[], COPY_METHOD copy_method)
{
   // Verifica se handle é válido
   if (handle == INVALID_HANDLE)
     return false;

     //Print("METODO DE COPIA: " + EnumToString(copy_method));

   // Seleciona qual banda copiar baseado no método solicitado
   switch (copy_method)
   {
     case COPY_LOWER:
       //Print("COPIANDO - LOWER");
       return CopyLower(shift, count, buffer); // Copia banda inferior

     case COPY_UPPER:
       //Print("COPIANDO - UPPER");
       return CopyUpper(shift, count, buffer); // Copia banda superior

     case COPY_MIDDLE:
       //Print("COPIANDO - MIDDLE");
       return CopyValues(shift, count, buffer); // Copia banda média

     default:
       //Print("ERRO: Método de cópia inválido");
       return false; // Método não suportado
   }
};

//+------------------------------------------------------------------+
//| Implementação do método virtual para obter valor do indicador   |
//+------------------------------------------------------------------+
double CBollinger::OnGetIndicatorValue(int shift, COPY_METHOD copy_method)
{
   //Print("OnGetIndicatorValue bollinger class: " + EnumToString(copy_method));
   //Print("OnGetIndicatorValue bollinger class: " + (string)(copy_method));

   // Retorna valor da banda solicitada para o cálculo de inclinação
   if (copy_method == COPY_LOWER)
   {
     return GetLower(shift); // Valor da banda inferior
   }
   else if (copy_method == COPY_UPPER)
   {
     return GetUpper(shift); // Valor da banda superior
   }
   else
   {
     return GetValue(shift); // Valor da banda média (padrão)
   }
}

//+------------------------------------------------------------------+
//| Retorna índice de configuração de inclinação baseado na banda   |
//+------------------------------------------------------------------+
int CBollinger::OnGetSlopeConfigIndex(COPY_METHOD copy_method)
{
   // Cada banda tem um índice diferente no array de configurações de inclinação
   if (copy_method == COPY_MIDDLE)
   {
     //Print("RETORNANDO MIDDLE");
     return 1; // Índice 1 para banda média
   }
   else if (copy_method == COPY_UPPER)
   {
         //Print("RETORNANDO UPPER");
     return 0; // Índice 0 para banda superior
   }
   else if (copy_method == COPY_LOWER)
   {
         //Print("RETORNANDO LOWER");
     return 2; // Índice 2 para banda inferior
   }

   return 1; // Padrão = banda média
}

//+------------------------------------------------------------------+
//| Calcula largura das bandas para cada candle                     |
//| Largura = Banda Superior - Banda Inferior                       |
//+------------------------------------------------------------------+
void CBollinger::CalculateWidths()
{
     // VALIDAÇÃO: Verifica se indicador está pronto antes de calcular
     if (!IsReady())
     {
        Print("AVISO: Indicador Bollinger não está pronto - pulando cálculo de larguras");
        return;
     }

     // Otimização: pula recálculo se dados estão atualizados
     if (!m_width_data_dirty) return;

     // Redimensiona array para armazenar histórico de larguras
     ArrayResize(width_array, m_width_history);

     int valid_calculations = 0;

     // Calcula largura para cada candle no histórico
     for(int i = 0; i < m_width_history; i++)
     {
        double upper = GetUpper(i);    // Banda superior do candle i
        double lower = GetLower(i);    // Banda inferior do candle i

        // VALIDAÇÕES ADICIONAIS: Verificações rigorosas de validade
        if (!MathIsValidNumber(upper) || !MathIsValidNumber(lower))
        {
           Print("ERRO: Valores inválidos em candle ", i, " - upper: ", upper, " lower: ", lower);
           width_array[i] = 0.0;
           continue;
        }

        if (upper <= lower)
        {
           Print("ERRO: Banda superior <= inferior em candle ", i, " - upper: ", upper, " lower: ", lower);
           width_array[i] = 0.0;
           continue;
        }

        // Largura válida - calcula diferença
        width_array[i] = upper - lower;
        valid_calculations++;
     }

     Print("DEBUG: CalculateWidths completado - ", valid_calculations, "/", m_width_history, " cálculos válidos");

     // Marca dados como atualizados e atualiza cache de estatísticas
     m_width_data_dirty = false;
     CacheWidthStats(); // Calcula percentil e z-score para otimização
}

//+------------------------------------------------------------------+
//| Calcula Z-score da largura mais recente                          |
//|                                                                  |
//| CONCEITO ESTATÍSTICO: O Z-score mede o afastamento de um valor  |
//| em relação à distribuição normal da população.                  |
//|                                                                  |
//| FÓRMULA MATEMÁTICA: Z-score = (valor_atual - média) / desvio_padrão |
//| LÓGICA: Mede quantos desvios padrão o valor atual está da média histórica |
//| INTERPRETAÇÃO: Z > 0 = acima da média, Z < 0 = abaixo da média |
//| EXEMPLO: Z = 2.0 significa valor 2 desvios acima da média (evento raro) |
//|                                                                  |
//| UTILIZAÇÃO: Detecta se a volatilidade atual é anormalmente alta/baixa |
double CBollinger::CalculateWidthZScore(const double &width_array[], int length, int lookback)
{
   // VALIDAÇÃO: Z-score precisa de pelo menos 1 valor, mas estatisticamente 2+ é melhor
   if (length < 1 || lookback < 1) return 0.0; // Retorna neutro se dados insuficientes

   int actual_lookback = MathMin(lookback, length); // Limita ao tamanho disponível

   // CÁLCULO DA MÉDIA ARITMÉTICA: Soma todos os valores e divide por quantidade
   // FÓRMULA: média = Σ(valores) / n
   double sum = 0.0;
   for(int i = 0; i < actual_lookback; i++)
     sum += width_array[i];
   double mean = sum / actual_lookback;

   // CÁLCULO DA VARIÂNCIA: Mede dispersão dos dados em torno da média
   // FÓRMULA: variância = Σ(diferenças_ao_quadrado) / n
   // ONDE: diferença = valor - média
   double sum_sq = 0.0;
   for(int i = 0; i < actual_lookback; i++)
   {
     double diff = width_array[i] - mean;     // Diferença em relação à média
     sum_sq += diff * diff;                    // Soma dos quadrados das diferenças
   }
   double variance = sum_sq / actual_lookback; // Variância populacional

   // DESVIO PADRÃO: Raiz quadrada da variância (mede volatilidade)
   // FÓRMULA: σ = √(variância)
   double std = MathSqrt(variance);

   // PREVENÇÃO DE DIVISÃO POR ZERO: Se todos os valores são iguais
   if (std == 0.0) return 0.0; // Z-score = 0 (valor na média)

   // CÁLCULO FINAL DO Z-SCORE
   double current = width_array[0]; // Valor mais recente
   return (current - mean) / std;   // Normalização: quantos σ o valor está da média
}

//+------------------------------------------------------------------+
//| Calcula percentil da largura mais recente (com ordenação aprimorada) |
//|                                                                  |
//| CONCEITO ESTATÍSTICO: O percentil indica a posição relativa de um |
//| valor dentro da distribuição ordenada da população.             |
//|                                                                  |
//| FÓRMULA MATEMÁTICA: Percentil = [posição_ordenada / (n-1)] × 100 |
//| LÓGICA: Ordena histórico de larguras e encontra posição relativa do valor atual |
//| INTERPOLAÇÃO: Para valores entre posições, usa interpolação linear |
//| EXEMPLO: Se valor atual é 3º em array de 10 elementos → percentil = (3/9)×100 = 33.33% |
//|                                                                  |
//| UTILIZAÇÃO: Classifica se a volatilidade está em níveis extremos |
double CBollinger::CalculateWidthPercentile(const double &width_array[], int length, int lookback)
{
    // VALIDAÇÃO ESTATÍSTICA: Percentil precisa de mínimo 2 valores para distribuição válida
    if (length < 2 || lookback < 2) return 50.0; // Retorna mediana (50%) como valor padrão

    int actual_lookback = MathMin(lookback, length); // Garante não ultrapassar tamanho do array
    if (actual_lookback < 2) return 50.0;

    // CRIAÇÃO DE CÓPIA ORDENADA: Preserva array original para outros cálculos
    // Array ordenado necessário para cálculo preciso de percentil
    double sorted[];
    ArrayResize(sorted, actual_lookback);
    ArrayCopy(sorted, width_array, 0, 0, actual_lookback);

    // ALGORITMO DE ORDENAÇÃO: Bubble Sort O(n²) - aceitável para arrays pequenos (< 200 elementos)
    // ORDENAÇÃO CRESCENTE: Valores menores primeiro, maiores depois
    for(int i = 0; i < actual_lookback - 1; i++)
    {
       for(int j = i + 1; j < actual_lookback; j++)
       {
          if (sorted[i] > sorted[j])
          {
             // TROCA DE ELEMENTOS: Move valores maiores para posições posteriores
             double temp = sorted[i];
             sorted[i] = sorted[j];
             sorted[j] = temp;
          }
       }
    }

    double current = width_array[0]; // Valor mais recente (candle atual)

    // BUSCA SEQUENCIAL: Encontra posição do valor atual na distribuição ordenada
    // Complexidade O(n) mas array pequeno justifica abordagem simples
    int pos = 0;
    while (pos < actual_lookback && sorted[pos] < current) pos++;

    // TRATAMENTO DE CASOS EXTREMOS:
    if (pos == 0) return 0.0;                    // Valor menor que todos = percentil mínimo
    if (pos >= actual_lookback) return 100.0;    // Valor maior que todos = percentil máximo

    // CÁLCULO DE PERCENTIL COM INTERPOLAÇÃO:
    if (sorted[pos] == current)
    {
       // CORRESPONDÊNCIA EXATA: Cálculo direto da posição relativa
       // FÓRMULA: percentil = (posição_encontrada / total_posições) × 100
       // NOTA: Divide por (n-1) para normalização correta
       return (double)pos / (actual_lookback - 1) * 100.0;
    }
    else
    {
       // INTERPOLAÇÃO LINEAR: Valor entre duas posições ordenadas
       // FÓRMULA: percentil = [(posição - 1) + fração_interpolada] / (n-1) × 100
       // ONDE: fração = (valor_atual - valor_inferior) / (valor_superior - valor_inferior)
       double lower = sorted[pos-1];    // Valor na posição anterior
       double upper = sorted[pos];      // Valor na posição atual
       double fraction = (current - lower) / (upper - lower); // Fração linear entre posições
       return ((pos - 1 + fraction) / (actual_lookback - 1)) * 100.0;
    }
}

//+------------------------------------------------------------------+
//| Classifica região de largura baseada no percentil               |
//|                                                                  |
//| LÓGICA: Divide a volatilidade em regiões baseadas em percentis  |
//| Muito Estreita: Volatilidade muito baixa (< threshold[0]%)     |
//| Estreita: Volatilidade baixa (threshold[0]-threshold[1]%)      |
//| Normal: Volatilidade típica (threshold[1]-threshold[2]%)       |
//| Larga: Volatilidade alta (threshold[2]-threshold[3]%)          |
//| Muito Larga: Volatilidade muito alta (> threshold[3]%)         |
//+------------------------------------------------------------------+
ENUM_WIDTH_REGION CBollinger::ClassifyWidthRegion(double percentile)
{
   // Classificação baseada nos limites configuráveis de percentil
   if (percentile < m_percentile_thresholds[0]) return WIDTH_VERY_NARROW;
   if (percentile >= m_percentile_thresholds[0] && percentile < m_percentile_thresholds[1]) return WIDTH_NARROW;
   if (percentile >= m_percentile_thresholds[1] && percentile < m_percentile_thresholds[2]) return WIDTH_NORMAL;
   if (percentile >= m_percentile_thresholds[2] && percentile < m_percentile_thresholds[3]) return WIDTH_WIDE;
   return WIDTH_VERY_WIDE; // Acima do último threshold
}

//+------------------------------------------------------------------+
//| Calcula taxa de mudança da largura (usada para detecção de squeeze) |
//+------------------------------------------------------------------+
double CBollinger::CalculateWidthChangeRate(const double &width_array[], int length, int periods)
{
   if (length < periods + 1 || periods < 1) return 0.0;

   // Calcula mudança percentual sobre os últimos 'periods' candles
   double current = width_array[0];
   double past = width_array[periods];

   if (past <= 0.0) return 0.0;

   return (current - past) / past; // Taxa de mudança
}

//+------------------------------------------------------------------+
//| Mapeia região de largura para fase de mercado                    |
//|                                                                  |
//| CONTRACÇÃO: Bandas muito estreitas/estreitas = baixa volatilidade |
//| NORMAL: Bandas normais = volatilidade típica                    |
//| EXPANSÃO: Bandas largas/muito largas = alta volatilidade       |
//+------------------------------------------------------------------+
ENUM_MARKET_PHASE CBollinger::MapRegionToPhase(ENUM_WIDTH_REGION region)
{
   // Mapeamento direto baseado na largura das bandas
   if (region == WIDTH_VERY_NARROW || region == WIDTH_NARROW) return PHASE_CONTRACTION;
   if (region == WIDTH_NORMAL) return PHASE_NORMAL;
   return PHASE_EXPANSION; // WIDTH_WIDE ou WIDTH_VERY_WIDE
}

//+------------------------------------------------------------------+
//| Calcula inclinação da largura usando regressão linear           |
//|                                                                  |
//| MÉTODO: Ajusta uma linha reta aos dados de largura histórica    |
//| VANTAGEM: Considera toda a tendência, não apenas pontos extremos |
//| USO: Melhor para detectar tendências de longo prazo             |
//+------------------------------------------------------------------+
SSlopeResult CBollinger::CalculateWidthSlopeLinearRegression(double atr, int lookback)
{
    // Delegação para classe especializada em cálculos de inclinação
    SSlopeResult result = m_slope.CalculateLinearRegressionSlope(m_symbol, width_array, atr, lookback);

    // LOG DIAGNÓSTICO DETALHADO
    Print("=== SLOPE ANALYSIS ===");
    Print("Raw slope: ", DoubleToString(result.slope_value, 8));
    Print("ATR normalization: ", DoubleToString(atr, 2));
    Print("Lookback periods: ", lookback);
    Print("R-squared quality: ", DoubleToString(result.r_squared, 4));

    // Log mudança de largura percentual
    if (ArraySize(width_array) >= lookback && lookback > 0)
    {
       double current_width = width_array[0];
       double past_width = width_array[lookback-1];
       double width_change_pct = (past_width > 0) ? ((current_width - past_width) / past_width) * 100.0 : 0.0;

       Print("Width change: ", DoubleToString(current_width, 2), " → ", DoubleToString(past_width, 2));
       Print("Width change %: ", DoubleToString(width_change_pct, 2), "%");
    }

    return result;
}

//+------------------------------------------------------------------+
//| Calcula inclinação da largura usando diferença simples          |
//|                                                                  |
//| MÉTODO: Subtrai valor atual do valor passado (primeiro - último) |
//| VANTAGEM: Simples e rápido de calcular                          |
//| LIMITAÇÃO: Sensível a outliers e ruído                         |
//+------------------------------------------------------------------+
SSlopeResult CBollinger::CalculateWidthSlopeSimpleDifference(double atr, int lookback)
{
   return m_slope.CalculateSimpleDifference(m_symbol, width_array, atr, lookback);
}

//+------------------------------------------------------------------+
//| Calcula inclinação da largura usando derivada discreta          |
//|                                                                  |
//| MÉTODO: Calcula variação instantânea usando diferenças finitas  |
//| VANTAGEM: Boa resposta a mudanças rápidas                       |
//| USO: Ideal para detectar aceleração/desaceleração               |
//+------------------------------------------------------------------+
SSlopeResult CBollinger::CalculateWidthSlopeDiscreteDerivative(double atr, int lookback)
{
   return m_slope.CalculateDiscreteDerivative(m_symbol, width_array, atr, lookback);
}

//+------------------------------------------------------------------+
//| Calcula inclinação direta da largura (fallback)                  |
//+------------------------------------------------------------------+
double CBollinger::CalculateDirectWidthSlope(int lookback)
{
   if (ArraySize(width_array) < lookback || lookback < 2)
      return 0.0;

   double current = width_array[0];
   double past = width_array[lookback-1];

   if (past <= 0.0)
      return 0.0;

   // Retorna variação percentual simples
   return (current - past) / past;
}

//+------------------------------------------------------------------+
//| Classifica estado da inclinação baseado em threshold            |
//|                                                                  |
//| EXPANDINDO: Inclinação positiva ≥ threshold (volatilidade crescendo) |
//| CONTRAINDO: Inclinação negativa ≤ -threshold (volatilidade diminuindo) |
//| ESTÁVEL: Inclinação entre -threshold e +threshold             |
//+------------------------------------------------------------------+
ENUM_SLOPE_STATE CBollinger::ClassifySlopeState(double slope_value)
{
   const double NUMERICAL_PRECISION = 0.01;

   Print("=== SLOPE CLASSIFICATION ===");
   Print("Slope value: ", DoubleToString(slope_value, 10));
   Print("Abs(slope): ", DoubleToString(MathAbs(slope_value), 10));
   Print("Precision threshold: ", DoubleToString(NUMERICAL_PRECISION, 12));

   if (slope_value > NUMERICAL_PRECISION)
   {
      Print("→ Result: SLOPE_EXPANDING (bands widening)");
      return SLOPE_EXPANDING;
   }

   if (slope_value < -NUMERICAL_PRECISION)
   {
      Print("→ Result: SLOPE_CONTRACTING (bands narrowing)");
      return SLOPE_CONTRACTING;
   }

   Print("→ Result: SLOPE_STABLE (no significant change)");
   return SLOPE_STABLE;
}

//+------------------------------------------------------------------+
//| Classifica direção coletiva do canal das bandas                   |
//|                                                                  |
//| PROPÓSITO: Determinar se as três bandas estão formando um canal |
//| ascendente, descendente ou lateral coletivamente.               |
//|                                                                  |
//| LÓGICA: Verifica se todas as bandas têm inclinação na mesma     |
//| direção (todas positivas = ascendente, todas negativas =        |
//| descendente, mistas ou próximas de zero = lateral).             |
//|                                                                  |
//| RETORNO: CHANNEL_ASCENDING, CHANNEL_DESCENDING, ou CHANNEL_SIDEWAYS |
//+------------------------------------------------------------------+
ENUM_CHANNEL_DIRECTION CBollinger::ClassifyChannelDirection(double upper_slope, double middle_slope, double lower_slope)
{
   const double NUMERICAL_PRECISION = 1e-10;

   Print("=== CHANNEL DIRECTION CLASSIFICATION ===");
   Print("Upper slope: ", DoubleToString(upper_slope, 8));
   Print("Middle slope: ", DoubleToString(middle_slope, 8));
   Print("Lower slope: ", DoubleToString(lower_slope, 8));
   Print("Precision threshold: ", DoubleToString(NUMERICAL_PRECISION, 12));

   // Verifica se todas as bandas estão subindo (canal ascendente)
   bool all_ascending = (upper_slope > NUMERICAL_PRECISION) &&
                       (middle_slope > NUMERICAL_PRECISION) &&
                       (lower_slope > NUMERICAL_PRECISION);

   // Verifica se todas as bandas estão descendo (canal descendente)
   bool all_descending = (upper_slope < -NUMERICAL_PRECISION) &&
                        (middle_slope < -NUMERICAL_PRECISION) &&
                        (lower_slope < -NUMERICAL_PRECISION);

   Print("All ascending: ", all_ascending ? "TRUE" : "FALSE");
   Print("All descending: ", all_descending ? "TRUE" : "FALSE");

   if (all_ascending)
   {
      Print("→ Result: CHANNEL_ASCENDING (all bands sloping up)");
      return CHANNEL_ASCENDING;
   }
   else if (all_descending)
   {
      Print("→ Result: CHANNEL_DESCENDING (all bands sloping down)");
      return CHANNEL_DESCENDING;
   }
   else
   {
      Print("→ Result: CHANNEL_SIDEWAYS (bands not aligned or flat)");
      return CHANNEL_SIDEWAYS;
   }
}

//+------------------------------------------------------------------+
//| ComputeCombinedSignal - Cálculo Aprimorado de Sinal Combinado   |
//|                                                                  |
//| PROPÓSITO: Determinar direção (BULL/BEAR/NEUTRAL) com confiança |
//| baseado em múltiplas análises técnicas das Bandas de Bollinger. |
//|                                                                  |
//| MELHORIAS IMPLEMENTADAS:                                         |
//| - Análise ponderada das três bandas (superior/média/inferior)   |
//| - Cálculo de confiança baseado em múltiplos fatores técnicos    |
//| - Detecção de squeeze (contração) e expansão das bandas         |
//| - Sistema de consenso para reduzir falsos sinais                |
//|                                                                  |
//| RESULTADO: Sinal com direção, confiança e explicação detalhada  |
//+------------------------------------------------------------------+
SCombinedSignal CBollinger::ComputeCombinedSignal(double atr, int lookback = -1)
{
   SCombinedSignal signal;
   signal.confidence = 0.0;
   signal.direction = "NEUTRAL";
   signal.reason = "";
   signal.region = WIDTH_NORMAL;
   signal.slope_state = SLOPE_STABLE;
   signal.width_slope_value = 0.0;
   signal.channel_direction = CHANNEL_SIDEWAYS;

  int actual_lookback = (lookback == -1) ? m_slope_lookback : lookback;

  // === ANÁLISE DAS BANDAS INDIVIDUAIS ===
  // Explicação: Cada banda (superior, média, inferior) tem uma inclinação
  // que indica a tendência local. Analisamos as três separadamente para
  // obter um quadro completo da movimentação do mercado.

  SSlopeValidation upper_val = GetSlopeValidation(atr, COPY_UPPER);
  // Obtém validação da inclinação da banda superior (resistência dinâmica)
  // COPY_UPPER = constante que especifica qual buffer copiar (banda superior)

  SSlopeValidation middle_val = GetSlopeValidation(atr, COPY_MIDDLE);
  // Banda média (linha central) - tendência de médio prazo

  SSlopeValidation lower_val = GetSlopeValidation(atr, COPY_LOWER);
  // Banda inferior - nível de suporte dinâmico

  // === CLASSIFICAÇÃO DA DIREÇÃO COLETIVA DO CANAL ===
  signal.channel_direction = ClassifyChannelDirection(upper_val.linear_regression.slope_value,
                                                     middle_val.linear_regression.slope_value,
                                                     lower_val.linear_regression.slope_value);

  // === SISTEMA DE CONSENSO PONDERADO ===
  // Explicação: Substituímos a contagem simples (alta/baixa) por um sistema
  // de consenso que considera a força relativa de cada banda.
  // Banda superior tem mais peso (resistência), inferior tem menos (suporte)

  double direction_score = CalculateWeightedDirectionConsensus(upper_val, middle_val, lower_val);
  // Calcula score de 0-1 baseado na força e direção das inclinações
  // 0.6+ = BULL (alta), 0.4- = BEAR (baixa), meio = NEUTRAL (neutro)

  // === DETERMINAÇÃO DA DIREÇÃO ===
  // Explicação: A direção final é determinada pelo consenso das bandas
  // Thresholds ajustados para maior sensibilidade na detecção de tendências

  if (direction_score > 0.55) signal.direction = "BULL";
  else if (direction_score < 0.45) signal.direction = "BEAR";
  else signal.direction = "NEUTRAL";

  // Conta bandas para string de razão (alta, baixa, neutra)
  int up_count = 0, down_count = 0, neutral_count = 0;

  if (upper_val.linear_regression.slope_value > 0) up_count++;
  else if (upper_val.linear_regression.slope_value < 0) down_count++;
  else neutral_count++;

  if (middle_val.linear_regression.slope_value > 0) up_count++;
  else if (middle_val.linear_regression.slope_value < 0) down_count++;
  else neutral_count++;

  if (lower_val.linear_regression.slope_value > 0) up_count++;
  else if (lower_val.linear_regression.slope_value < 0) down_count++;
  else neutral_count++;

  // Garante que os dados de largura estão calculados antes de usar
  if (m_width_data_dirty || ArraySize(width_array) == 0)
      CalculateWidths();

  // Obtém percentil e região da largura
  double percentile = CalculateWidthPercentile(width_array, ArraySize(width_array), m_width_lookback);
  signal.region = ClassifyWidthRegion(percentile);

  // Modificador de largura - bônus para regiões extremas
  double width_modifier = 0.0;
  if (signal.region == WIDTH_VERY_NARROW || signal.region == WIDTH_VERY_WIDE)
    width_modifier = 0.25; // +25% de confiança para extremos

  // Obtém inclinação da largura
  SSlopeResult width_slope = CalculateWidthSlopeLinearRegression(atr, actual_lookback);

  // FALLBACK: Se slope muito pequeno, usar cálculo direto
  if (MathAbs(width_slope.slope_value) < 1e-12)
  {
     Print("WARNING: Slope muito pequeno, usando cálculo direto");
     double direct_slope = CalculateDirectWidthSlope(actual_lookback);
     width_slope.slope_value = direct_slope;
     Print("Direct slope: ", DoubleToString(direct_slope, 8));
  }

  // Armazena o valor da inclinação da largura no sinal
  signal.width_slope_value = width_slope.slope_value;

  signal.slope_state = ClassifySlopeState(width_slope.slope_value);

  // Força da inclinação (normalizada, limitada a 1.0)
  double slope_strength = MathMin(1.0, MathAbs(width_slope.slope_value));

  // Fator R-quadrado (qualidade do ajuste da regressão)
  double r_squared_factor = width_slope.r_squared;

  // Calcula fatores adicionais para análise aprimorada
  double position_strength = CalculatePositionStrength();    // Força da posição do preço
  double convergence_factor = GetBandConvergence();       // Fator de convergência das bandas
  bool is_squeeze = DetectSqueeze();                          // Detecta squeeze (contração extrema)

  // Calcula confiança integrada combinando todos os fatores
  signal.confidence = CalculateIntegratedConfidence(direction_score, slope_strength * r_squared_factor,
                                                    width_modifier, position_strength,
                                                    convergence_factor, is_squeeze);

  // Constrói razão aprimorada com todos os fatores analisados
  signal.reason = BuildEnhancedReason(up_count, down_count, neutral_count,
                                      signal.region, signal.slope_state,
                                      position_strength, convergence_factor, is_squeeze,
                                      signal.width_slope_value, signal.channel_direction);

  Print("=== SIGNAL SUMMARY ===");
  Print("Width region: ", EnumToString(signal.region));
  Print("Slope state: ", EnumToString(signal.slope_state));
  Print("Width slope: ", DoubleToString(signal.width_slope_value, 8));
  Print("Channel direction: ", EnumToString(signal.channel_direction));
  Print("Direction: ", signal.direction);
  Print("Confidence: ", DoubleToString(signal.confidence, 3));
  Print("=====================");

  return signal;
}

//+------------------------------------------------------------------+
//| SetConfigurableParameters - Define Parâmetros Configuráveis     |
//|                                                                  |
//| PROPÓSITO: Permitir personalização avançada do indicador através |
//| de parâmetros externos, adaptando seu comportamento a diferentes |
//| condições de mercado e estratégias.                             |
//|                                                                  |
//| PARÂMETROS:                                                      |
//| - width_history: Histórico para análise de largura              |
//| - width_lookback: Período para cálculos estatísticos            |
//| - slope_lookback: Período para análise de inclinação            |
//| - percentile_thresholds: Limites para classificação de regiões  |
//| - weights: Pesos para combinação de fatores                     |
//|                                                                  |
//| VALIDAÇÃO: Todos os parâmetros são verificados e corrigidos     |
//| automaticamente para garantir estabilidade.                     |
//+------------------------------------------------------------------+
void CBollinger::SetConfigurableParameters(int width_history, int width_lookback, int slope_lookback,
                                          int &percentile_thresholds[], double &weights[])
{
  m_width_history = width_history > 0 ? width_history : WIDTH_HISTORY;
  m_width_lookback = width_lookback > 0 ? width_lookback : WIDTH_LOOKBACK;
  m_slope_lookback = slope_lookback > 0 ? slope_lookback : SLOPE_LOOKBACK;

  if (ArraySize(percentile_thresholds) >= 4)
  {
    for(int i = 0; i < 4; i++)
      m_percentile_thresholds[i] = percentile_thresholds[i];
  }

  if (ArraySize(weights) >= 3)
  {
    for(int i = 0; i < 3; i++)
      m_weights[i] = weights[i];
  }

  // Valida e corrige parâmetros automaticamente
  ValidateAndCorrectParameters();

  // Carrega predefinições específicas do símbolo
  LoadPresetForSymbol(m_symbol);

  // Nota: Adaptação de mercado com ATR é realizada em Update() quando ATR estiver disponível

  // Redimensiona array de largura se necessário
  if (ArraySize(width_array) != m_width_history)
  {
    ArrayResize(width_array, m_width_history);
    m_width_data_dirty = true; // Marca para recálculo
  }
}

//+------------------------------------------------------------------+
//| CalculatePositionStrength - Força da Posição do Preço           |
//|                                                                  |
//| PROPÓSITO: Medir quão forte é a posição atual do preço          |
//| nas Bandas de Bollinger, indicando proximidade de suportes/     |
//| resistências dinâmicas.                                         |
//|                                                                  |
//| RETORNO: Valor entre 0.0-1.0 (0=fraco, 1=forte)                |
//| USO: Componente para cálculo de confiança do sinal              |
//|                                                                 |
//| INTERPRETAÇÃO: Valores próximos de 1.0 indicam preço em         |
//| regiões de alta probabilidade de reversão.                      |
//+------------------------------------------------------------------+
double CBollinger::CalculatePositionStrength()
{
   /*
    * LÓGICA DE CÁLCULO:
    * ----------------
    * A força da posição é determinada pela proximidade do preço
    * às bandas e pela consistência da direção das bandas.
    *
    * Fatores considerados:
    * 1. Distância relativa do preço às bandas
    * 2. Alinhamento das inclinações das bandas
    * 3. Volatilidade atual vs histórica
    */

   double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   // Preço atual do ativo para análise de posicionamento

   double middle = GetValue(0);   // Banda média (linha central)
   double upper = GetUpper(0);    // Banda superior (resistência)
   double lower = GetLower(0);    // Banda inferior (suporte)
   double width = upper - lower;  // Largura total das bandas

   // Verificação de segurança para evitar divisão por zero
   if (width <= 0.0)
      return 0.0;   // Largura inválida = força zero

   // Calcular posição relativa (0% = banda inferior, 100% = banda superior)
   double position_pct = (price - lower) / width * 100.0;

   /*
    * INTERPRETAÇÃO DA POSIÇÃO:
    * -------------------------
    * 0-25%: Preço próximo à banda inferior (possível zona de compra)
    * 25-75%: Posição intermediária (normal)
    * 75-100%: Preço próximo à banda superior (possível zona de venda)
    *
    * Para WIN$N especificamente:
    * - Valores abaixo de 20% podem indicar oversold
    * - Valores acima de 80% podem indicar overbought
    */

   return MathMin(1.0, position_pct / 100.0);
}

//+------------------------------------------------------------------+
//| GetBandConvergence - Calcula Fator de Convergência das Bandas   |
//|                                                                  |
//| PROPÓSITO: Medir o grau de contração das bandas em relação à    |
//| volatilidade histórica, detectando condições de "squeeze".      |
//|                                                                  |
//| LÓGICA: Quanto menor a largura atual vs histórica, maior o      |
//| fator de convergência (0-1), indicando potencial explosão.      |
//|                                                                  |
//| USO: Aumenta confiança do sinal quando bandas estão contraídas. |
//+------------------------------------------------------------------+
double CBollinger::GetBandConvergence()
{
    // Garante que os dados de largura estão calculados
    if (m_width_data_dirty || ArraySize(width_array) == 0)
        CalculateWidths();

    double current_width = GetUpper(0) - GetLower(0);

    // DEBUG: Logs diagnósticos para análise de convergência
    Print("DEBUG Conv - current_width: ", current_width,
          " array_size: ", ArraySize(width_array),
          " width_data_dirty: ", m_width_data_dirty);

   // VALIDAÇÃO: Verificações de segurança adicionais
   if (ArraySize(width_array) == 0)
   {
      Print("ERRO: width_array vazio - impossibilitando cálculo de convergência");
      return 0.0;
   }


   if (current_width <= 0.0)
   {
      Print("ERRO: Largura atual inválida (<= 0.0) - bandas não calculadas corretamente");
      return 0.0;
   }

   // Calcula largura média do histórico
   double avg_width = 0.0;
   int valid_count = 0;
   for(int i = 0; i < ArraySize(width_array); i++)
   {
      if (width_array[i] > 0.0)  // Só conta valores válidos
      {
         avg_width += width_array[i];
         valid_count++;
      }
   }

   if (valid_count == 0)
   {
      Print("ERRO: Nenhum valor válido no histórico de larguras");
      return 0.0;
   }

   avg_width /= valid_count;

   if (avg_width <= 0.0)
   {
      Print("ERRO: Largura média inválida (<= 0.0)");
      return 0.0;
   }

   // Fator de convergência: maior quando largura atual é menor que média
   // Removida normalização por ATR - convergência é medida relativa ao histórico próprio
   double convergence = 1.0 - (current_width / avg_width);

   double result = MathMax(0.0, MathMin(1.0, convergence));

   Print("DEBUG Conv - avg_width: ", avg_width,
         " current_width: ", current_width,
         " convergence: ", convergence,
         " result: ", result);

   return result;
}

//+------------------------------------------------------------------+
//| DetectAdvancedSqueeze - Detecção Avançada de Squeeze             |
//|                                                                  |
//| PROPÓSITO: Detectar condições de squeeze usando múltiplos       |
//| fatores: percentil da largura E taxa de mudança negativa.       |
//|                                                                  |
//| CRITÉRIOS: Largura < 20º percentil E mudança < -5%              |
//| RETORNO: true se squeeze avançado detectado, false caso contrário |
//|                                                                  |
//| MELHORIA: Mais preciso que detecção simples, reduz falsos positivos |
//+------------------------------------------------------------------+
bool CBollinger::DetectAdvancedSqueeze()
{
    // Garante que os dados de largura estão calculados
    if (m_width_data_dirty || ArraySize(width_array) == 0)
        CalculateWidths();

    double current_percentile = CalculateWidthPercentile(width_array, ArraySize(width_array), m_width_lookback);
    double width_change_rate = CalculateWidthChangeRate(width_array, ArraySize(width_array), 9);
    return (current_percentile < 20.0 && width_change_rate < -0.05);
}

//+------------------------------------------------------------------+
//| DetectSqueeze - Detecta Condições de Squeeze                     |
//|                                                                  |
//| PROPÓSITO: Identificar quando as bandas estão muito contraídas  |
//| E a inclinação está diminuindo, sinalizando acúmulo de energia  |
//| que pode resultar em forte movimento explosivo.                 |
//|                                                                  |
//| CRITÉRIOS: Bandas muito estreitas E inclinação contrátil        |
//| RETORNO: true se squeeze detectado, false caso contrário       |
//|                                                                  |
//| IMPORTÂNCIA: Squeeze é um padrão de alta probabilidade no       |
//| trading com Bandas de Bollinger.                                |
//+------------------------------------------------------------------+
bool CBollinger::DetectSqueeze()
{
    // Usa detecção avançada de squeeze com múltiplos fatores
    return DetectAdvancedSqueeze();
}

//+------------------------------------------------------------------+
//| CalculateWeightedDirectionConsensus - Consenso Específico Bollinger |
//|                                                                     |
//| PROPÓSITO: Sistema de consenso rigoroso baseado na análise técnica |
//| tradicional de Bandas de Bollinger, exigindo alinhamento específico |
//| das bandas para gerar sinais confiáveis.                           |
//|                                                                     |
//| LÓGICA DE SINAIS:                                                   |
//| - BULL: Banda Superior↑ E Banda Média↑ (resistência+tendência)     |
//| - BEAR: Banda Inferior↓ E Banda Média↓ (suporte+tendência)         |
//| - NEUTRAL: Qualquer outra combinação ou cálculo ponderado          |
//|                                                                     |
//| RESULTADO: Score de 0-1 onde:                                       |
//| - 0.8 = BULL forte (condições perfeitas)                           |
//| - 0.2 = BEAR forte (condições perfeitas)                           |
//| - 0.3-0.7 = NEUTRAL (cálculo ponderado)                            |
double CBollinger::CalculateWeightedDirectionConsensus(const SSlopeValidation &upper,
                                                        const SSlopeValidation &middle,
                                                        const SSlopeValidation &lower)
{
     // === SISTEMA DE CONSENSO ESPECÍFICO PARA BOLLINGER BANDS ===
     // Lógica baseada na análise técnica tradicional:
     // - BULL: Banda Superior (resistência) E Banda Média (tendência) devem subir
     // - BEAR: Banda Inferior (suporte) E Banda Média (tendência) devem descer
     // - NEUTRAL: Qualquer outra combinação

     // DEBUG: Log das inclinações das bandas
     Print("=== BAND CONSENSUS ANALYSIS ===");
     Print("Upper band slope: ", DoubleToString(upper.linear_regression.slope_value, 8));
     Print("Middle band slope: ", DoubleToString(middle.linear_regression.slope_value, 8));
     Print("Lower band slope: ", DoubleToString(lower.linear_regression.slope_value, 8));

     // Verifica condições para sinal BULL
     // Banda superior subindo + banda média subindo = resistência dinâmica subindo + tendência de alta
     bool bull_condition = (upper.linear_regression.slope_value > 1e-10) &&
                          (middle.linear_regression.slope_value > 1e-10);

     // Verifica condições para sinal BEAR
     // Banda inferior descendo + banda média descendo = suporte dinâmico descendo + tendência de baixa
     bool bear_condition = (lower.linear_regression.slope_value < -1e-10) &&
                          (middle.linear_regression.slope_value < -1e-10);

     Print("Bull condition (upper↑ + middle↑): ", bull_condition ? "TRUE" : "FALSE");
     Print("Bear condition (lower↓ + middle↓): ", bear_condition ? "TRUE" : "FALSE");

     // DECISÃO BASEADA EM CONDIÇÕES ESPECÍFICAS
     if (bull_condition && !bear_condition)
     {
        // Sinal BULL forte: resistência e tendência alinhadas para cima
        Print("→ Decision: BULL (resistance↑ + trend↑)");
        return 0.8;  // BULL confiante
     }
     else if (bear_condition && !bull_condition)
     {
        // Sinal BEAR forte: suporte e tendência alinhadas para baixo
        Print("→ Decision: BEAR (support↓ + trend↓)");
        return 0.2;  // BEAR confiante
     }
     else
     {
        // NEUTRAL: Condições não atendidas ou conflitantes
        Print("→ Decision: NEUTRAL (conditions not met or conflicting)");

        // Usa cálculo ponderado para casos intermediários
        const double UPPER_WEIGHT = 0.4;   // Resistência
        const double MIDDLE_WEIGHT = 0.4;  // Tendência (mais importante)
        const double LOWER_WEIGHT = 0.2;   // Suporte

        double total_up = 0.0, total_down = 0.0;

        // Cálculo ponderado para casos neutros
        double upper_strength = MathAbs(upper.linear_regression.slope_value) * UPPER_WEIGHT;
        if (upper.linear_regression.slope_value > 1e-10) total_up += upper_strength;
        else if (upper.linear_regression.slope_value < -1e-10) total_down += upper_strength;

        double middle_strength = MathAbs(middle.linear_regression.slope_value) * MIDDLE_WEIGHT;
        if (middle.linear_regression.slope_value > 1e-10) total_up += middle_strength;
        else if (middle.linear_regression.slope_value < -1e-10) total_down += middle_strength;

        double lower_strength = MathAbs(lower.linear_regression.slope_value) * LOWER_WEIGHT;
        if (lower.linear_regression.slope_value > 1e-10) total_up += lower_strength;
        else if (lower.linear_regression.slope_value < -1e-10) total_down += lower_strength;

        // Normaliza para 0.3-0.7 (faixa neutra)
        double consensus = total_up - total_down;
        double normalized = (consensus + 1.0) / 2.0;  // 0-1
        double final_score = MathMax(0.3, MathMin(0.7, normalized));

        Print("→ Neutral score: ", DoubleToString(final_score, 3), " (weighted calculation)");
        return final_score;
     }
}

//+------------------------------------------------------------------+
//| CalculateIntegratedConfidence - Calcula Score Integrado de Confiança |
//|                                                                       |
//| PROPÓSITO: Combinar múltiplos fatores técnicos em um score único    |
//| de confiança (0-1) que quantifica a robustez do sinal gerado.       |
//|                                                                       |
//| FÓRMULA: Confiança = Σ(componente × peso) + bônus_condicional       |
//| COMPONENTES: direção_bandas(40%), slope(40%), width(20%) + extras(10% cada) |
//| LÓGICA: Combina múltiplos fatores técnicos em score unificado 0-1   |
//|                                                                       |
//| BÔNUS: +20% para squeeze (condições de alta probabilidade)           |
//|                                                                       |
//| INTERPRETAÇÃO: Valores próximos de 1.0 indicam sinais muito         |
//| confiáveis, próximos de 0.0 indicam baixa confiança.                |
double CBollinger::CalculateIntegratedConfidence(double direction_score, double slope_strength,
                                                double width_modifier, double position_strength,
                                                double convergence_factor, bool is_squeeze)
{
   // COMPONENTES PRINCIPAIS: Usam pesos configuráveis do sistema
   // 1. DIREÇÃO DAS BANDAS: Score de consenso (0-1) × peso_banda
   double band_component = direction_score * m_weights[0];

   // 2. FORÇA DO SLOPE: Intensidade da inclinação × peso_slope
   double slope_component = slope_strength * m_weights[1];

   // 3. MODIFICADOR DE LARGURA: Bonus para regiões extremas × peso_width
   double width_component = width_modifier * m_weights[2];

   // COMPONENTES ADICIONAIS: Pesos fixos para fatores complementares
   // 4. POSIÇÃO DO PREÇO: Força relativa nas bandas (10% do total)
   double position_component = position_strength * 0.1;

   // 5. CONVERGÊNCIA DAS BANDAS: Fator de squeeze/contração (10% do total)
   double convergence_component = convergence_factor * 0.1;

   // BÔNUS CONDICIONAL: Recompensa condições especiais
   // 6. SQUEEZE BONUS: +20% quando detectado squeeze (alta probabilidade)
   double squeeze_bonus = is_squeeze ? 0.2 : 0.0;

   // SOMA INTEGRADA: Combinação linear de todos os fatores
   // FÓRMULA: confiança_total = Σ(componentes) + bônus
   double total_confidence = band_component + slope_component + width_component +
                           position_component + convergence_component + squeeze_bonus;

   // NORMALIZAÇÃO: Garante que resultado esteja no intervalo [0, 1]
   // IMPORTANTE: Previne valores negativos ou > 100%
   return MathMin(1.0, MathMax(0.0, total_confidence));
}

//+------------------------------------------------------------------+
//| BuildEnhancedReason - Constrói String de Razão Aprimorada       |
//|                                                                  |
//| PROPÓSITO: Criar uma descrição textual detalhada do sinal,      |
//| incluindo todos os fatores analisados para transparência e     |
//| debugging do sistema de trading.                                |
//|                                                                  |
//| FORMATO: "Bands:XU/YD/ZN, Width:REGIAO, Slope:ESTADO, Pos:VALOR, |
//| Conv:VALOR, Squeeze:SIM/NAO"                                    |
//|                                                                  |
//| USO: Ajuda na análise e validação dos sinais gerados.           |
//+------------------------------------------------------------------+
string CBollinger::BuildEnhancedReason(int up_count, int down_count, int neutral_count,
                                     ENUM_WIDTH_REGION region, ENUM_SLOPE_STATE slope_state,
                                     double position_strength, double convergence_factor, bool is_squeeze,
                                     double width_slope_value, ENUM_CHANNEL_DIRECTION channel_direction)
{
    return StringFormat("Bands:%dU/%dD/%dN, Width:%s, Slope:%s, WidthSlope:%.6f, Channel:%s, Pos:%.2f, Conv:%.2f, Squeeze:%s",
                       up_count, down_count, neutral_count,
                       EnumToString(region), EnumToString(slope_state),
                       width_slope_value, EnumToString(channel_direction), position_strength, convergence_factor, is_squeeze ? "YES" : "NO");
}

//+------------------------------------------------------------------+
//| ValidateAndCorrectParameters - Valida e Auto-Corrige Parâmetros |
//|                                                                  |
//| PROPÓSITO: Garantir que todos os parâmetros configuráveis estejam |
//| dentro de limites seguros e lógicos, prevenindo erros e         |
//| comportamentos inesperados do indicador.                        |
//|                                                                  |
//| VALIDAÇÕES REALIZADAS:                                           |
//| - Limites mínimos e máximos para históricos e lookbacks         |
//| - Ordem crescente dos thresholds percentuais                    |
//| - Normalização dos pesos para soma = 1.0                        |
//| - Valores padrão como fallback                                  |
//|                                                                  |
//| IMPORTÂNCIA: Previne crashes e garante consistência.            |
//+------------------------------------------------------------------+
void CBollinger::ValidateAndCorrectParameters()
{
    // Valida e corrige width_history
    if (m_width_history < 10) m_width_history = 10;
    if (m_width_history > 500) m_width_history = 500;

    // Valida e corrige width_lookback
    if (m_width_lookback < 5) m_width_lookback = 5;
    if (m_width_lookback > 200) m_width_lookback = 200;

    // Valida e corrige slope_lookback
    if (m_slope_lookback < 3) m_slope_lookback = 3;
    if (m_slope_lookback > 50) m_slope_lookback = 50;

    // Valida thresholds percentuais (devem ser estritamente crescentes 0-100)
    if (m_percentile_thresholds[0] <= 0) m_percentile_thresholds[0] = PERCENTILE_THRESHOLD_VERY_NARROW;
    if (m_percentile_thresholds[1] <= m_percentile_thresholds[0]) m_percentile_thresholds[1] = PERCENTILE_THRESHOLD_NARROW;
    if (m_percentile_thresholds[2] <= m_percentile_thresholds[1]) m_percentile_thresholds[2] = PERCENTILE_THRESHOLD_NORMAL;
    if (m_percentile_thresholds[3] <= m_percentile_thresholds[2]) m_percentile_thresholds[3] = PERCENTILE_THRESHOLD_WIDE;
    if (m_percentile_thresholds[3] >= 100) m_percentile_thresholds[3] = 95;

    // Valida pesos (cada um 0.0-1.0, normaliza se soma != 1.0)
    double weight_sum = 0.0;
    for(int i = 0; i < 3; i++)
    {
       if (m_weights[i] < 0.0) m_weights[i] = 0.0;
       if (m_weights[i] > 1.0) m_weights[i] = 1.0;
       weight_sum += m_weights[i];
    }

    // Normaliza pesos para soma = 1.0
    if (weight_sum > 0.0)
    {
       for(int i = 0; i < 3; i++)
          m_weights[i] /= weight_sum;
    }
    else
    {
       // Fallback para padrões
       m_weights[0] = WEIGHT_BAND;
       m_weights[1] = WEIGHT_SLOPE;
       m_weights[2] = WEIGHT_WIDTH;
    }
}

//+------------------------------------------------------------------+
//| AdaptParametersToMarket - Adapta Parâmetros às Condições de Mercado |
//|                                                                  |
//| PROPÓSITO: Ajustar dinamicamente os parâmetros do indicador     |
//| baseado na volatilidade atual medida pelo ATR (Average True Range). |
//|                                                                  |
//| LÓGICA DE ADAPTAÇÃO:                                             |
//| - Alta volatilidade (ATR > 1%): Aumenta lookbacks para estabilidade |
//| - Baixa volatilidade (ATR < 0.2%): Diminui lookbacks para reatividade |
//| - Volatilidade normal: Mantém parâmetros atuais                 |
//|                                                                  |
//| BENEFÍCIO: Melhor performance em diferentes condições de mercado.|
//+------------------------------------------------------------------+
void CBollinger::AdaptParametersToMarket(double atr)
{
    if (atr <= 0.0) return;

    // Calcula ATR relativo ao preço atual
    double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    double atr_ratio = (current_price > 0.0) ? (atr / current_price) * 100.0 : 0.0;

    // Alta volatilidade: aumenta lookbacks para estabilidade
    if (atr_ratio > 1.0) // ATR > 1% do preço
    {
       m_width_lookback = (int)MathMin(200, m_width_lookback * 1.2);
       m_slope_lookback = (int)MathMin(40, m_slope_lookback * 1.2);
    }
    // Baixa volatilidade: diminui lookbacks para reatividade
    else if (atr_ratio < 0.2) // ATR < 0.2% do preço
    {
       m_width_lookback = (int)MathMax(5, m_width_lookback * 1);
       m_slope_lookback = (int)MathMax(3, m_slope_lookback * 1);
    }

    // Revalida após adaptação
    ValidateAndCorrectParameters();
}

//+------------------------------------------------------------------+
//| LoadPresetForSymbol - Carrega Predefinições para Símbolos Específicos |
//|                                                                     |
//| PROPÓSITO: Aplicar configurações otimizadas para diferentes tipos |
//| de ativos, considerando suas características específicas de        |
//| volatilidade e comportamento de preço.                            |
//|                                                                     |
//| WIN$N (Mini Ibovespa):                                             |
//| - Thresholds mais sensíveis para capturar mudanças rápidas        |
//| - Maior ênfase na inclinação devido à volatilidade               |
//| - Lookbacks reduzidos para resposta mais rápida                   |
//|                                                                     |
//| EXTENSIBILIDADE: Pode adicionar presets para outros símbolos.     |
//+------------------------------------------------------------------+
void CBollinger::LoadPresetForSymbol(string symbol)
{
    if (StringFind(symbol, "WIN") >= 0)
    {
       // Predefinições otimizadas para WIN$N e símbolos similares
       // Thresholds mais sensíveis para comportamento tipo cripto
       m_percentile_thresholds[0] = 5;   // Muito estreito
       m_percentile_thresholds[1] = 20;  // Estreito
       m_percentile_thresholds[2] = 80;  // Normal
       m_percentile_thresholds[3] = 95;  // Largo

       // Pesos ajustados: maior ênfase na inclinação para ativos voláteis
       m_weights[0] = 0.3; // Banda
       m_weights[1] = 0.4; // Inclinação
       m_weights[2] = 0.3; // Largura

       // Lookbacks mais curtos para resposta mais rápida
       m_width_lookback = MathMax(5, m_width_lookback - 10);
       m_slope_lookback = MathMax(3, m_slope_lookback - 2);
    }
    // Pode adicionar mais predefinições para outros símbolos se necessário

    // Valida após carregar predefinição
    ValidateAndCorrectParameters();
}

//+------------------------------------------------------------------+
//| IsWidthDataValid - Verifica se os Dados de Largura são Válidos  |
//|                                                                  |
//| PROPÓSITO: Garantir que os dados de largura das bandas estão    |
//| adequados para cálculos estatísticos, prevenindo erros em      |
//| operações matemáticas.                                          |
//|                                                                  |
//| VALIDAÇÕES:                                                      |
//| - Pelo menos 2 valores para cálculos estatísticos              |
//| - Todos os valores devem ser positivos e numéricos válidos     |
//|                                                                  |
//| RETORNO: true se dados válidos, false caso contrário.          |
//+------------------------------------------------------------------+
bool CBollinger::IsWidthDataValid()
{
    int size = ArraySize(width_array);
    if (size < 2) return false;

    // Verifica valores numéricos válidos
    for(int i = 0; i < size; i++)
    {
       if (width_array[i] <= 0.0 || !MathIsValidNumber(width_array[i]))
          return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| GetOptimalLookback - Obtém Período de Lookback Ótimo            |
//|                                                                  |
//| PROPÓSITO: Determinar o melhor período para análise estatística |
//| baseado na quantidade de dados disponíveis, garantindo          |
//| validade estatística sem desperdiçar dados.                     |
//|                                                                  |
//| LÓGICA:                                                         |
//| - Baseia-se no lookback configurado                             |
//| - Ajusta se há poucos dados disponíveis                         |
//| - Garante mínimo de 2 para validade estatística                |
//+------------------------------------------------------------------+
int CBollinger::GetOptimalLookback()
{
    // Usa lookback configurado como base
    int optimal = m_width_lookback;

    // Ajusta baseado nos dados disponíveis
    int available_data = ArraySize(width_array);
    if (available_data < optimal)
       optimal = MathMax(2, available_data - 1);

    // Garante mínimo para validade estatística
    return MathMax(2, optimal);
}

//+------------------------------------------------------------------+
//| CacheWidthStats - Armazena Estatísticas de Largura em Cache     |
//|                                                                  |
//| PROPÓSITO: Calcular e armazenar estatísticas de largura para    |
//| evitar recálculos repetidos, melhorando performance.            |
//|                                                                  |
//| ESTATÍSTICAS ARMAZENADAS:                                        |
//| - Percentil da largura atual                                    |
//| - Z-score da largura atual                                      |
//| - Lookback ótimo usado                                          |
//|                                                                  |
//| BENEFÍCIO: Reduz overhead computacional em chamadas frequentes.|
//+------------------------------------------------------------------+
void CBollinger::CacheWidthStats()
{
    if (!IsWidthDataValid())
    {
       m_cached_percentile = 50.0; // Padrão
       m_cached_zscore = 0.0;
       m_cached_lookback = m_width_lookback;
       return;
    }

    int optimal_lookback = GetOptimalLookback();
    m_cached_percentile = CalculateWidthPercentile(width_array, ArraySize(width_array), optimal_lookback);
    m_cached_zscore = CalculateWidthZScore(width_array, ArraySize(width_array), optimal_lookback);
    m_cached_lookback = optimal_lookback;
    m_width_data_dirty = false;
}

//+------------------------------------------------------------------+
//| CalibrateForWinIndex - Calibração Específica para WIN$N         |
//| PROPÓSITO: Ajustar parâmetros baseado no timeframe do WIN$N     |
//| FUNDAMENTO: Cada timeframe tem características de volatilidade distintas |
//| MÉTODO: Switch case com configurações otimizadas por timeframe |
//| VALIDAÇÃO: Parâmetros corrigidos automaticamente após calibração |
void CBollinger::CalibrateForWinIndex(ENUM_TIMEFRAMES timeframe)
{
     /*
      * FUNDAMENTO TÉCNICO DO WIN$N:
      * ----------------------------
      * WIN$N (Mini Índice Ibovespa) características específicas:
      * - Tick size: 5 pontos (R$ 0,05 por ponto)
      * - Volatilidade: Alta durante pregão (9:00-17:00 B3)
      * - Padrões: Diferentes por timeframe devido ao ruído
      *
      * ESTRATÉGIA DE CALIBRAÇÃO:
      * - M1: Filtros rigorosos contra ruído de alta frequência
      * - M3: Balance otimizado baseado em dados históricos reais
      * - M15+: Lookback maior pois trends são mais claras
      */

     switch(timeframe)
     {
        case PERIOD_M1:
           /*
            * CONFIGURAÇÃO M1 (1 MINUTO):
            * OBJETIVO: Filtrar ruído mantendo reatividade
            * LÓGICA: Histórico maior + lookback curto = suavização com resposta rápida
            */
           m_width_history = 150;      // HISTÓRICO AMPLIO: Suaviza ruído de 1min
           m_width_lookback = 30;      // LOOKBACK CURTO: Reage rápido a mudanças
           m_slope_lookback = 6;       // SLOPE RÁPIDO: Detecção imediata de tendência

           // THRESHOLDS MAIS SENSÍVEIS: Capturam mudanças rápidas
           m_percentile_thresholds[0] = 20;  // Very narrow (mais permissivo)
           m_percentile_thresholds[1] = 40;  // Narrow
           m_percentile_thresholds[2] = 60;  // Normal
           m_percentile_thresholds[3] = 80;  // Wide


           // PESOS EQUILIBRADOS: Banda e slope têm mesma importância
           m_weights[0] = 0.4;  // Band: 40% (resistência/suporte)
           m_weights[1] = 0.4;  // Slope: 40% (inclinação - crítico em M1)
           m_weights[2] = 0.2;  // Width: 20% (volatilidade)
           break;

        case PERIOD_M3:
           /*
            * CONFIGURAÇÃO M3 (3 MINUTOS) - OTIMIZADA PARA WIN$N:
            * BASE: Análise de dados históricos reais do WIN$N
            * OBJETIVO: Melhor balance entre sensibilidade e robustez
            * MÉTODO: Parâmetros ajustados para capturar oportunidades reais
            */
           // PARÂMETROS DE HISTÓRICO: Otimizados para WIN$N M3
           m_width_history = 50;      // BASE DE DADOS: 100 candles históricos
           m_width_lookback = 20;      // ANÁLISE: 40 candles para estatísticas
           m_slope_lookback = 9;       // MOMENTUM: 6 candles para resposta mais rápida

           // THRESHOLDS MAIS SENSÍVEIS: Para detectar squeezes no WIN$N
           m_percentile_thresholds[0] = 15;  // Very narrow (mais sensível)
           m_percentile_thresholds[1] = 35;  // Narrow
           m_percentile_thresholds[2] = 65;  // Normal
           m_percentile_thresholds[3] = 85;  // Wide


           // PESOS AJUSTADOS: Maior ênfase no slope para WIN$N
           m_weights[0] = 0.3;  // Band: 30% (direção das bandas)
           m_weights[1] = 0.5;  // Slope: 50% (maior peso - momentum crítico para WIN$N)
           m_weights[2] = 0.2;  // Width: 20% (modificadores de volatilidade)
           break;

      case PERIOD_M5:
         // M5: Mais filtros, abordagem balanceada
         m_width_history = 80;
         m_width_lookback = 80;
         m_slope_lookback = 12;
         m_percentile_thresholds[0] = 10;  // Muito estreito
         m_percentile_thresholds[1] = 30;  // Estreito
         m_percentile_thresholds[2] = 70;  // Normal
         m_percentile_thresholds[3] = 90;  // Largo
         m_weights[0] = 0.6;  // Banda (conservador)
         m_weights[1] = 0.2;  // Inclinação
         m_weights[2] = 0.2;  // Largura
         break;

      case PERIOD_M15:
         // M15: Lookbacks maiores, menos ruído
         m_width_history = 80;
         m_width_lookback = 80;
         m_slope_lookback = 12;
         m_percentile_thresholds[0] = 10;  // Muito estreito
         m_percentile_thresholds[1] = 30;  // Estreito
         m_percentile_thresholds[2] = 70;  // Normal
         m_percentile_thresholds[3] = 90;  // Largo
         m_weights[0] = 0.6;  // Banda
         m_weights[1] = 0.2;  // Inclinação
         m_weights[2] = 0.2;  // Largura
         break;

      case PERIOD_H1:
         // H1: Parâmetros conservadores para timeframe maior
         m_width_history = 60;
         m_width_lookback = 60;
         m_slope_lookback = 15;
         m_percentile_thresholds[0] = 5;   // Muito estreito
         m_percentile_thresholds[1] = 25;  // Estreito
         m_percentile_thresholds[2] = 75;  // Normal
         m_percentile_thresholds[3] = 95;  // Largo
         m_weights[0] = 0.7;  // Banda (muito conservador)
         m_weights[1] = 0.2;  // Inclinação
         m_weights[2] = 0.1;  // Largura
         break;

      default:
         // Para outros timeframes, usa M3 como referência
         CalibrateForWinIndex(PERIOD_M3);
         break;
   }

   // Valida parâmetros após calibração
   ValidateAndCorrectParameters();
}

#endif // __BOLLINGER_MQH__
