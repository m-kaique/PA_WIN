//+------------------------------------------------------------------+
//|                                    priceaction/trendline.mqh      |
//|  TrendLine pattern detection derived from CPriceActionBase        |
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
   
   // Dados da linha de tendência de suporte
   datetime          m_support_time1;
   double            m_support_price1;
   datetime          m_support_time2;
   double            m_support_price2;
   bool              m_support_valid;
   
   // Dados da linha de tendência de resistência
   datetime          m_resistance_time1;
   double            m_resistance_price1;
   datetime          m_resistance_time2;
   double            m_resistance_price2;
   bool              m_resistance_valid;
   
   bool              m_ready;

   // Métodos privados
   bool              DetectTrendLines();
   bool              FindSupport(datetime &time1, double &price1, datetime &time2, double &price2);
   bool              FindResistance(datetime &time1, double &price1, datetime &time2, double &price2);
   bool              IsLocalMinimum(int index);
   bool              IsLocalMaximum(int index);
   double            CalculateTrendLinePrice(datetime time1, double price1, datetime time2, double price2, datetime target_time);

public:
                     CTrendLine();
                    ~CTrendLine();

   bool              Init(string symbol, ENUM_TIMEFRAMES timeframe,
                         int period, int left, int right);
   bool              Init(string symbol, ENUM_TIMEFRAMES timeframe,
                         CTrendLineConfig &config);

   // Implementação da interface base
   virtual bool      Init(string symbol, ENUM_TIMEFRAMES timeframe, int period);
   virtual double    GetValue(int shift=0);       // Retorna preço da linha de suporte
   virtual bool      CopyValues(int shift, int count, double &buffer[]);
   virtual bool      IsReady();
   virtual bool      Update();

   // Métodos específicos da TrendLine
   double            GetSupportPrice(int shift=0);
   double            GetResistancePrice(int shift=0);
   bool              IsSupportValid();
   bool              IsResistanceValid();
   bool              GetSupportPoints(datetime &time1, double &price1, datetime &time2, double &price2);
   bool              GetResistancePoints(datetime &time1, double &price1, datetime &time2, double &price2);
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
   
   m_support_time1=0;
   m_support_price1=0.0;
   m_support_time2=0;
   m_support_price2=0.0;
   m_support_valid=false;
   
   m_resistance_time1=0;
   m_resistance_price1=0.0;
   m_resistance_time2=0;
   m_resistance_price2=0.0;
   m_resistance_valid=false;
   
   m_ready=false;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTrendLine::~CTrendLine()
  {
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
   return Init(symbol, timeframe, config.period, config.left, config.right);
  }

//+------------------------------------------------------------------+
//| Interface base implementation                                    |
//+------------------------------------------------------------------+
bool CTrendLine::Init(string symbol, ENUM_TIMEFRAMES timeframe, int period)
  {
   return Init(symbol, timeframe, period, 3, 3);
  }

//+------------------------------------------------------------------+
//| Get support line price for given shift                          |
//+------------------------------------------------------------------+
double CTrendLine::GetValue(int shift)
  {
   return GetSupportPrice(shift);
  }

//+------------------------------------------------------------------+
//| Get support line price for given shift                          |
//+------------------------------------------------------------------+
double CTrendLine::GetSupportPrice(int shift)
  {
   if(!m_support_valid)
      return 0.0;
      
   datetime target_time = iTime(m_symbol, m_timeframe, shift);
   if(target_time == 0)
      return 0.0;
      
   return CalculateTrendLinePrice(m_support_time1, m_support_price1,
                                  m_support_time2, m_support_price2,
                                  target_time);
  }

//+------------------------------------------------------------------+
//| Get resistance line price for given shift                       |
//+------------------------------------------------------------------+
double CTrendLine::GetResistancePrice(int shift)
  {
   if(!m_resistance_valid)
      return 0.0;
      
   datetime target_time = iTime(m_symbol, m_timeframe, shift);
   if(target_time == 0)
      return 0.0;
      
   return CalculateTrendLinePrice(m_resistance_time1, m_resistance_price1,
                                  m_resistance_time2, m_resistance_price2,
                                  target_time);
  }

//+------------------------------------------------------------------+
//| Copy support line values                                         |
//+------------------------------------------------------------------+
bool CTrendLine::CopyValues(int shift, int count, double &buffer[])
  {
   if(!m_support_valid)
      return false;
      
   ArrayResize(buffer, count);
   ArraySetAsSeries(buffer, true);
   
   for(int i = 0; i < count; i++)
     {
      buffer[i] = GetSupportPrice(shift + i);
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
        }
      return m_ready;
     }
   
   // Recalcular linhas de tendência
   return DetectTrendLines();
  }

//+------------------------------------------------------------------+
//| Detect both support and resistance trend lines                  |
//+------------------------------------------------------------------+
bool CTrendLine::DetectTrendLines()
  {
   bool support_found = FindSupport(m_support_time1, m_support_price1,
                                   m_support_time2, m_support_price2);
   bool resistance_found = FindResistance(m_resistance_time1, m_resistance_price1,
                                         m_resistance_time2, m_resistance_price2);
   
   m_support_valid = support_found;
   m_resistance_valid = resistance_found;
   
   return support_found || resistance_found;
  }

//+------------------------------------------------------------------+
//| Find support trend line connecting lows                         |
//+------------------------------------------------------------------+
bool CTrendLine::FindSupport(datetime &time1, double &price1, datetime &time2, double &price2)
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
   
   // Encontrar os dois pontos mais significativos para a linha de suporte
   // Usar os dois mínimos mais baixos
   int min1_idx = 0, min2_idx = 1;
   
   for(int i = 0; i < low_count; i++)
     {
      if(lows[i] < lows[min1_idx])
        {
         min2_idx = min1_idx;
         min1_idx = i;
        }
      else if(lows[i] < lows[min2_idx] && i != min1_idx)
        {
         min2_idx = i;
        }
     }
   
   // Ordenar por tempo (o mais antigo primeiro)
   if(times[min1_idx] > times[min2_idx])
     {
      int temp_idx = min1_idx;
      min1_idx = min2_idx;
      min2_idx = temp_idx;
     }
   
   time1 = times[min1_idx];
   price1 = lows[min1_idx];
   time2 = times[min2_idx];
   price2 = lows[min2_idx];
   
   return true;
  }

//+------------------------------------------------------------------+
//| Find resistance trend line connecting highs                     |
//+------------------------------------------------------------------+
bool CTrendLine::FindResistance(datetime &time1, double &price1, datetime &time2, double &price2)
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
   
   // Encontrar os dois pontos mais significativos para a linha de resistência
   // Usar os dois máximos mais altos
   int max1_idx = 0, max2_idx = 1;
   
   for(int i = 0; i < high_count; i++)
     {
      if(highs[i] > highs[max1_idx])
        {
         max2_idx = max1_idx;
         max1_idx = i;
        }
      else if(highs[i] > highs[max2_idx] && i != max1_idx)
        {
         max2_idx = i;
        }
     }
   
   // Ordenar por tempo (o mais antigo primeiro)
   if(times[max1_idx] > times[max2_idx])
     {
      int temp_idx = max1_idx;
      max1_idx = max2_idx;
      max2_idx = temp_idx;
     }
   
   time1 = times[max1_idx];
   price1 = highs[max1_idx];
   time2 = times[max2_idx];
   price2 = highs[max2_idx];
   
   return true;
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
//| Get status of support line                                      |
//+------------------------------------------------------------------+
bool CTrendLine::IsSupportValid()
  {
   return m_support_valid;
  }

//+------------------------------------------------------------------+
//| Get status of resistance line                                   |
//+------------------------------------------------------------------+
bool CTrendLine::IsResistanceValid()
  {
   return m_resistance_valid;
  }

//+------------------------------------------------------------------+
//| Get support line points                                         |
//+------------------------------------------------------------------+
bool CTrendLine::GetSupportPoints(datetime &time1, double &price1,
                                  datetime &time2, double &price2)
  {
   if(!m_support_valid)
      return false;
   
   time1 = m_support_time1;
   price1 = m_support_price1;
   time2 = m_support_time2;
   price2 = m_support_price2;
   
   return true;
  }

//+------------------------------------------------------------------+
//| Get resistance line points                                      |
//+------------------------------------------------------------------+
bool CTrendLine::GetResistancePoints(datetime &time1, double &price1,
                                     datetime &time2, double &price2)
  {
   if(!m_resistance_valid)
      return false;
   
   time1 = m_resistance_time1;
   price1 = m_resistance_price1;
   time2 = m_resistance_time2;
   price2 = m_resistance_price2;
   
   return true;
  }

#endif // __TRENDLINE_MQH__