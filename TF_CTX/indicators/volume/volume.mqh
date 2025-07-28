//+------------------------------------------------------------------+
//|                                    indicators/volume.mqh         |
//|  Simple Volume indicator derived from CIndicatorBase             |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.01"

#include "../indicator_base/indicator_base.mqh"
#include "../../config_types.mqh"
#include "volume_defs.mqh"

//+------------------------------------------------------------------+
//| Classe para acesso ao volume                                     |
//+------------------------------------------------------------------+
class CVolume : public CIndicatorBase
  {
private:
   int             m_base_shift;   // Shift base configurado

public:
                     CVolume();
                    ~CVolume();

  bool             Init(string symbol, ENUM_TIMEFRAMES timeframe,
                        int base_shift, ENUM_MA_METHOD method);
  bool             Init(string symbol, ENUM_TIMEFRAMES timeframe,
                        CVolumeConfig &config);

  virtual double   GetValue(int shift=0);
  virtual bool     CopyValues(int shift, int count, double &buffer[]);
  virtual bool     IsReady();
  virtual bool     Update() override;
  };

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CVolume::CVolume()
  {
   m_symbol="";
   m_timeframe=PERIOD_CURRENT;
   m_base_shift=0;
  }

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CVolume::~CVolume()
  {
  }

//+------------------------------------------------------------------+
//| Inicialização                                                    |
//+------------------------------------------------------------------+
bool CVolume::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                   int base_shift, ENUM_MA_METHOD method)
  {
   m_symbol      = symbol;
   m_timeframe   = timeframe;
   m_base_shift  = base_shift;
   return true; // nenhuma inicialização necessária
  }

bool CVolume::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                   CVolumeConfig &config)
  {
   return Init(symbol, timeframe, config.shift, MODE_SMA);
  }

//+------------------------------------------------------------------+
//| Obter valor de volume                                            |
//+------------------------------------------------------------------+
double CVolume::GetValue(int shift)
  {
   int index = m_base_shift + shift;
   long vol = iVolume(m_symbol, m_timeframe, index);
   return (double)vol;
  }

//+------------------------------------------------------------------+
//| Copiar valores de volume                                         |
//+------------------------------------------------------------------+
bool CVolume::CopyValues(int shift, int count, double &buffer[])
  {
   ArrayResize(buffer,count);
   ArraySetAsSeries(buffer,true);
   for(int i=0;i<count;i++)
      buffer[i]=(double)iVolume(m_symbol, m_timeframe, m_base_shift + shift + i);
   return true;
  }

//+------------------------------------------------------------------+
//| Verificar se o volume está pronto                                |
//+------------------------------------------------------------------+
bool CVolume::IsReady()
  {
   return (Bars(m_symbol,m_timeframe) > m_base_shift);
  }

//+------------------------------------------------------------------+
//| Atualizacao simples (sem handle)                                  |
//+------------------------------------------------------------------+
bool CVolume::Update()
  {
   return IsReady();
  }

