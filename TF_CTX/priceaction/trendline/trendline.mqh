//+------------------------------------------------------------------+
//|                                    priceaction/trendline.mqh      |
//|  TrendLine pattern detection with LTA/LTB drawing CORRECTED      |
//+------------------------------------------------------------------+
#ifndef __TRENDLINE_MQH__
#define __TRENDLINE_MQH__

#include "../priceaction_base.mqh"
#include "../../config_types.mqh"
#include "trendline_defs.mqh"

class CTrendLine : public CPriceActionBase
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_period;
   int               m_left;
   int               m_right;
   
   // Configurações de desenho
   bool              m_draw_lta;
   bool              m_draw_ltb;
   color             m_lta_color;
   color             m_ltb_color;
   ENUM_LINE_STYLE   m_lta_style;
   ENUM_LINE_STYLE   m_ltb_style;
   int               m_lta_width;
   int               m_ltb_width;
   bool              m_extend_right;
   bool              m_show_labels;
   
   // Dados da LTA (Linha de Tendência de Alta - conecta mínimos ascendentes)
   datetime          m_lta_time1;
   double            m_lta_price1;
   datetime          m_lta_time2;
   double            m_lta_price2;
   bool              m_lta_valid;
   string            m_lta_line_name;
   string            m_lta_label_name;
   
   // Dados da LTB (Linha de Tendência de Baixa - conecta máximos descendentes)
   datetime          m_ltb_time1;
   double            m_ltb_price1;
   datetime          m_ltb_time2;
   double            m_ltb_price2;
   bool              m_ltb_valid;
   string            m_ltb_line_name;
   string            m_ltb_label_name;
   
   bool              m_ready;
   string            m_obj_prefix;

   // Métodos privados
   bool              DetectTrendLines();
   bool              FindLTA(datetime &time1, double &price1, datetime &time2, double &price2);
   bool              FindLTB(datetime &time1, double &price1, datetime &time2, double &price2);
   bool              IsValidSwingLow(int index);
   bool              IsValidSwingHigh(int index);
   double            CalculateTrendLinePrice(datetime time1, double price1, datetime time2, double price2, datetime target_time);
   void              DrawTrendLines();
   void              DeleteObjects();
   ENUM_TRENDLINE_DIRECTION GetTrendDirection(double price1, double price2);
   bool              IsAscendingTrend(double price1, double price2);
   bool              IsDescendingTrend(double price1, double price2);

public:
                     CTrendLine();
                    ~CTrendLine();

   bool              Init(string symbol, ENUM_TIMEFRAMES timeframe,
                         int period, int left, int right);
   bool              Init(string symbol, ENUM_TIMEFRAMES timeframe,
                         CTrendLineConfig &config);

   // Implementação da interface base
   virtual bool      Init(string symbol, ENUM_TIMEFRAMES timeframe, int period);
   virtual double    GetValue(int shift=0);       // Retorna preço da LTA por padrão
   virtual bool      CopyValues(int shift, int count, double &buffer[]);
   virtual bool      IsReady();
   virtual bool      Update();

   // Métodos específicos da TrendLine
   double            GetLTAPrice(int shift=0);     // Linha de Tendência de Alta
   double            GetLTBPrice(int shift=0);     // Linha de Tendência de Baixa
   bool              IsLTAValid();
   bool              IsLTBValid();
   bool              GetLTAPoints(datetime &time1, double &price1, datetime &time2, double &price2);
   bool              GetLTBPoints(datetime &time1, double &price1, datetime &time2, double &price2);
   ENUM_TRENDLINE_DIRECTION GetLTADirection();
   ENUM_TRENDLINE_DIRECTION GetLTBDirection();
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTrendLine::CTrendLine()
  {
   m_symbol="";
   m_timeframe=PERIOD_CURRENT;
   m_period=50; // Período maior para análise mais consistente
   m_left=5;    // Mais velas para confirmar pivôs
   m_right=5;
   
   // Configurações padrão de desenho
   m_draw_lta=true;
   m_draw_ltb=true;
   m_lta_color=clrGreen;  // Verde para linha de alta
   m_ltb_color=clrRed;    // Vermelho para linha de baixa
   m_lta_style=STYLE_SOLID;
   m_ltb_style=STYLE_SOLID;
   m_lta_width=2;
   m_ltb_width=2;
   m_extend_right=true;
   m_show_labels=false;
   
   // LTA
   m_lta_time1=0;
   m_lta_price1=0.0;
   m_lta_time2=0;
   m_lta_price2=0.0;
   m_lta_valid=false;
   m_lta_line_name="";
   m_lta_label_name="";
   
   // LTB
   m_ltb_time1=0;
   m_ltb_price1=0.0;
   m_ltb_time2=0;
   m_ltb_price2=0.0;
   m_ltb_valid=false;
   m_ltb_line_name="";
   m_ltb_label_name="";
   
   m_ready=false;
   m_obj_prefix="TL_"+IntegerToString(GetTickCount());
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTrendLine::~CTrendLine()
  {
   DeleteObjects();
  }

//+------------------------------------------------------------------+
//| Init with full parameters                                        |
//+------------------------------------------------------------------+
bool CTrendLine::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                      int period, int left, int right)
  {
   m_symbol=symbol;
   m_timeframe=timeframe;
   m_period=MathMax(period, 20); // Mínimo de 20 para análise consistente
   m_left=MathMax(left, 3);      // Mínimo de 3 para confirmar pivôs
   m_right=MathMax(right, 3);
   
   m_ready=false;
   return true;
  }

//+------------------------------------------------------------------+
//| Init from configuration structure                                |
//+------------------------------------------------------------------+
bool CTrendLine::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                      CTrendLineConfig &config)
  {
   m_symbol=symbol;
   m_timeframe=timeframe;
   m_period=MathMax(config.period, 20);
   m_left=MathMax(config.left, 3);
   m_right=MathMax(config.right, 3);
   
   // Configurações de desenho
   m_draw_lta=config.draw_lta;
   m_draw_ltb=config.draw_ltb;
   m_lta_color=config.lta_color;
   m_ltb_color=config.ltb_color;
   m_lta_style=config.lta_style;
   m_ltb_style=config.ltb_style;
   m_lta_width=config.lta_width;
   m_ltb_width=config.ltb_width;
   m_extend_right=config.extend_right;
   m_show_labels=config.show_labels;
   
   m_ready=false;
   return true;
  }

//+------------------------------------------------------------------+
//| Interface base implementation                                    |
//+------------------------------------------------------------------+
bool CTrendLine::Init(string symbol, ENUM_TIMEFRAMES timeframe, int period)
  {
   return Init(symbol, timeframe, period, 5, 5);
  }

//+------------------------------------------------------------------+
//| Get LTA price for given shift (default return)                  |
//+------------------------------------------------------------------+
double CTrendLine::GetValue(int shift)
  {
   return GetLTAPrice(shift);
  }

//+------------------------------------------------------------------+
//| Get LTA price for given shift                                   |
//+------------------------------------------------------------------+
double CTrendLine::GetLTAPrice(int shift)
  {
   if(!m_lta_valid)
      return 0.0;
      
   datetime target_time = iTime(m_symbol, m_timeframe, shift);
   if(target_time == 0)
      return 0.0;
      
   return CalculateTrendLinePrice(m_lta_time1, m_lta_price1,
                                  m_lta_time2, m_lta_price2,
                                  target_time);
  }

//+------------------------------------------------------------------+
//| Get LTB price for given shift                                   |
//+------------------------------------------------------------------+
double CTrendLine::GetLTBPrice(int shift)
  {
   if(!m_ltb_valid)
      return 0.0;
      
   datetime target_time = iTime(m_symbol, m_timeframe, shift);
   if(target_time == 0)
      return 0.0;
      
   return CalculateTrendLinePrice(m_ltb_time1, m_ltb_price1,
                                  m_ltb_time2, m_ltb_price2,
                                  target_time);
  }

//+------------------------------------------------------------------+
//| Copy LTA values                                                 |
//+------------------------------------------------------------------+
bool CTrendLine::CopyValues(int shift, int count, double &buffer[])
  {
   if(!m_lta_valid)
      return false;
      
   ArrayResize(buffer, count);
   ArraySetAsSeries(buffer, true);
   
   for(int i = 0; i < count; i++)
     {
      buffer[i] = GetLTAPrice(shift + i);
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Check if trend line analysis is ready                           |
//+------------------------------------------------------------------+
bool CTrendLine::IsReady()
  {
   return m_ready && (Bars(m_symbol, m_timeframe) >= m_period + m_left + m_right + 10);
  }

//+------------------------------------------------------------------+
//| Update trend line analysis                                       |
//+------------------------------------------------------------------+
bool CTrendLine::Update()
  {
   if(!IsReady())
     {
      if(Bars(m_symbol, m_timeframe) >= m_period + m_left + m_right + 10)
        {
         m_ready = DetectTrendLines();
         if(m_ready)
            DrawTrendLines();
        }
      return m_ready;
     }
   
   // Recalcular e redesenhar linhas de tendência
   bool result = DetectTrendLines();
   if(result)
      DrawTrendLines();
   
   return result;
  }

//+------------------------------------------------------------------+
//| Detect both LTA and LTB trend lines                             |
//+------------------------------------------------------------------+
bool CTrendLine::DetectTrendLines()
  {
   bool lta_found = false;
   bool ltb_found = false;
   
   if(m_draw_lta)
     {
      lta_found = FindLTA(m_lta_time1, m_lta_price1, m_lta_time2, m_lta_price2);
      m_lta_valid = lta_found;
      if(lta_found)
         Print("LTA encontrada: P1(", TimeToString(m_lta_time1), ", ", m_lta_price1, ") P2(", TimeToString(m_lta_time2), ", ", m_lta_price2, ")");
     }
   
   if(m_draw_ltb)
     {
      ltb_found = FindLTB(m_ltb_time1, m_ltb_price1, m_ltb_time2, m_ltb_price2);
      m_ltb_valid = ltb_found;
      if(ltb_found)
         Print("LTB encontrada: P1(", TimeToString(m_ltb_time1), ", ", m_ltb_price1, ") P2(", TimeToString(m_ltb_time2), ", ", m_ltb_price2, ")");
     }
   
   return lta_found || ltb_found;
  }

//+------------------------------------------------------------------+
//| Find LTA (connecting ascending lows)                            |
//+------------------------------------------------------------------+
bool CTrendLine::FindLTA(datetime &time1, double &price1, datetime &time2, double &price2)
  {
   double lows[];
   datetime times[];
   int indices[];
   int low_count = 0;
   
   // Analisar do candle mais antigo para o mais recente (excluindo os 10 mais recentes)
   int start_bar = m_period + m_left + m_right;
   int end_bar = 10; // Excluir os 10 candles mais recentes
   
   // Encontrar mínimos válidos (swing lows) no período
   for(int i = start_bar; i >= end_bar; i--)
     {
      if(IsValidSwingLow(i))
        {
         low_count++;
        }
     }
   
   if(low_count < 2)
     {
      Print("LTA: Poucos swing lows encontrados (", low_count, ")");
      return false;
     }
   
   ArrayResize(lows, low_count);
   ArrayResize(times, low_count);
   ArrayResize(indices, low_count);
   int index = 0;
   
   // Coletar os swing lows válidos
   for(int i = start_bar; i >= end_bar; i--)
     {
      if(IsValidSwingLow(i))
        {
         lows[index] = iLow(m_symbol, m_timeframe, i);
         times[index] = iTime(m_symbol, m_timeframe, i);
         indices[index] = i;
         index++;
        }
     }
   
   // Encontrar os dois pontos que formam a melhor linha ascendente
   // Buscar mínimos crescentes (segundo mínimo > primeiro mínimo)
   double best_slope = 0;
   int best_p1 = -1, best_p2 = -1;
   
   for(int i = 0; i < low_count - 1; i++)
     {
      for(int j = i + 1; j < low_count; j++)
        {
         // Verificar se é uma linha ascendente (mínimos crescentes)
         if(lows[j] > lows[i] && times[j] > times[i])
           {
            // Calcular inclinação
            double slope = (lows[j] - lows[i]) / (double)(times[j] - times[i]);
            
            // Procurar a melhor inclinação positiva
            if(slope > best_slope)
              {
               best_slope = slope;
               best_p1 = i;
               best_p2 = j;
              }
           }
        }
     }
   
   if(best_p1 >= 0 && best_p2 >= 0)
     {
      time1 = times[best_p1];
      price1 = lows[best_p1];
      time2 = times[best_p2];
      price2 = lows[best_p2];
      
      Print("LTA: Inclinação = ", best_slope, " Ascendente = ", (price2 > price1));
      return true;
     }
   
   Print("LTA: Nenhuma linha ascendente válida encontrada");
   return false;
  }

//+------------------------------------------------------------------+
//| Find LTB (connecting descending highs)                          |
//+------------------------------------------------------------------+
bool CTrendLine::FindLTB(datetime &time1, double &price1, datetime &time2, double &price2)
  {
   double highs[];
   datetime times[];
   int indices[];
   int high_count = 0;
   
   // Analisar do candle mais antigo para o mais recente (excluindo os 10 mais recentes)
   int start_bar = m_period + m_left + m_right;
   int end_bar = 10; // Excluir os 10 candles mais recentes
   
   // Encontrar máximos válidos (swing highs) no período
   for(int i = start_bar; i >= end_bar; i--)
     {
      if(IsValidSwingHigh(i))
        {
         high_count++;
        }
     }
   
   if(high_count < 2)
     {
      Print("LTB: Poucos swing highs encontrados (", high_count, ")");
      return false;
     }
   
   ArrayResize(highs, high_count);
   ArrayResize(times, high_count);
   ArrayResize(indices, high_count);
   int index = 0;
   
   // Coletar os swing highs válidos
   for(int i = start_bar; i >= end_bar; i--)
     {
      if(IsValidSwingHigh(i))
        {
         highs[index] = iHigh(m_symbol, m_timeframe, i);
         times[index] = iTime(m_symbol, m_timeframe, i);
         indices[index] = i;
         index++;
        }
     }
   
   // Encontrar os dois pontos que formam a melhor linha descendente
   // Buscar máximos decrescentes (segundo máximo < primeiro máximo)
   double best_slope = 0;
   int best_p1 = -1, best_p2 = -1;
   
   for(int i = 0; i < high_count - 1; i++)
     {
      for(int j = i + 1; j < high_count; j++)
        {
         // Verificar se é uma linha descendente (máximos decrescentes)
         if(highs[j] < highs[i] && times[j] > times[i])
           {
            // Calcular inclinação (será negativa)
            double slope = (highs[j] - highs[i]) / (double)(times[j] - times[i]);
            
            // Procurar a melhor inclinação negativa (menor valor)
            if(slope < best_slope)
              {
               best_slope = slope;
               best_p1 = i;
               best_p2 = j;
              }
           }
        }
     }
   
   if(best_p1 >= 0 && best_p2 >= 0)
     {
      time1 = times[best_p1];
      price1 = highs[best_p1];
      time2 = times[best_p2];
      price2 = highs[best_p2];
      
      Print("LTB: Inclinação = ", best_slope, " Descendente = ", (price2 < price1));
      return true;
     }
   
   Print("LTB: Nenhuma linha descendente válida encontrada");
   return false;
  }

//+------------------------------------------------------------------+
//| Check if bar at index is a valid swing low                      |
//+------------------------------------------------------------------+
bool CTrendLine::IsValidSwingLow(int index)
  {
   if(index < m_right || index > Bars(m_symbol, m_timeframe) - m_left - 1)
      return false;
      
   double center_low = iLow(m_symbol, m_timeframe, index);
   
   // Verificar barras à esquerda (mais antigas)
   for(int i = index + 1; i <= index + m_left; i++)
     {
      if(iLow(m_symbol, m_timeframe, i) <= center_low)
         return false;
     }
   
   // Verificar barras à direita (mais recentes)
   for(int i = index - 1; i >= index - m_right; i--)
     {
      if(iLow(m_symbol, m_timeframe, i) <= center_low)
         return false;
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Check if bar at index is a valid swing high                     |
//+------------------------------------------------------------------+
bool CTrendLine::IsValidSwingHigh(int index)
  {
   if(index < m_right || index > Bars(m_symbol, m_timeframe) - m_left - 1)
      return false;
      
   double center_high = iHigh(m_symbol, m_timeframe, index);
   
   // Verificar barras à esquerda (mais antigas)
   for(int i = index + 1; i <= index + m_left; i++)
     {
      if(iHigh(m_symbol, m_timeframe, i) >= center_high)
         return false;
     }
   
   // Verificar barras à direita (mais recentes)
   for(int i = index - 1; i >= index - m_right; i--)
     {
      if(iHigh(m_symbol, m_timeframe, i) >= center_high)
         return false;
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Calculate price on trend line for given time                    |
//+------------------------------------------------------------------+
double CTrendLine::CalculateTrendLinePrice(datetime time1, double price1,
                                          datetime time2, double price2,
                                          datetime target_time)
  {
   if(time1 == time2)
      return price1;
   
   double slope = (price2 - price1) / (double)(time2 - time1);
   return price1 + slope * (double)(target_time - time1);
  }

//+------------------------------------------------------------------+
//| Draw trend lines on chart                                       |
//+------------------------------------------------------------------+
void CTrendLine::DrawTrendLines()
  {
   DeleteObjects(); // Limpar objetos anteriores
   
   datetime current_time = TimeCurrent();
   datetime future_time = current_time + (24 * 3600 * 7); // 1 semana no futuro
   
   // Desenhar LTA se válida e habilitada
   if(m_lta_valid && m_draw_lta)
     {
      m_lta_line_name = m_obj_prefix + "_LTA";
      
      datetime end_time = m_extend_right ? future_time : m_lta_time2;
      double end_price = m_extend_right ? 
                        CalculateTrendLinePrice(m_lta_time1, m_lta_price1, m_lta_time2, m_lta_price2, end_time) :
                        m_lta_price2;
      
      if(ObjectCreate(0, m_lta_line_name, OBJ_TREND, 0, m_lta_time1, m_lta_price1, end_time, end_price))
        {
         ObjectSetInteger(0, m_lta_line_name, OBJPROP_COLOR, m_lta_color);
         ObjectSetInteger(0, m_lta_line_name, OBJPROP_STYLE, m_lta_style);
         ObjectSetInteger(0, m_lta_line_name, OBJPROP_WIDTH, m_lta_width);
         ObjectSetInteger(0, m_lta_line_name, OBJPROP_RAY_RIGHT, m_extend_right);
         ObjectSetInteger(0, m_lta_line_name, OBJPROP_RAY_LEFT, false);
         ObjectSetInteger(0, m_lta_line_name, OBJPROP_SELECTABLE, true);
         
         // Adicionar rótulo se habilitado
         if(m_show_labels)
           {
            m_lta_label_name = m_obj_prefix + "_LTA_Label";
            datetime label_time = m_lta_time2 + (m_lta_time2 - m_lta_time1) / 4;
            double label_price = CalculateTrendLinePrice(m_lta_time1, m_lta_price1, m_lta_time2, m_lta_price2, label_time);
            
            if(ObjectCreate(0, m_lta_label_name, OBJ_TEXT, 0, label_time, label_price))
              {
               ObjectSetString(0, m_lta_label_name, OBJPROP_TEXT, "LTA");
               ObjectSetInteger(0, m_lta_label_name, OBJPROP_COLOR, m_lta_color);
               ObjectSetInteger(0, m_lta_label_name, OBJPROP_FONTSIZE, 10);
               ObjectSetString(0, m_lta_label_name, OBJPROP_FONT, "Arial Bold");
              }
           }
         Print("LTA desenhada com sucesso");
        }
     }
   
   // Desenhar LTB se válida e habilitada
   if(m_ltb_valid && m_draw_ltb)
     {
      m_ltb_line_name = m_obj_prefix + "_LTB";
      
      datetime end_time = m_extend_right ? future_time : m_ltb_time2;
      double end_price = m_extend_right ? 
                        CalculateTrendLinePrice(m_ltb_time1, m_ltb_price1, m_ltb_time2, m_ltb_price2, end_time) :
                        m_ltb_price2;
      
      if(ObjectCreate(0, m_ltb_line_name, OBJ_TREND, 0, m_ltb_time1, m_ltb_price1, end_time, end_price))
        {
         ObjectSetInteger(0, m_ltb_line_name, OBJPROP_COLOR, m_ltb_color);
         ObjectSetInteger(0, m_ltb_line_name, OBJPROP_STYLE, m_ltb_style);
         ObjectSetInteger(0, m_ltb_line_name, OBJPROP_WIDTH, m_ltb_width);
         ObjectSetInteger(0, m_ltb_line_name, OBJPROP_RAY_RIGHT, m_extend_right);
         ObjectSetInteger(0, m_ltb_line_name, OBJPROP_RAY_LEFT, false);
         ObjectSetInteger(0, m_ltb_line_name, OBJPROP_SELECTABLE, true);
         
         // Adicionar rótulo se habilitado
         if(m_show_labels)
           {
            m_ltb_label_name = m_obj_prefix + "_LTB_Label";
            datetime label_time = m_ltb_time2 + (m_ltb_time2 - m_ltb_time1) / 4;
            double label_price = CalculateTrendLinePrice(m_ltb_time1, m_ltb_price1, m_ltb_time2, m_ltb_price2, label_time);
            
            if(ObjectCreate(0, m_ltb_label_name, OBJ_TEXT, 0, label_time, label_price))
              {
               ObjectSetString(0, m_ltb_label_name, OBJPROP_TEXT, "LTB");
               ObjectSetInteger(0, m_ltb_label_name, OBJPROP_COLOR, m_ltb_color);
               ObjectSetInteger(0, m_ltb_label_name, OBJPROP_FONTSIZE, 10);
               ObjectSetString(0, m_ltb_label_name, OBJPROP_FONT, "Arial Bold");
              }
           }
         Print("LTB desenhada com sucesso");
        }
     }
  }

//+------------------------------------------------------------------+
//| Delete chart objects                                             |
//+------------------------------------------------------------------+
void CTrendLine::DeleteObjects()
  {
   if(StringLen(m_lta_line_name) > 0)
     {
      ObjectDelete(0, m_lta_line_name);
      m_lta_line_name = "";
     }
   
   if(StringLen(m_lta_label_name) > 0)
     {
      ObjectDelete(0, m_lta_label_name);
      m_lta_label_name = "";
     }
   
   if(StringLen(m_ltb_line_name) > 0)
     {
      ObjectDelete(0, m_ltb_line_name);
      m_ltb_line_name = "";
     }
   
   if(StringLen(m_ltb_label_name) > 0)
     {
      ObjectDelete(0, m_ltb_label_name);
      m_ltb_label_name = "";
     }
  }

//+------------------------------------------------------------------+
//| Get trend direction for a line                                  |
//+------------------------------------------------------------------+
ENUM_TRENDLINE_DIRECTION CTrendLine::GetTrendDirection(double price1, double price2)
  {
   if(price2 > price1)
      return TRENDLINE_ASCENDING;
   else if(price2 < price1)
      return TRENDLINE_DESCENDING;
   else
      return TRENDLINE_HORIZONTAL;
  }

//+------------------------------------------------------------------+
//| Check if trend is ascending                                     |
//+------------------------------------------------------------------+
bool CTrendLine::IsAscendingTrend(double price1, double price2)
  {
   return price2 > price1;
  }

//+------------------------------------------------------------------+
//| Check if trend is descending                                   |
//+------------------------------------------------------------------+
bool CTrendLine::IsDescendingTrend(double price1, double price2)
  {
   return price2 < price1;
  }

//+------------------------------------------------------------------+
//| Get status of LTA                                              |
//+------------------------------------------------------------------+
bool CTrendLine::IsLTAValid()
  {
   return m_lta_valid;
  }

//+------------------------------------------------------------------+
//| Get status of LTB                                              |
//+------------------------------------------------------------------+
bool CTrendLine::IsLTBValid()
  {
   return m_ltb_valid;
  }

//+------------------------------------------------------------------+
//| Get LTA points                                                 |
//+------------------------------------------------------------------+
bool CTrendLine::GetLTAPoints(datetime &time1, double &price1,
                              datetime &time2, double &price2)
  {
   if(!m_lta_valid)
      return false;
   
   time1 = m_lta_time1;
   price1 = m_lta_price1;
   time2 = m_lta_time2;
   price2 = m_lta_price2;
   
   return true;
  }

//+------------------------------------------------------------------+
//| Get LTB points                                                 |
//+------------------------------------------------------------------+
bool CTrendLine::GetLTBPoints(datetime &time1, double &price1,
                              datetime &time2, double &price2)
  {
   if(!m_ltb_valid)
      return false;
   
   time1 = m_ltb_time1;
   price1 = m_ltb_price1;
   time2 = m_ltb_time2;
   price2 = m_ltb_price2;
   
   return true;
  }

//+------------------------------------------------------------------+
//| Get LTA direction                                              |
//+------------------------------------------------------------------+
ENUM_TRENDLINE_DIRECTION CTrendLine::GetLTADirection()
  {
   if(!m_lta_valid)
      return TRENDLINE_HORIZONTAL;
   
   return GetTrendDirection(m_lta_price1, m_lta_price2);
  }

//+------------------------------------------------------------------+
//| Get LTB direction                                              |
//+------------------------------------------------------------------+
ENUM_TRENDLINE_DIRECTION CTrendLine::GetLTBDirection()
  {
   if(!m_ltb_valid)
      return TRENDLINE_HORIZONTAL;
   
   return GetTrendDirection(m_ltb_price1, m_ltb_price2);
  }

#endif // __TRENDLINE_MQH__