//+------------------------------------------------------------------+
//|                                                sup_res.mqh       |
//|  Simple support and resistance lines                             |
//+------------------------------------------------------------------+
#ifndef __SUP_RES_MQH__
#define __SUP_RES_MQH__

#include "../priceaction_base.mqh"
#include "sup_res_defs.mqh"
#include "../../config_types.mqh"

// Structure representing a support/resistance zone
struct SRZone
  {
   double upper;   // upper price limit of the zone
   double lower;   // lower price limit of the zone
   int    touches; // number of touches inside the zone
  };

class CSupRes : public CPriceActionBase
  {
private:
   string          m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int             m_period;
   bool            m_draw_sup;
   bool            m_draw_res;
   color           m_sup_color;
   color           m_res_color;
   ENUM_LINE_STYLE m_sup_style;
   ENUM_LINE_STYLE m_res_style;
   int             m_sup_width;
   int             m_res_width;
   bool            m_extend_right;
   bool            m_show_labels;
  ENUM_TIMEFRAMES m_alert_tf;
  int             m_touch_lookback;
  double          m_touch_tolerance;
  double          m_zone_range;      // max range to group touches as one zone
  int             m_max_zones_to_draw;
  int             m_min_touches;
  ENUM_SUPRES_VALIDATION m_validation;
  bool            m_sup_valid;
  bool            m_res_valid;
  bool            m_ready;
  double          m_sup_val;
  double          m_res_val;
  bool            m_breakdown;
  bool            m_breakup;
  string          m_res_obj_names[];     // fixed object names for resistance zones
  string          m_sup_obj_names[];     // fixed object names for support zones
  int             m_prev_res_zones;      // number of resistance zones drawn previously
  int             m_prev_sup_zones;      // number of support zones drawn previously
  SRZone          m_price_zones[];       // all calculated zones
  SRZone          m_current_supports[];  // zones classified as supports
  SRZone          m_current_resistances[]; // zones classified as resistances
  // persistent buffers for price data
  double          m_highs[];
  double          m_lows[];
  double          m_opens[];
  double          m_closes[];

  void            DrawLine(string name,double price,color col,ENUM_LINE_STYLE st,int width);
  void            DrawZone(string name,double lower,double upper,color col);
  void            CalculatePriceZones(const double &highs[],const double &lows[],int bars,double range);
  void            ClassifyZones();
  bool            IsBullPinBar(const double &o[],const double &c[],const double &h[],const double &l[],int index);
  bool            IsBearPinBar(const double &o[],const double &c[],const double &h[],const double &l[],int index);
  bool            IsBullEngulf(const double &o[],const double &c[],int index);
  bool            IsBearEngulf(const double &o[],const double &c[],int index);
  bool            IsDoji(const double &o[],const double &c[],const double &h[],const double &l[],int index);
  bool            IsBullMarubozu(const double &o[],const double &c[],const double &h[],const double &l[],int index);
  bool            IsBearMarubozu(const double &o[],const double &c[],const double &h[],const double &l[],int index);
  bool            IsInsideBar(const double &h[],const double &l[],int index);
  bool            IsOutsideBar(const double &h[],const double &l[],int index);

  void            CalculateZones(int bars);
  void            DrawZones();
  void            DetectPatterns(int bars);
  void            EvaluateBreakouts();

public:
                     CSupRes();
                    ~CSupRes();

   bool             Init(string symbol,ENUM_TIMEFRAMES timeframe,CSupResConfig &cfg);
   virtual bool     Init(string symbol,ENUM_TIMEFRAMES timeframe,int period);
   virtual double   GetValue(int shift=0); // returns support value
   virtual bool     CopyValues(int shift,int count,double &buffer[]);
  virtual bool     IsReady();
  virtual bool     Update();

  double           GetSupportValue(int shift=0);
  double           GetResistanceValue(int shift=0);
  int              GetSupportZones(SRZone &zones_buffer[]);
  int              GetResistanceZones(SRZone &zones_buffer[]);
  bool             IsBreakdown();
  bool             IsBreakup();

  // Counters for touches and patterns
  int             m_sup_touches;
  int             m_res_touches;
  int             m_sup_pinbar;
  int             m_res_pinbar;
  int             m_sup_engulf;
  int             m_res_engulf;
  int             m_sup_doji;
  int             m_res_doji;
  int             m_sup_maru_bull;
  int             m_res_maru_bull;
  int             m_sup_maru_bear;
  int             m_res_maru_bear;
  int             m_sup_insidebar;
  int             m_res_insidebar;
  int             m_sup_outsidebar;
  int             m_res_outsidebar;
  };

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CSupRes::CSupRes()
  {
   m_symbol="";
   m_timeframe=PERIOD_CURRENT;
   m_period=50;
   m_draw_sup=true;
   m_draw_res=true;
   m_sup_color=clrBlue;
   m_res_color=clrRed;
   m_sup_style=STYLE_SOLID;
   m_res_style=STYLE_SOLID;
   m_sup_width=1;
   m_res_width=1;
   m_extend_right=true;
   m_show_labels=false;
  m_alert_tf=PERIOD_CURRENT;
  m_touch_lookback=20;
  m_touch_tolerance=0.0;
  m_zone_range=10.0;
  m_max_zones_to_draw=3;
  m_min_touches=2;
  m_validation=SUPRES_VALIDATE_TOUCHES;
  m_sup_touches=0;
  m_res_touches=0;
  m_sup_pinbar=0;
  m_res_pinbar=0;
  m_sup_engulf=0;
  m_res_engulf=0;
  m_sup_doji=0;
  m_res_doji=0;
  m_sup_maru_bull=0;
  m_res_maru_bull=0;
  m_sup_maru_bear=0;
  m_res_maru_bear=0;
  m_sup_insidebar=0;
  m_res_insidebar=0;
  m_sup_outsidebar=0;
  m_res_outsidebar=0;
  m_sup_valid=false;
  m_res_valid=false;
  m_ready=false;
   m_sup_val=0.0;
   m_res_val=0.0;
  m_breakdown=false;
  m_breakup=false;
  m_prev_res_zones=0;
  m_prev_sup_zones=0;
  ArrayResize(m_price_zones,0);
  ArrayResize(m_current_supports,0);
  ArrayResize(m_current_resistances,0);
  ArrayResize(m_highs,0);
  ArrayResize(m_lows,0);
  ArrayResize(m_opens,0);
  ArrayResize(m_closes,0);
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CSupRes::~CSupRes()
  {
  for(int i=0;i<ArraySize(m_res_obj_names);i++)
     if(StringLen(m_res_obj_names[i])>0)
        ObjectDelete(0,m_res_obj_names[i]);
  for(int i=0;i<ArraySize(m_sup_obj_names);i++)
     if(StringLen(m_sup_obj_names[i])>0)
        ObjectDelete(0,m_sup_obj_names[i]);
  }

//+------------------------------------------------------------------+
//| Draw horizontal line                                              |
//+------------------------------------------------------------------+
void CSupRes::DrawLine(string name,double price,color col,ENUM_LINE_STYLE st,int width)
  {
   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_HLINE,0,0,price);
   else
      ObjectSetDouble(0,name,OBJPROP_PRICE,price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,col);
   ObjectSetInteger(0,name,OBJPROP_STYLE,st);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,m_extend_right);
  }

//+------------------------------------------------------------------+
//| Draw support/resistance zone                                      |
//+------------------------------------------------------------------+
void CSupRes::DrawZone(string name,double lower,double upper,color col)
  {
   datetime t1=iTime(m_symbol,m_timeframe,m_period-1);
   datetime t2=iTime(m_symbol,m_timeframe,0);
   if(m_extend_right)
      t2 += (datetime)(PeriodSeconds(m_timeframe)*m_period*10);
   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_RECTANGLE,0,t1,lower,t2,upper);
   else
     {
      ObjectMove(0,name,0,t1,lower);
      ObjectMove(0,name,1,t2,upper);
     }
   ObjectSetInteger(0,name,OBJPROP_COLOR,col);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
  }

//+------------------------------------------------------------------+
//| Check for bullish pin bar (hammer)                                |
//+------------------------------------------------------------------+
bool CSupRes::IsBullPinBar(const double &o[],const double &c[],const double &h[],const double &l[],int index)
  {
   double body=MathAbs(o[index]-c[index]);
   double upper=h[index]-MathMax(o[index],c[index]);
   double lower=MathMin(o[index],c[index])-l[index];
   return(lower>body*2 && upper<body);
  }

//+------------------------------------------------------------------+
//| Check for bearish pin bar (shooting star)                         |
//+------------------------------------------------------------------+
bool CSupRes::IsBearPinBar(const double &o[],const double &c[],const double &h[],const double &l[],int index)
  {
   double body=MathAbs(o[index]-c[index]);
   double upper=h[index]-MathMax(o[index],c[index]);
   double lower=MathMin(o[index],c[index])-l[index];
   return(upper>body*2 && lower<body);
  }

//+------------------------------------------------------------------+
//| Check for bullish engulfing                                       |
//+------------------------------------------------------------------+
bool CSupRes::IsBullEngulf(const double &o[],const double &c[],int index)
  {
   if(index+1>=ArraySize(o))
      return false;
   double o1=o[index+1];
   double c1=c[index+1];
   double o2=o[index];
   double c2=c[index];
   return(c1<o1 && c2>o2 && c2>o1 && o2<c1);
  }

//+------------------------------------------------------------------+
//| Check for bearish engulfing                                       |
//+------------------------------------------------------------------+
bool CSupRes::IsBearEngulf(const double &o[],const double &c[],int index)
  {
   if(index+1>=ArraySize(o))
      return false;
   double o1=o[index+1];
   double c1=c[index+1];
   double o2=o[index];
   double c2=c[index];
   return(c1>o1 && c2<o2 && c2<o1 && o2>c1);
  }

//+------------------------------------------------------------------+
//| Check for doji                                                    |
//+------------------------------------------------------------------+
bool CSupRes::IsDoji(const double &o[],const double &c[],const double &h[],const double &l[],int index)
  {
   double range=h[index]-l[index];
   if(range==0.0) return false;
   double body=MathAbs(o[index]-c[index]);
   return(body<=range*0.1);
  }

//+------------------------------------------------------------------+
//| Check for bullish marubozu                                        |
//+------------------------------------------------------------------+
bool CSupRes::IsBullMarubozu(const double &o[],const double &c[],const double &h[],const double &l[],int index)
  {
   double body=c[index]-o[index];
   double upper=h[index]-c[index];
   double lower=o[index]-l[index];
   return(body>0 && upper<=body*0.1 && lower<=body*0.1);
  }

//+------------------------------------------------------------------+
//| Check for bearish marubozu                                        |
//+------------------------------------------------------------------+
bool CSupRes::IsBearMarubozu(const double &o[],const double &c[],const double &h[],const double &l[],int index)
  {
   double body=o[index]-c[index];
   double upper=h[index]-o[index];
   double lower=c[index]-l[index];
   return(body>0 && upper<=body*0.1 && lower<=body*0.1);
  }

//+------------------------------------------------------------------+
//| Check for inside bar                                              |
//+------------------------------------------------------------------+
bool CSupRes::IsInsideBar(const double &h[],const double &l[],int index)
  {
   if(index+1>=ArraySize(h))
      return false;
   return(h[index]<h[index+1] && l[index]>l[index+1]);
  }

//+------------------------------------------------------------------+
//| Check for outside bar                                             |
//+------------------------------------------------------------------+
bool CSupRes::IsOutsideBar(const double &h[],const double &l[],int index)
  {
   if(index+1>=ArraySize(h))
      return false;
   return(h[index]>h[index+1] && l[index]<l[index+1]);
  }

//+------------------------------------------------------------------+
//| Calculate price zones using highs and lows                         |
//+------------------------------------------------------------------+
void CSupRes::CalculatePriceZones(const double &highs[],const double &lows[],int bars,double range)
  {
   double pivots[];
   ArrayResize(pivots,(bars-1)*2);
   int pidx=0;
   for(int i=1;i<bars;i++)
     {
      pivots[pidx++]=highs[i];
      pivots[pidx++]=lows[i];
     }

   SRZone zones[];
   ArrayResize(zones,0);

   // Agrupa preços iniciais em zonas considerando o range
   for(int i=0;i<ArraySize(pivots);i++)
     {
      double price=pivots[i];
      bool added=false;
      for(int j=0;j<ArraySize(zones);j++)
        {
         if(price>=zones[j].lower-range && price<=zones[j].upper+range)
           {
            if(price<zones[j].lower) zones[j].lower=price;
            if(price>zones[j].upper) zones[j].upper=price;
            zones[j].touches++;
            added=true;
            break;
           }
        }
      if(!added)
        {
         int pos=ArraySize(zones);
         ArrayResize(zones,pos+1);
         zones[pos].lower=price;
         zones[pos].upper=price;
         zones[pos].touches=1;
        }
     }

   // Mescla zonas sobrepostas somando seus toques
   bool merged=true;
   while(merged)
     {
      merged=false;
      for(int i=0;i<ArraySize(zones);i++)
        {
         for(int j=i+1;j<ArraySize(zones);j++)
           {
            if(zones[i].upper>=zones[j].lower && zones[i].lower<=zones[j].upper)
              {
               zones[i].lower=MathMin(zones[i].lower,zones[j].lower);
               zones[i].upper=MathMax(zones[i].upper,zones[j].upper);
               zones[i].touches+=zones[j].touches;
               for(int k=j;k<ArraySize(zones)-1;k++)
                  zones[k]=zones[k+1];
               ArrayResize(zones,ArraySize(zones)-1);
               merged=true;
               j--; // índices ajustados
              }
           }
        }
     }

   // Ordena zonas por número de toques (decrescente)
   int n=ArraySize(zones);
   for(int i=0;i<n-1;i++)
      for(int j=i+1;j<n;j++)
         if(zones[j].touches>zones[i].touches)
           { SRZone tmp=zones[i]; zones[i]=zones[j]; zones[j]=tmp; }

   SRZone filtered[];
   ArrayResize(filtered,0);
   for(int i=0;i<n;i++)
      if(zones[i].touches>=m_min_touches)
        {
         int p=ArraySize(filtered);
         ArrayResize(filtered,p+1);
         filtered[p]=zones[i];
        }

   int limit=ArraySize(filtered);
   if(limit>m_max_zones_to_draw)
      limit=m_max_zones_to_draw;
   ArrayResize(m_price_zones,limit);
  for(int i=0;i<limit;i++)
     m_price_zones[i]=filtered[i];
  }

//+------------------------------------------------------------------+
//| Classify zones as support or resistance based on current price    |
//+------------------------------------------------------------------+
void CSupRes::ClassifyZones()
  {
   double current_price=SymbolInfoDouble(m_symbol,SYMBOL_BID);
   ArrayResize(m_current_supports,0);
   ArrayResize(m_current_resistances,0);
   for(int i=0;i<ArraySize(m_price_zones);i++)
     {
      if(current_price>m_price_zones[i].upper)
        {
         int p=ArraySize(m_current_supports);
         ArrayResize(m_current_supports,p+1);
         m_current_supports[p]=m_price_zones[i];
        }
      else if(current_price<m_price_zones[i].lower)
        {
         int p=ArraySize(m_current_resistances);
         ArrayResize(m_current_resistances,p+1);
         m_current_resistances[p]=m_price_zones[i];
        }
     }

   // sort supports descending by upper price (nearest first)
   for(int i=0;i<ArraySize(m_current_supports)-1;i++)
      for(int j=i+1;j<ArraySize(m_current_supports);j++)
         if(m_current_supports[j].upper>m_current_supports[i].upper)
           { SRZone tmp=m_current_supports[i]; m_current_supports[i]=m_current_supports[j]; m_current_supports[j]=tmp; }

   // sort resistances ascending by lower price
   for(int i=0;i<ArraySize(m_current_resistances)-1;i++)
      for(int j=i+1;j<ArraySize(m_current_resistances);j++)
         if(m_current_resistances[j].lower<m_current_resistances[i].lower)
           { SRZone tmp=m_current_resistances[i]; m_current_resistances[i]=m_current_resistances[j]; m_current_resistances[j]=tmp; }
  }

//+------------------------------------------------------------------+
//| Init using configuration                                          |
//+------------------------------------------------------------------+
bool CSupRes::Init(string symbol,ENUM_TIMEFRAMES timeframe,CSupResConfig &cfg)
  {
   m_symbol=symbol;
   m_timeframe=timeframe;
   m_period=cfg.period;
   m_draw_sup=cfg.draw_sup;
   m_draw_res=cfg.draw_res;
   m_sup_color=cfg.sup_color;
   m_res_color=cfg.res_color;
   m_sup_style=cfg.sup_style;
   m_res_style=cfg.res_style;
   m_sup_width=cfg.sup_width;
   m_res_width=cfg.res_width;
  m_extend_right=cfg.extend_right;
  m_show_labels=cfg.show_labels;
  m_alert_tf=cfg.alert_tf;
  m_touch_lookback=cfg.touch_lookback;
  m_touch_tolerance=cfg.touch_tolerance;
  m_zone_range=cfg.zone_range;
  m_max_zones_to_draw=cfg.max_zones_to_draw;
  m_min_touches=cfg.min_touches;
  m_validation=cfg.validation;
  m_sup_touches=0;
  m_res_touches=0;
  m_sup_pinbar=0;
  m_res_pinbar=0;
  m_sup_engulf=0;
  m_res_engulf=0;
  m_sup_doji=0;
  m_res_doji=0;
  m_sup_maru_bull=0;
  m_res_maru_bull=0;
  m_sup_maru_bear=0;
  m_res_maru_bear=0;
  m_sup_insidebar=0;
  m_res_insidebar=0;
  m_sup_outsidebar=0;
  m_res_outsidebar=0;
  m_sup_valid=false;
  m_res_valid=false;
  ArrayResize(m_res_obj_names,m_max_zones_to_draw);
  ArrayResize(m_sup_obj_names,m_max_zones_to_draw);
  for(int i=0;i<m_max_zones_to_draw;i++)
    {
     m_res_obj_names[i]="DYN_RES_"+IntegerToString(i);
     m_sup_obj_names[i]="DYN_SUP_"+IntegerToString(i);
    }
  int bars=m_period>0?m_period:50;
  ArrayResize(m_highs,bars);
  ArrayResize(m_lows,bars);
  ArrayResize(m_opens,bars);
  ArrayResize(m_closes,bars);
  ArraySetAsSeries(m_highs,true);
  ArraySetAsSeries(m_lows,true);
  ArraySetAsSeries(m_opens,true);
  ArraySetAsSeries(m_closes,true);

  // tenta calcular as zonas iniciais; se falhar por falta de barras,
  // o objeto continua valido e a proxima chamada de Update tentara novamente
  Update();
  return true;
  }

//+------------------------------------------------------------------+
//| Default init                                                      |
//+------------------------------------------------------------------+
bool CSupRes::Init(string symbol,ENUM_TIMEFRAMES timeframe,int period)
  {
   CSupResConfig tmp;
   tmp.period=period;
   return Init(symbol,timeframe,tmp);
  }

//+------------------------------------------------------------------+
//| Support value                                                     |
//+------------------------------------------------------------------+
double CSupRes::GetSupportValue(int shift)
  {
   if(shift==0)
      return m_sup_val;
   return m_sup_val; // for older interface shift ignored
  }

//+------------------------------------------------------------------+
//| Resistance value                                                  |
//+------------------------------------------------------------------+
double CSupRes::GetResistanceValue(int shift)
  {
   if(shift==0)
      return m_res_val;
   return m_res_val; // shift ignored with zones
  }

int CSupRes::GetSupportZones(SRZone &zones_buffer[])
  {
   int n=ArraySize(m_current_supports);
   ArrayResize(zones_buffer,n);
   for(int i=0;i<n;i++)
      zones_buffer[i]=m_current_supports[i];
   return n;
  }

int CSupRes::GetResistanceZones(SRZone &zones_buffer[])
  {
   int n=ArraySize(m_current_resistances);
   ArrayResize(zones_buffer,n);
   for(int i=0;i<n;i++)
      zones_buffer[i]=m_current_resistances[i];
   return n;
  }

//+------------------------------------------------------------------+
//| GetValue (support)                                                |
//+------------------------------------------------------------------+
double CSupRes::GetValue(int shift)
  {
   return GetSupportValue(shift);
  }

//+------------------------------------------------------------------+
//| CopyValues (support)                                              |
//+------------------------------------------------------------------+
bool CSupRes::CopyValues(int shift,int count,double &buffer[])
  {
   ArrayResize(buffer,count);
   for(int i=0;i<count;i++)
      buffer[i]=GetValue(shift+i);
   return true;
  }

//+------------------------------------------------------------------+
//| Ready flag                                                        |
//+------------------------------------------------------------------+
bool CSupRes::IsReady()
  {
   return m_ready;
  }

//+------------------------------------------------------------------+
//| Recalculate and classify price zones                              |
//+------------------------------------------------------------------+
void CSupRes::CalculateZones(int bars)
  {
   CalculatePriceZones(m_highs,m_lows,bars,m_zone_range);
   ClassifyZones();
   m_res_val=(ArraySize(m_current_resistances)>0)?m_current_resistances[0].upper:0.0;
   m_sup_val=(ArraySize(m_current_supports)>0)?m_current_supports[0].lower:0.0;
  }

//+------------------------------------------------------------------+
//| Draw support and resistance zones                                 |
//+------------------------------------------------------------------+
void CSupRes::DrawZones()
  {
   int res_limit=MathMin(ArraySize(m_current_resistances),m_max_zones_to_draw);
   if(m_draw_res)
     {
      for(int i=0;i<res_limit;i++)
         DrawZone(m_res_obj_names[i],m_current_resistances[i].lower,m_current_resistances[i].upper,m_res_color);
     }
   for(int i=res_limit;i<m_prev_res_zones && i<m_max_zones_to_draw;i++)
      ObjectDelete(0,m_res_obj_names[i]);
   m_prev_res_zones=res_limit;

   int sup_limit=MathMin(ArraySize(m_current_supports),m_max_zones_to_draw);
   if(m_draw_sup)
     {
      for(int i=0;i<sup_limit;i++)
         DrawZone(m_sup_obj_names[i],m_current_supports[i].lower,m_current_supports[i].upper,m_sup_color);
     }
   for(int i=sup_limit;i<m_prev_sup_zones && i<m_max_zones_to_draw;i++)
      ObjectDelete(0,m_sup_obj_names[i]);
   m_prev_sup_zones=sup_limit;
  }

//+------------------------------------------------------------------+
//| Count touches and candlestick patterns                             |
//+------------------------------------------------------------------+
void CSupRes::DetectPatterns(int bars)
  {
   m_sup_touches=0;
   m_res_touches=0;
   m_sup_pinbar=0;
   m_res_pinbar=0;
   m_sup_engulf=0;
   m_res_engulf=0;
   m_sup_doji=0;
   m_res_doji=0;
   m_sup_maru_bull=0;
   m_res_maru_bull=0;
   m_sup_maru_bear=0;
   m_res_maru_bear=0;
   m_sup_insidebar=0;
   m_res_insidebar=0;
   m_sup_outsidebar=0;
   m_res_outsidebar=0;

   int lookback=MathMin(m_touch_lookback,bars-1);
   for(int i=1;i<=lookback;i++)
     {
      bool sup_touch=false;
      for(int z=0;z<ArraySize(m_current_supports);z++)
         if(m_highs[i]>=m_current_supports[z].lower-m_touch_tolerance && m_lows[i]<=m_current_supports[z].upper+m_touch_tolerance)
           { sup_touch=true; break; }

      bool res_touch=false;
      for(int z=0;z<ArraySize(m_current_resistances);z++)
         if(m_highs[i]>=m_current_resistances[z].lower-m_touch_tolerance && m_lows[i]<=m_current_resistances[z].upper+m_touch_tolerance)
           { res_touch=true; break; }

      if(sup_touch)
        {
         m_sup_touches++;
         if(IsBullPinBar(m_opens,m_closes,m_highs,m_lows,i))   m_sup_pinbar++;
         if(IsBullEngulf(m_opens,m_closes,i))              m_sup_engulf++;
         if(IsDoji(m_opens,m_closes,m_highs,m_lows,i))         m_sup_doji++;
         if(IsBullMarubozu(m_opens,m_closes,m_highs,m_lows,i)) m_sup_maru_bull++;
         if(IsBearMarubozu(m_opens,m_closes,m_highs,m_lows,i)) m_sup_maru_bear++;
         if(IsInsideBar(m_highs,m_lows,i))                 m_sup_insidebar++;
         if(IsOutsideBar(m_highs,m_lows,i))                m_sup_outsidebar++;
        }
      if(res_touch)
        {
         m_res_touches++;
         if(IsBearPinBar(m_opens,m_closes,m_highs,m_lows,i))   m_res_pinbar++;
         if(IsBearEngulf(m_opens,m_closes,i))              m_res_engulf++;
         if(IsDoji(m_opens,m_closes,m_highs,m_lows,i))         m_res_doji++;
         if(IsBullMarubozu(m_opens,m_closes,m_highs,m_lows,i)) m_res_maru_bull++;
         if(IsBearMarubozu(m_opens,m_closes,m_highs,m_lows,i)) m_res_maru_bear++;
         if(IsInsideBar(m_highs,m_lows,i))                 m_res_insidebar++;
         if(IsOutsideBar(m_highs,m_lows,i))                m_res_outsidebar++;
        }
     }

   m_sup_valid=true;
   m_res_valid=true;
   if(m_validation==SUPRES_VALIDATE_TOUCHES)
     {
      m_sup_valid=(m_sup_touches>=m_min_touches);
      m_res_valid=(m_res_touches>=m_min_touches);
     }
   else if(m_validation==SUPRES_VALIDATE_PATTERNS)
     {
      int sup_pat=m_sup_pinbar+m_sup_engulf+m_sup_doji+m_sup_maru_bull+m_sup_maru_bear+m_sup_insidebar+m_sup_outsidebar;
      int res_pat=m_res_pinbar+m_res_engulf+m_res_doji+m_res_maru_bull+m_res_maru_bear+m_res_insidebar+m_res_outsidebar;
      m_sup_valid=(sup_pat>0);
      m_res_valid=(res_pat>0);
     }
   else if(m_validation==SUPRES_VALIDATE_BOTH)
     {
      int sup_pat=m_sup_pinbar+m_sup_engulf+m_sup_doji+m_sup_maru_bull+m_sup_maru_bear+m_sup_insidebar+m_sup_outsidebar;
      int res_pat=m_res_pinbar+m_res_engulf+m_res_doji+m_res_maru_bull+m_res_maru_bear+m_res_insidebar+m_res_outsidebar;
      m_sup_valid=(m_sup_touches>=m_min_touches && sup_pat>0);
      m_res_valid=(m_res_touches>=m_min_touches && res_pat>0);
     }
  }

//+------------------------------------------------------------------+
//| Evaluate breakout conditions                                       |
//+------------------------------------------------------------------+
void CSupRes::EvaluateBreakouts()
  {
   if(CopyClose(m_symbol,m_alert_tf,0,2,m_closes)>0)
     {
      m_breakup=false;
      double nearest_res=DBL_MAX;
      for(int z=0;z<ArraySize(m_current_resistances);z++)
         if(m_current_resistances[z].upper<nearest_res)
            nearest_res=m_current_resistances[z].upper;
      if(nearest_res<DBL_MAX && m_closes[1]>nearest_res)
         m_breakup=true;

      m_breakdown=false;
      double nearest_sup=-DBL_MAX;
      for(int z=0;z<ArraySize(m_current_supports);z++)
         if(m_current_supports[z].lower>nearest_sup)
            nearest_sup=m_current_supports[z].lower;
      if(nearest_sup>-DBL_MAX && m_closes[1]<nearest_sup)
         m_breakdown=true;
     }
   else
     {
      m_breakup=false;
      m_breakdown=false;
     }
  }

//+------------------------------------------------------------------+
//| Update support/resistance values                                  |
//+------------------------------------------------------------------+
bool CSupRes::Update()
  {
  int bars=m_period>0?m_period:50;
   int got_high=CopyHigh(m_symbol,m_timeframe,0,bars,m_highs);
   int got_low =CopyLow(m_symbol,m_timeframe,0,bars,m_lows);
   int got_open=CopyOpen(m_symbol,m_timeframe,0,bars,m_opens);
   int got_close=CopyClose(m_symbol,m_timeframe,0,bars,m_closes);
   if(got_high<bars || got_low<bars || got_open<bars || got_close<bars)
     {
      m_ready=false;       // aguardando mais barras
      return false;
     }

  int hi_idx=ArrayMaximum(m_highs);
  int lo_idx=ArrayMinimum(m_lows);

  CalculateZones(bars);
  DrawZones();
  DetectPatterns(bars);
  EvaluateBreakouts();

  m_ready=true;
  return true;
  }

bool CSupRes::IsBreakdown(){ return m_breakdown; }
bool CSupRes::IsBreakup(){ return m_breakup; }

#endif // __SUP_RES_MQH__
