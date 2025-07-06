#ifndef __TREND_IDENTIFIER_MQH__
#define __TREND_IDENTIFIER_MQH__

#include "../tf_ctx.mqh"

// Este módulo condensa regras do eBook "Identificação de Tendência para WINM25"
// Ele avalia EMAs, VWAP e Bandas de Bollinger em timeframes M15, H1 e H4 para
// determinar se o mercado está em alta, baixa ou neutro. Cada bloco abaixo
// segue as recomendações do capítulo 4 do eBook, onde múltiplos timeframes e
// confluência de indicadores são usados para confirmar a direção predominante.

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
   string  m_symbol;
public:
                     CTrendIdentifier() { m_ctx_m15=NULL; m_ctx_h1=NULL; m_ctx_h4=NULL; m_symbol=""; }
   bool               Init(string symbol, TF_CTX *m15, TF_CTX *h1, TF_CTX *h4)
                       {
                        m_symbol=symbol;
                        m_ctx_m15=m15;
                        m_ctx_h1=h1;
                        m_ctx_h4=h4;
                        return true;
                       }
   ENUM_TREND_STATE   Detect();
  };

ENUM_TREND_STATE CTrendIdentifier::Detect()
  {
   int up=0, down=0;

   //--- M15 indicadores principais
   // Conforme o eBook, a tendência no M15 ganha força quando EMA9 supera EMA21
   // e o preço se mantém acima delas. VWAP ascendente e Bandas de Bollinger
   // abertas reforçam o cenário de alta; o contrário indica possível queda.
   if(m_ctx_m15!=NULL)
     {
      double ema9_cur  = m_ctx_m15.GetIndicatorValue("ema9",0);
      double ema21_cur = m_ctx_m15.GetIndicatorValue("ema21",0);
      double ema9_prev = m_ctx_m15.GetIndicatorValue("ema9",1);
      double ema21_prev = m_ctx_m15.GetIndicatorValue("ema21",1);
      double price_m15 = iClose(m_symbol,PERIOD_M15,0);
      if(ema9_cur>ema21_cur && price_m15>ema9_cur && ema9_cur>ema9_prev && ema21_cur>ema21_prev)
         up++;
      else if(ema9_cur<ema21_cur && price_m15<ema9_cur && ema9_cur<ema9_prev && ema21_cur<ema21_prev)
         down++;

      // VWAP diário: preço acima e VWAP inclinada para cima apontam confluência
      // de compra. Se o preço estiver abaixo e a VWAP inclinar para baixo, soma
      // pontos para a venda.
      double vwap_cur = m_ctx_m15.GetIndicatorValue("vwap_diario_fin",0);
      double vwap_prev = m_ctx_m15.GetIndicatorValue("vwap_diario_fin",1);
      if(price_m15>vwap_cur && vwap_cur>vwap_prev)
         up++;
      else if(price_m15<vwap_cur && vwap_cur<vwap_prev)
         down++;

      // Bandas de Bollinger: quando a banda média (20 períodos) está inclinada
      // para cima e o preço se move acima dela, a volatilidade tende a favorecer
      // a continuação da alta. A inclinação descendente sugere venda.
      double boll_mid = m_ctx_m15.GetIndicatorValue("boll20",0);
      double boll_prev = m_ctx_m15.GetIndicatorValue("boll20",1);
      if(price_m15>boll_mid && boll_mid>boll_prev)
         up++;
      else if(price_m15<boll_mid && boll_mid<boll_prev)
         down++;
     }

   //--- H1 EMA50
   // O eBook define a EMA50 como guia da tendência de médio prazo. Preço e
   // média inclinados para cima reforçam compras; valores abaixo indicam venda.
   if(m_ctx_h1!=NULL)
     {
      double ema50_cur = m_ctx_h1.GetIndicatorValue("ema50",0);
      double ema50_prev = m_ctx_h1.GetIndicatorValue("ema50",1);
      double price_h1 = iClose(m_symbol,PERIOD_H1,0);
      if(price_h1>ema50_cur && ema50_cur>ema50_prev)
         up++;
      else if(price_h1<ema50_cur && ema50_cur<ema50_prev)
         down++;
     }

   //--- H4 SMA200
   // A SMA200 é a referência de longo prazo. De acordo com o eBook, tendência
   // principal de alta ocorre quando o preço está acima dela e a média se
   // inclina para cima; caso contrário há viés baixista.
   if(m_ctx_h4!=NULL)
     {
      double sma200_cur = m_ctx_h4.GetIndicatorValue("sma200",0);
      double sma200_prev = m_ctx_h4.GetIndicatorValue("sma200",1);
      double price_h4 = iClose(m_symbol,PERIOD_H4,0);
      if(price_h4>sma200_cur && sma200_cur>sma200_prev)
         up++;
      else if(price_h4<sma200_cur && sma200_cur<sma200_prev)
         down++;
     }

   // Resultado final: se as pontuações de alta superam as de baixa, o mercado
   // é considerado em tendência de alta e vice-versa. Empate indica neutralidade.
   if(up>down) return TREND_BULLISH;
   if(down>up) return TREND_BEARISH;
   return TREND_NEUTRAL;
  }

#endif // __TREND_IDENTIFIER_MQH__
