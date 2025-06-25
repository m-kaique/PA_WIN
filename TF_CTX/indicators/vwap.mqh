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

   double          CalcVWAP(int shift);
public:
                     CVWAP();
                    ~CVWAP();

   virtual bool     Init(string symbol, ENUM_TIMEFRAMES timeframe,
                         int period, ENUM_MA_METHOD method);
   virtual double   GetValue(int shift=0);
   virtual bool     CopyValues(int shift,int count,double &buffer[]);
   virtual bool     IsReady();
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CVWAP::CVWAP()
  {
   m_symbol="";
   m_timeframe=PERIOD_CURRENT;
   m_period=1;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CVWAP::~CVWAP()
  {
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

#endif // __VWAP_MQH__
