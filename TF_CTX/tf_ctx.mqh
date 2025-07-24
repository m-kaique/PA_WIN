//+------------------------------------------------------------------+
//|                                                       TF_CTX.mqh |
//|  Generic timeframe context handling multiple indicators           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "2.00"

#include "factories/indicator_factory.mqh"
#include "config_types.mqh"

//+------------------------------------------------------------------+
//| Classe principal para contexto de TimeFrame                     |
//+------------------------------------------------------------------+
class TF_CTX
{
private:
  ENUM_TIMEFRAMES m_timeframe; // TimeFrame para análise
  datetime m_last_bar_time;    // Tempo da última Barra do TF
  int m_num_candles;           // Número de velas para análise
  string m_symbol;             // Símbolo atual
  bool m_initialized;          // Flag de inicialização

  // Configurações e instâncias dos indicadores
  CIndicatorConfig *m_cfg[];
  CIndicatorBase *m_indicators[];
  string m_names[];

  // PriceActions
  CPriceActionConfig *m_pa_cfg[];
  string m_pa_names[];

  bool CreateIndicators();
  void AddIndicator(CIndicatorBase *ind, string name);
  int FindByName(string name, string &arr[]);
  bool IsValidTimeframe(ENUM_TIMEFRAMES tf);
  bool ValidateParameters();
  void CleanUp();

public:
  TF_CTX(ENUM_TIMEFRAMES timeframe, int num_candles,
         CIndicatorConfig *&cfg[], CPriceActionConfig *&pa_cfg[]);
  ~TF_CTX();

  bool Init();
  bool Update();
  double GetIndicatorValue(string name, int shift = 0);
  bool CopyIndicatorValues(string name, int shift, int count, double &buffer[]);
  double GetPriceActionValue(string name, int shift = 0);
  CIndicatorBase *GetIndicator(string name);
  bool CopyPriceActionValues(string name, int shift, int count, double &buffer[]);
  bool HasNewBar();
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
TF_CTX::TF_CTX(ENUM_TIMEFRAMES timeframe, int num_candles,
               CIndicatorConfig *&cfg[], CPriceActionConfig *&pa_cfg[])
{
  m_timeframe = timeframe;
  m_last_bar_time = 0;
  m_num_candles = num_candles;
  m_symbol = Symbol();
  m_initialized = false;

  int sz = ArraySize(cfg);
  ArrayResize(m_cfg, sz);
  for (int i = 0; i < sz; i++)
    m_cfg[i] = cfg[i];

  int psz = ArraySize(pa_cfg);
  ArrayResize(m_pa_cfg, psz);
  for (int i = 0; i < psz; i++)
    m_pa_cfg[i] = pa_cfg[i];

  ArrayResize(m_indicators, 0);
  ArrayResize(m_names, 0);
  ArrayResize(m_pa_names, 0);
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
TF_CTX::~TF_CTX()
{
  CleanUp();
}

//+------------------------------------------------------------------+
//| Helper methods                                                   |
//+------------------------------------------------------------------+
void TF_CTX::AddIndicator(CIndicatorBase *ind, string name)
{
  int pos = ArraySize(m_indicators);
  ArrayResize(m_indicators, pos + 1);
  ArrayResize(m_names, pos + 1);
  m_indicators[pos] = ind;
  m_names[pos] = name;
}

int TF_CTX::FindByName(string name, string &arr[])
{
  for (int i = 0; i < ArraySize(arr); i++)
    if (arr[i] == name)
      return i;
  return -1;
}

bool TF_CTX::IsValidTimeframe(ENUM_TIMEFRAMES tf)
{
  return (tf >= PERIOD_M1 && tf <= PERIOD_MN1);
}

bool TF_CTX::CreateIndicators()
{
  CIndicatorFactory *factory = CIndicatorFactory::Instance();
  for (int i = 0; i < ArraySize(m_cfg); i++)
  {
    CIndicatorConfig *cfg = m_cfg[i];
    if (cfg == NULL || !cfg.enabled)
      continue;

    if (!factory.IsRegistered(cfg.type))
    {
      Print("Tipo de indicador nao suportado: ", cfg.type);
      continue;
    }
    CIndicatorBase *ind = factory.Create(cfg.type, m_symbol, m_timeframe, cfg);
    if (ind == NULL)
    {
      Print("ERRO: Falha ao inicializar indicador ", cfg.name);
      return false;
    }
    AddIndicator(ind, cfg.name);

    // Alert(cfg.name + "->" + EnumToString(cfg.alert_tf));
    // // Chamar AttachToChart() após a criação do indicador
    // if (ind.AttachToChart())
    // {
    //     Print("Indicador ", cfg.name, " acoplado ao gráfico.");
    // }
    // else
    // {
    //     Print("Indicador ", cfg.name, " não acoplado ao gráfico ou falha no acoplamento.");
    // }
  }
  return true;
}


//+------------------------------------------------------------------+
//| Inicialização                                                    |
//+------------------------------------------------------------------+
bool TF_CTX::Init()
{
  if (!ValidateParameters())
    return false;

  if (!CreateIndicators())
  {
    CleanUp();
    return false;
  }
  m_initialized = true;
  return true;
}

//+------------------------------------------------------------------+
//| Validar parâmetros                                               |
//+------------------------------------------------------------------+
bool TF_CTX::ValidateParameters()
{
  if (!IsValidTimeframe(m_timeframe))
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
  for (int i = 0; i < ArraySize(m_indicators); i++)
  {
    if (m_indicators[i] != NULL)
      delete m_indicators[i];
  }
  for (int i = 0; i < ArraySize(m_cfg); i++)
  {
    if (m_cfg[i] != NULL)
      delete m_cfg[i];
  }
  for (int i = 0; i < ArraySize(m_pa_cfg); i++)
    if (m_pa_cfg[i] != NULL)
      delete m_pa_cfg[i];
  ArrayResize(m_indicators, 0);
  ArrayResize(m_names, 0);
  ArrayResize(m_cfg, 0);
  ArrayResize(m_pa_names, 0);
  ArrayResize(m_pa_cfg, 0);
  m_initialized = false;
}

//+------------------------------------------------------------------+
//| Obter valor do indicador                                         |
//+------------------------------------------------------------------+
double TF_CTX::GetIndicatorValue(string name, int shift)
{
  int idx = FindByName(name, m_names);
  if (idx >= 0 && m_indicators[idx] != NULL)
    return m_indicators[idx].GetValue(shift);
  Print("Indicador nao encontrado: ", name);
  return 0.0;
}

//+------------------------------------------------------------------+
//| Copiar valores do indicador                                      |
//+------------------------------------------------------------------+
bool TF_CTX::CopyIndicatorValues(string name, int shift, int count, double &buffer[])
{
  int idx = FindByName(name, m_names);
  if (idx >= 0 && m_indicators[idx] != NULL)
    return m_indicators[idx].CopyValues(shift, count, buffer);
  Print("Indicador nao encontrado: ", name);
  return false;
}



//+------------------------------------------------------------------+
//| Obter ponteiro para o Indicador                                  |
//+------------------------------------------------------------------+
CIndicatorBase *TF_CTX::GetIndicator(string name)
{
  int idx = FindByName(name, m_names);
  if (idx >= 0)
    return m_indicators[idx];
  return NULL;
}


bool TF_CTX::HasNewBar()
{
  if (!m_initialized)
    return false;

  datetime current_bar_time = iTime(m_symbol, m_timeframe, 0);
  return (current_bar_time > m_last_bar_time);
}

//+------------------------------------------------------------------+
//| Atualizar contexto                                               |
//+------------------------------------------------------------------+
bool TF_CTX::Update()
{
  if (!m_initialized)
    return false;

  //  Verificar se há nova vela para este timeframe
  datetime current_bar_time = iTime(m_symbol, m_timeframe, 0);
  if (current_bar_time <= m_last_bar_time)
    return true; // Não há nova vela, retorna sem atualizar

  m_last_bar_time = current_bar_time;

  bool ready = true;
  for (int i = 0; i < ArraySize(m_indicators); i++)
    if (m_indicators[i] != NULL)
      ready &= m_indicators[i].Update();

  return ready;
}

//+------------------------------------------------------------------+
