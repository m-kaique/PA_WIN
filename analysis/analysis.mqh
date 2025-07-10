#ifndef __MARKET_ANALYSIS_MQH__
#define __MARKET_ANALYSIS_MQH__

#include "../TF_CTX/priceaction/sup_res/sup_res.mqh"

//+------------------------------------------------------------------+
//| Contexto de análise do D1                                         |
//+------------------------------------------------------------------+
struct SD1Context
  {
   double  fib_retracements[6];  // 23.6%, 38.2%, 50%, 61.8%, 78.6%, 100%
   double  fib_extensions[3];    // 127%, 161.8%, 261.8%
   SRZone   supports[];          // zonas de suporte detectadas
   SRZone   resistances[];       // zonas de resistência detectadas
   bool     bullish_move;        // true se o movimento de referência é de alta
  };

/*
   Trechos relevantes do manual para o D1:
   - linhas 68-82 do "MANUAL DO USUÁRIO: IDENTIFICAÇÃO DE TENDÊNCIA NO WINM25"
     explicam que o gráfico diário fornece o pano de fundo do mercado e que
     devemos traçar Fibonacci da mínima à máxima do dia anterior, além de
     identificar suportes e resistências principais com o sistema `sr_completo`.
*/

//+------------------------------------------------------------------+
//| Obter contexto de D1                                              |
//+------------------------------------------------------------------+
bool AnalyzeD1(string symbol, SD1Context &ctx)
  {
   ArrayInitialize(ctx.fib_retracements,0.0);
   ArrayInitialize(ctx.fib_extensions,0.0);
   ArrayResize(ctx.supports,0);
   ArrayResize(ctx.resistances,0);

   double high=iHigh(symbol,PERIOD_D1,1);
   double low =iLow(symbol,PERIOD_D1,1);
   if(high==0 || low==0)
      return false;

  double open=iOpen(symbol,PERIOD_D1,1);
  double close=iClose(symbol,PERIOD_D1,1);
  bool bullish=(close>=open);
  double range=MathAbs(high-low);
  ctx.bullish_move=bullish;

   if(bullish)
     {
      ctx.fib_retracements[0]=high-range*0.236;
      ctx.fib_retracements[1]=high-range*0.382;
      ctx.fib_retracements[2]=high-range*0.5;
      ctx.fib_retracements[3]=high-range*0.618;
      ctx.fib_retracements[4]=high-range*0.786;
      ctx.fib_retracements[5]=low;
      ctx.fib_extensions[0]=high+range*0.27;   // 127%
      ctx.fib_extensions[1]=high+range*0.618;  // 161.8%
      ctx.fib_extensions[2]=high+range*1.618;  // 261.8%
     }
   else
     {
      ctx.fib_retracements[0]=low+range*0.236;
      ctx.fib_retracements[1]=low+range*0.382;
      ctx.fib_retracements[2]=low+range*0.5;
      ctx.fib_retracements[3]=low+range*0.618;
      ctx.fib_retracements[4]=low+range*0.786;
      ctx.fib_retracements[5]=high;
      ctx.fib_extensions[0]=low-range*0.27;    // 127%
      ctx.fib_extensions[1]=low-range*0.618;   // 161.8%
      ctx.fib_extensions[2]=low-range*1.618;   // 261.8%
     }

   CSupRes sr;
   CSupResConfig cfg;
   cfg.draw_sup=false;
   cfg.draw_res=false;
   cfg.show_labels=false;
   cfg.extend_right=false;
   sr.Init(symbol,PERIOD_D1,cfg);
   if(!sr.IsReady())
      sr.Update();
   sr.GetSupportZones(ctx.supports);
  sr.GetResistanceZones(ctx.resistances);

  return true;
  }

//| Market trend enumeration                                         |
//+------------------------------------------------------------------+
enum ENUM_MARKET_TREND
  {
   MARKET_TREND_SIDEWAYS = 0,
   MARKET_TREND_BULLISH  = 1,
   MARKET_TREND_BEARISH  = 2
  };

/*
   Referência:
   MANUAL DO USUÁRIO: IDENTIFICAÇÃO DE TENDÊNCIA NO WINM25 (Versão Detalhada)
   Seção "COMO CONFIRMAR A TENDÊNCIA NO H1" linhas 123-128
   - A sequência de topos e fundos ascendentes confirma tendência de alta
   - A sequência de topos e fundos descendentes confirma tendência de baixa
   - Preço acima ou abaixo da EMA50 reforça a direção da tendência
*/

//+------------------------------------------------------------------+
//| Convert trend enum to string                                      |
//+------------------------------------------------------------------+
string MarketTrendToString(ENUM_MARKET_TREND trend)
  {
   switch(trend)
     {
      case MARKET_TREND_BULLISH:  return "BULLISH";
      case MARKET_TREND_BEARISH:  return "BEARISH";
      default:                    return "SIDEWAYS";
     }
  }

//+------------------------------------------------------------------+
//| Avaliar tendência atual baseada no D1                            |
//+------------------------------------------------------------------+
ENUM_MARKET_TREND EvaluateD1Trend(string symbol,const SD1Context &ctx)
  {
   double close_today=iClose(symbol,PERIOD_D1,0);
   if(close_today==0)
      return MARKET_TREND_SIDEWAYS;

   double fib61=ctx.fib_retracements[3]; // nível de 61.8%

   if(ctx.bullish_move)
     {
      if(close_today>fib61)
         return MARKET_TREND_BULLISH;
      if(close_today<fib61)
         return MARKET_TREND_BEARISH;
     }
   else
     {
      if(close_today<fib61)
         return MARKET_TREND_BEARISH;
      if(close_today>fib61)
         return MARKET_TREND_BULLISH;
     }

   return MARKET_TREND_SIDEWAYS;
  }

//+------------------------------------------------------------------+
//| Determine market trend on given timeframe                         |
//| The logic follows the user manual:                                |
//|  - Sequence of highs/lows (market structure)                      |
//|  - Price relative to EMA50 and its slope                          |
//+------------------------------------------------------------------+
ENUM_MARKET_TREND DetectMarketTrend(string symbol, ENUM_TIMEFRAMES tf)
  {
   int handle=iFractals(symbol,tf);
   if(handle==INVALID_HANDLE)
      return MARKET_TREND_SIDEWAYS;

   const int lookback=200;
   double up[],down[];
   ArraySetAsSeries(up,true);
   ArraySetAsSeries(down,true);
   if(CopyBuffer(handle,0,0,lookback,up)<=0 || CopyBuffer(handle,1,0,lookback,down)<=0)
     {
      IndicatorRelease(handle);
      return MARKET_TREND_SIDEWAYS;
     }

   int h1=-1,h2=-1,l1=-1,l2=-1;
   for(int i=3;i<lookback && h1==-1;i++)
      if(up[i]!=EMPTY_VALUE) h1=i;
   for(int i=h1+1;i<lookback && h2==-1;i++)
      if(up[i]!=EMPTY_VALUE) h2=i;
   for(int i=3;i<lookback && l1==-1;i++)
      if(down[i]!=EMPTY_VALUE) l1=i;
   for(int i=l1+1;i<lookback && l2==-1;i++)
      if(down[i]!=EMPTY_VALUE) l2=i;
   IndicatorRelease(handle);

   if(h1<=0 || h2<=0 || l1<=0 || l2<=0)
      return MARKET_TREND_SIDEWAYS;

   bool higher_highs = up[h1] > up[h2];
   bool higher_lows  = down[l1] > down[l2];
   bool lower_highs  = up[h1] < up[h2];
   bool lower_lows   = down[l1] < down[l2];

   double ema_curr=iMA(symbol,tf,50,0,MODE_EMA,PRICE_CLOSE,1);
   double ema_prev=iMA(symbol,tf,50,0,MODE_EMA,PRICE_CLOSE,2);
   double close=iClose(symbol,tf,1);
   bool ema_up   = ema_curr>ema_prev;
   bool ema_down = ema_curr<ema_prev;

   if(higher_highs && higher_lows && close>ema_curr && ema_up)
      return MARKET_TREND_BULLISH;
   if(lower_highs && lower_lows && close<ema_curr && ema_down)
      return MARKET_TREND_BEARISH;

   return MARKET_TREND_SIDEWAYS;
  }

#endif // __MARKET_ANALYSIS_MQH__
