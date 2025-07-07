#ifndef __D1_ANALYSIS_MQH__
#define __D1_ANALYSIS_MQH__

#include "../priceaction_base.mqh"
#include "../../config_types.mqh"

struct SAnalysisLevel
  {
   double price;
   int    count;
  };

class CD1Analysis : public CPriceActionBase
  {
private:
   string          m_symbol;
   ENUM_TIMEFRAMES m_tf;
   int             m_lookback;
   datetime        m_last_bar;
   bool            m_ready;

   void   AddLevel(SAnalysisLevel &levels[],double price,double tolerance);
   void   DetectLevels(const double &values[],int bars,double tolerance,SAnalysisLevel &out[]);
   void   PrintLevels(string title,SAnalysisLevel &levels[]);
   string FormatPrice(double price);

public:
                     CD1Analysis();
                    ~CD1Analysis(){}

   bool            Init(string symbol,ENUM_TIMEFRAMES timeframe,CD1AnalysisConfig &cfg);
   virtual bool    Init(string symbol,ENUM_TIMEFRAMES timeframe,int period);
   virtual double  GetValue(int shift=0);
   virtual bool    CopyValues(int shift,int count,double &buffer[]);
   virtual bool    Update();
   virtual bool    IsReady();
  };


//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CD1Analysis::CD1Analysis()
  {
   m_symbol="";
   m_tf=PERIOD_D1;
   m_lookback=50;
   m_last_bar=0;
   m_ready=false;
  }

//+------------------------------------------------------------------+
//| Helper to format price                                            |
//+------------------------------------------------------------------+
string CD1Analysis::FormatPrice(double price)
  {
   int digits=(int)SymbolInfoInteger(m_symbol,SYMBOL_DIGITS);
   return DoubleToString(price,digits);
  }

//+------------------------------------------------------------------+
//| Add level aggregating by tolerance                                |
//+------------------------------------------------------------------+
void CD1Analysis::AddLevel(SAnalysisLevel &levels[],double price,double tolerance)
  {
   for(int i=0;i<ArraySize(levels);i++)
     {
      if(MathAbs(levels[i].price-price)<=tolerance)
        {
         levels[i].price=(levels[i].price*levels[i].count+price)/(levels[i].count+1);
         levels[i].count++;
         return;
        }
     }
   int pos=ArraySize(levels);
   ArrayResize(levels,pos+1);
   levels[pos].price=price;
   levels[pos].count=1;
  }

//+------------------------------------------------------------------+
//| Detect support/resistance levels                                  |
//+------------------------------------------------------------------+
void CD1Analysis::DetectLevels(const double &values[],int bars,double tolerance,SAnalysisLevel &out[])
  {
   ArrayResize(out,0);
   for(int i=1;i<bars-1;i++)
     {
      if(values[i]>values[i-1] && values[i]>values[i+1])
         AddLevel(out,values[i],tolerance);
      if(values[i]<values[i-1] && values[i]<values[i+1])
         AddLevel(out,values[i],tolerance);
     }
  }

//+------------------------------------------------------------------+
//| Print levels helper                                               |
//+------------------------------------------------------------------+
void CD1Analysis::PrintLevels(string title,SAnalysisLevel &levels[])
  {
   string msg=title+":";
   for(int i=0;i<ArraySize(levels);i++)
      if(levels[i].count>=2)
         msg+=" "+FormatPrice(levels[i].price)+"("+IntegerToString(levels[i].count)+")";
   Print(msg);
  }

//+------------------------------------------------------------------+
//| Init from config                                                  |
//+------------------------------------------------------------------+
bool CD1Analysis::Init(string symbol,ENUM_TIMEFRAMES timeframe,CD1AnalysisConfig &cfg)
  {
   m_symbol=symbol;
   m_tf=timeframe;
   m_lookback=cfg.lookback>0?cfg.lookback:50;
   m_last_bar=0;
   m_ready=true;
   return true;
  }

bool CD1Analysis::Init(string symbol,ENUM_TIMEFRAMES timeframe,int period)
  {
   CD1AnalysisConfig cfg;
   cfg.lookback=period;
   return Init(symbol,timeframe,cfg);
  }

double CD1Analysis::GetValue(int shift)
  {
   return 0.0;
  }

bool CD1Analysis::CopyValues(int shift,int count,double &buffer[])
  {
   ArrayResize(buffer,0);
   return false;
  }

bool CD1Analysis::IsReady()
  {
   return m_ready;
  }

//+------------------------------------------------------------------+
//| Main update - executed on new D1 bar                              |
//+------------------------------------------------------------------+
bool CD1Analysis::Update()
  {
   datetime t=iTime(m_symbol,m_tf,0);
   if(t==m_last_bar)
      return true;
   m_last_bar=t;

   Print("=== D1 Analysis ",TimeToString(m_last_bar,TIME_DATE)," ===");

   double highs[];
   double lows[];
   ArraySetAsSeries(highs,true);
   ArraySetAsSeries(lows,true);
   if(CopyHigh(m_symbol,m_tf,0,m_lookback+2,highs)<=0)
      return false;
   if(CopyLow(m_symbol,m_tf,0,m_lookback+2,lows)<=0)
      return false;

   string trend="lateral";
   if(highs[1]>highs[2] && lows[1]>lows[2])
      trend="alta";
   else if(highs[1]<highs[2] && lows[1]<lows[2])
      trend="baixa";

   int hi_idx=ArrayMaximum(highs,0,m_lookback);
   int lo_idx=ArrayMinimum(lows,0,m_lookback);
   double hi=highs[hi_idx];
   double lo=lows[lo_idx];
   double start=trend=="baixa"?hi:lo;
   double end=trend=="baixa"?lo:hi;
   double range=end-start;
   double fib23=end-range*0.236;
   double fib38=end-range*0.382;
   double fib50=end-range*0.5;
   double fib61=end-range*0.618;

   double tolerance=range*0.005;
   SAnalysisLevel levels[];
   DetectLevels(highs,m_lookback,tolerance,levels);
   SAnalysisLevel lows_lvls[];
   DetectLevels(lows,m_lookback,tolerance,lows_lvls);

   Print("Tendencia D1: ",trend);
   Print("Fibonacci 23.6: ",FormatPrice(fib23)," 38.2: ",FormatPrice(fib38)," 50: ",FormatPrice(fib50)," 61.8: ",FormatPrice(fib61));
   PrintLevels("Resistencias",levels);
   PrintLevels("Suportes",lows_lvls);

   double close1=iClose(m_symbol,m_tf,1);
   double close0=iClose(m_symbol,m_tf,0);
   for(int i=0;i<ArraySize(levels);i++)
     if(levels[i].count>=2 && close1>levels[i].price && close0>levels[i].price)
        Print("Resistencia ",FormatPrice(levels[i].price)," virou suporte (inversao)");
   for(int i=0;i<ArraySize(lows_lvls);i++)
     if(lows_lvls[i].count>=2 && close1<lows_lvls[i].price && close0<lows_lvls[i].price)
        Print("Suporte ",FormatPrice(lows_lvls[i].price)," virou resistencia (inversao)");

   return true;
  }

#endif // __D1_ANALYSIS_MQH__
