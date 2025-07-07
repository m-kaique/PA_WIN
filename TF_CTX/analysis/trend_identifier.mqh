#ifndef __TREND_IDENTIFIER_MQH__
#define __TREND_IDENTIFIER_MQH__

#include "../tf_ctx.mqh"
#include "../priceaction/sup_res/sup_res.mqh"

// Este módulo condensa regras do eBook "Identificação de Tendência para WINM25"
// Ele avalia EMAs, VWAP, Bandas de Bollinger e Volume em múltiplos timeframes
// (M5, M15, H1 e H4) para determinar se o mercado está em alta, baixa ou neutro.
// Inclui ainda a verificação de linhas de tendência (LTA/LTB) e da estrutura de
// topos e fundos no gráfico de 5 minutos, seguindo as recomendações do capítulo
// 4 do eBook, onde a confluência desses indicadores confirma a direção
// predominante.

// Estado da tendência
enum ENUM_TREND_STATE
  {
   TREND_NEUTRAL = 0,
   TREND_BULLISH = 1,
   TREND_BEARISH = -1
  };

class CTrendIdentifier
  {
private:
   TF_CTX *m_ctx_m15;
   TF_CTX *m_ctx_h1;
   TF_CTX *m_ctx_h4;
  TF_CTX *m_ctx_d1;
  string  m_symbol;
  int     m_pivot_window;
  int     m_pivot_sep;
  string  m_log;

  ENUM_TREND_STATE   DetectM5Structure();
  string             GetLog() const { return m_log; }

public:
                     CTrendIdentifier() { m_ctx_m15=NULL; m_ctx_h1=NULL; m_ctx_h4=NULL; m_ctx_d1=NULL; m_symbol=""; m_pivot_window=50; m_pivot_sep=3; m_log=""; }
   bool               Init(string symbol, TF_CTX *m15, TF_CTX *h1, TF_CTX *h4, TF_CTX *d1=NULL, int pivot_window=50, int pivot_sep=3)
                       {
                        m_symbol=symbol;
                        m_ctx_m15=m15;
                        m_ctx_h1=h1;
                        m_ctx_h4=h4;
                        m_ctx_d1=d1;
                        m_pivot_window=pivot_window;
                        m_pivot_sep=pivot_sep;
                        m_log="";
                        return true;
                       }
  ENUM_TREND_STATE   Detect();
  };

//+------------------------------------------------------------------+
//| Detecta estrutura de mercado no M5 utilizando pivôs               |
//| Retorna TREND_BULLISH, TREND_BEARISH ou TREND_NEUTRAL             |
//+------------------------------------------------------------------+
ENUM_TREND_STATE CTrendIdentifier::DetectM5Structure()
  {
   // Quantidade de barras a analisar: janela configurada mais uma margem
   int bars=m_pivot_window+m_pivot_sep+10;
   if(bars<10)
      bars=10;
   int handle=iFractals(m_symbol,PERIOD_M5);
   if(handle==INVALID_HANDLE)
      return TREND_NEUTRAL;

   double up[],down[];
   ArraySetAsSeries(up,true);
   ArraySetAsSeries(down,true);
   if(CopyBuffer(handle,0,0,bars,up)!=bars ||
      CopyBuffer(handle,1,0,bars,down)!=bars)
     {
      IndicatorRelease(handle);
      return TREND_NEUTRAL;
     }

   // Vetores com as posições dos pivôs relevantes
   int hidx[]; ArrayResize(hidx,0);
   int lidx[]; ArrayResize(lidx,0);
   for(int i=m_pivot_sep;i<bars && i<=m_pivot_window+m_pivot_sep;i++)
     {
      if(up[i]!=EMPTY_VALUE)
        {
         if(ArraySize(hidx)==0 || i-hidx[ArraySize(hidx)-1]>=m_pivot_sep)
           {
            int p=ArraySize(hidx); ArrayResize(hidx,p+1); hidx[p]=i;
           }
        }
      if(down[i]!=EMPTY_VALUE)
        {
         if(ArraySize(lidx)==0 || i-lidx[ArraySize(lidx)-1]>=m_pivot_sep)
           {
            int p=ArraySize(lidx); ArrayResize(lidx,p+1); lidx[p]=i;
           }
        }
     }

   IndicatorRelease(handle);

   // Verificar se há pelo menos três topos e três fundos válidos
   int hs=ArraySize(hidx);
   int ls=ArraySize(lidx);
   if(hs>=3 && ls>=3)
     {
      // Utiliza sempre os três pivôs mais recentes, ignorando micro-movimentos
      double h2=up[hidx[hs-3]], h1=up[hidx[hs-2]], h0=up[hidx[hs-1]];
      double l2=down[lidx[ls-3]], l1=down[lidx[ls-2]], l0=down[lidx[ls-1]];
      bool higher_highs=(h2<h1 && h1<h0);
      bool lower_highs=(h2>h1 && h1>h0);
      bool higher_lows=(l2<l1 && l1<l0);
      bool lower_lows=(l2>l1 && l1>l0);
      if(higher_highs && higher_lows) return TREND_BULLISH;
      if(lower_highs && lower_lows) return TREND_BEARISH;
     }
   return TREND_NEUTRAL;
  }

ENUM_TREND_STATE CTrendIdentifier::Detect()
  {
   m_log="";
   int up=0, down=0;

   //--- Estrutura de mercado no M5 usando pivôs com separação mínima
   ENUM_TREND_STATE m5_state=DetectM5Structure();
   string txt="M5 estrutura: ";
   if(m5_state==TREND_BULLISH){ txt+="BULLISH"; up++; }
   else if(m5_state==TREND_BEARISH){ txt+="BEARISH"; down++; }
   else txt+="NEUTRAL";
   m_log+=txt+"\n";

   //--- M15 indicadores principais
   // A combinação de EMAs, VWAP, Bollinger e Volume no M15 serve para
   // confirmar se a estrutura de alta observada no M5 encontra respaldo
   // em indicadores de momentum e de volatilidade.
   // A seguir são checados, em sequência, cruzamento de EMAs, posição do preço
   // em relação à VWAP, inclinação da média de Bollinger e comportamento do
   // volume.
   if(m_ctx_m15!=NULL)
     {
      double ema9_cur  = m_ctx_m15.GetIndicatorValue("ema9",0);
      double ema21_cur = m_ctx_m15.GetIndicatorValue("ema21",0);
      double ema9_prev = m_ctx_m15.GetIndicatorValue("ema9",1);
      double ema21_prev = m_ctx_m15.GetIndicatorValue("ema21",1);
      double price_m15 = iClose(m_symbol,PERIOD_M15,0);
      if(ema9_cur>ema21_cur && price_m15>ema9_cur && ema9_cur>ema9_prev && ema21_cur>ema21_prev)
        { up++; m_log+="M15 EMAs: bullish\n"; }
      else if(ema9_cur<ema21_cur && price_m15<ema9_cur && ema9_cur<ema9_prev && ema21_cur<ema21_prev)
        { down++; m_log+="M15 EMAs: bearish\n"; }
      else
        m_log+="M15 EMAs: neutro\n";

      // VWAP diário: preço acima e VWAP inclinada para cima apontam confluência
      // de compra. Se o preço estiver abaixo e a VWAP inclinar para baixo, soma
      // pontos para a venda.
      double vwap_cur = m_ctx_m15.GetIndicatorValue("vwap_diario_fin",0);
      double vwap_prev = m_ctx_m15.GetIndicatorValue("vwap_diario_fin",1);
      // VWAP: preço acima de uma VWAP crescente reforça compra;
      // preço abaixo de uma VWAP descendente reforça venda.
      if(price_m15>vwap_cur && vwap_cur>vwap_prev)
        { up++; m_log+="M15 VWAP: bullish\n"; }
      else if(price_m15<vwap_cur && vwap_cur<vwap_prev)
        { down++; m_log+="M15 VWAP: bearish\n"; }
      else
        m_log+="M15 VWAP: neutro\n";

      // Bandas de Bollinger: quando a banda média (20 períodos) está inclinada
      // para cima e o preço se move acima dela, a volatilidade tende a favorecer
      // a continuação da alta. A inclinação descendente sugere venda.
      double boll_mid = m_ctx_m15.GetIndicatorValue("boll20",0);
      double boll_prev = m_ctx_m15.GetIndicatorValue("boll20",1);
      // Bollinger: média inclinada para cima e preço acima dela denotam
      // expansão e continuidade da alta. O inverso sinaliza queda.
      if(price_m15>boll_mid && boll_mid>boll_prev)
        { up++; m_log+="M15 Bollinger: bullish\n"; }
      else if(price_m15<boll_mid && boll_mid<boll_prev)
        { down++; m_log+="M15 Bollinger: bearish\n"; }
      else
        m_log+="M15 Bollinger: neutro\n";

      // Volume como confirmador de movimento. Avalia se o volume atual
      // supera o volume médio recente e se está aumentando em relação à barra
      // anterior. Volume alto com candle de alta confirma força compradora e
      // vice-versa. Volume decrescente com candle de alta ou baixa sinaliza
      // possível exaustão.
      double vol_cur  = m_ctx_m15.GetIndicatorValue("vol0",0);
      double vol_prev = m_ctx_m15.GetIndicatorValue("vol0",1);
      double vol_sum  = 0.0;
      for(int i=1;i<=20;i++)
         vol_sum += m_ctx_m15.GetIndicatorValue("vol0",i);
      double vol_avg  = vol_sum/20.0;
      double open_m15 = iOpen(m_symbol,PERIOD_M15,0);
      bool   bull_bar = price_m15>open_m15;
      bool   bear_bar = price_m15<open_m15;

      // Volume: compara o volume atual com o da barra anterior e com a
      // média das últimas 20. Volume crescente acima da média valida o
      // movimento da barra atual; volume fraco sugere exaustão.
      if(vol_cur>vol_prev && vol_cur>vol_avg)
        {
         if(bull_bar){ up++; m_log+="M15 Volume: confirma compra\n"; }
         else if(bear_bar){ down++; m_log+="M15 Volume: confirma venda\n"; }
        }
      else if(vol_cur<vol_prev && vol_cur<vol_avg)
        {
         if(bull_bar){ down++; m_log+="M15 Volume: alta sem volume\n"; }
         else if(bear_bar){ up++; m_log+="M15 Volume: baixa sem volume\n"; }
         else
            m_log+="M15 Volume: neutro\n";
        }
      else
        m_log+="M15 Volume: neutro\n";
    }

   //--- H1 EMA50
   // A EMA50 do H1 atua como um filtro de tendência de prazo intermediário.
   // Procuramos preço acima de uma EMA50 ascendente para compras e o inverso
   // para vendas. Uma LTA no mesmo timeframe ajuda a delimitar regiões de
   // suporte dinâmico.
   if(m_ctx_h1!=NULL)
     {
      double ema50_cur = m_ctx_h1.GetIndicatorValue("ema50",0);
      double ema50_prev = m_ctx_h1.GetIndicatorValue("ema50",1);
      double price_h1 = iClose(m_symbol,PERIOD_H1,0);
      if(price_h1>ema50_cur && ema50_cur>ema50_prev)
        { up++; m_log+="H1 EMA50: bullish\n"; }
      else if(price_h1<ema50_cur && ema50_cur<ema50_prev)
        { down++; m_log+="H1 EMA50: bearish\n"; }
      else
        m_log+="H1 EMA50: neutro\n";

      // LTA do timeframe H1 atuando como suporte.
      // Se o preço respeita essa linha de tendência, há maior
      // probabilidade de continuação da alta.
      double lta = m_ctx_h1.GetPriceActionValue("swing_lines",0);
      if(lta!=0.0)
        {
         if(price_h1>=lta){ up++; m_log+="H1 LTA: suporte respeitado\n"; }
         else if(price_h1<lta){ down++; m_log+="H1 LTA: rompida\n"; }
        }
     }

   //--- H4 SMA200
   // No H4 buscamos a referência de longo prazo. A SMA200 define
   // o viés principal: preço acima de uma SMA200 ascendente favorece
   // compras e o contrário sugere vendas.
   if(m_ctx_h4!=NULL)
     {
      double sma200_cur = m_ctx_h4.GetIndicatorValue("sma200",0);
      double sma200_prev = m_ctx_h4.GetIndicatorValue("sma200",1);
      double price_h4 = iClose(m_symbol,PERIOD_H4,0);
      if(price_h4>sma200_cur && sma200_cur>sma200_prev)
        { up++; m_log+="H4 SMA200: bullish\n"; }
      else if(price_h4<sma200_cur && sma200_cur<sma200_prev)
        { down++; m_log+="H4 SMA200: bearish\n"; }
      else
        m_log+="H4 SMA200: neutro\n";

      // Validar zonas de suporte e resistência no H4.
      // Rompimentos ou rejeições nesses níveis servem como
      // confirmação adicional do viés detectado.
      CPriceActionBase *pa_sr=m_ctx_h4.GetPriceAction("sr_completo");
      if(pa_sr!=NULL)
        {
         CSupRes *sr=(CSupRes*)pa_sr;
         double sup=sr.GetSupportValue();
         double res=sr.GetResistanceValue();
         if(sr.IsBreakup() || (res>0 && price_h4>res))
           { up++; m_log+="H4 SR: rompimento/resistencia\n"; }
         if(sr.IsBreakdown() || (sup>0 && price_h4<sup))
           { down++; m_log+="H4 SR: perda/suporte\n"; }
        }
     }

   //--- D1 zonas de suporte e resistência para confirmação adicional
   // O timeframe diário serve como filtro final. Se o preço está rompendo
   // ou respeitando níveis importantes no D1, a probabilidade de continuação
   // aumenta.
   if(m_ctx_d1!=NULL)
     {
      CPriceActionBase *pa_sr=m_ctx_d1.GetPriceAction("sr_completo");
      if(pa_sr!=NULL)
        {
         CSupRes *sr=(CSupRes*)pa_sr;
         double price_d1=iClose(m_symbol,PERIOD_D1,0);
         double sup=sr.GetSupportValue();
         double res=sr.GetResistanceValue();
         if(sr.IsBreakup() || (res>0 && price_d1>res))
           { up++; m_log+="D1 SR: rompimento/resistencia\n"; }
         if(sr.IsBreakdown() || (sup>0 && price_d1<sup))
           { down++; m_log+="D1 SR: perda/suporte\n"; }
        }
     }

   // Resultado final: após somar todos os pontos de cada sinal, definimos
   // a tendência predominante. A maior pontuação entre "up" e "down" vence;
   // se houver empate, consideramos o mercado neutro.
   string res="";
   if(up>down) res="BULLISH";
   else if(down>up) res="BEARISH";
   else res="NEUTRAL";
   m_log+="Resultado: "+res+"\n";
   m_log+="Pontos up="+IntegerToString(up)+" down="+IntegerToString(down)+"\n";
   if(res=="BULLISH") return TREND_BULLISH;
   if(res=="BEARISH") return TREND_BEARISH;
   return TREND_NEUTRAL;
 }

#endif // __TREND_IDENTIFIER_MQH__
