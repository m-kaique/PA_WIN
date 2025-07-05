//+------------------------------------------------------------------+
//|                                                  vwap_indicator.mq5 |
//|  Custom VWAP indicator                                           |
//+------------------------------------------------------------------+
#property copyright "OpenAI"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1  "VWAP"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrAqua
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#include "vwap_defs.mqh"

input int                InpPeriod      = 1;
input ENUM_VWAP_CALC_MODE InpCalcMode   = VWAP_CALC_BAR;
input ENUM_TIMEFRAMES     InpSessionTF  = PERIOD_D1;
input ENUM_VWAP_PRICE_TYPE InpPriceType = VWAP_PRICE_FINANCIAL_AVERAGE;
input datetime           InpStartTime   = 0;

double VWAPBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0,VWAPBuffer,INDICATOR_DATA);
   ArraySetAsSeries(VWAPBuffer,true);
   PlotIndexSetString(0,PLOT_LABEL,"VWAP");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Calculate typical price based on selected type                   |
//+------------------------------------------------------------------+
double TypicalPrice(const double &open[],const double &high[],const double &low[],const double &close[],int index)
  {
   switch(InpPriceType)
     {
      case VWAP_PRICE_OPEN:   return open[index];
      case VWAP_PRICE_HIGH:   return high[index];
      case VWAP_PRICE_LOW:    return low[index];
      case VWAP_PRICE_CLOSE:  return close[index];
      case VWAP_PRICE_HL2:    return (high[index]+low[index])/2.0;
      case VWAP_PRICE_HLC3:   return (high[index]+low[index]+close[index])/3.0;
      case VWAP_PRICE_OHLC4:  return (open[index]+high[index]+low[index]+close[index])/4.0;
      default:                return (high[index]+low[index]+close[index])/3.0; // financial average
     }
  }

//+------------------------------------------------------------------+
//| Check if bar starts a new session                                |
//+------------------------------------------------------------------+
bool IsNewSession(const datetime &time[],int bar_index)
  {
   if(bar_index>=ArraySize(time)-1)
      return true;
   datetime current_time=time[bar_index];
   datetime previous_time=time[bar_index+1];
   if(InpSessionTF==PERIOD_D1)
     {
      MqlDateTime cur_dt,prev_dt;
      TimeToStruct(current_time,cur_dt);
      TimeToStruct(previous_time,prev_dt);
      return(cur_dt.day!=prev_dt.day);
     }
   else if(InpSessionTF==PERIOD_W1)
     {
      int cur_week=(int)(current_time/(7*24*3600));
      int prev_week=(int)(previous_time/(7*24*3600));
      return(cur_week!=prev_week);
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(rates_total<=0)
      return 0;

   ArraySetAsSeries(time,true);
   ArraySetAsSeries(open,true);
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(close,true);
   ArraySetAsSeries(volume,true);
   ArraySetAsSeries(VWAPBuffer,true);

   double cum_pv=0.0;
   double cum_vol=0.0;

   for(int i=rates_total-1;i>=0;i--)
     {
      datetime bar_time=time[i];
      double price=TypicalPrice(open,high,low,close,i);
      double vol=(double)volume[i];

      bool reset=false;
      if(InpCalcMode==VWAP_CALC_PERIODIC)
        {
         if(IsNewSession(time,i))
            reset=true;
        }
      else if(InpCalcMode==VWAP_CALC_FROM_DATE)
        {
         if(bar_time<InpStartTime)
           {
            VWAPBuffer[i]=EMPTY_VALUE;
            continue;
           }
         if(i==rates_total-1 || time[i+1]<InpStartTime)
            reset=true;
        }
      else if(InpCalcMode==VWAP_CALC_BAR)
        {
         double sum_pv=0.0;
         double sum_vol=0.0;
         int start_bar=MathMin(i+InpPeriod-1,rates_total-1);
         for(int j=start_bar;j>=i;j--)
           {
            double p=TypicalPrice(open,high,low,close,j);
            double v=(double)volume[j];
            sum_pv+=p*v;
            sum_vol+=v;
           }
         VWAPBuffer[i]=(sum_vol!=0)?sum_pv/sum_vol:EMPTY_VALUE;
         continue;
        }

      if(reset)
        {
         cum_pv=price*vol;
         cum_vol=vol;
        }
      else
        {
         cum_pv+=price*vol;
         cum_vol+=vol;
        }

      VWAPBuffer[i]=(cum_vol!=0)?cum_pv/cum_vol:EMPTY_VALUE;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
