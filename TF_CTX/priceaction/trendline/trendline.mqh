//+------------------------------------------------------------------+
//|                                    priceaction/trendline.mqh      |
//|  TrendLine pattern detection with LTA/LTB drawing using Fractals |
//+------------------------------------------------------------------+
#ifndef __TRENDLINE_MQH__
#define __TRENDLINE_MQH__

#include "../priceaction_base.mqh"
#include "../../config_types.mqh"
#include "trendline_defs.mqh"

const int TRENDLINE_MAX_FRACTALS = 50;
const double TRENDLINE_SCORE_THRESHOLD = 10.0;

// Estrutura para armazenar um ponto fractal
struct SFractalPoint
{
   datetime time;
   double price;
   int bar_index;
   bool is_valid;

   SFractalPoint() : time(0), price(0.0), bar_index(-1), is_valid(false) {}
};

struct TrendLineState
{
   bool         valid;
   datetime     last_confirmation_time;
   int          stability_count;
   SFractalPoint p1;
   SFractalPoint p2;
   TrendLineState() : valid(false), last_confirmation_time(0), stability_count(0) {}
};

struct FractalCache
{
   datetime       last_update_time;
   int            confirmation_bars;
   SFractalPoint  confirmed_points[];
   SFractalPoint  candidate_points[];
   FractalCache() : last_update_time(0), confirmation_bars(2) {}
};

struct LineVersion
{
   TrendLineState confirmed;
   TrendLineState candidate;
   int            stability_threshold;
   LineVersion() : stability_threshold(2) {}
};

class CTrendLine : public CPriceActionBase
{
private:
   string          m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int             m_period;
   int             m_left;
   int             m_right;
   
   // Configurações de desenho
   bool            m_draw_lta;
   bool            m_draw_ltb;
   color           m_lta_color;
   color           m_ltb_color;
   ENUM_LINE_STYLE m_lta_style;
   ENUM_LINE_STYLE m_ltb_style;
   int             m_lta_width;
   int             m_ltb_width;
   bool            m_extend_right;
   bool            m_show_labels;
   
   // Handles e buffers
   int             m_fractals_handle;
   double          m_lta_buffer[];
   double          m_ltb_buffer[];
   
   // Pontos fractais
   SFractalPoint   m_lows[];     // Mínimos fractais
   SFractalPoint   m_highs[];    // Máximos fractais
   
   // Objetos gráficos
   string          m_lta_line_name;
   string          m_ltb_line_name;
   string          m_lta_label_name;
   string          m_ltb_label_name;
   
   // Estado das linhas
   bool            m_lta_valid;
   bool            m_ltb_valid;
   SFractalPoint   m_lta_point1, m_lta_point2;
   SFractalPoint   m_ltb_point1, m_ltb_point2;
   TrendLineState  m_lta_state;
  TrendLineState  m_ltb_state;
  int             m_stability_bars;
  int             m_confirm_bars;
  int             m_min_distance;
  bool            m_validate_mtf;
  ENUM_TIMEFRAMES m_mtf_timeframe;

  FractalCache    m_low_cache;
  FractalCache    m_high_cache;
  LineVersion     m_lta_version;
  LineVersion     m_ltb_version;
  bool            m_need_redraw;
  ScoreWeights    m_weights;

  UpdateControl   m_update_ctrl;
  int             m_atr_handle;

   // Métodos privados
  bool            CreateATRHandle();
  void            ReleaseATRHandle();
  double          GetATR(int shift);
  bool            CreateFractalsHandle();
  void            ReleaseFractalsHandle();
   bool            UpdateFractals(bool &updated);
   void            FindTrendLines();
   void            CalculateBuffers();
   double          CalculateLinePrice(SFractalPoint &point1, SFractalPoint &point2, int shift);
   void            DrawLines();
   void            DeleteObjects();
   bool            IsValidLTA(SFractalPoint &p_old, SFractalPoint &p_recent);
   bool            IsValidLTB(SFractalPoint &p_old, SFractalPoint &p_recent);
   double          ScorePair(SFractalPoint &p_old, SFractalPoint &p_recent);
   double          ComputeTrendStrength(SFractalPoint &p_old, SFractalPoint &p_recent);
   double          ComputeVolumeConfirmation(SFractalPoint &p_old, SFractalPoint &p_recent);
   double          ComputeLineTests(SFractalPoint &p_old, SFractalPoint &p_recent);
   double          ComputeTimeValidity(SFractalPoint &p_old, SFractalPoint &p_recent);
   double          ComputePsychologicalLevel(SFractalPoint &p_old, SFractalPoint &p_recent);
   double          ComputeVolatilityContext(SFractalPoint &p_old, SFractalPoint &p_recent);
   void            UpdateTrendState(TrendLineState &state, SFractalPoint &p_old, SFractalPoint &p_recent);
   bool            ValidateLineWithMTF(SFractalPoint &p_old, SFractalPoint &p_recent);
   void            ConditionalUpdate(ENUM_UPDATE_TRIGGER trigger);
   bool            ShouldUpdate(ENUM_UPDATE_TRIGGER &trigger);
   void            ValidateLineCorrections();
public:
   CTrendLine();
   ~CTrendLine();
   bool            Init(string symbol, ENUM_TIMEFRAMES timeframe, CTrendLineConfig &config);
   virtual bool    Init(string symbol, ENUM_TIMEFRAMES timeframe, int period);
   virtual double  GetValue(int shift = 0);
   virtual bool    CopyValues(int shift, int count, double &buffer[]);
   virtual bool    IsReady();
   double         GetLTAValue(int shift=0);
   double         GetLTBValue(int shift=0);
   bool           IsLTAValid();
   bool           IsLTBValid();
   void           GetLTAPoints(SFractalPoint &p1, SFractalPoint &p2);
   void           GetLTBPoints(SFractalPoint &p1, SFractalPoint &p2);
   double         GetLTASlope();
   double         GetLTBSlope();
   ENUM_TRENDLINE_DIRECTION GetLineDirection(SFractalPoint &p1, SFractalPoint &p2);
   void           PrintLineStatus();
   virtual bool    Update();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTrendLine::CTrendLine()
{
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_period = 21;
   m_left = 3;
   m_right = 3;
   
   m_draw_lta = true;
   m_draw_ltb = true;
   m_lta_color = clrGreen;
   m_ltb_color = clrRed;
   m_lta_style = STYLE_SOLID;
   m_ltb_style = STYLE_SOLID;
   m_lta_width = 1;
   m_ltb_width = 1;
   m_extend_right = true;
   m_show_labels = false;
   
   m_fractals_handle = INVALID_HANDLE;
   ArrayResize(m_lta_buffer, 0);
   ArrayResize(m_ltb_buffer, 0);
   ArrayResize(m_lows, 0);
   ArrayResize(m_highs, 0);
   ArrayResize(m_low_cache.confirmed_points,0);
   ArrayResize(m_low_cache.candidate_points,0);
   ArrayResize(m_high_cache.confirmed_points,0);
   ArrayResize(m_high_cache.candidate_points,0);
   
   m_lta_line_name = "";
   m_ltb_line_name = "";
   m_lta_label_name = "";
   m_ltb_label_name = "";

   m_lta_valid = false;
   m_ltb_valid = false;

   m_stability_bars = 2;
   m_confirm_bars = 2;
   m_min_distance = 5;
   m_validate_mtf = false;
   m_mtf_timeframe = PERIOD_H1;
   m_need_redraw = true;
   m_weights = ScoreWeights();

   m_low_cache.confirmation_bars = m_confirm_bars;
   m_high_cache.confirmation_bars = m_confirm_bars;
   m_lta_version.stability_threshold = m_stability_bars;
   m_ltb_version.stability_threshold = m_stability_bars;
   m_atr_handle = INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTrendLine::~CTrendLine()
{
   DeleteObjects();
   ReleaseFractalsHandle();
   ReleaseATRHandle();
   ArrayFree(m_lta_buffer);
   ArrayFree(m_ltb_buffer);
   ArrayFree(m_lows);
   ArrayFree(m_highs);
   ArrayFree(m_low_cache.confirmed_points);
   ArrayFree(m_low_cache.candidate_points);
   ArrayFree(m_high_cache.confirmed_points);
   ArrayFree(m_high_cache.candidate_points);
}

//+------------------------------------------------------------------+
//| Init with configuration structure                                |
//+------------------------------------------------------------------+
bool CTrendLine::Init(string symbol, ENUM_TIMEFRAMES timeframe, CTrendLineConfig &config)
{
   m_symbol = symbol;
   m_timeframe = timeframe;
   m_period = config.period;
   m_left = config.left;
   m_right = config.right;
   
   m_draw_lta = config.draw_lta;
   m_draw_ltb = config.draw_ltb;
   m_lta_color = config.lta_color;
   m_ltb_color = config.ltb_color;
   m_lta_style = config.lta_style;
   m_ltb_style = config.ltb_style;
   m_lta_width = config.lta_width;
   m_ltb_width = config.ltb_width;
   m_extend_right = config.extend_right;
  m_show_labels = config.show_labels;
  m_stability_bars = config.stability_bars;
   m_confirm_bars = config.confirm_bars;
  m_min_distance = config.min_distance;
  m_validate_mtf = config.validate_mtf;
  m_mtf_timeframe = config.mtf_timeframe;
  m_weights = config.weights;
  m_update_ctrl.params = config.update_control;
   
   // Criar nomes únicos para objetos
   string suffix = "_" + m_symbol + "_" + EnumToString(m_timeframe) + "_" + IntegerToString(GetTickCount());
   m_lta_line_name = "LTA_Line" + suffix;
   m_ltb_line_name = "LTB_Line" + suffix;
   m_lta_label_name = "LTA_Label" + suffix;
  m_ltb_label_name = "LTB_Label" + suffix;

  m_low_cache.confirmation_bars = m_confirm_bars;
  m_high_cache.confirmation_bars = m_confirm_bars;
  m_lta_version.stability_threshold = m_stability_bars;
  m_ltb_version.stability_threshold = m_stability_bars;
  ReleaseFractalsHandle();
  ReleaseATRHandle();
  if(!CreateFractalsHandle())
     return false;
  return CreateATRHandle();
}

//+------------------------------------------------------------------+
//| Interface base implementation                                    |
//+------------------------------------------------------------------+
bool CTrendLine::Init(string symbol, ENUM_TIMEFRAMES timeframe, int period)
{
   CTrendLineConfig default_config;
   default_config.period = period;
   return Init(symbol, timeframe, default_config);
}

//+------------------------------------------------------------------+
//| Create fractals handle                                           |
//+------------------------------------------------------------------+
bool CTrendLine::CreateFractalsHandle()
{
   m_fractals_handle = iFractals(m_symbol, m_timeframe);
   if(m_fractals_handle == INVALID_HANDLE)
   {
      Print("ERRO: Falha ao criar handle Fractals para ", m_symbol, " ", EnumToString(m_timeframe));
      return false;
   }
   
   Print("TrendLine inicializado para ", m_symbol, " - ", EnumToString(m_timeframe), " - Período: ", m_period);
   return true;
}

//+------------------------------------------------------------------+
//| Release fractals handle                                          |
//+------------------------------------------------------------------+
void CTrendLine::ReleaseFractalsHandle()
{
   if(m_fractals_handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_fractals_handle);
      m_fractals_handle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Create ATR handle                                                |
//+------------------------------------------------------------------+
bool CTrendLine::CreateATRHandle()
{
   m_atr_handle = iATR(m_symbol, m_timeframe, 14);
   if(m_atr_handle == INVALID_HANDLE)
   {
      Print("ERRO: Falha ao criar handle ATR para ", m_symbol);
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Release ATR handle                                               |
//+------------------------------------------------------------------+
void CTrendLine::ReleaseATRHandle()
{
   if(m_atr_handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_atr_handle);
      m_atr_handle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Get ATR value                                                    |
//+------------------------------------------------------------------+
double CTrendLine::GetATR(int shift)
{
   if(m_atr_handle == INVALID_HANDLE)
      return 0.0;

   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(m_atr_handle, 0, shift, 1, buf) <= 0)
      return 0.0;

   return buf[0];
}

//+------------------------------------------------------------------+
//| Update fractals data                                             |
//+------------------------------------------------------------------+
bool CTrendLine::UpdateFractals(bool &updated)
{
   if(m_fractals_handle == INVALID_HANDLE)
      return false;

   datetime cur_time=iTime(m_symbol,m_timeframe,0);
   updated=false;
   if(m_low_cache.last_update_time==cur_time)
      return true;  // dados já atualizados

   updated=true;

   m_low_cache.last_update_time=cur_time;
   m_high_cache.last_update_time=cur_time;

   double upper_fractals[];
   double lower_fractals[];
   
   ArraySetAsSeries(upper_fractals, true);
   ArraySetAsSeries(lower_fractals, true);
   
   int bars_to_copy = MathMin(m_period * 2, Bars(m_symbol, m_timeframe));
   
   if(CopyBuffer(m_fractals_handle, 0, 0, bars_to_copy, upper_fractals) <= 0 ||
      CopyBuffer(m_fractals_handle, 1, 0, bars_to_copy, lower_fractals) <= 0)
   {
      Print("ERRO: Falha ao copiar dados dos fractais");
      return false;
   }
   
   // Limpar caches
   ArrayResize(m_high_cache.candidate_points,0);
   ArrayResize(m_low_cache.candidate_points,0);
   ArrayResize(m_high_cache.confirmed_points,0);
   ArrayResize(m_low_cache.confirmed_points,0);

   // Extrair fractais válidos com confirmação
   // Processar do mais antigo para o mais recente para manter ordem cronológica
   for(int i=bars_to_copy-1;i>=0;i--)
   {
      if(upper_fractals[i]!=EMPTY_VALUE && upper_fractals[i]>0)
      {
         SFractalPoint p; p.price=upper_fractals[i]; p.bar_index=i; p.time=iTime(m_symbol,m_timeframe,i); p.is_valid=true;
         if(i>=m_confirm_bars)
         {
            int pos=ArraySize(m_high_cache.confirmed_points);
            ArrayResize(m_high_cache.confirmed_points,pos+1);
            m_high_cache.confirmed_points[pos]=p;
         }
         else
         {
            int pos=ArraySize(m_high_cache.candidate_points);
            ArrayResize(m_high_cache.candidate_points,pos+1);
            m_high_cache.candidate_points[pos]=p;
         }
      }

      if(lower_fractals[i]!=EMPTY_VALUE && lower_fractals[i]>0)
      {
         SFractalPoint p; p.price=lower_fractals[i]; p.bar_index=i; p.time=iTime(m_symbol,m_timeframe,i); p.is_valid=true;
         if(i>=m_confirm_bars)
         {
            int pos=ArraySize(m_low_cache.confirmed_points);
            ArrayResize(m_low_cache.confirmed_points,pos+1);
            m_low_cache.confirmed_points[pos]=p;
         }
         else
         {
            int pos=ArraySize(m_low_cache.candidate_points);
            ArrayResize(m_low_cache.candidate_points,pos+1);
            m_low_cache.candidate_points[pos]=p;
         }
      }
   }

   // Copiar para arrays antigos para compatibilidade
   ArrayCopy(m_highs,m_high_cache.confirmed_points);
   ArrayCopy(m_lows,m_low_cache.confirmed_points);

   return true;
}

//+------------------------------------------------------------------+
//| Find trend lines from fractals                                   |
//+------------------------------------------------------------------+
void CTrendLine::FindTrendLines()
{
   m_lta_valid = false;
   m_ltb_valid = false;

   // ----- Procurar LTA -----
   // Usar apenas fractais confirmados para evitar linhas instáveis
   SFractalPoint lows_all[];
   ArrayCopy(lows_all,m_low_cache.confirmed_points); // ordem: [0] = mais antigo
   if(ArraySize(lows_all) > TRENDLINE_MAX_FRACTALS)
      ArrayResize(lows_all, TRENDLINE_MAX_FRACTALS);

   if(m_draw_lta && ArraySize(lows_all) >= 2)
   {
      double best_score = -1;
      SFractalPoint best_p1, best_p2;
      for(int i = 0; i < ArraySize(lows_all) - 1; i++)
      {
         for(int j = i + 1; j < ArraySize(lows_all); j++)
         {
            // lows_all[i] é o ponto mais antigo; lows_all[j], o mais recente
            if(!IsValidLTA(lows_all[i], lows_all[j]))
               continue;
            if((lows_all[i].bar_index - lows_all[j].bar_index) < m_min_distance)
               continue;

            double score = ScorePair(lows_all[i], lows_all[j]);
            if(score < TRENDLINE_SCORE_THRESHOLD) continue;
            if(score > best_score)
            {
               best_score = score;
               best_p1 = lows_all[i];
               best_p2 = lows_all[j];
            }
         }
      }

      if(best_score > 0 && ValidateLineWithMTF(best_p1, best_p2))
         UpdateTrendState(m_lta_version.candidate, best_p1, best_p2);

      if(m_lta_version.candidate.stability_count >= m_lta_version.stability_threshold)
      {
         m_lta_version.confirmed = m_lta_version.candidate;
         m_lta_version.confirmed.valid = true;
         m_need_redraw = true;
      }

      if(m_lta_version.confirmed.valid)
      {
         m_lta_point1 = m_lta_version.confirmed.p1;
         m_lta_point2 = m_lta_version.confirmed.p2;
         m_lta_valid = (m_lta_point2.price > m_lta_point1.price);
      }
   }

   // ----- Procurar LTB -----
   SFractalPoint highs_all[];
   // Apenas fractais confirmados para estabilidade
   ArrayCopy(highs_all,m_high_cache.confirmed_points); // ordem: [0] = mais antigo
   if(ArraySize(highs_all) > TRENDLINE_MAX_FRACTALS)
      ArrayResize(highs_all, TRENDLINE_MAX_FRACTALS);

   if(m_draw_ltb && ArraySize(highs_all) >= 2)
   {
      double best_score = -1;
      SFractalPoint best_p1, best_p2;
      for(int i = 0; i < ArraySize(highs_all) - 1; i++)
      {
         for(int j = i + 1; j < ArraySize(highs_all); j++)
         {
            // highs_all[i] é o ponto mais antigo; highs_all[j], o mais recente
            if(!IsValidLTB(highs_all[i], highs_all[j]))
               continue;
            if((highs_all[i].bar_index - highs_all[j].bar_index) < m_min_distance)
               continue;

            double score = ScorePair(highs_all[i], highs_all[j]);
            if(score < TRENDLINE_SCORE_THRESHOLD) continue;
            if(score > best_score)
            {
               best_score = score;
               best_p1 = highs_all[i];
               best_p2 = highs_all[j];
            }
         }
      }

      if(best_score > 0 && ValidateLineWithMTF(best_p1, best_p2))
         UpdateTrendState(m_ltb_version.candidate, best_p1, best_p2);

      if(m_ltb_version.candidate.stability_count >= m_ltb_version.stability_threshold)
      {
         m_ltb_version.confirmed = m_ltb_version.candidate;
         m_ltb_version.confirmed.valid = true;
         m_need_redraw = true;
      }

      if(m_ltb_version.confirmed.valid)
      {
         m_ltb_point1 = m_ltb_version.confirmed.p1;
         m_ltb_point2 = m_ltb_version.confirmed.p2;
         m_ltb_valid = (m_ltb_point2.price < m_ltb_point1.price);
      }
   }
   ValidateLineCorrections();
}

//+------------------------------------------------------------------+
//| Check if LTA is valid (ascending lows)                          |
//+------------------------------------------------------------------+
bool CTrendLine::IsValidLTA(SFractalPoint &p_old, SFractalPoint &p_recent)
{
   // p_old   : ponto mais antigo (índice maior)
   // p_recent: ponto mais recente (índice menor)
   // Para LTA: o preço mais recente (p_recent) deve ser maior que o antigo
   if(p_old.bar_index <= p_recent.bar_index)
      return false;
   return (p_recent.price > p_old.price);
}

//+------------------------------------------------------------------+
//| Check if LTB is valid (descending highs)                        |
//+------------------------------------------------------------------+
bool CTrendLine::IsValidLTB(SFractalPoint &p_old, SFractalPoint &p_recent)
{
   // p_old   : ponto mais antigo (índice maior)
   // p_recent: ponto mais recente (índice menor)
   // Para LTB: o preço mais recente (p_recent) deve ser menor que o antigo
   if(p_old.bar_index <= p_recent.bar_index)
      return false;
   return (p_recent.price < p_old.price);
}

//+------------------------------------------------------------------+
//| Calculate price of line at specific shift                        |
//+------------------------------------------------------------------+
double CTrendLine::CalculateLinePrice(SFractalPoint &point1, SFractalPoint &point2, int shift)
{
   if(!point1.is_valid || !point2.is_valid)
      return EMPTY_VALUE;
      
   // point1 é o ponto mais antigo (maior bar_index)
   // point2 é o ponto mais recente (menor bar_index)
   
   int delta_bars = point1.bar_index - point2.bar_index;
   if(delta_bars == 0) return point1.price; // Evitar divisão por zero
   
   // Calcular coeficiente angular da reta
   double slope = (point2.price - point1.price) / (double)delta_bars;
   
   // Calcular preço no shift especificado
   // A fórmula: preço = preço_do_ponto_mais_recente + slope * (bar_index_ponto_recente - shift)
   double price = point2.price + slope * (point2.bar_index - shift);
   double deviation=MathAbs(price-point2.price)/MathMax(point2.price,1);
   if(deviation>1.0 || price<=0 || MathAbs(shift-point2.bar_index)>(delta_bars*2))
      return EMPTY_VALUE;
   
   return price;
}

//+------------------------------------------------------------------+
//| Calculate buffers with line prices                               |
//+------------------------------------------------------------------+
void CTrendLine::CalculateBuffers()
{
   int bars = Bars(m_symbol, m_timeframe);
   if(bars <= 0) return;
   
   ArrayResize(m_lta_buffer, bars);
   ArrayResize(m_ltb_buffer, bars);
   ArraySetAsSeries(m_lta_buffer, true);
   ArraySetAsSeries(m_ltb_buffer, true);
   
   // Preencher buffers
   for(int i = 0; i < bars; i++)
   {
      if(m_lta_valid)
         m_lta_buffer[i] = CalculateLinePrice(m_lta_point1, m_lta_point2, i);
      else
         m_lta_buffer[i] = EMPTY_VALUE;
         
      if(m_ltb_valid)
         m_ltb_buffer[i] = CalculateLinePrice(m_ltb_point1, m_ltb_point2, i);
      else
         m_ltb_buffer[i] = EMPTY_VALUE;
   }
}

//+------------------------------------------------------------------+
//| Draw trend lines on chart                                        |
//+------------------------------------------------------------------+
void CTrendLine::DrawLines()
{
   if(!m_need_redraw)
      return;
   m_need_redraw=false;
   DeleteObjects();
   
   // Desenhar LTA
   if(m_lta_valid && m_draw_lta)
   {
      // Ponto de início: mais antigo
      datetime start_time = m_lta_point1.time;
      double start_price = m_lta_point1.price;
      
      // Ponto de fim: calcular baseado na extensão
      datetime end_time;
      double end_price;
      
      if(m_extend_right)
      {
         // Estender a linha para frente (shift negativo para projeção futura)
         end_time = TimeCurrent() + PeriodSeconds(m_timeframe) * 20;
         end_price = CalculateLinePrice(m_lta_point1, m_lta_point2, -20);
      }
      else
      {
         // Terminar no ponto mais recente
         end_time = m_lta_point2.time;
         end_price = m_lta_point2.price;
      }
      
      Print("Desenhando LTA: ", start_time, " @ ", start_price, " -> ", end_time, " @ ", end_price);
      
      if(ObjectCreate(0, m_lta_line_name, OBJ_TREND, 0, start_time, start_price, end_time, end_price))
      {
         ObjectSetInteger(0, m_lta_line_name, OBJPROP_COLOR, m_lta_color);
         ObjectSetInteger(0, m_lta_line_name, OBJPROP_STYLE, m_lta_style);
         ObjectSetInteger(0, m_lta_line_name, OBJPROP_WIDTH, m_lta_width);
         ObjectSetInteger(0, m_lta_line_name, OBJPROP_RAY_RIGHT, m_extend_right);
         ObjectSetInteger(0, m_lta_line_name, OBJPROP_SELECTABLE, true);
         
         if(m_show_labels)
         {
            if(ObjectCreate(0, m_lta_label_name, OBJ_TEXT, 0, start_time, start_price - 50 * _Point))
            {
               ObjectSetString(0, m_lta_label_name, OBJPROP_TEXT, "LTA");
               ObjectSetInteger(0, m_lta_label_name, OBJPROP_COLOR, m_lta_color);
               ObjectSetInteger(0, m_lta_label_name, OBJPROP_FONTSIZE, 8);
            }
         }
      }
      else
      {
         Print("ERRO: Falha ao criar objeto LTA");
      }
   }
   
   // Desenhar LTB
   if(m_ltb_valid && m_draw_ltb)
   {
      // Ponto de início: mais antigo
      datetime start_time = m_ltb_point1.time;
      double start_price = m_ltb_point1.price;
      
      // Ponto de fim: calcular baseado na extensão
      datetime end_time;
      double end_price;
      
      if(m_extend_right)
      {
         // Estender a linha para frente
         end_time = TimeCurrent() + PeriodSeconds(m_timeframe) * 20;
         end_price = CalculateLinePrice(m_ltb_point1, m_ltb_point2, -20);
      }
      else
      {
         // Terminar no ponto mais recente
         end_time = m_ltb_point2.time;
         end_price = m_ltb_point2.price;
      }
      
      Print("Desenhando LTB: ", start_time, " @ ", start_price, " -> ", end_time, " @ ", end_price);
      
      if(ObjectCreate(0, m_ltb_line_name, OBJ_TREND, 0, start_time, start_price, end_time, end_price))
      {
         ObjectSetInteger(0, m_ltb_line_name, OBJPROP_COLOR, m_ltb_color);
         ObjectSetInteger(0, m_ltb_line_name, OBJPROP_STYLE, m_ltb_style);
         ObjectSetInteger(0, m_ltb_line_name, OBJPROP_WIDTH, m_ltb_width);
         ObjectSetInteger(0, m_ltb_line_name, OBJPROP_RAY_RIGHT, m_extend_right);
         ObjectSetInteger(0, m_ltb_line_name, OBJPROP_SELECTABLE, true);
         
         if(m_show_labels)
         {
            if(ObjectCreate(0, m_ltb_label_name, OBJ_TEXT, 0, start_time, start_price + 50 * _Point))
            {
               ObjectSetString(0, m_ltb_label_name, OBJPROP_TEXT, "LTB");
               ObjectSetInteger(0, m_ltb_label_name, OBJPROP_COLOR, m_ltb_color);
               ObjectSetInteger(0, m_ltb_label_name, OBJPROP_FONTSIZE, 8);
            }
         }
      }
      else
      {
         Print("ERRO: Falha ao criar objeto LTB");
      }
   }
}

//+------------------------------------------------------------------+
//| Delete graphic objects                                           |
//+------------------------------------------------------------------+
void CTrendLine::DeleteObjects()
{
   if(StringLen(m_lta_line_name) > 0)
      ObjectDelete(0, m_lta_line_name);
   if(StringLen(m_ltb_line_name) > 0)
      ObjectDelete(0, m_ltb_line_name);
   if(StringLen(m_lta_label_name) > 0)
      ObjectDelete(0, m_lta_label_name);
   if(StringLen(m_ltb_label_name) > 0)
      ObjectDelete(0, m_ltb_label_name);
}

//+------------------------------------------------------------------+
//| Get line price at specific shift                                 |
//+------------------------------------------------------------------+
double CTrendLine::GetValue(int shift)
{
   // Por padrão, retorna LTA. Se não disponível, retorna LTB
   if(m_lta_valid && shift < ArraySize(m_lta_buffer))
      return m_lta_buffer[shift];
   else if(m_ltb_valid && shift < ArraySize(m_ltb_buffer))
      return m_ltb_buffer[shift];
      
   return EMPTY_VALUE;
}

//+------------------------------------------------------------------+
//| Copy line values to buffer                                       |
//+------------------------------------------------------------------+
bool CTrendLine::CopyValues(int shift, int count, double &buffer[])
{
   if(shift < 0 || count <= 0)
      return false;
      
   ArrayResize(buffer, count);
   ArraySetAsSeries(buffer, true);
   
   // Por padrão, copia LTA. Se não disponível, copia LTB
   double source_buffer[];
   if(m_lta_valid && ArraySize(m_lta_buffer) > 0)
      ArrayCopy(source_buffer, m_lta_buffer);
   else if(m_ltb_valid && ArraySize(m_ltb_buffer) > 0)
      ArrayCopy(source_buffer, m_ltb_buffer);
   else
      return false;
      
   int available = ArraySize(source_buffer) - shift;
   if(available <= 0)
      return false;
      
   int to_copy = MathMin(count, available);
   for(int i = 0; i < to_copy; i++)
   {
      buffer[i] = source_buffer[shift + i];
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Score candidate pair                                             |
//+------------------------------------------------------------------+
double CTrendLine::ScorePair(SFractalPoint &p_old, SFractalPoint &p_recent)
{
   int dist = p_old.bar_index - p_recent.bar_index;
   if(dist <= 0)
      return -1.0;

   TrendLineQuality q;
   q.trend_strength      = ComputeTrendStrength(p_old,p_recent);
   q.volume_confirmation = ComputeVolumeConfirmation(p_old,p_recent);
   q.line_tests          = ComputeLineTests(p_old,p_recent);
   q.time_validity       = ComputeTimeValidity(p_old,p_recent);
   q.psychological_level = ComputePsychologicalLevel(p_old,p_recent);
   q.volatility_context  = ComputeVolatilityContext(p_old,p_recent);
   q.mtf_alignment       = ValidateLineWithMTF(p_old,p_recent) ? 100.0 : 0.0;

   double total_w = m_weights.trend_weight + m_weights.volume_weight +
                    m_weights.tests_weight + m_weights.time_weight +
                    m_weights.psychological_weight + m_weights.volatility_weight +
                    m_weights.mtf_weight;
   if(total_w<=0.0) total_w=1.0;

   double score =
       q.trend_strength      * m_weights.trend_weight +
       q.volume_confirmation * m_weights.volume_weight +
       q.line_tests          * m_weights.tests_weight +
       q.time_validity       * m_weights.time_weight +
       q.psychological_level * m_weights.psychological_weight +
       q.volatility_context  * m_weights.volatility_weight +
       q.mtf_alignment       * m_weights.mtf_weight;

   return score / total_w;
}

//--- Cálculo dos fatores individuais ---
double CTrendLine::ComputeTrendStrength(SFractalPoint &p_old, SFractalPoint &p_recent)
{
   int dist=p_old.bar_index-p_recent.bar_index;
   if(dist<=0) return 0.0;
   double slope=MathAbs((p_recent.price-p_old.price)/dist);
   double rel=slope/MathMax(p_old.price,1);
   return MathMin(rel*10000.0,100.0);
}

double CTrendLine::ComputeVolumeConfirmation(SFractalPoint &p_old, SFractalPoint &p_recent)
{
   double v1=iVolume(m_symbol,m_timeframe,p_old.bar_index);
   double v2=iVolume(m_symbol,m_timeframe,p_recent.bar_index);
   double sum=0; int count=0;
   for(int i=0;i<20 && i<Bars(m_symbol,m_timeframe);i++)
   { sum+=iVolume(m_symbol,m_timeframe,i); count++; }
   double avg=(count>0)?sum/count:1.0;
   double rel=((v1+v2)/2.0)/MathMax(avg,1.0);
   return MathMin(rel*100.0,100.0);
}

double CTrendLine::ComputeLineTests(SFractalPoint &p_old, SFractalPoint &p_recent)
{
   int tests=0;
   for(int i=p_old.bar_index-1;i>p_recent.bar_index;i--)
   {
      double price=CalculateLinePrice(p_old,p_recent,i);
      double hi=iHigh(m_symbol,m_timeframe,i);
      double lo=iLow(m_symbol,m_timeframe,i);
      if(price>=lo && price<=hi)
         tests++;
   }
   return MathMin(tests*50.0,100.0); // 2 ou mais toques = 100
}

double CTrendLine::ComputeTimeValidity(SFractalPoint &p_old, SFractalPoint &p_recent)
{
   int dist=p_old.bar_index-p_recent.bar_index;
   return MathMin(dist*10.0,100.0);
}

double CTrendLine::ComputePsychologicalLevel(SFractalPoint &p_old, SFractalPoint &p_recent)
{
   double step=100.0;
   double diff1=MathAbs(p_old.price-MathRound(p_old.price/step)*step);
   double diff2=MathAbs(p_recent.price-MathRound(p_recent.price/step)*step);
   double diff=(diff1+diff2)/2.0;
   double score=100.0-(diff/(step*0.5))*100.0;
   if(score<0) score=0.0;
   return MathMin(score,100.0);
}

double CTrendLine::ComputeVolatilityContext(SFractalPoint &p_old, SFractalPoint &p_recent)
{
   int dist=p_old.bar_index-p_recent.bar_index;
   if(dist<=0) return 0.0;
   double slope=MathAbs((p_recent.price-p_old.price)/dist);
   double atr=GetATR(0);
   if(atr<=0) return 50.0;
   double rel=slope/atr;
   return MathMin(rel*50.0,100.0);
}

//+------------------------------------------------------------------+
//| Update persistent trend state                                    |
//+------------------------------------------------------------------+
void CTrendLine::UpdateTrendState(TrendLineState &state, SFractalPoint &p_old, SFractalPoint &p_recent)
{
   bool same=(state.p1.time==p_old.time && state.p2.time==p_recent.time);

   if(same)
      state.stability_count++;
   else
   {
      double dprice1=MathAbs(p_old.price-state.p1.price);
      double dprice2=MathAbs(p_recent.price-state.p2.price);
      int    dbar1=MathAbs(p_old.bar_index-state.p1.bar_index);
      int    dbar2=MathAbs(p_recent.bar_index-state.p2.bar_index);
      bool   near=(dbar1<=1 && dbar2<=1 &&
                   dprice1<=state.p1.price*0.001 &&
                   dprice2<=state.p2.price*0.001);

      if(!near && state.stability_count>1)
         state.stability_count--;
      else if(!near)
         state.stability_count=1;

      state.p1 = p_old;
      state.p2 = p_recent;
   }

   if(state.stability_count >= m_stability_bars)
   {
      state.valid = true;
      state.last_confirmation_time = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Validate line with higher timeframe                               |
//+------------------------------------------------------------------+
bool CTrendLine::ValidateLineWithMTF(SFractalPoint &p_old, SFractalPoint &p_recent)
{
   if(!m_validate_mtf || m_mtf_timeframe == PERIOD_CURRENT)
      return true;

   int sh1 = iBarShift(m_symbol, m_mtf_timeframe, p_old.time, false);
   int sh2 = iBarShift(m_symbol, m_mtf_timeframe, p_recent.time, false);
   if(sh1 < 0 || sh2 < 0)
      return false;

   double pr1 = iClose(m_symbol, m_mtf_timeframe, sh1);
   double pr2 = iClose(m_symbol, m_mtf_timeframe, sh2);
   if(pr1 == 0 || pr2 == 0)
      return false;

   double diff_htf = pr2 - pr1;
   double diff = p_recent.price - p_old.price;
   return ((diff_htf > 0 && diff > 0) || (diff_htf < 0 && diff < 0));
}

//+------------------------------------------------------------------+
//| Check if ready                                                   |
//+------------------------------------------------------------------+
bool CTrendLine::IsReady()
{
   return (BarsCalculated(m_fractals_handle) > 0);
}

//+------------------------------------------------------------------+
//| Determine if an update is needed                                 |
//+------------------------------------------------------------------+
bool CTrendLine::ShouldUpdate(ENUM_UPDATE_TRIGGER &trigger)
{
   trigger = TRIGGER_TIME_THRESHOLD;
   datetime now = TimeCurrent();

   // 1. Verificar novos fractais periodicamente
   if(now - m_update_ctrl.last_fractal_time >= m_update_ctrl.params.fractal_check_interval)
   {
      bool updated=false;
      if(UpdateFractals(updated) && updated)
      {
         m_update_ctrl.last_fractal_time = now;
         trigger = TRIGGER_NEW_FRACTAL;
         return true;
      }
   }

   double price = iClose(m_symbol, m_timeframe, 0);
   double tol   = m_update_ctrl.params.line_break_threshold;

   // 2. Verificar rompimento das linhas existentes
   if(m_lta_valid)
   {
      double lp = CalculateLinePrice(m_lta_point1, m_lta_point2, 0);
      if(price < lp * (1.0 - tol))
      {
         trigger = TRIGGER_LINE_BROKEN;
         return true;
      }
   }

   if(m_ltb_valid)
   {
      double lp = CalculateLinePrice(m_ltb_point1, m_ltb_point2, 0);
      if(price > lp * (1.0 + tol))
      {
         trigger = TRIGGER_LINE_BROKEN;
         return true;
      }
   }

   // 3. Checar volatilidade
   double atr_now  = GetATR(0);
   double atr_prev = GetATR(1);
   if(atr_prev > 0 && MathAbs(atr_now - atr_prev) / atr_prev >= m_update_ctrl.params.volatility_threshold)
   {
      trigger = TRIGGER_VOLATILITY_SPIKE;
      return true;
   }

   // 4. Intervalo mínimo
   if(now - m_update_ctrl.last_update >= m_update_ctrl.params.min_update_interval)
   {
      trigger = TRIGGER_TIME_THRESHOLD;
      return true;
   }

   // 5. Atualização manual pendente
   if(m_update_ctrl.pending_line_update || m_update_ctrl.pending_draw_update)
   {
      trigger = TRIGGER_MANUAL_REFRESH;
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Executar update condicional                                      |
//+------------------------------------------------------------------+
void CTrendLine::ConditionalUpdate(ENUM_UPDATE_TRIGGER trigger)
{
   switch(trigger)
   {
      case TRIGGER_NEW_FRACTAL:
         FindTrendLines();
         CalculateBuffers();
         DrawLines();
         break;
      case TRIGGER_LINE_BROKEN:
         CalculateBuffers();
         DrawLines();
         break;
      case TRIGGER_VOLATILITY_SPIKE:
         FindTrendLines();
         CalculateBuffers();
         DrawLines();
         break;
      case TRIGGER_MANUAL_REFRESH:
         FindTrendLines();
         CalculateBuffers();
         DrawLines();
         m_update_ctrl.pending_line_update=false;
         m_update_ctrl.pending_draw_update=false;
         break;
      case TRIGGER_TIME_THRESHOLD:
      case TRIGGER_CONFIG_CHANGE:
         CalculateBuffers();
         DrawLines();
         break;
   }
}

//+------------------------------------------------------------------+
//| Update trend lines                                               |
//+------------------------------------------------------------------+
bool CTrendLine::Update()
{
   if(!IsReady())
      return false;

   ENUM_UPDATE_TRIGGER trig;
   if(!ShouldUpdate(trig))
      return false;

   ConditionalUpdate(trig);
   m_update_ctrl.last_update = TimeCurrent();
   return true;
}
double CTrendLine::GetLTASlope()
{
   if(!m_lta_valid) return 0.0;
   int dist=m_lta_point1.bar_index-m_lta_point2.bar_index;
   if(dist==0) return 0.0;
   return (m_lta_point2.price-m_lta_point1.price)/(double)dist;
}

double CTrendLine::GetLTBSlope()
{
   if(!m_ltb_valid) return 0.0;
   int dist=m_ltb_point1.bar_index-m_ltb_point2.bar_index;
   if(dist==0) return 0.0;
   return (m_ltb_point2.price-m_ltb_point1.price)/(double)dist;
}

ENUM_TRENDLINE_DIRECTION CTrendLine::GetLineDirection(SFractalPoint &p1, SFractalPoint &p2)
{
   if(p2.price > p1.price)
      return TRENDLINE_ASCENDING;
   else if(p2.price < p1.price)
      return TRENDLINE_DESCENDING;
   else
      return TRENDLINE_HORIZONTAL;
}

void CTrendLine::GetLTAPoints(SFractalPoint &p1, SFractalPoint &p2){p1=m_lta_point1;p2=m_lta_point2;}
void CTrendLine::GetLTBPoints(SFractalPoint &p1, SFractalPoint &p2){p1=m_ltb_point1;p2=m_ltb_point2;}
bool CTrendLine::IsLTAValid(){return m_lta_valid;}
bool CTrendLine::IsLTBValid(){return m_ltb_valid;}
double CTrendLine::GetLTAValue(int shift){if(!m_lta_valid||shift>=ArraySize(m_lta_buffer))return EMPTY_VALUE;return m_lta_buffer[shift];}
double CTrendLine::GetLTBValue(int shift){if(!m_ltb_valid||shift>=ArraySize(m_ltb_buffer))return EMPTY_VALUE;return m_ltb_buffer[shift];}
void CTrendLine::PrintLineStatus(){
   Print("LTA",m_lta_valid,
         " slope",GetLTASlope(),
         " dir",GetLineDirection(m_lta_point1,m_lta_point2),
         " p1",m_lta_point1.bar_index," ",m_lta_point1.price,
         " p2",m_lta_point2.bar_index," ",m_lta_point2.price);
   Print("LTB",m_ltb_valid,
         " slope",GetLTBSlope(),
         " dir",GetLineDirection(m_ltb_point1,m_ltb_point2),
         " p1",m_ltb_point1.bar_index," ",m_ltb_point1.price,
         " p2",m_ltb_point2.bar_index," ",m_ltb_point2.price);
}
void CTrendLine::ValidateLineCorrections()
{
   if(m_lta_version.confirmed.valid)
   {
      double os=(m_lta_version.confirmed.p2.price-m_lta_version.confirmed.p1.price)/
                (double)(m_lta_version.confirmed.p1.bar_index-m_lta_version.confirmed.p2.bar_index);
      double ns=(m_lta_version.candidate.p2.price-m_lta_version.candidate.p1.price)/
                (double)(m_lta_version.candidate.p1.bar_index-m_lta_version.candidate.p2.bar_index);
      if(ns<=0.0 || MathAbs(ns-os)/MathMax(MathAbs(os),0.0001)>0.1)
         m_lta_version.candidate=m_lta_version.confirmed;
   }

   if(m_ltb_version.confirmed.valid)
   {
      double os=(m_ltb_version.confirmed.p2.price-m_ltb_version.confirmed.p1.price)/
                (double)(m_ltb_version.confirmed.p1.bar_index-m_ltb_version.confirmed.p2.bar_index);
      double ns=(m_ltb_version.candidate.p2.price-m_ltb_version.candidate.p1.price)/
                (double)(m_ltb_version.candidate.p1.bar_index-m_ltb_version.candidate.p2.bar_index);
      if(ns>=0.0 || MathAbs(ns-os)/MathMax(MathAbs(os),0.0001)>0.1)
         m_ltb_version.candidate=m_ltb_version.confirmed;
   }
}



#endif // __TRENDLINE_MQH__
