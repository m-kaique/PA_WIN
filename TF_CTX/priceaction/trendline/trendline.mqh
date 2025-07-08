//+------------------------------------------------------------------+
//|                                                trendline.mqh     |
//|  Trend line price action                                         |
//+------------------------------------------------------------------+
#ifndef __TRENDLINE_MQH__
#define __TRENDLINE_MQH__

#include "../priceaction_base.mqh"
#include "trendline_defs.mqh"
#include "../../config_types.mqh"

// mínimo de ângulo para que uma linha de tendência seja considerada válida
#define MIN_TRENDLINE_ANGLE 20.0

class CTrendLine : public CPriceActionBase
{
private:
  string m_symbol;
  ENUM_TIMEFRAMES m_timeframe;
  int m_period;
  int m_pivot_left;
  int m_pivot_right;
  bool m_draw_lta;
  bool m_draw_ltb;
  color m_lta_color;
  color m_ltb_color;
  ENUM_LINE_STYLE m_lta_style;
  ENUM_LINE_STYLE m_ltb_style;
  int m_lta_width;
  int m_ltb_width;
  bool m_extend_right;
  bool m_show_labels;
  ENUM_TIMEFRAMES m_alert_tf;
  bool m_breakdown;
  bool m_breakup;

  bool m_ready;
  double m_lta_val;
  double m_ltb_val;
  double m_lta_angle;
  double m_ltb_angle;

  string m_obj_lta;
  string m_obj_ltb;

  // persistent buffers for price data
  double m_highs[];
  double m_lows[];
  double m_opens[];
  double m_closes[];

  void DrawLines(datetime t1, double p1, datetime t2, double p2,
                 ENUM_TRENDLINE_SIDE side);
  //+------------------------------------------------------------------+
  //| Calcula o slope entre dois pontos de tempo/preço                  |
  //+------------------------------------------------------------------+
  double CTrendLine::CalcSlope(datetime t1, double p1, datetime t2, double p2)
  {
    if (t1 == t2)
      return 0.0;
    return (p2 - p1) / (double)(t2 - t1);
  }

public:
  CTrendLine();
  ~CTrendLine();

  bool Init(string symbol, ENUM_TIMEFRAMES timeframe, CTrendLineConfig &cfg);
  virtual bool Init(string symbol, ENUM_TIMEFRAMES timeframe, int period);
  virtual double GetValue(int shift = 0); // returns LTA value
  virtual bool CopyValues(int shift, int count, double &buffer[]);
  virtual bool IsReady();
  virtual bool Update();

  double GetLTAValue(int shift = 0);
  double GetLTBValue(int shift = 0);
  bool IsLTAValid();
  bool IsLTBValid();
  bool IsBreakdown();
  bool IsBreakup();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CTrendLine::CTrendLine()
{
  m_symbol = "";
  m_timeframe = PERIOD_CURRENT;
  m_period = 20;
  m_pivot_left = 3;
  m_pivot_right = 3;
  m_draw_lta = true;
  m_draw_ltb = true;
  m_lta_color = clrGreen;
  m_ltb_color = clrRed;
  m_lta_style = STYLE_SOLID;
  m_ltb_style = STYLE_SOLID;
  m_lta_width = 1;
  m_ltb_width = 1;
  m_extend_right = true;
  m_show_labels = false;
  m_alert_tf = PERIOD_H1;
  m_breakdown = false;
  m_breakup = false;
  m_ready = false;
  m_lta_val = 0.0;
  m_ltb_val = 0.0;
  m_lta_angle = 0.0;
  m_ltb_angle = 0.0;
  m_obj_lta = "";
  m_obj_ltb = "";
  ArrayResize(m_highs, 0);
  ArrayResize(m_lows, 0);
  ArrayResize(m_opens, 0);
  ArrayResize(m_closes, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CTrendLine::~CTrendLine()
{
  if (StringLen(m_obj_lta) > 0)
    ObjectDelete(0, m_obj_lta);
  if (StringLen(m_obj_ltb) > 0)
    ObjectDelete(0, m_obj_ltb);
}


//+------------------------------------------------------------------+
//| Init using config                                                 |
//+------------------------------------------------------------------+
bool CTrendLine::Init(string symbol, ENUM_TIMEFRAMES timeframe, CTrendLineConfig &cfg)
{
  m_symbol = symbol;
  m_timeframe = timeframe;
  m_period = cfg.period;
  m_pivot_left = cfg.pivot_left;
  m_pivot_right = cfg.pivot_right;
  m_draw_lta = cfg.draw_lta;
  m_draw_ltb = cfg.draw_ltb;
  m_lta_color = cfg.lta_color;
  m_ltb_color = cfg.ltb_color;
  m_lta_style = cfg.lta_style;
  m_ltb_style = cfg.ltb_style;
  m_lta_width = cfg.lta_width;
  m_ltb_width = cfg.ltb_width;
  m_extend_right = cfg.extend_right;
  m_show_labels = cfg.show_labels;
  m_alert_tf = cfg.alert_tf;

  bool ok = true;
  m_obj_lta = "TL_LTA_" + IntegerToString(GetTickCount());
  m_obj_ltb = "TL_LTB_" + IntegerToString(GetTickCount());
  int bars = m_period > 0 ? m_period : 50;
  ArrayResize(m_highs, bars);
  ArrayResize(m_lows, bars);
  ArrayResize(m_opens, bars);
  ArrayResize(m_closes, 2); // only need last two closes
  ArraySetAsSeries(m_highs, true);
  ArraySetAsSeries(m_lows, true);
  ArraySetAsSeries(m_opens, true);
  ArraySetAsSeries(m_closes, true);
  m_lta_angle = 0.0;
  m_ltb_angle = 0.0;
  return ok;
}

//+------------------------------------------------------------------+
//| Default init                                                      |
//+------------------------------------------------------------------+
bool CTrendLine::Init(string symbol, ENUM_TIMEFRAMES timeframe, int period)
{
  CTrendLineConfig tmp;
  tmp.period = period;
  return Init(symbol, timeframe, tmp);
}

//+------------------------------------------------------------------+
//| GetValue (LTA)                                                    |
//+------------------------------------------------------------------+
double CTrendLine::GetValue(int shift)
{
  return GetLTAValue(shift);
}

//+------------------------------------------------------------------+
//| CopyValues                                                        |
//+------------------------------------------------------------------+
bool CTrendLine::CopyValues(int shift, int count, double &buffer[])
{
  ArrayResize(buffer, count);
  for (int i = 0; i < count; i++)
    buffer[i] = GetValue(shift + i);
  return true;
}

//+------------------------------------------------------------------+
//| Ready                                                             |
//+------------------------------------------------------------------+
bool CTrendLine::IsReady()
{
  return m_ready;
}

//+------------------------------------------------------------------+
//| Draw trend line                                                   |
//+------------------------------------------------------------------+
void CTrendLine::DrawLines(datetime t1, double p1, datetime t2, double p2, ENUM_TRENDLINE_SIDE side)
{
  string name = (side == TRENDLINE_LTA) ? m_obj_lta : m_obj_ltb;
  color col = (side == TRENDLINE_LTA) ? m_lta_color : m_ltb_color;
  ENUM_LINE_STYLE st = (side == TRENDLINE_LTA) ? m_lta_style : m_ltb_style;
  int width = (side == TRENDLINE_LTA) ? m_lta_width : m_ltb_width;
  if (ObjectFind(0, name) < 0)
    ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
  else
    ObjectMove(0, name, 0, t1, p1);
  ObjectMove(0, name, 1, t2, p2);
  ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, m_extend_right);
  ObjectSetInteger(0, name, OBJPROP_COLOR, col);
  ObjectSetInteger(0, name, OBJPROP_STYLE, st);
  ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
}

//+------------------------------------------------------------------+
//| Update trend line values                                          |
//+------------------------------------------------------------------+
bool CTrendLine::Update()
  {
   int bars = m_period > 0 ? m_period : 50;
   int got_high = CopyHigh(m_symbol, m_timeframe, 0, bars, m_highs);
   int got_low  = CopyLow(m_symbol, m_timeframe, 0, bars, m_lows);
   if(got_high < bars || got_low < bars)
     {
      m_ready=false;
      return false;
     }

   int up1=-1, up2=-1, lo1=-1, lo2=-1;

   for(int i=m_pivot_right; i<bars-m_pivot_left; i++)
     {
      bool isHigh=true;
      for(int j=1;j<=m_pivot_left && isHigh;j++)
         if(m_highs[i]<=m_highs[i+j]) isHigh=false;
      for(int j=1;j<=m_pivot_right && isHigh;j++)
         if(m_highs[i]<m_highs[i-j]) isHigh=false;
      if(isHigh){ up1=i; break; }
     }

   for(int i=up1+m_pivot_right+1; i<bars-m_pivot_left; i++)
     {
      bool isHigh=true;
      for(int j=1;j<=m_pivot_left && isHigh;j++)
         if(m_highs[i]<=m_highs[i+j]) isHigh=false;
      for(int j=1;j<=m_pivot_right && isHigh;j++)
         if(m_highs[i]<m_highs[i-j]) isHigh=false;
      if(isHigh){ up2=i; break; }
     }

   for(int i=m_pivot_right; i<bars-m_pivot_left; i++)
     {
      bool isLow=true;
      for(int j=1;j<=m_pivot_left && isLow;j++)
         if(m_lows[i]>=m_lows[i+j]) isLow=false;
      for(int j=1;j<=m_pivot_right && isLow;j++)
         if(m_lows[i]>m_lows[i-j]) isLow=false;
      if(isLow){ lo1=i; break; }
     }

   for(int i=lo1+m_pivot_right+1; i<bars-m_pivot_left; i++)
     {
      bool isLow=true;
      for(int j=1;j<=m_pivot_left && isLow;j++)
         if(m_lows[i]>=m_lows[i+j]) isLow=false;
      for(int j=1;j<=m_pivot_right && isLow;j++)
         if(m_lows[i]>m_lows[i-j]) isLow=false;
      if(isLow){ lo2=i; break; }
     }

  m_ready=false;
  m_lta_val=0.0;
  m_ltb_val=0.0;
  m_lta_angle=0.0;
  m_ltb_angle=0.0;

  if(up1>0 && up2>0)
    {
      datetime t1=iTime(m_symbol,m_timeframe,up1);
      datetime t2=iTime(m_symbol,m_timeframe,up2);
      double p1=m_highs[up1];
      double p2=m_highs[up2];
      double ltb_slope=CalcSlope(t2,p2,t1,p1);
      m_ltb_angle=MathArctan(MathAbs(ltb_slope))*180.0/M_PI;
      if(m_draw_ltb && ltb_slope<0 && m_ltb_angle>=MIN_TRENDLINE_ANGLE)
        {
         m_ltb_val=p1 + (p1-p2)/(t1-t2)*(t1 - iTime(m_symbol,m_timeframe,0));
         DrawLines(t2,p2,t1,p1,TRENDLINE_LTB);
         m_ready=true;
        }
      else if(ObjectFind(0,m_obj_ltb)>=0)
        {
         ObjectDelete(0,m_obj_ltb);
        }
    }

  if(lo1>0 && lo2>0)
    {
      datetime t1=iTime(m_symbol,m_timeframe,lo1);
      datetime t2=iTime(m_symbol,m_timeframe,lo2);
      double p1=m_lows[lo1];
      double p2=m_lows[lo2];
      double lta_slope=CalcSlope(t2,p2,t1,p1);
      m_lta_angle=MathArctan(MathAbs(lta_slope))*180.0/M_PI;
      if(m_draw_lta && lta_slope>0 && m_lta_angle>=MIN_TRENDLINE_ANGLE)
        {
         m_lta_val=p1 + (p1-p2)/(t1-t2)*(t1 - iTime(m_symbol,m_timeframe,0));
         DrawLines(t2,p2,t1,p1,TRENDLINE_LTA);
         m_ready=true;
        }
      else if(ObjectFind(0,m_obj_lta)>=0)
        {
         ObjectDelete(0,m_obj_lta);
        }
    }

   datetime ct[];
   ArrayResize(ct,2);
   ArraySetAsSeries(ct,true);

   if(CopyClose(m_symbol,m_alert_tf,0,2,m_closes) > 0 &&
      CopyTime(m_symbol,m_alert_tf,0,2,ct) > 0)
     {
      double sup=ObjectGetValueByTime(0,m_obj_lta,ct[1]);
      double res=ObjectGetValueByTime(0,m_obj_ltb,ct[1]);
      m_breakdown=(m_closes[1] < sup);
      m_breakup  =(m_closes[1] > res);
     }

   return m_ready;
  }

//+------------------------------------------------------------------+
//| LTA value                                                         |
//+------------------------------------------------------------------+
double CTrendLine::GetLTAValue(int shift)
{
  if (shift == 0)
    return m_lta_val;
  datetime t = iTime(m_symbol, m_alert_tf, shift);
  if (t == 0)
    return 0.0;
  double val = ObjectGetValueByTime(0, m_obj_lta, t);
  return val;
}

//+------------------------------------------------------------------+
//| LTB value                                                         |
//+------------------------------------------------------------------+
double CTrendLine::GetLTBValue(int shift)
{
  if (shift == 0)
    return m_ltb_val;
  datetime t = iTime(m_symbol, m_alert_tf, shift);
  if (t == 0)
    return 0.0;
  double val = ObjectGetValueByTime(0, m_obj_ltb, t);
  return val;
}

//+------------------------------------------------------------------+
//| Valid flags                                                       |
//+------------------------------------------------------------------+
bool CTrendLine::IsLTAValid() { return (m_lta_val != 0.0 && m_lta_angle >= MIN_TRENDLINE_ANGLE); }
bool CTrendLine::IsLTBValid() { return (m_ltb_val != 0.0 && m_ltb_angle >= MIN_TRENDLINE_ANGLE); }
bool CTrendLine::IsBreakdown() { return m_breakdown; }
bool CTrendLine::IsBreakup() { return m_breakup; }

#endif // __TRENDLINE_MQH__
