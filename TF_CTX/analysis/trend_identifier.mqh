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
public:
                     CTrendIdentifier() { m_ctx_m15=NULL; m_ctx_h1=NULL; m_ctx_h4=NULL; m_ctx_d1=NULL; m_symbol=""; }
   bool               Init(string symbol, TF_CTX *m15, TF_CTX *h1, TF_CTX *h4, TF_CTX *d1=NULL)
                       {
                        m_symbol=symbol;
                        m_ctx_m15=m15;
                        m_ctx_h1=h1;
                        m_ctx_h4=h4;
                        m_ctx_d1=d1;
                        return true;
                       }
   ENUM_TREND_STATE   Detect();
  };

ENUM_TREND_STATE CTrendIdentifier::Detect()
  {
   int up=0, down=0;

   //--- Estrutura de mercado M5 (topos e fundos ascendentes)
   // Observamos os dois candles anteriores para saber se o mercado
   // vem fazendo máximas e mínimas mais altas (ou mais baixas).
   // Essa sequência de topos e fundos é um dos pilares para
   // confirmar tendência segundo o eBook.
   double h0=iHigh(m_symbol,PERIOD_M5,0);
   double h1=iHigh(m_symbol,PERIOD_M5,1);
   double h2=iHigh(m_symbol,PERIOD_M5,2);
   double l0=iLow(m_symbol,PERIOD_M5,0);
   double l1=iLow(m_symbol,PERIOD_M5,1);
   double l2=iLow(m_symbol,PERIOD_M5,2);
   if(h0>h1 && h1>h2 && l0>l1 && l1>l2)
      up++;   // sequência ascendente => viés de alta
   else if(h0<h1 && h1<h2 && l0<l1 && l1<l2)
      down++; // sequência descendente => viés de baixa

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
      // EMAs: se EMA9 está acima de EMA21, ambas subindo e o preço acima delas
      // soma ponto para tendência de alta. O contrário indica força vendedora.
      if(ema9_cur>ema21_cur && price_m15>ema9_cur && ema9_cur>ema9_prev && ema21_cur>ema21_prev)
         up++;
      else if(ema9_cur<ema21_cur && price_m15<ema9_cur && ema9_cur<ema9_prev && ema21_cur<ema21_prev)
         down++;

      // VWAP diário: preço acima e VWAP inclinada para cima apontam confluência
      // de compra. Se o preço estiver abaixo e a VWAP inclinar para baixo, soma
      // pontos para a venda.
      double vwap_cur = m_ctx_m15.GetIndicatorValue("vwap_diario_fin",0);
      double vwap_prev = m_ctx_m15.GetIndicatorValue("vwap_diario_fin",1);
      // VWAP: preço acima de uma VWAP crescente reforça compra;
      // preço abaixo de uma VWAP descendente reforça venda.
      if(price_m15>vwap_cur && vwap_cur>vwap_prev)
         up++;
      else if(price_m15<vwap_cur && vwap_cur<vwap_prev)
         down++;

      // Bandas de Bollinger: quando a banda média (20 períodos) está inclinada
      // para cima e o preço se move acima dela, a volatilidade tende a favorecer
      // a continuação da alta. A inclinação descendente sugere venda.
      double boll_mid = m_ctx_m15.GetIndicatorValue("boll20",0);
      double boll_prev = m_ctx_m15.GetIndicatorValue("boll20",1);
      // Bollinger: média inclinada para cima e preço acima dela denotam
      // expansão e continuidade da alta. O inverso sinaliza queda.
      if(price_m15>boll_mid && boll_mid>boll_prev)
         up++;
      else if(price_m15<boll_mid && boll_mid<boll_prev)
         down++;

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
         if(bull_bar)
            up++;   // alta sustentada por volume
         else if(bear_bar)
            down++; // venda forte em candle de baixa
        }
      else if(vol_cur<vol_prev && vol_cur<vol_avg)
        {
         if(bull_bar)
            down++; // candle de alta sem volume pode ser falso
         else if(bear_bar)
            up++;   // candle de baixa sem volume tem pouca força
        }
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
         up++;
      else if(price_h1<ema50_cur && ema50_cur<ema50_prev)
         down++;

      // LTA do timeframe H1 atuando como suporte.
      // Se o preço respeita essa linha de tendência, há maior
      // probabilidade de continuação da alta.
      double lta = m_ctx_h1.GetPriceActionValue("swing_lines",0);
      if(lta!=0.0)
        {
         if(price_h1>=lta)
            up++;
         else if(price_h1<lta)
            down++;
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
         up++;
      else if(price_h4<sma200_cur && sma200_cur<sma200_prev)
         down++;

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
            up++;
         if(sr.IsBreakdown() || (sup>0 && price_h4<sup))
            down++;
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
            up++;   // rompimento de resistência no diário
         if(sr.IsBreakdown() || (sup>0 && price_d1<sup))
            down++; // perda de suporte no diário
        }
     }

   // Resultado final: após somar todos os pontos de cada sinal, definimos
   // a tendência predominante. A maior pontuação entre "up" e "down" vence;
   // se houver empate, consideramos o mercado neutro.
   if(up>down) return TREND_BULLISH;
   if(down>up) return TREND_BEARISH;
   return TREND_NEUTRAL;
  }

#endif // __TREND_IDENTIFIER_MQH__
