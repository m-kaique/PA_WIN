//+------------------------------------------------------------------+
//|                                    priceaction/trendline.mqh      |
//|  TrendLine pattern detection with LTA/LTB drawing using Fractals |
//+------------------------------------------------------------------+
#ifndef __TRENDLINE_MQH__
#define __TRENDLINE_MQH__

#include "../priceaction_base.mqh"
#include "../../config_types.mqh"
#include "trendline_defs.mqh"

// Estrutura para armazenar um ponto fractal
struct SFractalPoint
{
   datetime time;
   double price;
   int bar_index;
   bool is_valid;
   
   SFractalPoint() : time(0), price(0.0), bar_index(-1), is_valid(false) {}
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
   
   // Métodos privados
   bool            CreateFractalsHandle();
   void            ReleaseFractalsHandle();
   bool            UpdateFractals();
   void            FindTrendLines();
   void            CalculateBuffers();
   double          CalculateLinePrice(SFractalPoint &point1, SFractalPoint &point2, int shift);
   void            DrawLines();
   void            DeleteObjects();
   bool            IsValidLTA(SFractalPoint &p1, SFractalPoint &p2);
   bool            IsValidLTB(SFractalPoint &p1, SFractalPoint &p2);

public:
   CTrendLine();
   ~CTrendLine();

   bool            Init(string symbol, ENUM_TIMEFRAMES timeframe, CTrendLineConfig &config);
   virtual bool    Init(string symbol, ENUM_TIMEFRAMES timeframe, int period);
   virtual double  GetValue(int shift = 0);
   virtual bool    CopyValues(int shift, int count, double &buffer[]);
   virtual bool    IsReady();
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
   
   m_lta_line_name = "";
   m_ltb_line_name = "";
   m_lta_label_name = "";
   m_ltb_label_name = "";
   
   m_lta_valid = false;
   m_ltb_valid = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTrendLine::~CTrendLine()
{
   DeleteObjects();
   ReleaseFractalsHandle();
   ArrayFree(m_lta_buffer);
   ArrayFree(m_ltb_buffer);
   ArrayFree(m_lows);
   ArrayFree(m_highs);
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
   
   // Criar nomes únicos para objetos
   string suffix = "_" + m_symbol + "_" + EnumToString(m_timeframe) + "_" + IntegerToString(GetTickCount());
   m_lta_line_name = "LTA_Line" + suffix;
   m_ltb_line_name = "LTB_Line" + suffix;
   m_lta_label_name = "LTA_Label" + suffix;
   m_ltb_label_name = "LTB_Label" + suffix;
   
   ReleaseFractalsHandle();
   return CreateFractalsHandle();
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
//| Update fractals data                                             |
//+------------------------------------------------------------------+
bool CTrendLine::UpdateFractals()
{
   if(m_fractals_handle == INVALID_HANDLE)
      return false;
      
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
   
   // Limpar arrays
   ArrayResize(m_highs, 0);
   ArrayResize(m_lows, 0);
   
   // Extrair fractais válidos
   for(int i = 0; i < bars_to_copy; i++)
   {
      // Fractal superior (máximo)
      if(upper_fractals[i] != EMPTY_VALUE && upper_fractals[i] > 0)
      {
         SFractalPoint point;
         point.price = upper_fractals[i];
         point.bar_index = i;
         point.time = iTime(m_symbol, m_timeframe, i);
         point.is_valid = true;
         
         int pos = ArraySize(m_highs);
         ArrayResize(m_highs, pos + 1);
         m_highs[pos] = point;
      }
      
      // Fractal inferior (mínimo)
      if(lower_fractals[i] != EMPTY_VALUE && lower_fractals[i] > 0)
      {
         SFractalPoint point;
         point.price = lower_fractals[i];
         point.bar_index = i;
         point.time = iTime(m_symbol, m_timeframe, i);
         point.is_valid = true;
         
         int pos = ArraySize(m_lows);
         ArrayResize(m_lows, pos + 1);
         m_lows[pos] = point;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Find trend lines from fractals                                   |
//+------------------------------------------------------------------+
void CTrendLine::FindTrendLines()
{
   m_lta_valid = false;
   m_ltb_valid = false;
   
   // Buscar LTA (conecta mínimos ascendentes)
   if(m_draw_lta && ArraySize(m_lows) >= 2)
   {
      // Procurar os dois mínimos mais recentes que formem uma linha ascendente
      for(int i = 0; i < ArraySize(m_lows) - 1; i++)
      {
         for(int j = i + 1; j < ArraySize(m_lows); j++)
         {
            // Como arrays estão em ordem cronológica reversa (mais recente primeiro)
            // m_lows[i] é mais recente que m_lows[j]
            if(m_lows[i].bar_index < m_lows[j].bar_index && m_lows[i].price > m_lows[j].price)
            {
               m_lta_point1 = m_lows[j]; // Ponto mais antigo (maior bar_index)
               m_lta_point2 = m_lows[i]; // Ponto mais recente (menor bar_index)
               m_lta_valid = true;
               
               Print("LTA encontrada: P1[", m_lta_point1.bar_index, "] = ", m_lta_point1.price, 
                     " -> P2[", m_lta_point2.bar_index, "] = ", m_lta_point2.price);
               break;
            }
         }
         if(m_lta_valid) break;
      }
   }
   
   // Buscar LTB (conecta máximos descendentes)
   if(m_draw_ltb && ArraySize(m_highs) >= 2)
   {
      // Procurar os dois máximos mais recentes que formem uma linha descendente
      for(int i = 0; i < ArraySize(m_highs) - 1; i++)
      {
         for(int j = i + 1; j < ArraySize(m_highs); j++)
         {
            // Como arrays estão em ordem cronológica reversa (mais recente primeiro)
            // m_highs[i] é mais recente que m_highs[j]
            if(m_highs[i].bar_index < m_highs[j].bar_index && m_highs[i].price < m_highs[j].price)
            {
               m_ltb_point1 = m_highs[j]; // Ponto mais antigo (maior bar_index)
               m_ltb_point2 = m_highs[i]; // Ponto mais recente (menor bar_index)
               m_ltb_valid = true;
               
               Print("LTB encontrada: P1[", m_ltb_point1.bar_index, "] = ", m_ltb_point1.price, 
                     " -> P2[", m_ltb_point2.bar_index, "] = ", m_ltb_point2.price);
               break;
            }
         }
         if(m_ltb_valid) break;
      }
   }
}

//+------------------------------------------------------------------+
//| Check if LTA is valid (ascending lows)                          |
//+------------------------------------------------------------------+
bool CTrendLine::IsValidLTA(SFractalPoint &p1, SFractalPoint &p2)
{
   // p1 é mais recente (índice menor), p2 é mais antigo (índice maior)
   // Para LTA: preço mais recente deve ser maior que o antigo
   return (p1.bar_index < p2.bar_index && p1.price > p2.price);
}

//+------------------------------------------------------------------+
//| Check if LTB is valid (descending highs)                        |
//+------------------------------------------------------------------+
bool CTrendLine::IsValidLTB(SFractalPoint &p1, SFractalPoint &p2)
{
   // p1 é mais recente (índice menor), p2 é mais antigo (índice maior)
   // Para LTB: preço mais recente deve ser menor que o antigo
   return (p1.bar_index < p2.bar_index && p1.price < p2.price);
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
//| Check if ready                                                   |
//+------------------------------------------------------------------+
bool CTrendLine::IsReady()
{
   return (BarsCalculated(m_fractals_handle) > 0);
}

//+------------------------------------------------------------------+
//| Update trend lines                                               |
//+------------------------------------------------------------------+
bool CTrendLine::Update()
{
   if(!IsReady())
      return false;
      
   // Atualizar fractais
   if(!UpdateFractals())
      return false;
      
   // Encontrar linhas de tendência
   FindTrendLines();
   
   // Calcular buffers
   CalculateBuffers();
   
   // Desenhar linhas
   DrawLines();
   
   return true;
}

#endif // __TRENDLINE_MQH__