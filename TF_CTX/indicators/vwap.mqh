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
   
   bool            IsNewSession(int bar_index);
   void            UpdateCurrentBar();

   void            DeleteObjects();

   double          TypicalPrice(int index);
   void            ComputeAll();
   void            DrawAll();

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

   bool SetCalcMode(ENUM_VWAP_CALC_MODE mode){ m_calc_mode=mode; return true; }
   bool SetPriceType(ENUM_VWAP_PRICE_TYPE type){ m_price_type=type; return true; }
   bool SetSessionTimeframe(ENUM_TIMEFRAMES tf){ m_session_tf=tf; return true; }
   bool SetStartTime(datetime start){ m_start_time=start; return true; }
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
  m_obj_prefix=symbol+"_"+EnumToString(timeframe)+"_";
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
      return EMPTY_VALUE;
   return m_vwap_buffer[shift];
  }

//+------------------------------------------------------------------+
//| Get single value                                                 |
//+------------------------------------------------------------------+
double CVWAP::GetValue(int shift)
  {
   if(ArraySize(m_vwap_buffer)<=shift)
      return EMPTY_VALUE;
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
   Print("VWAP::ComputeAll() Mode=", (int)m_calc_mode);
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
         if(IsNewSession(i))
            reset=true;
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
         int start_bar=MathMin(i + m_period - 1, bars - 1);
         for(int j=start_bar;j>=i;j--)
           {
            double p=TypicalPrice(j);
            long v=iVolume(m_symbol,m_timeframe,j);
            sum_pv+=p*v;
            sum_vol+=v;
           }
         m_vwap_buffer[i]=(sum_vol!=0)?sum_pv/sum_vol:EMPTY_VALUE;
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

      m_vwap_buffer[i]=(cum_vol!=0)?cum_pv/cum_vol:EMPTY_VALUE;
    }

  DrawAll();
 }

//+------------------------------------------------------------------+
//| Check if bar starts a new session                                 |
//+------------------------------------------------------------------+
bool CVWAP::IsNewSession(int bar_index)
  {
   if(bar_index>=Bars(m_symbol,m_timeframe)-1)
      return true;

   datetime current_time=iTime(m_symbol,m_timeframe,bar_index);
   datetime previous_time=iTime(m_symbol,m_timeframe,bar_index+1);

   if(m_session_tf==PERIOD_D1)
     {
      MqlDateTime cur_dt,prev_dt;
      TimeToStruct(current_time,cur_dt);
      TimeToStruct(previous_time,prev_dt);
      return(cur_dt.day!=prev_dt.day);
     }
   else if(m_session_tf==PERIOD_W1)
     {
      int cur_week=(int)(current_time/(7*24*3600));
      int prev_week=(int)(previous_time/(7*24*3600));
      return(cur_week!=prev_week);
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Update only the current bar                                       |
//+------------------------------------------------------------------+
void CVWAP::UpdateCurrentBar()
  {
   int bars=Bars(m_symbol,m_timeframe);
   if(bars==0)
      return;

   ArrayResize(m_vwap_buffer,bars);
   ArraySetAsSeries(m_vwap_buffer,true);

  if(m_calc_mode==VWAP_CALC_BAR)
    {
      double sum_pv=0.0;
      double sum_vol=0.0;
      int start_bar=MathMin(m_period-1,bars-1);
      for(int j=start_bar;j>=0;j--)
        {
         double p=TypicalPrice(j);
         long v=iVolume(m_symbol,m_timeframe,j);
         sum_pv+=p*v;
         sum_vol+=v;
        }
      m_vwap_buffer[0]=(sum_vol!=0)?sum_pv/sum_vol:EMPTY_VALUE;
      return;
    }

  int session_start=0;
  for(int j=1;j<bars;j++)
    {
     if(m_calc_mode==VWAP_CALC_PERIODIC && IsNewSession(j-1))
       {
        session_start=j-1;
        break;
       }
     if(m_calc_mode==VWAP_CALC_FROM_DATE && iTime(m_symbol,m_timeframe,j)<m_start_time)
       {
        session_start=j-1;
        break;
       }
    }

  double cum_pv=0.0;
  double cum_vol=0.0;
  for(int j=session_start;j>=0;j--)
    {
     double p=TypicalPrice(j);
     long v=iVolume(m_symbol,m_timeframe,j);
     cum_pv+=p*v;
     cum_vol+=v;
    }

  m_vwap_buffer[0]=(cum_vol!=0)?cum_pv/cum_vol:EMPTY_VALUE;

  DrawAll();
 }

//+------------------------------------------------------------------+
//| Draw VWAP line on chart                                          |
//+------------------------------------------------------------------+
void CVWAP::DrawAll()
  {
   Print("VWAP::DrawAll() - bars=",ArraySize(m_vwap_buffer));
   DeleteObjects();
   int bars=ArraySize(m_vwap_buffer);
   if(bars<2)
      return;
   ArrayResize(m_line_names,bars-1);
   for(int i=0;i<bars-1;i++)
     {
      if(m_vwap_buffer[i]==EMPTY_VALUE || m_vwap_buffer[i+1]==EMPTY_VALUE)
         continue;
      string name=m_obj_prefix+"VWAP_"+IntegerToString(i);
      m_line_names[i]=name;
      datetime t1=iTime(m_symbol,m_timeframe,i+1);
      datetime t2=iTime(m_symbol,m_timeframe,i);
      if(!ObjectCreate(0,name,OBJ_TREND,0,t1,m_vwap_buffer[i+1],t2,m_vwap_buffer[i]))
         continue;
      ObjectSetInteger(0,name,OBJPROP_COLOR,m_color);
      ObjectSetInteger(0,name,OBJPROP_STYLE,m_style);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,m_width);
      ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,name,OBJPROP_RAY_LEFT,false);
     }
  }

//+------------------------------------------------------------------+
//| Recalculate and redraw VWAP line                                 |
//+------------------------------------------------------------------+
bool CVWAP::Update()
  {
   Print("VWAP::Update");
   if(!IsReady())
      return(false);

   int bars=Bars(m_symbol,m_timeframe);
   int current_size=ArraySize(m_vwap_buffer);

   if(bars<=current_size && current_size>0)
     {
      UpdateCurrentBar();
      return(true);
     }

   ComputeAll();
   return(true);
  }

#endif // __VWAP_MQH__
