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
  double m_lta2_val;
  double m_ltb2_val;
  double m_lta_angle;
  double m_ltb_angle;
  double m_lta2_angle;
  double m_ltb2_angle;

  string m_obj_lta;
  string m_obj_ltb;
  string m_obj_lta2;
  string m_obj_ltb2;

  // persistent buffers for price data
  double m_highs[];
  double m_lows[];
  double m_opens[];
  double m_closes[];

  // informações da LTA ativa
  bool     m_lta_active;
  bool     m_lta2_active;
  datetime m_lta_t1; // pivô mais antigo
  datetime m_lta_t2; // pivô mais recente
  double   m_lta_p1;
  double   m_lta_p2;
  double   m_lta2_p2;
  datetime m_lta_last_break;

  // informações da LTB ativa
  bool     m_ltb_active;
  bool     m_ltb2_active;
  datetime m_ltb_t1;
  datetime m_ltb_t2;
  double   m_ltb_p1;
  double   m_ltb_p2;
  double   m_ltb2_p2;
  datetime m_ltb_last_break;

  void DrawLines(datetime t1, double p1, datetime t2, double p2,
                 ENUM_TRENDLINE_SIDE side);
  void RemoveLine(ENUM_TRENDLINE_SIDE side);
  bool CheckBreakLTA();
  bool CheckBreakLTB();
  bool FindNewPivots(const double &buffer[],int &idx1,int &idx2,double &p1,double &p2,
                     int left,int right,datetime last_break,bool isHigh);
  void UpdateTrendlineLTA();
  void UpdateTrendlineLTB();
  void CalculateBases(int idx_old,int idx_new,double p_old,double p_new,
                      double &base_old,double &base_new);
  void CalculateMetrics(int idx_old,int idx_new,double base_old,double p_new,double base_new,
                        double &slope,double &slope2,double &angle,double &angle2);
  void ResetLTA();
  void ResetLTB();
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
  double GetLTA2Value(int shift = 0);
  double GetLTB2Value(int shift = 0);
  bool IsLTAValid();
  bool IsLTBValid();
  bool IsLTA2Valid();
  bool IsLTB2Valid();
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
  m_lta2_val = 0.0;
  m_ltb2_val = 0.0;
  m_lta_angle = 0.0;
  m_ltb_angle = 0.0;
  m_lta2_angle = 0.0;
  m_ltb2_angle = 0.0;
  m_obj_lta = "";
  m_obj_ltb = "";
  m_obj_lta2 = "";
  m_obj_ltb2 = "";
  ArrayResize(m_highs, 0);
  ArrayResize(m_lows, 0);
  ArrayResize(m_opens, 0);
  ArrayResize(m_closes, 0);
  ResetLTA();
  ResetLTB();
  m_lta_last_break=0;
  m_ltb_last_break=0;
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
  if (StringLen(m_obj_lta2) > 0)
    ObjectDelete(0, m_obj_lta2);
  if (StringLen(m_obj_ltb2) > 0)
    ObjectDelete(0, m_obj_ltb2);
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
  m_obj_lta2 = "TL_LTA2_" + IntegerToString(GetTickCount());
  m_obj_ltb2 = "TL_LTB2_" + IntegerToString(GetTickCount());
  int bars = m_period > 0 ? m_period : 50;
  ArrayResize(m_highs, bars);
  ArrayResize(m_lows, bars);
  ArrayResize(m_opens, bars);
  ArrayResize(m_closes, 2); // only need last two closes
  ArraySetAsSeries(m_highs, true);
  ArraySetAsSeries(m_lows, true);
  ArraySetAsSeries(m_opens, true);
  ArraySetAsSeries(m_closes, true);
  m_lta_angle = 0.0;   m_lta2_angle = 0.0;
  m_ltb_angle = 0.0;   m_ltb2_angle = 0.0;
  ResetLTA();
  ResetLTB();
  m_lta_last_break=0;
  m_ltb_last_break=0;
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
  string name;
  color col;
  ENUM_LINE_STYLE st;
  int width;
  switch(side)
  {
    case TRENDLINE_LTA:
      name=m_obj_lta; col=m_lta_color; st=m_lta_style; width=m_lta_width; break;
    case TRENDLINE_LTB:
      name=m_obj_ltb; col=m_ltb_color; st=m_ltb_style; width=m_ltb_width; break;
    case TRENDLINE_LTA2:
      name=m_obj_lta2; col=m_lta_color; st=m_lta_style; width=m_lta_width; break;
    case TRENDLINE_LTB2:
      name=m_obj_ltb2; col=m_ltb_color; st=m_ltb_style; width=m_ltb_width; break;
    default:
      name=""; col=clrWhite; st=STYLE_SOLID; width=1; break;
  }
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
  string name="";
  switch(side)
  {
    case TRENDLINE_LTA:  name=m_obj_lta;  break;
    case TRENDLINE_LTB:  name=m_obj_ltb;  break;
    case TRENDLINE_LTA2: name=m_obj_lta2; break;
    case TRENDLINE_LTB2: name=m_obj_ltb2; break;
    default:             name="";         break;
  }
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
      ResetLTA();
      m_lta_last_break=t;
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
      ResetLTB();
      m_ltb_last_break=t;
      return true;
    }
  return false;
}

bool CTrendLine::FindNewPivots(const double &buffer[],int &idx_recent,int &idx_old,double &p_recent,double &p_old,
                               int left,int right,datetime last_break,bool isHigh)
{
  int bars=m_period>0?m_period:50;
  idx_recent=-1; idx_old=-1;
  for(int i=right; i<bars-left; i++)
  {
     bool pivot=true;
     for(int j=1;j<=left && pivot;j++)
        if(isHigh?buffer[i]<=buffer[i+j]:buffer[i]>=buffer[i+j]) pivot=false;
     for(int j=1;j<=right && pivot;j++)
        if(isHigh?buffer[i]<buffer[i-j]:buffer[i]>buffer[i-j]) pivot=false;
     if(pivot)
       {
        datetime tt=iTime(m_symbol,m_timeframe,i);
        if(tt<=last_break) continue;
        idx_recent=i; p_recent=buffer[i];
        break;
       }
  }
  for(int i=idx_recent+right+1; i<bars-left; i++)
  {
     bool pivot=true;
     for(int j=1;j<=left && pivot;j++)
        if(isHigh?buffer[i]<=buffer[i+j]:buffer[i]>=buffer[i+j]) pivot=false;
     for(int j=1;j<=right && pivot;j++)
        if(isHigh?buffer[i]<buffer[i-j]:buffer[i]>buffer[i-j]) pivot=false;
     if(pivot)
       {
        datetime tt=iTime(m_symbol,m_timeframe,i);
        if(tt<=last_break) continue;
        idx_old=i; p_old=buffer[i];
        break;
       }
  }
  return (idx_recent>0 && idx_old>0);
}

void CTrendLine::CalculateBases(int idx_old,int idx_new,double p_old,double p_new,
                                double &base_old,double &base_new)
{
  double open_old=iOpen(m_symbol,m_timeframe,idx_old);
  double close_old=iClose(m_symbol,m_timeframe,idx_old);
  base_old=(MathAbs(open_old-p_old)<MathAbs(close_old-p_old)?open_old:close_old);
  double open_new=iOpen(m_symbol,m_timeframe,idx_new);
  double close_new=iClose(m_symbol,m_timeframe,idx_new);
  base_new=(MathAbs(open_new-p_new)<MathAbs(close_new-p_new)?open_new:close_new);
}

void CTrendLine::CalculateMetrics(int idx_old,int idx_new,double base_old,double p_new,double base_new,
                                  double &slope,double &slope2,double &angle,double &angle2)
{
  slope=CalcSlope(idx_old,base_old,idx_new,p_new);
  slope2=CalcSlope(idx_old,base_old,idx_new,base_new);
  angle=MathArctan2(p_new-base_old,idx_new-idx_old)*180.0/M_PI;
  angle2=MathArctan2(base_new-base_old,idx_new-idx_old)*180.0/M_PI;
  if(angle<0) angle=-angle;
  if(angle2<0) angle2=-angle2;
}

void CTrendLine::ResetLTA()
{
  RemoveLine(TRENDLINE_LTA);
  RemoveLine(TRENDLINE_LTA2);
  m_lta_active=false; m_lta2_active=false;
  m_lta_t1=0; m_lta_t2=0; m_lta_p1=0.0; m_lta_p2=0.0; m_lta2_p2=0.0;
  m_lta_val=0.0; m_lta2_val=0.0;
  m_lta_angle=0.0; m_lta2_angle=0.0;
}

void CTrendLine::ResetLTB()
{
  RemoveLine(TRENDLINE_LTB);
  RemoveLine(TRENDLINE_LTB2);
  m_ltb_active=false; m_ltb2_active=false;
  m_ltb_t1=0; m_ltb_t2=0; m_ltb_p1=0.0; m_ltb_p2=0.0; m_ltb2_p2=0.0;
  m_ltb_val=0.0; m_ltb2_val=0.0;
  m_ltb_angle=0.0; m_ltb2_angle=0.0;
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
     double slope2=CalcSlope(idx_old,m_ltb_p1,idx_new,m_ltb2_p2);
     m_ltb_val=m_ltb_p2 - slope*idx_new;
     m_ltb2_val=m_ltb2_p2 - slope2*idx_new;
     return;
  }

  int idx_new,idx_old; double p_new,p_old;
  if(FindNewPivots(m_highs,idx_new,idx_old,p_new,p_old,
                    m_pivot_left,m_pivot_right,m_ltb_last_break,true))
    {
      int id_old=idx_old; int id_new=idx_new;
      double base_old,base_new;
      CalculateBases(id_old,id_new,p_old,p_new,base_old,base_new);
      double slope,slope2,angle,angle2;
      CalculateMetrics(id_old,id_new,base_old,p_new,base_new,slope,slope2,angle,angle2);
      if(m_draw_ltb && slope<0 && angle>=MIN_TRENDLINE_ANGLE)
        {
         datetime t1=iTime(m_symbol,m_timeframe,id_old);
         datetime t2=iTime(m_symbol,m_timeframe,id_new);
         DrawLines(t1,base_old,t2,p_new,TRENDLINE_LTB);
         DrawLines(t1,base_old,t2,base_new,TRENDLINE_LTB2);
         m_ltb_active=true;
         m_ltb2_active=true;
         m_ltb_angle=angle;
         m_ltb2_angle=angle2;
         m_ltb_t1=t1; m_ltb_t2=t2; m_ltb_p1=base_old; m_ltb_p2=p_new;
         m_ltb2_p2=base_new;
         m_ltb_val=p_new - slope*id_new;
         m_ltb2_val=base_new - slope2*id_new;
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
     double slope2=CalcSlope(idx_old,m_lta_p1,idx_new,m_lta2_p2);
     m_lta_val=m_lta_p2 - slope*idx_new;
     m_lta2_val=m_lta2_p2 - slope2*idx_new;
     return;
  }

  int idx_new,idx_old; double p_new,p_old;
  if(FindNewPivots(m_lows,idx_new,idx_old,p_new,p_old,
                    m_pivot_left,m_pivot_right,m_lta_last_break,false))
    {
      int id_old=idx_old; int id_new=idx_new;
      double base_old,base_new;
      CalculateBases(id_old,id_new,p_old,p_new,base_old,base_new);
      double slope,slope2,angle,angle2;
      CalculateMetrics(id_old,id_new,base_old,p_new,base_new,slope,slope2,angle,angle2);
      if(m_draw_lta && slope>0 && angle>=MIN_TRENDLINE_ANGLE)
        {
         datetime t1=iTime(m_symbol,m_timeframe,id_old);
         datetime t2=iTime(m_symbol,m_timeframe,id_new);
         DrawLines(t1,base_old,t2,p_new,TRENDLINE_LTA);
         DrawLines(t1,base_old,t2,base_new,TRENDLINE_LTA2);
         m_lta_active=true;
         m_lta2_active=true;
         m_lta_angle=angle;
         m_lta2_angle=angle2;
         m_lta_t1=t1; m_lta_t2=t2; m_lta_p1=base_old; m_lta_p2=p_new;
         m_lta2_p2=base_new;
         m_lta_val=p_new - slope*id_new;
         m_lta2_val=base_new - slope2*id_new;
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
//| LTA2 value                                                        |
//+------------------------------------------------------------------+
double CTrendLine::GetLTA2Value(int shift)
{
  if(shift==0)
     return m_lta2_val;
  datetime t=iTime(m_symbol,m_alert_tf,shift);
  if(t==0)
     return 0.0;
  double val=ObjectGetValueByTime(0,m_obj_lta2,t);
  return val;
}

//+------------------------------------------------------------------+
//| LTB2 value                                                        |
//+------------------------------------------------------------------+
double CTrendLine::GetLTB2Value(int shift)
{
  if(shift==0)
     return m_ltb2_val;
  datetime t=iTime(m_symbol,m_alert_tf,shift);
  if(t==0)
     return 0.0;
  double val=ObjectGetValueByTime(0,m_obj_ltb2,t);
  return val;
}

//+------------------------------------------------------------------+
//| Valid flags                                                       |
//+------------------------------------------------------------------+
bool CTrendLine::IsLTAValid() { return (m_lta_val != 0.0 && m_lta_angle >= MIN_TRENDLINE_ANGLE); }
bool CTrendLine::IsLTBValid() { return (m_ltb_val != 0.0 && m_ltb_angle >= MIN_TRENDLINE_ANGLE); }
bool CTrendLine::IsLTA2Valid() { return (m_lta2_val != 0.0 && m_lta2_angle >= MIN_TRENDLINE_ANGLE); }
bool CTrendLine::IsLTB2Valid() { return (m_ltb2_val != 0.0 && m_ltb2_angle >= MIN_TRENDLINE_ANGLE); }
bool CTrendLine::IsBreakdown() { return m_breakdown; }
bool CTrendLine::IsBreakup() { return m_breakup; }

#endif // __TRENDLINE_MQH__
