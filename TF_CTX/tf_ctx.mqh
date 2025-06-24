//+------------------------------------------------------------------+
//|                                                       TF_CTX.mqh |
//|  Generic timeframe context handling multiple indicators           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "2.00"

#include "indicators/moving_averages.mqh"
#include "indicators/stochastic.mqh"
#include "indicators/volume.mqh"
#include "indicators/bollinger.mqh"
#include "indicators/fibonacci.mqh"
#include "config_types.mqh"

//+------------------------------------------------------------------+
//| Classe principal para contexto de TimeFrame                     |
//+------------------------------------------------------------------+
class TF_CTX
  {
private:
   ENUM_TIMEFRAMES     m_timeframe;        // TimeFrame para análise
   int                 m_num_candles;      // Número de velas para análise
   string              m_symbol;           // Símbolo atual
   bool                m_initialized;      // Flag de inicialização

   // Configurações e instâncias dos indicadores
   SIndicatorConfig    m_cfg[];
   CIndicatorBase*     m_indicators[];
   string              m_names[];

   bool                ValidateParameters();
   void                CleanUp();

public:
                     TF_CTX(ENUM_TIMEFRAMES timeframe, int num_candles, SIndicatorConfig &cfg[]);
                    ~TF_CTX();

   bool             Init();
   bool             Update();
   double           GetIndicatorValue(string name, int shift=0);
   bool             CopyIndicatorValues(string name, int shift, int count, double &buffer[]);
  };

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
TF_CTX::TF_CTX(ENUM_TIMEFRAMES timeframe, int num_candles, SIndicatorConfig &cfg[])
  {
   m_timeframe   = timeframe;
   m_num_candles = num_candles;
   m_symbol      = Symbol();
   m_initialized = false;

   int sz = ArraySize(cfg);
   ArrayResize(m_cfg, sz);
   for(int i=0;i<sz;i++)
      m_cfg[i] = cfg[i];

   ArrayResize(m_indicators,0);
   ArrayResize(m_names,0);
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
   if(!ValidateParameters())
      return false;

   for(int i=0;i<ArraySize(m_cfg);i++)
     {
      if(!m_cfg[i].enabled)
         continue;

      CIndicatorBase *ind=NULL;

      if(m_cfg[i].type=="MA")
        {
         ind = new CMovingAverages();
         if(ind==NULL || !ind.Init(m_symbol, m_timeframe, m_cfg[i].period, m_cfg[i].method))
           {
            Print("ERRO: Falha ao inicializar indicador ", m_cfg[i].name);
            delete ind;
            CleanUp();
            return false;
           }
        }
      else if(m_cfg[i].type=="STO")
        {
         ind = new CStochastic();
         if(ind==NULL || !((CStochastic*)ind).Init(m_symbol, m_timeframe,
                                                  m_cfg[i].period,
                                                  m_cfg[i].dperiod,
                                                  m_cfg[i].slowing,
                                                  m_cfg[i].method,
                                                  m_cfg[i].price_field))
           {
            Print("ERRO: Falha ao inicializar indicador ", m_cfg[i].name);
            delete ind;
            CleanUp();
            return false;
           }
        }
      else if(m_cfg[i].type=="VOL")
        {
         ind = new CVolume();
         if(ind==NULL || !ind.Init(m_symbol, m_timeframe, m_cfg[i].shift, m_cfg[i].method))
           {
            Print("ERRO: Falha ao inicializar indicador ", m_cfg[i].name);
            delete ind;
            CleanUp();
            return false;
           }
        }
      else if(m_cfg[i].type=="BOLL")
        {
         ind = new CBollinger();
         if(ind==NULL || !((CBollinger*)ind).Init(m_symbol, m_timeframe,
                                                 m_cfg[i].period,
                                                 m_cfg[i].shift,
                                                 m_cfg[i].deviation,
                                                 m_cfg[i].applied_price))
           {
            Print("ERRO: Falha ao inicializar indicador ", m_cfg[i].name);
            delete ind;
            CleanUp();
            return false;
           }
        }
      else if(m_cfg[i].type=="FIBO")
        {
         ind = new CFibonacci();
         if(ind==NULL || !((CFibonacci*)ind).Init(m_symbol, m_timeframe,
                                                m_cfg[i].period,
                                                m_cfg[i].level_1,
                                                m_cfg[i].level_2,
                                                m_cfg[i].level_3,
                                                m_cfg[i].level_4,
                                                m_cfg[i].level_5,
                                                m_cfg[i].level_6,
                                                m_cfg[i].levels_color))
           {
            Print("ERRO: Falha ao inicializar indicador ", m_cfg[i].name);
            delete ind;
            CleanUp();
            return false;
           }
        }
      else
        {
         Print("Tipo de indicador nao suportado: ", m_cfg[i].type);
         continue;
        }

      int pos=ArraySize(m_indicators);
      ArrayResize(m_indicators,pos+1);
      ArrayResize(m_names,pos+1);
      m_indicators[pos]=ind;
      m_names[pos]=m_cfg[i].name;
     }

   m_initialized = true;
   return true;
  }

//+------------------------------------------------------------------+
//| Validar parâmetros                                               |
//+------------------------------------------------------------------+
bool TF_CTX::ValidateParameters()
  {
   if(m_timeframe < PERIOD_M1 || m_timeframe > PERIOD_MN1)
     {
      Print("ERRO: TimeFrame invalido: ", EnumToString(m_timeframe));
      return false;
     }
   if(StringLen(m_symbol)==0)
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
   for(int i=0;i<ArraySize(m_indicators);i++)
     {
      if(m_indicators[i]!=NULL)
        delete m_indicators[i];
     }
   ArrayResize(m_indicators,0);
   ArrayResize(m_names,0);
   ArrayResize(m_cfg,0);
   m_initialized=false;
  }

//+------------------------------------------------------------------+
//| Obter valor do indicador                                         |
//+------------------------------------------------------------------+
double TF_CTX::GetIndicatorValue(string name, int shift)
  {
   for(int i=0;i<ArraySize(m_names);i++)
      if(m_names[i]==name && m_indicators[i]!=NULL)
         return m_indicators[i].GetValue(shift);
   Print("Indicador nao encontrado: ", name);
   return 0.0;
  }

//+------------------------------------------------------------------+
//| Copiar valores do indicador                                      |
//+------------------------------------------------------------------+
bool TF_CTX::CopyIndicatorValues(string name, int shift, int count, double &buffer[])
  {
   for(int i=0;i<ArraySize(m_names);i++)
      if(m_names[i]==name && m_indicators[i]!=NULL)
         return m_indicators[i].CopyValues(shift,count,buffer);
   Print("Indicador nao encontrado: ", name);
   return false;
  }

//+------------------------------------------------------------------+
//| Atualizar contexto                                               |
//+------------------------------------------------------------------+
bool TF_CTX::Update()
  {
   if(!m_initialized)
     return false;

  bool ready=true;
  for(int i=0;i<ArraySize(m_indicators);i++)
     if(m_indicators[i]!=NULL)
        ready &= m_indicators[i].Update();
  return ready;
  }

//+------------------------------------------------------------------+
