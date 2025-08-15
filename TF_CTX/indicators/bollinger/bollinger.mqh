//+------------------------------------------------------------------+
//|                                    indicators/bollinger.mqh      |
//|  Bollinger Bands indicator derived from CIndicatorBase           |
//+------------------------------------------------------------------+
#ifndef __BOLLINGER_MQH__
#define __BOLLINGER_MQH__

#include "../indicator_base/indicator_base.mqh"
#include "../../config_types.mqh"
#include "bollinger_defs.mqh"

class CBollinger : public CIndicatorBase
{
private:
  int m_period;
  int m_shift;
  double m_deviation;
  ENUM_APPLIED_PRICE m_price;

  bool CreateHandle();
  void ReleaseHandle();
  double GetBufferValue(int buffer_index, int shift = 0);
  virtual bool OnCopyValuesForSlope(int shift, int count, double &buffer[], COPY_METHOD copy_method) override;
  virtual double OnGetIndicatorValue(int shift, COPY_METHOD copy_method) override;

public:
  CBollinger();
  ~CBollinger();

  bool Init(string symbol, ENUM_TIMEFRAMES timeframe,
            int period, int shift, double deviation,
            ENUM_APPLIED_PRICE price);

  bool Init(string symbol, ENUM_TIMEFRAMES timeframe,
            CBollingerConfig &config);

  // Compatibilidade com interface base
  virtual bool Init(string symbol, ENUM_TIMEFRAMES timeframe,
                    int period, ENUM_MA_METHOD method);

  virtual double GetValue(int shift = 0); // Middle band
  double GetUpper(int shift = 0);
  double GetLower(int shift = 0);

  virtual bool CopyValues(int shift, int count, double &buffer[]); // middle
  bool CopyUpper(int shift, int count, double &buffer[]);
  bool CopyLower(int shift, int count, double &buffer[]);

  virtual bool IsReady();
  virtual bool Update() override;
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CBollinger::CBollinger()
{
  m_symbol = "";
  m_timeframe = PERIOD_CURRENT;
  m_period = 20;
  m_shift = 0;
  m_deviation = 2.0;
  m_price = PRICE_CLOSE;
  handle = INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CBollinger::~CBollinger()
{
  ReleaseHandle();
}

//+------------------------------------------------------------------+
//| Init with full parameters                                        |
//+------------------------------------------------------------------+
bool CBollinger::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                      int period, int shift, double deviation,
                      ENUM_APPLIED_PRICE price)
{
  m_symbol = symbol;
  m_timeframe = timeframe;
  m_period = period;
  m_shift = shift;
  m_deviation = deviation;
  m_price = price;

  ReleaseHandle();
  return CreateHandle();
}

//+------------------------------------------------------------------+
//| Interface base implementation (uses defaults)                    |
//+------------------------------------------------------------------+
bool CBollinger::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                      int period, ENUM_MA_METHOD method)
{
  // method parameter not used; default shift 0, deviation 2, PRICE_CLOSE
  return Init(symbol, timeframe, period, 0, 2.0, PRICE_CLOSE);
}

bool CBollinger::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                      CBollingerConfig &config)
{
  attach_chart = config.attach_chart;
  slope_values = config.slope_values[0];
  return Init(symbol, timeframe, config.period, config.shift,
              config.deviation, config.applied_price);
}

//+------------------------------------------------------------------+
//| Create indicator handle                                          |
//+------------------------------------------------------------------+
bool CBollinger::CreateHandle()
{
  handle = iBands(m_symbol, m_timeframe, m_period, m_shift, m_deviation, m_price);
  if (handle == INVALID_HANDLE)
  {
    Print("ERRO: Falha ao criar handle Bollinger para ", m_symbol);
    return false;
  }
  return true;
}

//+------------------------------------------------------------------+
//| Release handle                                                   |
//+------------------------------------------------------------------+
void CBollinger::ReleaseHandle()
{
  if (handle != INVALID_HANDLE)
  {
    IndicatorRelease(handle);
    handle = INVALID_HANDLE;
  }
}

//+------------------------------------------------------------------+
//| Get buffer value                                                 |
//+------------------------------------------------------------------+
double CBollinger::GetBufferValue(int buffer_index, int shift)
{
  if (handle == INVALID_HANDLE)
    return 0.0;
  double buf[];
  ArraySetAsSeries(buf, true);
  if (CopyBuffer(handle, buffer_index, shift, 1, buf) <= 0)
    return 0.0;
  return buf[0];
}

//+------------------------------------------------------------------+
//| Middle band (buffer 2)                                           |
//+------------------------------------------------------------------+
double CBollinger::GetValue(int shift)
{
  return GetBufferValue(0, shift);
}

//+------------------------------------------------------------------+
//| Upper band (buffer 0)                                            |
//+------------------------------------------------------------------+
double CBollinger::GetUpper(int shift)
{
  return GetBufferValue(1, shift);
}

//+------------------------------------------------------------------+
//| Lower band (buffer 1)                                            |
//+------------------------------------------------------------------+
double CBollinger::GetLower(int shift)
{
  return GetBufferValue(2, shift);
}

//+------------------------------------------------------------------+
//| Copy middle band values                                          |
//+------------------------------------------------------------------+
bool CBollinger::CopyValues(int shift, int count, double &buffer[])
{
  if (handle == INVALID_HANDLE)
    return false;
  ArrayResize(buffer, count);
  ArraySetAsSeries(buffer, true);
  return CopyBuffer(handle, 0, shift, count, buffer) > 0;
}

//+------------------------------------------------------------------+
//| Copy upper band values                                           |
//+------------------------------------------------------------------+
bool CBollinger::CopyUpper(int shift, int count, double &buffer[])
{
  if (handle == INVALID_HANDLE)
    return false;
  ArrayResize(buffer, count);
  ArraySetAsSeries(buffer, true);
  return CopyBuffer(handle, 1, shift, count, buffer) > 0;
}

//+------------------------------------------------------------------+
//| Copy lower band values                                           |
//+------------------------------------------------------------------+
bool CBollinger::CopyLower(int shift, int count, double &buffer[])
{
  if (handle == INVALID_HANDLE)
    return false;
  ArrayResize(buffer, count);
  ArraySetAsSeries(buffer, true);
  return CopyBuffer(handle, 2, shift, count, buffer) > 0;
}

//+------------------------------------------------------------------+
//| Check readiness                                                  |
//+------------------------------------------------------------------+
bool CBollinger::IsReady()
{
  return (BarsCalculated(handle) > 0);
}

//+------------------------------------------------------------------+
//| Recreate handle if necessary                                      |
//+------------------------------------------------------------------+
bool CBollinger::Update()
{
  if (handle == INVALID_HANDLE)
    return CreateHandle();

  if (BarsCalculated(handle) <= 0)
    return false;

  return true;
}


//+------------------------------------------------------------------+
//| Implementação do método template para copiar valores para o cálculo de inclinação |
//+------------------------------------------------------------------+
bool CBollinger::OnCopyValuesForSlope(int shift, int count, double &buffer[], COPY_METHOD copy_method)
{
  if (handle == INVALID_HANDLE)
    return false;

  switch (copy_method)
  {
  case COPY_LOWER:
    return CopyLower(shift, count, buffer);

  case COPY_UPPER:
    return CopyUpper(shift, count, buffer);

  case COPY_MIDDLE:
    return CopyValues(shift, count, buffer);

  default:
    Print("ERRO: Método de cópia inválido");
    return false;
  }
};

 //+------------------------------------------------------------------+
//| Implementação do método template para obter o valor do indicador |
//+------------------------------------------------------------------+
double CBollinger::OnGetIndicatorValue(int shift, COPY_METHOD copy_method)
{
  if (copy_method == COPY_LOWER)
  {
    return GetLower(shift);
  }
  else if (copy_method == COPY_UPPER)
  {
    return GetUpper(shift);
  }
  else
  {
    return GetValue(shift);
  }
}

#endif // __BOLLINGER_MQH__
