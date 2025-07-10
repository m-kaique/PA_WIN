//+------------------------------------------------------------------+
//|                                                       TF_CTX.mqh |
//|  Generic timeframe context handling multiple indicators           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "2.00"

#include "factories/indicator_factory.mqh"
#include "factories/priceaction_factory.mqh"
#include "config_types.mqh"


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
  CIndicatorConfig *m_cfg[];
  CIndicatorBase *m_indicators[];
  string m_names[];

  // PriceActions
  CPriceActionConfig *m_pa_cfg[];
  CPriceActionBase  *m_priceactions[];
  string m_pa_names[];

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
  double GetPriceActionValue(string name,int shift=0);
  bool CopyPriceActionValues(string name,int shift,int count,double &buffer[]);
  CPriceActionBase* GetPriceAction(string name);
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
TF_CTX::TF_CTX(ENUM_TIMEFRAMES timeframe, int num_candles,
               CIndicatorConfig *&cfg[], CPriceActionConfig *&pa_cfg[])
{
  m_timeframe = timeframe;
  m_num_candles = num_candles;
  m_symbol = Symbol();
  m_initialized = false;

  int sz = ArraySize(cfg);
  ArrayResize(m_cfg, sz);
  for (int i = 0; i < sz; i++)
    m_cfg[i] = cfg[i];

  int psz=ArraySize(pa_cfg);
  ArrayResize(m_pa_cfg,psz);
  for(int i=0;i<psz;i++)
    m_pa_cfg[i]=pa_cfg[i];

  ArrayResize(m_indicators, 0);
  ArrayResize(m_names, 0);
  ArrayResize(m_priceactions,0);
  ArrayResize(m_pa_names,0);
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

  for (int i = 0; i < ArraySize(m_cfg); i++)
  {
    if (m_cfg[i]==NULL || !m_cfg[i].enabled)
      continue;

    CIndicatorFactory *factory=CIndicatorFactory::Instance();
    if(!factory.IsRegistered(m_cfg[i].type))
    {
      Print("Tipo de indicador nao suportado: ", m_cfg[i].type);
      continue;
    }
    CIndicatorBase *ind=factory.Create(m_cfg[i].type,m_symbol,m_timeframe,m_cfg[i]);
    if(ind==NULL)
    {
      Print("ERRO: Falha ao inicializar indicador ", m_cfg[i].name);
      CleanUp();
      return false;
    }
    int pos = ArraySize(m_indicators);
    ArrayResize(m_indicators,pos+1);
    ArrayResize(m_names,pos+1);
    m_indicators[pos]=ind;
    m_names[pos]=m_cfg[i].name;
  }

  // Inicializar priceactions
  for(int i=0;i<ArraySize(m_pa_cfg);i++)
  {
    if(m_pa_cfg[i]==NULL || !m_pa_cfg[i].enabled)
      continue;

    CPriceActionFactory *pafactory=CPriceActionFactory::Instance();
    if(!pafactory.IsRegistered(m_pa_cfg[i].type))
    {
      Print("Tipo de priceaction nao suportado: ", m_pa_cfg[i].type);
      continue;
    }
    CPriceActionBase *pa=pafactory.Create(m_pa_cfg[i].type,m_symbol,m_timeframe,m_pa_cfg[i]);
    if(pa==NULL)
    {
      Print("ERRO: Falha ao inicializar priceaction ", m_pa_cfg[i].name);
      CleanUp();
      return false;
    }
    int ppos=ArraySize(m_priceactions);
    ArrayResize(m_priceactions,ppos+1);
    ArrayResize(m_pa_names,ppos+1);
    m_priceactions[ppos]=pa;
    m_pa_names[ppos]=m_pa_cfg[i].name;
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
  for (int i = 0; i < ArraySize(m_indicators); i++)
  {
    if (m_indicators[i] != NULL)
      delete m_indicators[i];
  }
  for(int i=0;i<ArraySize(m_priceactions);i++)
    if(m_priceactions[i]!=NULL)
      delete m_priceactions[i];
  for (int i = 0; i < ArraySize(m_cfg); i++)
  {
    if (m_cfg[i] != NULL)
      delete m_cfg[i];
  }
  for(int i=0;i<ArraySize(m_pa_cfg);i++)
    if(m_pa_cfg[i]!=NULL)
      delete m_pa_cfg[i];
  ArrayResize(m_indicators, 0);
  ArrayResize(m_names, 0);
  ArrayResize(m_cfg, 0);
  ArrayResize(m_priceactions,0);
  ArrayResize(m_pa_names,0);
  ArrayResize(m_pa_cfg,0);
  m_initialized = false;
}

//+------------------------------------------------------------------+
//| Obter valor do indicador                                         |
//+------------------------------------------------------------------+
double TF_CTX::GetIndicatorValue(string name, int shift)
{
  for (int i = 0; i < ArraySize(m_names); i++)
    if (m_names[i] == name && m_indicators[i] != NULL)
      return m_indicators[i].GetValue(shift);
  Print("Indicador nao encontrado: ", name);
  return 0.0;
}

//+------------------------------------------------------------------+
//| Copiar valores do indicador                                      |
//+------------------------------------------------------------------+
bool TF_CTX::CopyIndicatorValues(string name, int shift, int count, double &buffer[])
{
  for (int i = 0; i < ArraySize(m_names); i++)
    if (m_names[i] == name && m_indicators[i] != NULL)
      return m_indicators[i].CopyValues(shift, count, buffer);
  Print("Indicador nao encontrado: ", name);
  return false;
}

//+------------------------------------------------------------------+
//| Obter valor da price action                                       |
//+------------------------------------------------------------------+
double TF_CTX::GetPriceActionValue(string name,int shift)
{
  for(int i=0;i<ArraySize(m_pa_names);i++)
    if(m_pa_names[i]==name && m_priceactions[i]!=NULL)
      return m_priceactions[i].GetValue(shift);
  Print("PriceAction nao encontrado: ",name);
  return 0.0;
}

//+------------------------------------------------------------------+
//| Copiar valores da price action                                    |
//+------------------------------------------------------------------+
bool TF_CTX::CopyPriceActionValues(string name,int shift,int count,double &buffer[])
{
  for(int i=0;i<ArraySize(m_pa_names);i++)
    if(m_pa_names[i]==name && m_priceactions[i]!=NULL)
      return m_priceactions[i].CopyValues(shift,count,buffer);
  Print("PriceAction nao encontrado: ",name);
  return false;
}

//+------------------------------------------------------------------+
//| Get price action object by name                                   |
//+------------------------------------------------------------------+
CPriceActionBase* TF_CTX::GetPriceAction(string name)
{
  for(int i=0;i<ArraySize(m_pa_names);i++)
    if(m_pa_names[i]==name)
      return m_priceactions[i];
  return NULL;
}

//+------------------------------------------------------------------+
//| Atualizar contexto                                               |
//+------------------------------------------------------------------+
bool TF_CTX::Update()
{
  if (!m_initialized)
    return false;

  bool ready = true;
  for (int i = 0; i < ArraySize(m_indicators); i++)
    if (m_indicators[i] != NULL)
      ready &= m_indicators[i].Update();
  for(int i=0;i<ArraySize(m_priceactions);i++)
    if(m_priceactions[i]!=NULL)
      ready &= m_priceactions[i].Update();
  return ready;
}

//+------------------------------------------------------------------+
