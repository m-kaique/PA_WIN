//+------------------------------------------------------------------+
//|                                    priceaction/trendline.mqh      |
//|  TrendLine pattern detection with LTA/LTB drawing                 |
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
   
   // Dados da LTB (Linha de Tendência de Baixa/Suporte)
   datetime          m_ltb_time1;
   double            m_ltb_price1;
   datetime          m_ltb_time2;
   double            m_ltb_price2;
   bool              m_ltb_valid;
   string            m_ltb_line_name;
   string            m_ltb_label_name;
   
   // Dados da LTA (Linha de Tendência de Alta/Resistência)
   datetime          m_lta_time1;
   double            m_lta_price1;
   datetime          m_lta_time2;
   double            m_lta_price2;
   bool              m_lta_valid;
   string            m_lta_line_name;
   string            m_lta_label_name;
   
   bool              m_ready;
   string            m_obj_prefix;

   // Métodos privados
   bool              DetectTrendLines();
   bool              FindLTB(datetime &time1, double &price1, datetime &time2, double &price2);
   bool              FindLTA(datetime &time1, double &price1, datetime &time2, double &price2);
   bool              IsLocalMinimum(int index);
   bool              IsLocalMaximum(int index);
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
   virtual double    GetValue(int shift=0);       // Retorna preço da LTB por padrão
   virtual bool      CopyValues(int shift, int count, double &buffer[]);
   virtual bool      IsReady();
   virtual bool      Update();

   // Métodos específicos da TrendLine
   double            GetLTBPrice(int shift=0);     // Linha de Tendência de Baixa
   double            GetLTAPrice(int shift=0);     // Linha de Tendência de Alta
   bool              IsLTBValid();
   bool              IsLTAValid();
   bool              GetLTBPoints(datetime &time1, double &price1, datetime &time2, double &price2);
   bool              GetLTAPoints(datetime &time1, double &price1, datetime &time2, double &price2);
   ENUM_TRENDLINE_DIRECTION GetLTBDirection();
   ENUM_TRENDLINE_DIRECTION GetLTADirection();
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTrendLine::CTrendLine()
  {
   m_symbol="";
   m_timeframe=PERIOD_CURRENT;
   m_period=21;
   m_left=3;
   m_right=3;
   
   // Configurações padrão de desenho
   m_draw_lta=true;
   m_draw_ltb=true;
   m_lta_color=clrGreen;
   m_ltb_color=clrRed;
   m_lta_style=STYLE_SOLID;
   m_ltb_style=STYLE_SOLID;
   m_lta_width=1;
   m_ltb_width=1;
   m_extend_right=true;
   m_show_labels=false;
   
   // LTB
   m_ltb_time1=0;
   m_ltb_price1=0.0;
   m_ltb_time2=0;
   m_ltb_price2=0.0;
   m_ltb_valid=false;
   m_ltb_line_name="";
   m_ltb_label_name="";
   
   // LTA
   m_lta_time1=0;
   m_lta_price1=0.0;
   m_lta_time2=0;
   m_lta_price2=0.0;
   m_lta_valid=false;
   m_lta_line_name="";
   m_lta_label_name="";
   
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
   m_period=period;
   m_left=left;
   m_right=right;
   
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
   m_period=config.period;
   m_left=config.left;
   m_right=config.right;
   
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
   return Init(symbol, timeframe, period, 3, 3);
  }

//+------------------------------------------------------------------+
//| Get LTB price for given shift (default return)                  |
//+------------------------------------------------------------------+
double CTrendLine::GetValue(int shift)
  {
   return GetLTBPrice(shift);
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
//| Copy LTB values                                                 |
//+------------------------------------------------------------------+
bool CTrendLine::CopyValues(int shift, int count, double &buffer[])
  {
   if(!m_ltb_valid)
      return false;
      
   ArrayResize(buffer, count);
   ArraySetAsSeries(buffer, true);
   
   for(int i = 0; i < count; i++)
     {
      buffer[i] = GetLTBPrice(shift + i);
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Check if trend line analysis is ready                           |
//+------------------------------------------------------------------+
bool CTrendLine::IsReady()
  {
   return m_ready && (Bars(m_symbol, m_timeframe) >= m_period + m_left + m_right);
  }

//+------------------------------------------------------------------+
//| Update trend line analysis                                       |
//+------------------------------------------------------------------+
bool CTrendLine::Update()
  {
   if(!IsReady())
     {
      if(Bars(m_symbol, m_timeframe) >= m_period + m_left + m_right)
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
   bool ltb_found = false;
   bool lta_found = false;
   
   if(m_draw_ltb)
     {
      ltb_found = FindLTB(m_ltb_time1, m_ltb_price1, m_ltb_time2, m_ltb_price2);
      m_ltb_valid = ltb_found;
     }
   
   if(m_draw_lta)
     {
      lta_found = FindLTA(m_lta_time1, m_lta_price1, m_lta_time2, m_lta_price2);
      m_lta_valid = lta_found;
     }
   
   return ltb_found || lta_found;
  }

//+------------------------------------------------------------------+
//| Find LTB (connecting ascending lows)                            |
//+------------------------------------------------------------------+
bool CTrendLine::FindLTB(datetime &time1, double &price1, datetime &time2, double &price2)
  {
   double lows[];
   datetime times[];
   int low_count = 0;
   
   // Encontrar mínimos locais no período
   for(int i = m_left; i <= m_period - m_right; i++)
     {
      if(IsLocalMinimum(i))
        {
         low_count++;
        }
     }
   
   if(low_count < 2)
      return false;
   
   ArrayResize(lows, low_count);
   ArrayResize(times, low_count);
   int index = 0;
   
   for(int i = m_left; i <= m_period - m_right; i++)
     {
      if(IsLocalMinimum(i))
        {
         lows[index] = iLow(m_symbol, m_timeframe, i);
         times[index] = iTime(m_symbol, m_timeframe, i);
         index++;
        }
     }
   
   // Encontrar os dois pontos que formam uma linha ascendente
   // Procurar a melhor linha de tendência de baixa (ascendente)
   double best_slope = -999999;
   int best_p1 = -1, best_p2 = -1;
   
   for(int i = 0; i < low_count - 1; i++)
     {
      for(int j = i + 1; j < low_count; j++)
        {
         // Calcular inclinação
         if(times[j] == times[i]) continue;
         
         double slope = (lows[j] - lows[i]) / (double)(times[j] - times[i]);
         
         // Verificar se é ascendente e se é a melhor encontrada
         if(slope > 0 && slope > best_slope)
           {
            best_slope = slope;
            best_p1 = i;
            best_p2 = j;
           }
        }
     }
   
   if(best_p1 >= 0 && best_p2 >= 0)
     {
      // Ordenar por tempo (o mais antigo primeiro)
      if(times[best_p1] > times[best_p2])
        {
         int temp = best_p1;
         best_p1 = best_p2;
         best_p2 = temp;
        }
      
      time1 = times[best_p1];
      price1 = lows[best_p1];
      time2 = times[best_p2];
      price2 = lows[best_p2];
      
      return true;
     }
   
   return false;
  }

//+------------------------------------------------------------------+
//| Find LTA (connecting descending highs)                          |
//+------------------------------------------------------------------+
bool CTrendLine::FindLTA(datetime &time1, double &price1, datetime &time2, double &price2)
  {
   double highs[];
   datetime times[];
   int high_count = 0;
   
   // Encontrar máximos locais no período
   for(int i = m_left; i <= m_period - m_right; i++)
     {
      if(IsLocalMaximum(i))
        {
         high_count++;
        }
     }
   
   if(high_count < 2)
      return false;
   
   ArrayResize(highs, high_count);
   ArrayResize(times, high_count);
   int index = 0;
   
   for(int i = m_left; i <= m_period - m_right; i++)
     {
      if(IsLocalMaximum(i))
        {
         highs[index] = iHigh(m_symbol, m_timeframe, i);
         times[index] = iTime(m_symbol, m_timeframe, i);
         index++;
        }
     }
   
   // Encontrar os dois pontos que formam uma linha descendente
   // Procurar a melhor linha de tendência de alta (descendente)
   double best_slope = 999999;
   int best_p1 = -1, best_p2 = -1;
   
   for(int i = 0; i < high_count - 1; i++)
     {
      for(int j = i + 1; j < high_count; j++)
        {
         // Calcular inclinação
         if(times[j] == times[i]) continue;
         
         double slope = (highs[j] - highs[i]) / (double)(times[j] - times[i]);
         
         // Verificar se é descendente e se é a melhor encontrada
         if(slope < 0 && slope < best_slope)
           {
            best_slope = slope;
            best_p1 = i;
            best_p2 = j;
           }
        }
     }
   
   if(best_p1 >= 0 && best_p2 >= 0)
     {
      // Ordenar por tempo (o mais antigo primeiro)
      if(times[best_p1] > times[best_p2])
        {
         int temp = best_p1;
         best_p1 = best_p2;
         best_p2 = temp;
        }
      
      time1 = times[best_p1];
      price1 = highs[best_p1];
      time2 = times[best_p2];
      price2 = highs[best_p2];
      
      return true;
     }
   
   return false;
  }

//+------------------------------------------------------------------+
//| Check if bar at index is a local minimum                        |
//+------------------------------------------------------------------+
bool CTrendLine::IsLocalMinimum(int index)
  {
   double center_low = iLow(m_symbol, m_timeframe, index);
   
   // Verificar barras à esquerda
   for(int i = index + 1; i <= index + m_left; i++)
     {
      if(iLow(m_symbol, m_timeframe, i) <= center_low)
         return false;
     }
   
   // Verificar barras à direita
   for(int i = index - 1; i >= index - m_right; i--)
     {
      if(iLow(m_symbol, m_timeframe, i) <= center_low)
         return false;
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Check if bar at index is a local maximum                        |
//+------------------------------------------------------------------+
bool CTrendLine::IsLocalMaximum(int index)
  {
   double center_high = iHigh(m_symbol, m_timeframe, index);
   
   // Verificar barras à esquerda
   for(int i = index + 1; i <= index + m_left; i++)
     {
      if(iHigh(m_symbol, m_timeframe, i) >= center_high)
         return false;
     }
   
   // Verificar barras à direita
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
   datetime future_time = current_time + (24 * 3600); // 1 dia no futuro
   
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
               ObjectSetInteger(0, m_ltb_label_name, OBJPROP_FONTSIZE, 8);
               ObjectSetString(0, m_ltb_label_name, OBJPROP_FONT, "Arial");
              }
           }
        }
     }
   
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
               ObjectSetInteger(0, m_lta_label_name, OBJPROP_FONTSIZE, 8);
               ObjectSetString(0, m_lta_label_name, OBJPROP_FONT, "Arial");
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Delete chart objects                                             |
//+------------------------------------------------------------------+
void CTrendLine::DeleteObjects()
  {
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
//| Get status of LTB                                              |
//+------------------------------------------------------------------+
bool CTrendLine::IsLTBValid()
  {
   return m_ltb_valid;
  }

//+------------------------------------------------------------------+
//| Get status of LTA                                              |
//+------------------------------------------------------------------+
bool CTrendLine::IsLTAValid()
  {
   return m_lta_valid;
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
//| Get LTB direction                                              |
//+------------------------------------------------------------------+
ENUM_TRENDLINE_DIRECTION CTrendLine::GetLTBDirection()
  {
   if(!m_ltb_valid)
      return TRENDLINE_HORIZONTAL;
   
   return GetTrendDirection(m_ltb_price1, m_ltb_price2);
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

#endif // __TRENDLINE_MQH__