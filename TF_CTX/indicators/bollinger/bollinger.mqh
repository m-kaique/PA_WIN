//+------------------------------------------------------------------+
//|                                    indicators/bollinger.mqh      |
//|  Bollinger Bands indicator derived from CIndicatorBase           |
//+------------------------------------------------------------------+
#ifndef __BOLLINGER_MQH__
#define __BOLLINGER_MQH__

#include "../indicator_base/indicator_base.mqh"
#include "../indicators_types.mqh"
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
  virtual int OnGetSlopeConfigIndex(COPY_METHOD copy_method) override;

  // Helpers para estatística e regressão sobre arrays em série (índice 0 = barra mais recente)
  static double LR_SlopeSeries(const double &series[], int count)
  {
    if (count < 2)
      return 0.0;

    // x = 0..count-1 (cronológico: 0 = mais antigo)
    // series está como "series", então invertimos o índice: series[count-1-i] = mais antigo -> mais recente
    double sumx = (count - 1) * count * 0.5;
    double sumx2 = (count - 1) * count * (2.0 * count - 1.0) / 6.0;
    double sumy = 0.0, sumxy = 0.0;

    for (int i = 0; i < count; ++i)
    {
      double y = series[count - 1 - i];
      sumy += y;
      sumxy += i * y;
    }

    double denom = count * sumx2 - sumx * sumx;
    if (denom == 0.0)
      return 0.0;
    return (count * sumxy - sumx * sumy) / denom; // unidades: preço por barra
  }

  static void MeanStdSeries(const double &series[], int count, double &mean, double &stdev)
  {
    if (count <= 0)
    {
      mean = 0.0;
      stdev = 0.0;
      return;
    }
    double sum = 0.0;
    for (int i = 0; i < count; ++i)
      sum += series[i];
    mean = sum / (double)count;

    if (count < 2)
    {
      stdev = 0.0;
      return;
    }
    double var = 0.0;
    for (int i = 0; i < count; ++i)
    {
      double d = series[i] - mean;
      var += d * d;
    }
    var /= (double)(count - 1);
    stdev = MathSqrt(var);
  }

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

  // Largura instantânea e cópia da largura
  double GetWidth(int shift = 0)
  {
    return GetUpper(shift) - GetLower(shift);
  }

  bool CopyWidth(int shift, int count, double &buffer[])
  {
    double up[], lo[];
    if (!CopyUpper(shift, count, up))
      return false;
    if (!CopyLower(shift, count, lo))
      return false;

    ArrayResize(buffer, count);
    ArraySetAsSeries(buffer, true);
    for (int i = 0; i < count; ++i)
      buffer[i] = up[i] - lo[i];
    return true;
  }

  // Núcleo: computa movimento (direção + vol) em uma janela
  // slope_lookback: janelas 14–20 são comuns
  // width_lookback: pode ser igual a slope_lookback
  // slope_eps: limiar para filtrar ruído (ex.: 0 para começar; ou 0.1*Point() etc.)
  // squeeze_z: z-score negativo para squeeze (ex.: 1.0)
  bool ComputeMovement(int shift,
                       int slope_lookback,
                       int width_lookback,
                       double slope_eps,
                       double squeeze_z,
                       SBollingerMovement &out)
  {
    if (handle == INVALID_HANDLE)
      return false;
    if (slope_lookback < 2 || width_lookback < 2)
      return false;

    // Copiamos apenas o necessário
    double mid[], up[], lo[], w[];
    if (!CopyValues(shift, slope_lookback, mid))
      return false;
    if (!CopyUpper(shift, slope_lookback, up))
      return false;
    if (!CopyLower(shift, slope_lookback, lo))
      return false;

    // Largura para janelas de slope e estatística
    if (!CopyWidth(shift, width_lookback, w))
      return false;

    // Slopes (regressão linear sobre arrays em série)
    out.slope_middle = LR_SlopeSeries(mid, slope_lookback);
    out.slope_upper = LR_SlopeSeries(up, slope_lookback);
    out.slope_lower = LR_SlopeSeries(lo, slope_lookback);

    // Métricas de largura
    out.width = w[0];
    out.slope_width = LR_SlopeSeries(w, width_lookback);
    MeanStdSeries(w, width_lookback, out.width_mean, out.width_stdev);
    out.width_zscore = (out.width_stdev > 0.0) ? ((out.width - out.width_mean) / out.width_stdev) : 0.0;

    // Direção
    if (out.slope_middle > slope_eps)
      out.dir = BOLL_DIR_UP;
    else if (out.slope_middle < -slope_eps)
      out.dir = BOLL_DIR_DOWN;
    else
      out.dir = BOLL_DIR_FLAT;

    // Volatilidade (expansão/contração) + squeeze
    if (out.width_zscore <= -MathAbs(squeeze_z))
      out.vol = BOLL_VOL_SQUEEZE;
    else if (out.slope_width > slope_eps)
      out.vol = BOLL_VOL_EXPANDING;
    else if (out.slope_width < -slope_eps)
      out.vol = BOLL_VOL_CONTRACTING;
    else
      out.vol = BOLL_VOL_STABLE;

    return true;
  }
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
  ArrayCopy(slope_values, config.slope_values);
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
    // Print("ERRO: Falha ao criar handle Bollinger para ", m_symbol);
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
  return GetBufferValue(BASE_LINE, shift);
}

//+------------------------------------------------------------------+
//| Upper band (buffer 0)                                            |
//+------------------------------------------------------------------+
double CBollinger::GetUpper(int shift)
{
  return GetBufferValue(UPPER_BAND, shift);
}

//+------------------------------------------------------------------+
//| Lower band (buffer 1)                                            |
//+------------------------------------------------------------------+
double CBollinger::GetLower(int shift)
{
  return GetBufferValue(LOWER_BAND, shift);
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
  return CopyBuffer(handle, BASE_LINE, shift, count, buffer) > 0;
}

//+------------------------------------------------------------------+
//| Copy upper band values                                           |
//+------------------------------------------------------------------+
bool CBollinger::CopyUpper(int shift, int count, double &buffer[])
{
  // 0 - BASE_LINE, 1 - UPPER_BAND, 2 - LOWER_BAND
  if (handle == INVALID_HANDLE)
    return false;
  ArrayResize(buffer, count);
  ArraySetAsSeries(buffer, true);
  return CopyBuffer(handle, UPPER_BAND, shift, count, buffer) > 0;
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
  return CopyBuffer(handle, LOWER_BAND, shift, count, buffer) > 0;
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

  // Print("METODO DE COPIA: " + EnumToString(copy_method));
  switch (copy_method)
  {
  case COPY_LOWER:
    // Print("COPIANDO - LOWER");
    return CopyLower(shift, count, buffer);

  case COPY_UPPER:
    // Print("COPIANDO - UPPER");
    return CopyUpper(shift, count, buffer);

  case COPY_MIDDLE:
    // Print("COPIANDO - MIDDLE");
    return CopyValues(shift, count, buffer);

  default:
    // Print("ERRO: Método de cópia inválido");
    return false;
  }
};

//+------------------------------------------------------------------+
//| Implementação do método template para obter o valor do indicador |
//+------------------------------------------------------------------+
double CBollinger::OnGetIndicatorValue(int shift, COPY_METHOD copy_method)
{ // Print("OnGetIndicatorValue bollinger class: " + EnumToString(copy_method));
  // Print("OnGetIndicatorValue bollinger class: " + (string)(copy_method));
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

int CBollinger::OnGetSlopeConfigIndex(COPY_METHOD copy_method)
{

  if (copy_method == COPY_MIDDLE)
  {
    // Print("RETORNANDO MIDDLE");
    return 1;
  }
  else if (copy_method == COPY_UPPER)
  {
    // Print("RETORNANDO UPPER");
    return 0;
  }
  else if (copy_method == COPY_LOWER)
  {
    // Print("RETORNANDO LOWER");
    return 2;
  }

  return 1;
}

#endif // __BOLLINGER_MQH__
