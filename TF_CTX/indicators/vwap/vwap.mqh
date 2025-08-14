//+------------------------------------------------------------------+
//|                                    indicators/vwap.mqh           |
//|  Volume Weighted Average Price indicator                         |
//+------------------------------------------------------------------+
#ifndef __VWAP_MQH__
#define __VWAP_MQH__

#include "../indicator_base/indicator_base.mqh"
#include "vwap_defs.mqh"
#include "../../config_types.mqh"

class CVWAP : public CIndicatorBase
{
private:
  int m_period;
  ENUM_MA_METHOD m_method;
  color m_color;
  ENUM_LINE_STYLE m_style;
  int m_width;
  ENUM_VWAP_CALC_MODE m_calc_mode;
  ENUM_VWAP_PRICE_TYPE m_price_type;
  ENUM_TIMEFRAMES m_session_tf;
  datetime m_start_time;
  datetime m_last_calculated_time;
  double m_vwap_buffer[];

  bool CreateHandle();
  void ReleaseHandle();

  // Helpers for VWAP calculation
  bool ShouldReset(int bar_index, datetime bar_time, int bars, bool &skip);
  double CalculateBarVWAP(int index, int bars);
  int FindSessionStart(int bars);
  void UpdateAccumulation(bool reset, double price, long volume, double &cum_pv, double &cum_vol);

  bool IsNewSession(int bar_index);
  void UpdateCurrentBar();

  double TypicalPrice(int index);
  void ComputeAll();

  double CalcVWAP(int shift);

public:
  CVWAP();
  ~CVWAP();

  bool Init(string symbol, ENUM_TIMEFRAMES timeframe,
            int period, ENUM_MA_METHOD method,
            ENUM_VWAP_CALC_MODE calc_mode,
            ENUM_TIMEFRAMES session_tf,
            ENUM_VWAP_PRICE_TYPE price_type,
            datetime start_time,
            color line_color,
            ENUM_LINE_STYLE line_style = STYLE_SOLID,
            int line_width = 1);
  bool Init(string symbol, ENUM_TIMEFRAMES timeframe,
            CVWAPConfig &config);
  virtual bool Init(string symbol, ENUM_TIMEFRAMES timeframe,
                    int period, ENUM_MA_METHOD method) override;
  virtual double GetValue(int shift = 0) override;
  virtual bool CopyValues(int shift, int count, double &buffer[]) override;
  virtual bool IsReady() override;
  virtual bool Update() override;

  bool SetCalcMode(ENUM_VWAP_CALC_MODE mode)
  {
    m_calc_mode = mode;
    return true;
  }
  bool SetPriceType(ENUM_VWAP_PRICE_TYPE type)
  {
    m_price_type = type;
    return true;
  }
  bool SetSessionTimeframe(ENUM_TIMEFRAMES tf)
  {
    m_session_tf = tf;
    return true;
  }
  bool SetStartTime(datetime start)
  {
    m_start_time = start;
    return true;
  }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CVWAP::CVWAP()
{
  m_symbol = "";
  m_timeframe = PERIOD_CURRENT;
  m_period = 1;
  m_method = MODE_SMA;
  m_color = clrAqua;
  m_style = STYLE_SOLID;
  m_width = 1;
  m_calc_mode = VWAP_CALC_BAR;
  m_price_type = VWAP_PRICE_FINANCIAL_AVERAGE;
  m_session_tf = PERIOD_D1;
  m_start_time = 0;
  m_last_calculated_time = 0;
  ArrayResize(m_vwap_buffer, 0);
  handle = INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CVWAP::~CVWAP()
{
  ReleaseHandle();
  ArrayResize(m_vwap_buffer, 0);
  ArrayFree(m_vwap_buffer);
}

bool CVWAP::CreateHandle()
{
  handle = iCustom(m_symbol, m_timeframe, "TF_CTX/indicators/vwap/vwap_indicator.ex5", m_period, m_calc_mode, m_session_tf, m_price_type, m_start_time);
  if (handle == INVALID_HANDLE)
  {
    Print("ERRO: Falha ao criar handle do VWAP para ", m_symbol);
    return false;
  }

  // ChartIndicatorAdd(0, 0, handle);

  return true;
}

void CVWAP::ReleaseHandle()
{
  if (handle != INVALID_HANDLE)
  {
    IndicatorRelease(handle);
    handle = INVALID_HANDLE;
  }
}

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
void CVWAP::UpdateAccumulation(bool reset, double price, long volume, double &cum_pv, double &cum_vol)
{
  if (reset)
  {
    cum_pv = price * volume;
    cum_vol = (double)volume;
  }
  else
  {
    cum_pv += price * volume;
    cum_vol += (double)volume;
  }
}

double CVWAP::CalculateBarVWAP(int index, int bars)
{
  double sum_pv = 0.0;
  double sum_vol = 0.0;
  int start_bar = MathMin(index + m_period - 1, bars - 1);
  for (int j = start_bar; j >= index; j--)
  {
    double p = TypicalPrice(j);
    long v = iVolume(m_symbol, m_timeframe, j);
    sum_pv += p * v;
    sum_vol += (double)v;
  }
  return (sum_vol != 0) ? sum_pv / sum_vol : EMPTY_VALUE;
}

bool CVWAP::ShouldReset(int bar_index, datetime bar_time, int bars, bool &skip)
{
  skip = false;
  if (m_calc_mode == VWAP_CALC_PERIODIC)
    return IsNewSession(bar_index);
  if (m_calc_mode == VWAP_CALC_FROM_DATE)
  {
    if (bar_time < m_start_time)
    {
      skip = true;
      return false;
    }
    if (bar_index == bars - 1 || iTime(m_symbol, m_timeframe, bar_index + 1) < m_start_time)
      return true;
  }
  return false;
}

int CVWAP::FindSessionStart(int bars)
{
  int session_start = 0;
  for (int j = 1; j < bars; j++)
  {
    if (m_calc_mode == VWAP_CALC_PERIODIC && IsNewSession(j - 1))
    {
      session_start = j - 1;
      break;
    }
    if (m_calc_mode == VWAP_CALC_FROM_DATE && iTime(m_symbol, m_timeframe, j) < m_start_time)
    {
      session_start = j - 1;
      break;
    }
  }
  return session_start;
}

//+------------------------------------------------------------------+
//| Initialization with full parameters                              |
//+------------------------------------------------------------------+
bool CVWAP::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                 int period, ENUM_MA_METHOD method,
                 ENUM_VWAP_CALC_MODE calc_mode,
                 ENUM_TIMEFRAMES session_tf,
                 ENUM_VWAP_PRICE_TYPE price_type,
                 datetime start_time,
                 color line_color,
                 ENUM_LINE_STYLE line_style,
                 int line_width)
{
  if (StringLen(symbol) == 0)
    return false;
  m_symbol = symbol;
  m_timeframe = timeframe;
  m_method = method;
  m_period = MathMax(1, period);
  m_calc_mode = calc_mode;
  m_price_type = price_type;
  m_session_tf = session_tf;
  m_start_time = start_time;
  m_color = line_color;
  m_style = line_style;
  m_width = line_width;
  m_last_calculated_time = 0;
  ArrayResize(m_vwap_buffer, 0);
  ReleaseHandle();
  return CreateHandle();
}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CVWAP::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                 int period, ENUM_MA_METHOD method)
{
  return Init(symbol, timeframe, period, method,
              VWAP_CALC_BAR, PERIOD_D1,
              VWAP_PRICE_FINANCIAL_AVERAGE, 0, clrAqua,
              STYLE_SOLID, 1);
}

bool CVWAP::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                 CVWAPConfig &config)
{
  attach_chart = config.attach_chart; // Atribui a flag do config
  slope_values = config.slope_values;
  
  return Init(symbol, timeframe, config.period, config.method,
              config.calc_mode, config.session_tf, config.price_type,
              config.start_time, config.line_color,
              config.line_style, config.line_width);
}

//+------------------------------------------------------------------+
//| Calculate VWAP for given shift                                   |
//+------------------------------------------------------------------+
double CVWAP::CalcVWAP(int shift)
{
  if (ArraySize(m_vwap_buffer) <= shift)
    return EMPTY_VALUE;
  return m_vwap_buffer[shift];
}

//+------------------------------------------------------------------+
//| Get single value                                                 |
//+------------------------------------------------------------------+
double CVWAP::GetValue(int shift)
{
  if (handle == INVALID_HANDLE)
    return EMPTY_VALUE;
  double buf[];
  ArraySetAsSeries(buf, true);
  if (CopyBuffer(handle, 0, shift, 1, buf) <= 0)
    return EMPTY_VALUE;
  return buf[0];
}

//+------------------------------------------------------------------+
//| Copy multiple values                                             |
//+------------------------------------------------------------------+
bool CVWAP::CopyValues(int shift, int count, double &buffer[])
{
  if (handle == INVALID_HANDLE)
    return false;
  ArrayResize(buffer, count);
  ArraySetAsSeries(buffer, true);
  return (CopyBuffer(handle, 0, shift, count, buffer) > 0);
}

//+------------------------------------------------------------------+
//| Check readiness                                                  |
//+------------------------------------------------------------------+
bool CVWAP::IsReady()
{
  return (handle != INVALID_HANDLE && BarsCalculated(handle) > 0);
}

//+------------------------------------------------------------------+
//| Calculate typical price based on selected type                    |
//+------------------------------------------------------------------+
double CVWAP::TypicalPrice(int index)
{
  double open = iOpen(m_symbol, m_timeframe, index);
  double high = iHigh(m_symbol, m_timeframe, index);
  double low = iLow(m_symbol, m_timeframe, index);
  double close = iClose(m_symbol, m_timeframe, index);

  switch (m_price_type)
  {
  case VWAP_PRICE_OPEN:
    return open;
  case VWAP_PRICE_HIGH:
    return high;
  case VWAP_PRICE_LOW:
    return low;
  case VWAP_PRICE_CLOSE:
    return close;
  case VWAP_PRICE_HL2:
    return (high + low) / 2.0;
  case VWAP_PRICE_HLC3:
    return (high + low + close) / 3.0;
  case VWAP_PRICE_OHLC4:
    return (open + high + low + close) / 4.0;
  default:
    return (high + low + close) / 3.0; // financial average
  }
}

//+------------------------------------------------------------------+
//| Recalculate entire VWAP buffer                                    |
//+------------------------------------------------------------------+
void CVWAP::ComputeAll()
{
  int bars = Bars(m_symbol, m_timeframe);
  if (bars <= 0)
    return;
  ArrayResize(m_vwap_buffer, bars);
  ArraySetAsSeries(m_vwap_buffer, true);

  double cum_pv = 0.0;
  double cum_vol = 0.0;

  for (int i = bars - 1; i >= 0; i--)
  {
    datetime bar_time = iTime(m_symbol, m_timeframe, i);
    double price = TypicalPrice(i);
    long volume = iVolume(m_symbol, m_timeframe, i);

    if (m_calc_mode == VWAP_CALC_BAR)
    {
      m_vwap_buffer[i] = CalculateBarVWAP(i, bars);
      continue;
    }

    bool skip = false;
    bool reset = ShouldReset(i, bar_time, bars, skip);
    if (skip)
    {
      m_vwap_buffer[i] = EMPTY_VALUE;
      continue;
    }

    UpdateAccumulation(reset, price, volume, cum_pv, cum_vol);
    m_vwap_buffer[i] = (cum_vol != 0) ? cum_pv / cum_vol : EMPTY_VALUE;
  }
}

//+------------------------------------------------------------------+
//| Check if bar starts a new session                                 |
//+------------------------------------------------------------------+
bool CVWAP::IsNewSession(int bar_index)
{
  if (bar_index >= Bars(m_symbol, m_timeframe) - 1)
    return true;

  datetime current_time = iTime(m_symbol, m_timeframe, bar_index);
  datetime previous_time = iTime(m_symbol, m_timeframe, bar_index + 1);

  if (m_session_tf == PERIOD_D1)
  {
    MqlDateTime cur_dt, prev_dt;
    TimeToStruct(current_time, cur_dt);
    TimeToStruct(previous_time, prev_dt);
    return (cur_dt.day != prev_dt.day);
  }
  else if (m_session_tf == PERIOD_W1)
  {
    int cur_week = (int)(current_time / (7 * 24 * 3600));
    int prev_week = (int)(previous_time / (7 * 24 * 3600));
    return (cur_week != prev_week);
  }

  return false;
}

//+------------------------------------------------------------------+
//| Update only the current bar                                       |
//+------------------------------------------------------------------+
void CVWAP::UpdateCurrentBar()
{
  int bars = Bars(m_symbol, m_timeframe);
  if (bars <= 0)
    return;

  ArrayResize(m_vwap_buffer, bars);
  ArraySetAsSeries(m_vwap_buffer, true);

  if (m_calc_mode == VWAP_CALC_BAR)
  {
    m_vwap_buffer[0] = CalculateBarVWAP(0, bars);
    return;
  }

  int session_start = FindSessionStart(bars);

  double cum_pv = 0.0;
  double cum_vol = 0.0;
  for (int j = session_start; j >= 0; j--)
  {
    double p = TypicalPrice(j);
    long v = iVolume(m_symbol, m_timeframe, j);
    cum_pv += p * v;
    cum_vol += (double)v;
  }

  m_vwap_buffer[0] = (cum_vol != 0) ? cum_pv / cum_vol : EMPTY_VALUE;
}

//+------------------------------------------------------------------+
//| Recalculate and redraw VWAP line                                 |
//+------------------------------------------------------------------+
bool CVWAP::Update()
{
  // (re)create the indicator handle when necessary
  if (handle == INVALID_HANDLE)
    if (!CreateHandle())
      return false;

  int bars = BarsCalculated(handle);
  if (bars <= 0)
    return false;

  ArraySetAsSeries(m_vwap_buffer, true);

  // First run or after parameter change - fetch all values
  if (ArraySize(m_vwap_buffer) == 0 || m_last_calculated_time == 0)
  {
    ArrayResize(m_vwap_buffer, bars);
    if (CopyBuffer(handle, 0, 0, bars, m_vwap_buffer) <= 0)
      return false;
    m_last_calculated_time = iTime(m_symbol, m_timeframe, 0);
    return true;
  }

  datetime latest_time = iTime(m_symbol, m_timeframe, 0);

  // When a new bar is available, append only its value
  if (latest_time != m_last_calculated_time)
  {
    int old_size = ArraySize(m_vwap_buffer);
    int add = bars - old_size;
    if (add < 1)
      add = 1;
    double tmp[];
    ArraySetAsSeries(tmp, true);
    if (CopyBuffer(handle, 0, 0, add, tmp) <= 0)
      return false;
    ArrayResize(m_vwap_buffer, old_size + add);
    for (int i = old_size - 1; i >= 0; i--)
      m_vwap_buffer[i + add] = m_vwap_buffer[i];
    for (int i = 0; i < add; i++)
      m_vwap_buffer[i] = tmp[i];
    m_last_calculated_time = latest_time;
    return true;
  }

  // Same bar - refresh the current value only
  double cur[];
  ArraySetAsSeries(cur, true);
  if (CopyBuffer(handle, 0, 0, 1, cur) <= 0)
    return false;
  m_vwap_buffer[0] = cur[0];

  return true;
}

#endif // __VWAP_MQH__
