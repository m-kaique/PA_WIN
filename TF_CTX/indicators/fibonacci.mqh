//+------------------------------------------------------------------+
//|                                indicators/fibonacci.mqh          |
//|  Fibonacci retracement indicator drawing object                  |
//+------------------------------------------------------------------+
#ifndef __FIBONACCI_MQH__
#define __FIBONACCI_MQH__

#include "indicator_base.mqh"

class CFibonacci : public CIndicatorBase
  {
private:
   string          m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int             m_bars;
   double          m_levels[6];
   color           m_levels_color;
   color           m_parallel_color;
   string          m_obj_name;
   bool            m_ready;

   void            DeleteObject();

public:
                     CFibonacci();
                    ~CFibonacci();

   bool             Init(string symbol, ENUM_TIMEFRAMES timeframe,
                          int bars,
                          double level1,double level2,double level3,
                          double level4,double level5,double level6,
                          color levels_color);
   // Interface base (chama Init com níveis padrão)
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
CFibonacci::CFibonacci()
  {
   m_symbol="";
   m_timeframe=PERIOD_CURRENT;
   m_bars=0;
   ArrayInitialize(m_levels,0.0);
   m_levels_color=clrOrange;
   m_parallel_color=clrYellow;
   m_obj_name="";
   m_ready=false;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CFibonacci::~CFibonacci()
  {
   DeleteObject();
  }

//+------------------------------------------------------------------+
//| Delete existing object                                           |
//+------------------------------------------------------------------+
void CFibonacci::DeleteObject()
  {
   if(StringLen(m_obj_name)>0)
     ObjectDelete(0,m_obj_name);
  }

//+------------------------------------------------------------------+
//| Init with custom levels                                          |
//+------------------------------------------------------------------+
bool CFibonacci::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                      int bars,
                      double level1,double level2,double level3,
                      double level4,double level5,double level6,
                      color levels_color)
  {
   m_symbol=symbol;
   m_timeframe=timeframe;
   m_bars=bars;
   m_levels[0]=level1;
   m_levels[1]=level2;
   m_levels[2]=level3;
   m_levels[3]=level4;
   m_levels[4]=level5;
   m_levels[5]=level6;
   m_levels_color=levels_color;
  // keep existing name for updates
  if(StringLen(m_obj_name)==0)
     m_obj_name="Fibo_"+IntegerToString(GetTickCount());

  return Update();
  }

//+------------------------------------------------------------------+
//| Interface base implementation                                    |
//+------------------------------------------------------------------+
bool CFibonacci::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                      int period, ENUM_MA_METHOD method)
  {
   double defaults[6]={23.6,38.2,50.0,61.8,78.6,100.0};
   return Init(symbol,timeframe,period,
               defaults[0],defaults[1],defaults[2],
               defaults[3],defaults[4],defaults[5],
               clrOrange);
  }

//+------------------------------------------------------------------+
//| No value returned                                                |
//+------------------------------------------------------------------+
double CFibonacci::GetValue(int shift)
  {
   return 0.0;
  }

//+------------------------------------------------------------------+
//| Not applicable                                                   |
//+------------------------------------------------------------------+
bool CFibonacci::CopyValues(int shift,int count,double &buffer[])
  {
   ArrayResize(buffer,0);
   return false;
  }

//+------------------------------------------------------------------+
//| Ready status                                                     |
//+------------------------------------------------------------------+
bool CFibonacci::IsReady()
  {
   return m_ready;
  }

//+------------------------------------------------------------------+
//| Recalculate and redraw Fibonacci levels                          |
//+------------------------------------------------------------------+
bool CFibonacci::Update()
  {
   DeleteObject();

   double highs[]; double lows[];
   if(CopyHigh(m_symbol,m_timeframe,0,m_bars,highs)<=0)
      return false;
   if(CopyLow(m_symbol,m_timeframe,0,m_bars,lows)<=0)
      return false;

   ArraySetAsSeries(highs,true); ArraySetAsSeries(lows,true);
   int hi_index=ArrayMaximum(highs); int lo_index=ArrayMinimum(lows);
   double hi=highs[hi_index]; double lo=lows[lo_index];
   datetime hi_time=iTime(m_symbol,m_timeframe,hi_index);
   datetime lo_time=iTime(m_symbol,m_timeframe,lo_index);

   if(StringLen(m_obj_name)==0)
      m_obj_name="Fibo_"+IntegerToString(GetTickCount());
   if(!ObjectCreate(0,m_obj_name,OBJ_FIBO,0,hi_time,hi,lo_time,lo))
      return false;

   double vals[6]; int cnt=0;
   for(int i=0;i<6;i++)
     if(m_levels[i]!=0.0)
        vals[cnt++]=m_levels[i];

   ObjectSetInteger(0,m_obj_name,OBJPROP_COLOR,m_parallel_color);
   ObjectSetInteger(0,m_obj_name,OBJPROP_LEVELS,cnt);
   for(int i=0;i<cnt;i++)
     {
      ObjectSetDouble(0,m_obj_name,OBJPROP_LEVELVALUE,i,vals[i]);
      ObjectSetInteger(0,m_obj_name,OBJPROP_LEVELCOLOR,i,m_levels_color);
     }

   m_ready=true;
   return true;
  }

#endif // __FIBONACCI_MQH__
