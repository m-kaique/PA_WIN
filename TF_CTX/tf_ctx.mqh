//+------------------------------------------------------------------+
//|                                                       TF_CTX.mqh |
//|  Generic timeframe context handling indicators and price action  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "3.00"

#include "indicators/ma/moving_averages.mqh"
#include "indicators/stochastic/stochastic.mqh"
#include "indicators/volume/volume.mqh"
#include "indicators/vwap/vwap.mqh"
#include "indicators/bollinger/bollinger.mqh"
#include "indicators/fibonacci/fibonacci.mqh"
#include "priceaction/trendline/trendline.mqh"
#include "config_types.mqh"

enum ENUM_INDICATOR_TYPE
{
  INDICATOR_TYPE_MA,
  INDICATOR_TYPE_STO,
  INDICATOR_TYPE_VOL,
  INDICATOR_TYPE_VWAP,
  INDICATOR_TYPE_BOLL,
  INDICATOR_TYPE_FIBO,
  INDICATOR_TYPE_UNKNOWN
};

enum ENUM_PRICEACTION_TYPE
{
  PRICEACTION_TYPE_TRENDLINE,
  PRICEACTION_TYPE_UNKNOWN
};

ENUM_INDICATOR_TYPE StringToIndicatorType(string type)
{
  if (type == "MA")
    return INDICATOR_TYPE_MA;
  if (type == "STO")
    return INDICATOR_TYPE_STO;
  if (type == "VOL")
    return INDICATOR_TYPE_VOL;
  if (type == "VWAP")
    return INDICATOR_TYPE_VWAP;
  if (type == "BOLL")
    return INDICATOR_TYPE_BOLL;
  if (type == "FIBO")
    return INDICATOR_TYPE_FIBO;
  return INDICATOR_TYPE_UNKNOWN;
}

ENUM_PRICEACTION_TYPE StringToPriceActionType(string type)
{
  if (type == "TRENDLINE")
    return PRICEACTION_TYPE_TRENDLINE;
  return PRICEACTION_TYPE_UNKNOWN;
}

//+------------------------------------------------------------------+
//| Classe principal para contexto de TimeFrame                     |
//+------------------------------------------------------------------+
class TF_CTX
{
private:
  ENUM_TIMEFRAMES m_timeframe; // TimeFrame para análise
  int m_num_candles;           // Número de velas para análise
  string m_symbol;             // Símbolo atual
  bool m_initialized;          // Flag de inicialização

  // Configurações e instâncias dos indicadores
  CIndicatorConfig *m_indicator_cfg[];
  CIndicatorBase *m_indicators[];
  string m_indicator_names[];

  // Configurações e instâncias do price action
  CPriceActionConfig *m_priceaction_cfg[];
  CPriceActionBase *m_priceactions[];
  string m_priceaction_names[];

  bool ValidateParameters();
  void CleanUp();

public:
  TF_CTX(ENUM_TIMEFRAMES timeframe, int num_candles, 
         CIndicatorConfig *&indicator_cfg[], 
         CPriceActionConfig *&priceaction_cfg[]);
  ~TF_CTX();

  bool Init();
  bool Update();
  
  // Métodos para indicadores (existentes)
  double GetIndicatorValue(string name, int shift = 0);
  bool CopyIndicatorValues(string name, int shift, int count, double &buffer[]);
  
  // Métodos para price action (novos)
  double GetPriceActionValue(string name, int shift = 0);
  bool CopyPriceActionValues(string name, int shift, int count, double &buffer[]);
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
TF_CTX::TF_CTX(ENUM_TIMEFRAMES timeframe, int num_candles, 
               CIndicatorConfig *&indicator_cfg[], 
               CPriceActionConfig *&priceaction_cfg[])
{
  m_timeframe = timeframe;
  m_num_candles = num_candles;
  m_symbol = Symbol();
  m_initialized = false;

  // Copiar configurações dos indicadores
  int ind_sz = ArraySize(indicator_cfg);
  ArrayResize(m_indicator_cfg, ind_sz);
  for (int i = 0; i < ind_sz; i++)
    m_indicator_cfg[i] = indicator_cfg[i];

  // Copiar configurações do price action
  int pa_sz = ArraySize(priceaction_cfg);
  ArrayResize(m_priceaction_cfg, pa_sz);
  for (int i = 0; i < pa_sz; i++)
    m_priceaction_cfg[i] = priceaction_cfg[i];

  ArrayResize(m_indicators, 0);
  ArrayResize(m_indicator_names, 0);
  ArrayResize(m_priceactions, 0);
  ArrayResize(m_priceaction_names, 0);
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
TF_CTX::~TF_CTX()
{
  CleanUp();
}

//+------------------------------------------------------------------+
//| Inicialização                                                    |
//+------------------------------------------------------------------+
bool TF_CTX::Init()
{
  if (!ValidateParameters())
    return false;

  // Inicializar indicadores (lógica existente)
  for (int i = 0; i < ArraySize(m_indicator_cfg); i++)
  {
    if (m_indicator_cfg[i]==NULL || !m_indicator_cfg[i].enabled)
      continue;

    CIndicatorBase *ind = NULL;
    switch (StringToIndicatorType(m_indicator_cfg[i].type))
    {
    case INDICATOR_TYPE_MA:
      {
        ind = new CMovingAverages();
        CMAConfig *ma_cfg=(CMAConfig*)m_indicator_cfg[i];
        if (ind == NULL || !((CMovingAverages*)ind).Init(m_symbol, m_timeframe,
                                           ma_cfg.period, ma_cfg.method))
        {
          Print("ERRO: Falha ao inicializar indicador ", m_indicator_cfg[i].name);
          delete ind;
          CleanUp();
          return false;
        }
      }
      break;

    case INDICATOR_TYPE_STO:
      {
        ind = new CStochastic();
        CStochasticConfig *sto_cfg=(CStochasticConfig*)m_indicator_cfg[i];
        if (ind == NULL || !((CStochastic *)ind).Init(m_symbol, m_timeframe,
                                           sto_cfg.period, sto_cfg.dperiod, sto_cfg.slowing,
                                           sto_cfg.method, sto_cfg.price_field))
        {
          Print("ERRO: Falha ao inicializar indicador ", m_indicator_cfg[i].name);
          delete ind;
          CleanUp();
          return false;
        }
      }
      break;

    case INDICATOR_TYPE_VOL:
      {
        ind = new CVolume();
        CVolumeConfig *vol_cfg=(CVolumeConfig*)m_indicator_cfg[i];
        if (ind == NULL || !((CVolume*)ind).Init(m_symbol, m_timeframe,
                                           vol_cfg.shift, MODE_SMA))
        {
          Print("ERRO: Falha ao inicializar indicador ", m_indicator_cfg[i].name);
          delete ind;
          CleanUp();
          return false;
        }
      }
      break;

    case INDICATOR_TYPE_VWAP:
      {
        ind = new CVWAP();
        CVWAPConfig *vwap_cfg=(CVWAPConfig*)m_indicator_cfg[i];
        if (ind == NULL || !((CVWAP*)ind).Init(m_symbol, m_timeframe,
                                           vwap_cfg.period, vwap_cfg.method, vwap_cfg.calc_mode,
                                           vwap_cfg.session_tf, vwap_cfg.price_type,
                                           vwap_cfg.start_time, vwap_cfg.line_color,
                                           vwap_cfg.line_style, vwap_cfg.line_width))
        {
          Print("ERRO: Falha ao inicializar indicador ", m_indicator_cfg[i].name);
          delete ind;
          CleanUp();
          return false;
        }
      }
      break;

    case INDICATOR_TYPE_BOLL:
      {
        ind = new CBollinger();
        CBollingerConfig *boll_cfg=(CBollingerConfig*)m_indicator_cfg[i];
        if (ind == NULL || !((CBollinger *)ind).Init(m_symbol, m_timeframe,
                                           boll_cfg.period, boll_cfg.shift,
                                           boll_cfg.deviation, boll_cfg.applied_price))
        {
          Print("ERRO: Falha ao inicializar indicador ", m_indicator_cfg[i].name);
          delete ind;
          CleanUp();
          return false;
        }
      }
      break;

    case INDICATOR_TYPE_FIBO:
      {
        ind = new CFibonacci();
        CFiboConfig *fibo_cfg=(CFiboConfig*)m_indicator_cfg[i];
        if (ind == NULL || !((CFibonacci *)ind).Init(m_symbol, m_timeframe, *fibo_cfg))
        {
          Print("ERRO: Falha ao inicializar indicador ", m_indicator_cfg[i].name);
          delete ind;
          CleanUp();
          return false;
        }
      }
      break;

    default:
      Print("Tipo de indicador nao suportado: ", m_indicator_cfg[i].type);
      continue;
    }

    int pos = ArraySize(m_indicators);
    ArrayResize(m_indicators, pos + 1);
    ArrayResize(m_indicator_names, pos + 1);
    m_indicators[pos] = ind;
    m_indicator_names[pos] = m_indicator_cfg[i].name;
  }

  // Inicializar price action patterns (nova lógica)
  for (int i = 0; i < ArraySize(m_priceaction_cfg); i++)
  {
    if (m_priceaction_cfg[i]==NULL || !m_priceaction_cfg[i].enabled)
      continue;

    CPriceActionBase *pa = NULL;
    switch (StringToPriceActionType(m_priceaction_cfg[i].type))
    {
    case PRICEACTION_TYPE_TRENDLINE:
      {
        pa = new CTrendLine();
        CTrendLineConfig *tl_cfg=(CTrendLineConfig*)m_priceaction_cfg[i];
        if (pa == NULL || !((CTrendLine*)pa).Init(m_symbol, m_timeframe,
                                           tl_cfg.period, tl_cfg.left, tl_cfg.right))
        {
          Print("ERRO: Falha ao inicializar price action ", m_priceaction_cfg[i].name);
          delete pa;
          CleanUp();
          return false;
        }
      }
      break;

    default:
      Print("Tipo de price action nao suportado: ", m_priceaction_cfg[i].type);
      continue;
    }

    int pos = ArraySize(m_priceactions);
    ArrayResize(m_priceactions, pos + 1);
    ArrayResize(m_priceaction_names, pos + 1);
    m_priceactions[pos] = pa;
    m_priceaction_names[pos] = m_priceaction_cfg[i].name;
  }

  m_initialized = true;
  return true;
}

//+------------------------------------------------------------------+
//| Validar parâmetros                                               |
//+------------------------------------------------------------------+
bool TF_CTX::ValidateParameters()
{
  if (m_timeframe < PERIOD_M1 || m_timeframe > PERIOD_MN1)
  {
    Print("ERRO: TimeFrame invalido: ", EnumToString(m_timeframe));
    return false;
  }
  if (StringLen(m_symbol) == 0)
  {
    Print("ERRO: Simbolo invalido");
    return false;
  }
  return true;
}

//+------------------------------------------------------------------+
//| Limpar recursos                                                  |
//+------------------------------------------------------------------+
void TF_CTX::CleanUp()
{
  // Limpar indicadores
  for (int i = 0; i < ArraySize(m_indicators); i++)
  {
    if (m_indicators[i] != NULL)
      delete m_indicators[i];
  }
  for (int i = 0; i < ArraySize(m_indicator_cfg); i++)
  {
    if (m_indicator_cfg[i] != NULL)
      delete m_indicator_cfg[i];
  }
  
  // Limpar price action
  for (int i = 0; i < ArraySize(m_priceactions); i++)
  {
    if (m_priceactions[i] != NULL)
      delete m_priceactions[i];
  }
  for (int i = 0; i < ArraySize(m_priceaction_cfg); i++)
  {
    if (m_priceaction_cfg[i] != NULL)
      delete m_priceaction_cfg[i];
  }
  
  ArrayResize(m_indicators, 0);
  ArrayResize(m_indicator_names, 0);
  ArrayResize(m_indicator_cfg, 0);
  ArrayResize(m_priceactions, 0);
  ArrayResize(m_priceaction_names, 0);
  ArrayResize(m_priceaction_cfg, 0);
  m_initialized = false;
}

//+------------------------------------------------------------------+
//| Obter valor do indicador                                         |
//+------------------------------------------------------------------+
double TF_CTX::GetIndicatorValue(string name, int shift)
{
  for (int i = 0; i < ArraySize(m_indicator_names); i++)
    if (m_indicator_names[i] == name && m_indicators[i] != NULL)
      return m_indicators[i].GetValue(shift);
  Print("Indicador nao encontrado: ", name);
  return 0.0;
}

//+------------------------------------------------------------------+
//| Copiar valores do indicador                                      |
//+------------------------------------------------------------------+
bool TF_CTX::CopyIndicatorValues(string name, int shift, int count, double &buffer[])
{
  for (int i = 0; i < ArraySize(m_indicator_names); i++)
    if (m_indicator_names[i] == name && m_indicators[i] != NULL)
      return m_indicators[i].CopyValues(shift, count, buffer);
  Print("Indicador nao encontrado: ", name);
  return false;
}

//+------------------------------------------------------------------+
//| Obter valor do price action                                      |
//+------------------------------------------------------------------+
double TF_CTX::GetPriceActionValue(string name, int shift)
{
  for (int i = 0; i < ArraySize(m_priceaction_names); i++)
    if (m_priceaction_names[i] == name && m_priceactions[i] != NULL)
      return m_priceactions[i].GetValue(shift);
  Print("Price Action nao encontrado: ", name);
  return 0.0;
}

//+------------------------------------------------------------------+
//| Copiar valores do price action                                   |
//+------------------------------------------------------------------+
bool TF_CTX::CopyPriceActionValues(string name, int shift, int count, double &buffer[])
{
  for (int i = 0; i < ArraySize(m_priceaction_names); i++)
    if (m_priceaction_names[i] == name && m_priceactions[i] != NULL)
      return m_priceactions[i].CopyValues(shift, count, buffer);
  Print("Price Action nao encontrado: ", name);
  return false;
}

//+------------------------------------------------------------------+
//| Atualizar contexto                                               |
//+------------------------------------------------------------------+
bool TF_CTX::Update()
{
  if (!m_initialized)
    return false;

  bool indicators_ready = true;
  bool priceaction_ready = true;
  
  // Atualizar indicadores
  for (int i = 0; i < ArraySize(m_indicators); i++)
    if (m_indicators[i] != NULL)
      indicators_ready &= m_indicators[i].Update();
      
  // Atualizar price action
  for (int i = 0; i < ArraySize(m_priceactions); i++)
    if (m_priceactions[i] != NULL)
      priceaction_ready &= m_priceactions[i].Update();
      
  return indicators_ready && priceaction_ready;
}

//+------------------------------------------------------------------+