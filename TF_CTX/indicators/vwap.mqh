//+------------------------------------------------------------------+
//|                                    indicators/vwap.mqh           |
//|  Volume Weighted Average Price indicator                         |
//+------------------------------------------------------------------+
#ifndef __VWAP_MQH__
#define __VWAP_MQH__

#include "indicator_base.mqh"

enum ENUM_VWAP_CALC_MODE
  {
   VWAP_CALC_BAR=0,
   VWAP_CALC_PERIODIC,
   VWAP_CALC_FROM_DATE
  };

enum ENUM_VWAP_PRICE_TYPE
  {
   VWAP_PRICE_FINANCIAL_AVERAGE=0,
   VWAP_PRICE_OPEN,
   VWAP_PRICE_HIGH,
   VWAP_PRICE_LOW,
   VWAP_PRICE_CLOSE,
   VWAP_PRICE_HL2,
   VWAP_PRICE_HLC3,
   VWAP_PRICE_OHLC4
  };

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
   ENUM_VWAP_CALC_MODE m_calc_mode;
   ENUM_VWAP_PRICE_TYPE m_price_type;
   ENUM_TIMEFRAMES     m_session_tf;
   datetime            m_start_time;
   datetime            m_last_calculated_time;
   double              m_vwap_buffer[];

   void            DeleteObjects();

   double          TypicalPrice(int index);
   void            ComputeAll();

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
   m_calc_mode=VWAP_CALC_BAR;
   m_price_type=VWAP_PRICE_FINANCIAL_AVERAGE;
   m_session_tf=PERIOD_D1;
   m_start_time=0;
   m_last_calculated_time=0;
   ArrayResize(m_vwap_buffer,0);
 }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CVWAP::~CVWAP()
  {
   DeleteObjects();
   ArrayResize(m_vwap_buffer,0);
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
   m_calc_mode=VWAP_CALC_BAR;
   m_price_type=VWAP_PRICE_FINANCIAL_AVERAGE;
   m_session_tf=PERIOD_D1;
   m_start_time=0;
   m_last_calculated_time=0;
   ArrayResize(m_vwap_buffer,0);
   return true;
  }

//+------------------------------------------------------------------+
//| Calculate VWAP for given shift                                   |
//+------------------------------------------------------------------+
double CVWAP::CalcVWAP(int shift)
  {
   if(ArraySize(m_vwap_buffer)<=shift)
      return 0.0;
   return m_vwap_buffer[shift];
  }

//+------------------------------------------------------------------+
//| Get single value                                                 |
//+------------------------------------------------------------------+
double CVWAP::GetValue(int shift)
  {
   if(ArraySize(m_vwap_buffer)<=shift)
      return 0.0;
   return m_vwap_buffer[shift];
  }

//+------------------------------------------------------------------+
//| Copy multiple values                                             |
//+------------------------------------------------------------------+
bool CVWAP::CopyValues(int shift,int count,double &buffer[])
  {
   int available=ArraySize(m_vwap_buffer);
   if(available<=shift)
      return false;
   int to_copy=MathMin(count,available-shift);
   ArrayResize(buffer,to_copy);
   ArraySetAsSeries(buffer,true);
   for(int j=0;j<to_copy;j++)
      buffer[j]=m_vwap_buffer[shift+j];
   return (to_copy>0);
  }

//+------------------------------------------------------------------+
//| Check readiness                                                  |
//+------------------------------------------------------------------+
bool CVWAP::IsReady()
  {
  return (Bars(m_symbol,m_timeframe) > 0);
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
//| Calculate typical price based on selected type                    |
//+------------------------------------------------------------------+
double CVWAP::TypicalPrice(int index)
  {
   double open=iOpen(m_symbol,m_timeframe,index);
   double high=iHigh(m_symbol,m_timeframe,index);
   double low=iLow(m_symbol,m_timeframe,index);
   double close=iClose(m_symbol,m_timeframe,index);

   switch(m_price_type)
     {
      case VWAP_PRICE_OPEN:   return open;
      case VWAP_PRICE_HIGH:   return high;
      case VWAP_PRICE_LOW:    return low;
      case VWAP_PRICE_CLOSE:  return close;
      case VWAP_PRICE_HL2:    return (high+low)/2.0;
      case VWAP_PRICE_HLC3:   return (high+low+close)/3.0;
      case VWAP_PRICE_OHLC4:  return (open+high+low+close)/4.0;
      default:                return (high+low+close)/3.0; // financial average
     }
  }

//+------------------------------------------------------------------+
//| Recalculate entire VWAP buffer                                    |
//+------------------------------------------------------------------+
void CVWAP::ComputeAll()
  {
   int bars=Bars(m_symbol,m_timeframe);
   ArrayResize(m_vwap_buffer,bars);
   ArraySetAsSeries(m_vwap_buffer,true);

   double cum_pv=0.0;
   double cum_vol=0.0;

   for(int i=bars-1;i>=0;i--)
     {
      datetime bar_time=iTime(m_symbol,m_timeframe,i);
      double price=TypicalPrice(i);
      long volume=iVolume(m_symbol,m_timeframe,i);

      bool reset=false;
      if(m_calc_mode==VWAP_CALC_PERIODIC)
        {
         datetime cur_session=iTime(m_symbol,m_session_tf,
                                    iBarShift(m_symbol,m_session_tf,bar_time));
         if(i==bars-1)
            reset=true;
         else
           {
            datetime prev_time=iTime(m_symbol,m_timeframe,i+1);
            datetime prev_session=iTime(m_symbol,m_session_tf,
                                        iBarShift(m_symbol,m_session_tf,prev_time));
            if(cur_session!=prev_session)
               reset=true;
           }
        }
      else if(m_calc_mode==VWAP_CALC_FROM_DATE)
        {
         if(bar_time<m_start_time)
           {
            m_vwap_buffer[i]=EMPTY_VALUE;
            continue;
           }
         if(i==bars-1 || iTime(m_symbol,m_timeframe,i+1)<m_start_time)
            reset=true;
        }
      else if(m_calc_mode==VWAP_CALC_BAR)
        {
         double sum_pv=0.0;
         double sum_vol=0.0;
         for(int j=0;j<m_period && (i+j)<bars;j++)
           {
            double p=TypicalPrice(i+j);
            long v=iVolume(m_symbol,m_timeframe,i+j);
            sum_pv+=p*v;
            sum_vol+=v;
           }
         m_vwap_buffer[i]=(sum_vol!=0)?sum_pv/sum_vol:0.0;
         continue;
        }

      if(reset)
        {
         cum_pv=price*volume;
         cum_vol=volume;
        }
      else
        {
         cum_pv+=price*volume;
         cum_vol+=volume;
        }

      m_vwap_buffer[i]=(cum_vol!=0)?cum_pv/cum_vol:0.0;
     }
  }

//+------------------------------------------------------------------+
//| Recalculate and redraw VWAP line                                 |
//+------------------------------------------------------------------+
bool CVWAP::Update()
  {
   if(!IsReady())
      return(false);

   datetime cur_time=iTime(m_symbol,m_timeframe,0);
   if(cur_time==m_last_calculated_time && ArraySize(m_vwap_buffer)>0)
      return(true);

   m_last_calculated_time=cur_time;
   ComputeAll();
   return(true);
  }

#endif // __VWAP_MQH__
