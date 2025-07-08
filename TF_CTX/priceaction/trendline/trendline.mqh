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

  // informações da LTA ativa
  bool     m_lta_active;
  datetime m_lta_t1; // pivô mais antigo
  datetime m_lta_t2; // pivô mais recente
  double   m_lta_p1;
  double   m_lta_p2;
  datetime m_lta_last_break;

  // informações da LTB ativa
  bool     m_ltb_active;
  datetime m_ltb_t1;
  datetime m_ltb_t2;
  double   m_ltb_p1;
  double   m_ltb_p2;
  datetime m_ltb_last_break;

  void DrawLines(datetime t1, double p1, datetime t2, double p2,
                 ENUM_TRENDLINE_SIDE side);
  void RemoveLine(ENUM_TRENDLINE_SIDE side);
  bool CheckBreakLTA();
  bool CheckBreakLTB();
  bool FindNewPivotsLTA(int &idx1,int &idx2,double &p1,double &p2);
  bool FindNewPivotsLTB(int &idx1,int &idx2,double &p1,double &p2);
  void UpdateTrendlineLTA();
  void UpdateTrendlineLTB();
  //+------------------------------------------------------------------+
  //| Calcula o slope entre dois pontos usando índices de barra         |
  //+------------------------------------------------------------------+
  double CTrendLine::CalcSlope(int idx1, double p1, int idx2, double p2)
  {
    if (idx1 == idx2)
      return 0.0;
    return (p2 - p1) / (double)(idx1 - idx2);
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
  m_lta_active=false; m_ltb_active=false;
  m_lta_t1=0; m_lta_t2=0; m_lta_p1=0.0; m_lta_p2=0.0; m_lta_last_break=0;
  m_ltb_t1=0; m_ltb_t2=0; m_ltb_p1=0.0; m_ltb_p2=0.0; m_ltb_last_break=0;
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
  m_lta_active=false; m_ltb_active=false;
  m_lta_t1=0; m_lta_t2=0; m_lta_p1=0.0; m_lta_p2=0.0; m_lta_last_break=0;
  m_ltb_t1=0; m_ltb_t2=0; m_ltb_p1=0.0; m_ltb_p2=0.0; m_ltb_last_break=0;
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

void CTrendLine::RemoveLine(ENUM_TRENDLINE_SIDE side)
{
  string name = (side == TRENDLINE_LTA) ? m_obj_lta : m_obj_ltb;
  if(ObjectFind(0,name) >= 0)
     ObjectDelete(0,name);
}

bool CTrendLine::CheckBreakLTA()
{
  if(!m_lta_active)
     return false;
  datetime t=iTime(m_symbol,m_alert_tf,1);
  if(t==0)
     return false;
  double val=ObjectGetValueByTime(0,m_obj_lta,t);
  if(iClose(m_symbol,m_alert_tf,1) < val)
    {
      RemoveLine(TRENDLINE_LTA);
      m_lta_active=false;
      m_lta_last_break=t;
      m_lta_val=0.0;
      m_lta_angle=0.0;
      return true;
    }
  return false;
}

bool CTrendLine::CheckBreakLTB()
{
  if(!m_ltb_active)
     return false;
  datetime t=iTime(m_symbol,m_alert_tf,1);
  if(t==0)
     return false;
  double val=ObjectGetValueByTime(0,m_obj_ltb,t);
  if(iClose(m_symbol,m_alert_tf,1) > val)
    {
      RemoveLine(TRENDLINE_LTB);
      m_ltb_active=false;
      m_ltb_last_break=t;
      m_ltb_val=0.0;
      m_ltb_angle=0.0;
      return true;
    }
  return false;
}

bool CTrendLine::FindNewPivotsLTB(int &idx_recent,int &idx_old,double &p_recent,double &p_old)
{
  int bars = m_period > 0 ? m_period : 50;
  idx_recent=-1; idx_old=-1;
  for(int i=m_pivot_right; i<bars-m_pivot_left; i++)
  {
     bool isHigh=true;
     for(int j=1;j<=m_pivot_left && isHigh;j++)
        if(m_highs[i]<=m_highs[i+j]) isHigh=false;
     for(int j=1;j<=m_pivot_right && isHigh;j++)
        if(m_highs[i]<m_highs[i-j]) isHigh=false;
     if(isHigh)
       {
        datetime tt=iTime(m_symbol,m_timeframe,i);
        if(tt<=m_ltb_last_break) continue;
        idx_recent=i; p_recent=m_highs[i];
        break;
       }
  }
  for(int i=idx_recent+m_pivot_right+1; i<bars-m_pivot_left; i++)
  {
     bool isHigh=true;
     for(int j=1;j<=m_pivot_left && isHigh;j++)
        if(m_highs[i]<=m_highs[i+j]) isHigh=false;
     for(int j=1;j<=m_pivot_right && isHigh;j++)
        if(m_highs[i]<m_highs[i-j]) isHigh=false;
     if(isHigh)
       {
        datetime tt=iTime(m_symbol,m_timeframe,i);
        if(tt<=m_ltb_last_break) continue;
        idx_old=i; p_old=m_highs[i];
        break;
       }
  }
  return (idx_recent>0 && idx_old>0);
}

bool CTrendLine::FindNewPivotsLTA(int &idx_recent,int &idx_old,double &p_recent,double &p_old)
{
  int bars = m_period > 0 ? m_period : 50;
  idx_recent=-1; idx_old=-1;
  for(int i=m_pivot_right; i<bars-m_pivot_left; i++)
  {
     bool isLow=true;
     for(int j=1;j<=m_pivot_left && isLow;j++)
        if(m_lows[i]>=m_lows[i+j]) isLow=false;
     for(int j=1;j<=m_pivot_right && isLow;j++)
        if(m_lows[i]>m_lows[i-j]) isLow=false;
     if(isLow)
       {
        datetime tt=iTime(m_symbol,m_timeframe,i);
        if(tt<=m_lta_last_break) continue;
        idx_recent=i; p_recent=m_lows[i];
        break;
       }
  }
  for(int i=idx_recent+m_pivot_right+1; i<bars-m_pivot_left; i++)
  {
     bool isLow=true;
     for(int j=1;j<=m_pivot_left && isLow;j++)
        if(m_lows[i]>=m_lows[i+j]) isLow=false;
     for(int j=1;j<=m_pivot_right && isLow;j++)
        if(m_lows[i]>m_lows[i-j]) isLow=false;
     if(isLow)
       {
        datetime tt=iTime(m_symbol,m_timeframe,i);
        if(tt<=m_lta_last_break) continue;
        idx_old=i; p_old=m_lows[i];
        break;
       }
  }
  return (idx_recent>0 && idx_old>0);
}

void CTrendLine::UpdateTrendlineLTB()
{
  if(m_ltb_active)
  {
     if(CheckBreakLTB())
        return;
     int idx_old=iBarShift(m_symbol,m_timeframe,m_ltb_t1,true);
     int idx_new=iBarShift(m_symbol,m_timeframe,m_ltb_t2,true);
     double slope=CalcSlope(idx_old,m_ltb_p1,idx_new,m_ltb_p2);
     m_ltb_val=m_ltb_p2 - slope*idx_new;
     return;
  }

  int idx_new,idx_old; double p_new,p_old;
  if(FindNewPivotsLTB(idx_new,idx_old,p_new,p_old))
    {
      int id_old=idx_old; int id_new=idx_new;
      double open_old=iOpen(m_symbol,m_timeframe,id_old);
      double close_old=iClose(m_symbol,m_timeframe,id_old);
      double base_old=(MathAbs(open_old-p_old)<MathAbs(close_old-p_old)?open_old:close_old);
      double slope=CalcSlope(id_old,base_old,id_new,p_new);
      double angle=MathArctan2(p_new-base_old,id_new-id_old)*180.0/M_PI;
      if(angle<0) angle=-angle;
      if(m_draw_ltb && slope<0 && angle>=MIN_TRENDLINE_ANGLE)
        {
         datetime t1=iTime(m_symbol,m_timeframe,id_old);
         datetime t2=iTime(m_symbol,m_timeframe,id_new);
         DrawLines(t1,base_old,t2,p_new,TRENDLINE_LTB);
         m_ltb_active=true;
         m_ltb_angle=angle;
         m_ltb_t1=t1; m_ltb_t2=t2; m_ltb_p1=base_old; m_ltb_p2=p_new;
         m_ltb_val=p_new - slope*id_new;
        }
    }
}

void CTrendLine::UpdateTrendlineLTA()
{
  if(m_lta_active)
  {
     if(CheckBreakLTA())
        return;
     int idx_old=iBarShift(m_symbol,m_timeframe,m_lta_t1,true);
     int idx_new=iBarShift(m_symbol,m_timeframe,m_lta_t2,true);
     double slope=CalcSlope(idx_old,m_lta_p1,idx_new,m_lta_p2);
     m_lta_val=m_lta_p2 - slope*idx_new;
     return;
  }

  int idx_new,idx_old; double p_new,p_old;
  if(FindNewPivotsLTA(idx_new,idx_old,p_new,p_old))
    {
      int id_old=idx_old; int id_new=idx_new;
      double open_old=iOpen(m_symbol,m_timeframe,id_old);
      double close_old=iClose(m_symbol,m_timeframe,id_old);
      double base_old=(MathAbs(open_old-p_old)<MathAbs(close_old-p_old)?open_old:close_old);
      double slope=CalcSlope(id_old,base_old,id_new,p_new);
      double angle=MathArctan2(p_new-base_old,id_new-id_old)*180.0/M_PI;
      if(angle<0) angle=-angle;
      if(m_draw_lta && slope>0 && angle>=MIN_TRENDLINE_ANGLE)
        {
         datetime t1=iTime(m_symbol,m_timeframe,id_old);
         datetime t2=iTime(m_symbol,m_timeframe,id_new);
         DrawLines(t1,base_old,t2,p_new,TRENDLINE_LTA);
         m_lta_active=true;
         m_lta_angle=angle;
         m_lta_t1=t1; m_lta_t2=t2; m_lta_p1=base_old; m_lta_p2=p_new;
         m_lta_val=p_new - slope*id_new;
        }
    }
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

   UpdateTrendlineLTB();
   UpdateTrendlineLTA();

   datetime ct[];
   ArrayResize(ct,2);
   ArraySetAsSeries(ct,true);
   m_breakdown=false;
   m_breakup=false;
   if(CopyClose(m_symbol,m_alert_tf,0,2,m_closes)>0 &&
      CopyTime(m_symbol,m_alert_tf,0,2,ct)>0)
     {
      if(m_lta_active)
        {
         double sup=ObjectGetValueByTime(0,m_obj_lta,ct[1]);
         m_breakdown=(m_closes[1]<sup);
        }
      if(m_ltb_active)
        {
         double res=ObjectGetValueByTime(0,m_obj_ltb,ct[1]);
         m_breakup=(m_closes[1]>res);
        }
     }

   m_ready=(m_lta_active || m_ltb_active);
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
