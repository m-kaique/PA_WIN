//+------------------------------------------------------------------+
//|                                    indicators/vwap.mqh           |
//|  Volume Weighted Average Price indicator                         |
//+------------------------------------------------------------------+
#ifndef __VWAP_MQH__
#define __VWAP_MQH__

#include "indicator_base.mqh"

class CVWAP : public CIndicatorBase
  {
private:
   string          m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int             m_period;
   color           m_color;
   int             m_style;
   int             m_width;
   string          m_obj_prefix;
   string          m_line_names[];

   void            DeleteObjects();

   double          CalcVWAP(int shift);
public:
                     CVWAP();
                    ~CVWAP();

   virtual bool     Init(string symbol, ENUM_TIMEFRAMES timeframe,
                         int period, ENUM_MA_METHOD method);
   virtual double   GetValue(int shift=0);
   virtual bool     CopyValues(int shift,int count,double &buffer[]);
   virtual bool     IsReady();
   virtual bool     Update();
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CVWAP::CVWAP()
  {
   m_symbol="";
   m_timeframe=PERIOD_CURRENT;
   m_period=1;
   m_color=clrAqua;
   m_style=STYLE_SOLID;
   m_width=1;
   m_obj_prefix="";
   ArrayResize(m_line_names,0);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CVWAP::~CVWAP()
  {
   DeleteObjects();
  }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CVWAP::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                 int period, ENUM_MA_METHOD method)
  {
   m_symbol=symbol;
   m_timeframe=timeframe;
   if(period>0) m_period=period; else m_period=1;
   return true;
  }

//+------------------------------------------------------------------+
//| Calculate VWAP for given shift                                   |
//+------------------------------------------------------------------+
double CVWAP::CalcVWAP(int shift)
  {
   double sum_pv=0.0;
   double sum_vol=0.0;
   for(int i=shift;i<shift+m_period;i++)
     {
      double high=iHigh(m_symbol,m_timeframe,i);
      double low=iLow(m_symbol,m_timeframe,i);
      double close=iClose(m_symbol,m_timeframe,i);
      long   vol=iVolume(m_symbol,m_timeframe,i);
      double typical=(high+low+close)/3.0;
      sum_pv += typical*vol;
      sum_vol += vol;
     }
   if(sum_vol==0.0)
      return 0.0;
   return sum_pv/sum_vol;
  }

//+------------------------------------------------------------------+
//| Get single value                                                 |
//+------------------------------------------------------------------+
double CVWAP::GetValue(int shift)
  {
   return CalcVWAP(shift);
  }

//+------------------------------------------------------------------+
//| Copy multiple values                                             |
//+------------------------------------------------------------------+
bool CVWAP::CopyValues(int shift,int count,double &buffer[])
  {
   ArrayResize(buffer,count);
   ArraySetAsSeries(buffer,true);
   for(int j=0;j<count;j++)
      buffer[j]=CalcVWAP(shift+j);
   return true;
  }

//+------------------------------------------------------------------+
//| Check readiness                                                  |
//+------------------------------------------------------------------+
bool CVWAP::IsReady()
  {
  return (Bars(m_symbol,m_timeframe) > m_period);
  }

//+------------------------------------------------------------------+
//| Delete previously drawn objects                                  |
//+------------------------------------------------------------------+
void CVWAP::DeleteObjects()
  {
   for(int i=0;i<ArraySize(m_line_names);i++)
      ObjectDelete(0,m_line_names[i]);
   ArrayResize(m_line_names,0);
  }

//+------------------------------------------------------------------+
//| Recalculate and redraw VWAP line                                 |
//+------------------------------------------------------------------+
bool CVWAP::Update()
  {
   if(!IsReady())
      return(false);

   DeleteObjects();

   if(StringLen(m_obj_prefix)==0)
      m_obj_prefix="VWAP_"+IntegerToString(GetTickCount());

   // allocate buffer for vwap values
   double vals[]; ArrayResize(vals,m_period); ArraySetAsSeries(vals,true);

   for(int i=0;i<m_period;i++)
      vals[i]=CalcVWAP(i);

   // create line segments between consecutive values
   ArrayResize(m_line_names,m_period-1);
   for(int i=m_period-1;i>0;i--)
     {
      string name=m_obj_prefix+"_"+IntegerToString(i);
      datetime t1=iTime(m_symbol,m_timeframe,i);
      datetime t2=iTime(m_symbol,m_timeframe,i-1);
      if(!ObjectCreate(0,name,OBJ_TREND,0,t1,vals[i],t2,vals[i-1]))
         continue;
      ObjectSetInteger(0,name,OBJPROP_COLOR,m_color);
      ObjectSetInteger(0,name,OBJPROP_STYLE,m_style);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,m_width);
      m_line_names[m_period-1-i]=name;
     }

   return(true);
  }

#endif // __VWAP_MQH__
