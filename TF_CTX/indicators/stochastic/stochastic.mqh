//+------------------------------------------------------------------+
//|                                 indicators/stochastic.mqh        |
//|  Implementation of Stochastic indicator derived from CIndicatorBase |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.01"

#include "../indicator_base.mqh"
#include "../../config_types.mqh"
#include "stochastic_defs.mqh"

//+------------------------------------------------------------------+
//| Classe para cálculo do Estocástico                               |
//+------------------------------------------------------------------+
class CStochastic : public CIndicatorBase
  {
private:
   int             m_kperiod;      // Período %K
   int             m_dperiod;      // Período %D
   int             m_slowing;      // Slowing
   ENUM_MA_METHOD  m_ma_method;    // Método de média
   ENUM_STO_PRICE  m_price_field;  // Campo de preço

   bool            CreateIndicatorHandle();
   void            ReleaseIndicatorHandle();
   double          GetBufferValue(int buffer_index, int shift=0);

public:
                     CStochastic();
                    ~CStochastic();

   // Inicialização específica com todos os parâmetros
  bool            Init(string symbol, ENUM_TIMEFRAMES timeframe,
                       int kperiod, int dperiod, int slowing,
                       ENUM_MA_METHOD ma_method, ENUM_STO_PRICE price_field);

  bool            Init(string symbol, ENUM_TIMEFRAMES timeframe,
                       CStochasticConfig &config);

   // Implementação da interface base (usa valores padrão para dperiod/slowing)
   virtual bool    Init(string symbol, ENUM_TIMEFRAMES timeframe,
                        int period, ENUM_MA_METHOD method);

   virtual double  GetValue(int shift=0);      // %K por padrão
   double          GetSignalValue(int shift=0); // %D

  virtual bool    CopyValues(int shift, int count, double &buffer[]);      // %K
  bool            CopySignalValues(int shift, int count, double &buffer[]); // %D

  virtual bool    IsReady();
  virtual bool    Update() override;
  };

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CStochastic::CStochastic()
  {
   m_symbol  = "";
   m_timeframe = PERIOD_CURRENT;
   m_kperiod = 0;
   m_dperiod = 0;
   m_slowing = 0;
   m_ma_method = MODE_SMA;
   m_price_field = STO_LOWHIGH;
   handle = INVALID_HANDLE;
  }

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CStochastic::~CStochastic()
  {
   ReleaseIndicatorHandle();
  }

//+------------------------------------------------------------------+
//| Inicialização completa                                           |
//+------------------------------------------------------------------+
bool CStochastic::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                       int kperiod, int dperiod, int slowing,
                       ENUM_MA_METHOD ma_method, ENUM_STO_PRICE price_field)
  {
   m_symbol      = symbol;
   m_timeframe   = timeframe;
   m_kperiod     = kperiod;
   m_dperiod     = dperiod;
   m_slowing     = slowing;
   m_ma_method   = ma_method;
   m_price_field = price_field;

   ReleaseIndicatorHandle();
   return CreateIndicatorHandle();
}

bool CStochastic::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                       CStochasticConfig &config)
  {
   return Init(symbol, timeframe, config.period, config.dperiod,
               config.slowing, config.method, config.price_field);
  }

//+------------------------------------------------------------------+
//| Implementação compatível com a interface base                    |
//+------------------------------------------------------------------+
bool CStochastic::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                       int period, ENUM_MA_METHOD method)
  {
   // Usa valores padrões de 3 para dperiod e slowing e campo Low/High
   return Init(symbol, timeframe, period, 3, 3, method, STO_LOWHIGH);
  }

//+------------------------------------------------------------------+
//| Criar handle do indicador                                        |
//+------------------------------------------------------------------+
bool CStochastic::CreateIndicatorHandle()
  {
   handle = iStochastic(m_symbol, m_timeframe, m_kperiod, m_dperiod,
                          m_slowing, m_ma_method, m_price_field);
   if(handle == INVALID_HANDLE)
     {
      Print("ERRO: Falha ao criar handle Stochastic para ", m_symbol);
      return false;
     }

   Print("Indicador Stochastic inicializado para ", m_symbol,
         " - ", EnumToString(m_timeframe),
         " - K:", m_kperiod,
         " D:", m_dperiod,
         " Slowing:", m_slowing);
   return true;
  }

//+------------------------------------------------------------------+
//| Liberar handle                                                   |
//+------------------------------------------------------------------+
void CStochastic::ReleaseIndicatorHandle()
  {
   if(handle != INVALID_HANDLE)
     {
      IndicatorRelease(handle);
      handle = INVALID_HANDLE;
     }
  }

//+------------------------------------------------------------------+
//| Obter valor de buffer                                            |
//+------------------------------------------------------------------+
double CStochastic::GetBufferValue(int buffer_index, int shift)
  {
   if(handle == INVALID_HANDLE)
     {
      Print("ERRO: Handle do Stochastic inválido");
      return 0.0;
     }

   double buffer[];
   ArraySetAsSeries(buffer, true);

   if(CopyBuffer(handle, buffer_index, shift, 1, buffer) <= 0)
     {
      Print("ERRO: Falha ao copiar dados do Stochastic");
      return 0.0;
     }

   return buffer[0];
  }

//+------------------------------------------------------------------+
//| Valor %K                                                         |
//+------------------------------------------------------------------+
double CStochastic::GetValue(int shift)
  {
   return GetBufferValue(0, shift);
  }

//+------------------------------------------------------------------+
//| Valor %D                                                         |
//+------------------------------------------------------------------+
double CStochastic::GetSignalValue(int shift)
  {
   return GetBufferValue(1, shift);
  }

//+------------------------------------------------------------------+
//| Copiar valores %K                                                |
//+------------------------------------------------------------------+
bool CStochastic::CopyValues(int shift, int count, double &buffer[])
  {
   if(handle == INVALID_HANDLE)
     {
      Print("ERRO: Handle do Stochastic inválido");
      return false;
     }
   ArrayResize(buffer, count);
   ArraySetAsSeries(buffer, true);
   if(CopyBuffer(handle, 0, shift, count, buffer) <= 0)
     {
      Print("ERRO: Falha ao copiar dados do Stochastic");
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Copiar valores %D                                                |
//+------------------------------------------------------------------+
bool CStochastic::CopySignalValues(int shift, int count, double &buffer[])
  {
   if(handle == INVALID_HANDLE)
     {
      Print("ERRO: Handle do Stochastic inválido");
      return false;
     }
   ArrayResize(buffer, count);
   ArraySetAsSeries(buffer, true);
   if(CopyBuffer(handle, 1, shift, count, buffer) <= 0)
     {
      Print("ERRO: Falha ao copiar dados do Stochastic");
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Verificar se indicador está pronto                               |
//+------------------------------------------------------------------+
bool CStochastic::IsReady()
  {
   return (BarsCalculated(handle) > 0);
  }

//+------------------------------------------------------------------+
//| Validate handle and refresh buffers                               |
//+------------------------------------------------------------------+
bool CStochastic::Update()
  {
   if(handle==INVALID_HANDLE)
      return CreateIndicatorHandle();

   if(BarsCalculated(handle)<=0)
      return false;

   return true;
  }


//+------------------------------------------------------------------+
