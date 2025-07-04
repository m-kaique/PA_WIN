//+------------------------------------------------------------------+
//|                                                 VWAP_Indicator.mq5 |
//|  Simple VWAP custom indicator using buffer                      |
//+------------------------------------------------------------------+
#property copyright "2025"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrAqua
#property indicator_label1  "VWAP"

#include "vwap.mqh"

input int               InpPeriod     = 14;
input ENUM_MA_METHOD    InpMethod     = MODE_SMA;
input ENUM_VWAP_CALC_MODE InpCalcMode = VWAP_CALC_BAR;
input ENUM_TIMEFRAMES   InpSessionTF  = PERIOD_D1;
input ENUM_VWAP_PRICE_TYPE InpPriceType = VWAP_PRICE_FINANCIAL_AVERAGE;
input datetime          InpStartTime  = 0;

//--- internal objects and buffers
CVWAP g_vwap;
double g_vwap_buffer[];
double g_tmp_buffer[];

//+------------------------------------------------------------------+
//| Indicator initialization function                                |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0,g_vwap_buffer,INDICATOR_DATA);
   ArraySetAsSeries(g_vwap_buffer,true);
   PlotIndexSetString(0,PLOT_LABEL,"VWAP");

   g_vwap.Init(Symbol(),Period(),InpPeriod,InpMethod,
               InpCalcMode,InpSessionTF,InpPriceType,InpStartTime);
   return(INIT_SUCCEEDED);
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

   g_vwap.Update();

   int bars=Bars(Symbol(),Period());
   g_vwap.CopyValues(0,bars,g_tmp_buffer);
   ArraySetAsSeries(g_tmp_buffer,true);
   int to_copy=MathMin(rates_total,ArraySize(g_tmp_buffer));
   for(int i=0;i<to_copy;i++)
      g_vwap_buffer[i]=g_tmp_buffer[i];

   return(rates_total);
  }
//+------------------------------------------------------------------+
