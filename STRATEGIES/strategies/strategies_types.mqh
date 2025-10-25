#ifndef __STRATEGIES_TYPES_MQH__
#define __STRATEGIES_TYPES_MQH__

//+------------------------------------------------------------------+
//| Classe base para configuração de estratégias                    |
//+------------------------------------------------------------------+
class CStrategyConfig
{
public:
   string name;
   string type;
   bool enabled;
   CStrategyConfig()
   {
      name = "";
      type = "";
      enabled = false;
   }
   virtual ~CStrategyConfig() {}
};

//+------------------------------------------------------------------+
//| Configuração para estratégia EMA Buy Bull                       |
//+------------------------------------------------------------------+
class CEmasBullBuyConfig : public CStrategyConfig
{
public:
   // Existing parameters
   double risk_percent;
   double stop_loss_pips;
   double take_profit_ratio;

   // New configurable parameters for trend and momentum
   double min_distance_9_21_atr_m3;
   double min_distance_21_50_atr_m3;
   double min_distance_9_21_atr_m15;
   double min_distance_21_50_atr_m15;
   int lookback_candles;
   double max_distance_atr;
   int max_duration_candles;
   int lookback_periods;
   double min_volatility_ratio;
   double max_volatility_ratio;
   double bullish_structure_atr_threshold;
   int adx_min_value;
   int adx_max_value;

   // Validation enable/disable flags
   bool enable_ema_alignment_m15;
   bool enable_ema_alignment_m3;
   bool enable_strong_trend_m15;
   bool enable_strong_trend_m3;
   bool enable_bullish_momentum;
   bool enable_good_volatility;
   bool enable_bullish_structure_m15;
   bool enable_bullish_structure_m3;
   bool enable_adx_filter;
   bool enable_pullback_ema9;
   bool enable_pullback_ema21;
   bool enable_bollinger_filter_m3;
   bool enable_bollinger_filter_m15;
   bool enable_bollinger_filter_h1;

   // New configurable parameters for Bollinger Bands micro inclination validation - M3
   double boll_micro_m3_min_width;
   double boll_micro_m3_max_width;
   double boll_micro_m3_upper_lr_min;
   double boll_micro_m3_upper_dd_min;
   double boll_micro_m3_upper_sd_min;
   double boll_micro_m3_lower_lr_abs_max;
   double boll_micro_m3_lower_dd_abs_max;
   double boll_micro_m3_lower_sd_abs_max;

   // New configurable parameters for Bollinger Bands micro inclination validation - M15
   double boll_micro_m15_min_width;
   double boll_micro_m15_max_width;
   double boll_micro_m15_upper_lr_min;
   double boll_micro_m15_upper_dd_min;
   double boll_micro_m15_upper_sd_min;
   double boll_micro_m15_lower_lr_abs_max;
   double boll_micro_m15_lower_dd_abs_max;
   double boll_micro_m15_lower_sd_abs_max;

   // New configurable parameters for Bollinger Bands micro inclination validation - H1
   double boll_micro_h1_min_width;
   double boll_micro_h1_max_width;
   double boll_micro_h1_upper_lr_min;
   double boll_micro_h1_upper_dd_min;
   double boll_micro_h1_upper_sd_min;
   double boll_micro_h1_lower_lr_abs_max;
   double boll_micro_h1_lower_dd_abs_max;
   double boll_micro_h1_lower_sd_abs_max;

   // New configurable parameters for pullback validation
   double pullback_depth_buffer_atr;
   double pullback_max_penetration_atr;
   double pullback_improvement_factor;
   double pullback_min_confirm_range_atr;

   // Authorized timeframes for signal generation
   ENUM_TIMEFRAMES authorized_timeframes[];

   // Time intervals for strategy operation (array of HH:MM-HH:MM format)
   string operating_hours_intervals[];

   // Method to check if timeframe is authorized
   bool IsTimeframeAuthorized(ENUM_TIMEFRAMES timeframe)
   {
      for (int i = 0; i < ArraySize(authorized_timeframes); i++)
      {
         if (authorized_timeframes[i] == timeframe)
            return true;
      }
      return false;
   }

   // Method to check if current time is within operating hours
   bool IsWithinOperatingHours()
   {
      if (ArraySize(operating_hours_intervals) == 0)
         return true; // No restrictions if not configured

      MqlDateTime current_time;
      TimeCurrent(current_time);

      // Convert current time to minutes since midnight
      int current_minutes = current_time.hour * 60 + current_time.min;

      // Check each interval
      for (int i = 0; i < ArraySize(operating_hours_intervals); i++)
      {
         if (IsTimeInInterval(current_minutes, operating_hours_intervals[i]))
            return true;
      }

      return false;
   }

   // Helper method to check if time is within a specific interval
   bool IsTimeInInterval(int current_minutes, string interval_str)
   {
      string parts[];
      StringSplit(interval_str, '-', parts);
      if (ArraySize(parts) != 2) return false;

      // Parse start time
      string start_parts[];
      StringSplit(parts[0], ':', start_parts);
      if (ArraySize(start_parts) != 2) return false;
      int start_minutes = (int)StringToInteger(start_parts[0]) * 60 + (int)StringToInteger(start_parts[1]);

      // Parse end time
      string end_parts[];
      StringSplit(parts[1], ':', end_parts);
      if (ArraySize(end_parts) != 2) return false;
      int end_minutes = (int)StringToInteger(end_parts[0]) * 60 + (int)StringToInteger(end_parts[1]);

      // Handle overnight intervals (e.g., 22:00-06:00)
      if (end_minutes < start_minutes)
      {
         // Interval spans midnight
         return (current_minutes >= start_minutes || current_minutes <= end_minutes);
      }
      else
      {
         // Normal interval within same day
         return (current_minutes >= start_minutes && current_minutes <= end_minutes);
      }
   }

   CEmasBullBuyConfig()
   {
      type = "emas_buy_bull";
      risk_percent = 1.0;
      stop_loss_pips = 50.0;
      take_profit_ratio = 2.0;

      // Initialize new parameters with default values
      min_distance_9_21_atr_m3 = 0.3;
      min_distance_21_50_atr_m3 = 0.5;
      min_distance_9_21_atr_m15 = 0.3;
      min_distance_21_50_atr_m15 = 0.5;
      lookback_candles = 3;
      max_distance_atr = 0.8;
      max_duration_candles = 3;
      lookback_periods = 10;
      min_volatility_ratio = 0.7;
      max_volatility_ratio = 1.5;
      bullish_structure_atr_threshold = 0.5;
      adx_min_value = 25;
      adx_max_value = 60;

      // Initialize new Bollinger micro inclination parameters with current hardcoded values - M3
      boll_micro_m3_min_width = 500;
      boll_micro_m3_max_width = 3000;
      boll_micro_m3_upper_lr_min = 0.05;
      boll_micro_m3_upper_dd_min = 0.04;
      boll_micro_m3_upper_sd_min = 0.20;
      boll_micro_m3_lower_lr_abs_max = 0.05;
      boll_micro_m3_lower_dd_abs_max = 0.04;
      boll_micro_m3_lower_sd_abs_max = 0.20;

      // Initialize new Bollinger micro inclination parameters with current hardcoded values - M15
      boll_micro_m15_min_width = 500;
      boll_micro_m15_max_width = 3000;
      boll_micro_m15_upper_lr_min = 0.05;
      boll_micro_m15_upper_dd_min = 0.04;
      boll_micro_m15_upper_sd_min = 0.20;
      boll_micro_m15_lower_lr_abs_max = 0.05;
      boll_micro_m15_lower_dd_abs_max = 0.04;
      boll_micro_m15_lower_sd_abs_max = 0.20;

      // Initialize new Bollinger micro inclination parameters with current hardcoded values - H1
      boll_micro_h1_min_width = 500;
      boll_micro_h1_max_width = 3000;
      boll_micro_h1_upper_lr_min = 0.05;
      boll_micro_h1_upper_dd_min = 0.04;
      boll_micro_h1_upper_sd_min = 0.20;
      boll_micro_h1_lower_lr_abs_max = 0.05;
      boll_micro_h1_lower_dd_abs_max = 0.04;
      boll_micro_h1_lower_sd_abs_max = 0.20;

      // Initialize new pullback parameters with current hardcoded values
      pullback_depth_buffer_atr = 0.5;
      pullback_max_penetration_atr = 1.5;
      pullback_improvement_factor = 1.15;
      pullback_min_confirm_range_atr = 0.1;

      // Initialize validation flags to true by default
      enable_ema_alignment_m15 = true;
      enable_ema_alignment_m3 = true;
      enable_strong_trend_m15 = true;
      enable_strong_trend_m3 = true;
      enable_bullish_momentum = true;
      enable_good_volatility = true;
      enable_bullish_structure_m15 = true;
      enable_bullish_structure_m3 = true;
      enable_adx_filter = true;
      enable_pullback_ema9 = true;
      enable_pullback_ema21 = true;
      enable_bollinger_filter_m3 = true;
      enable_bollinger_filter_m15 = true;
      enable_bollinger_filter_h1 = true;

      // Initialize authorized timeframes (default to M15 and M3 for this strategy)
      ArrayResize(authorized_timeframes, 2);
      authorized_timeframes[0] = PERIOD_M15;
      authorized_timeframes[1] = PERIOD_M3;

      // Initialize operating hours (default: no restrictions)
      ArrayResize(operating_hours_intervals, 0);
   }
};

//+------------------------------------------------------------------+
//| Configuração para estratégia EMA Bear Sell                       |
//+------------------------------------------------------------------+
class CEmasBearSellConfig : public CStrategyConfig
{
public:
   // Existing parameters
   double risk_percent;
   double stop_loss_pips;
   double take_profit_ratio;

   // New configurable parameters for trend and momentum
   double min_distance_9_21_atr_m3;
   double min_distance_21_50_atr_m3;
   double min_distance_9_21_atr_m15;
   double min_distance_21_50_atr_m15;
   int lookback_candles;
   double max_distance_atr;
   int max_duration_candles;
   int lookback_periods;
   double min_volatility_ratio;
   double max_volatility_ratio;
   double bearish_structure_atr_threshold;
   int adx_min_value;
   int adx_max_value;

   // Validation enable/disable flags
   bool enable_ema_alignment_m15;
   bool enable_ema_alignment_m3;
   bool enable_strong_trend_m15;
   bool enable_strong_trend_m3;
   bool enable_bearish_momentum;
   bool enable_good_volatility;
   bool enable_bearish_structure_m15;
   bool enable_bearish_structure_m3;
   bool enable_adx_filter;
   bool enable_pullback_ema9;
   bool enable_pullback_ema21;

   // New configurable parameters for Bollinger Bands micro inclination validation
   double boll_micro_min_width;
   double boll_micro_max_width;
   double boll_micro_upper_lr_min;
   double boll_micro_upper_dd_min;
   double boll_micro_upper_sd_min;
   double boll_micro_lower_lr_abs_max;
   double boll_micro_lower_dd_abs_max;
   double boll_micro_lower_sd_abs_max;

   // New configurable parameters for pullback validation
   double pullback_depth_buffer_atr;
   double pullback_max_penetration_atr;
   double pullback_improvement_factor;

   // Authorized timeframes for signal generation
   ENUM_TIMEFRAMES authorized_timeframes[];

   // Method to check if timeframe is authorized
   bool IsTimeframeAuthorized(ENUM_TIMEFRAMES timeframe)
   {
      for (int i = 0; i < ArraySize(authorized_timeframes); i++)
      {
         if (authorized_timeframes[i] == timeframe)
            return true;
      }
      return false;
   }

   CEmasBearSellConfig()
   {
      type = "emas_sell_bear";
      risk_percent = 1.0;
      stop_loss_pips = 50.0;
      take_profit_ratio = 2.0;

      // Initialize new parameters with default values
      min_distance_9_21_atr_m3 = 0.3;
      min_distance_21_50_atr_m3 = 0.5;
      min_distance_9_21_atr_m15 = 0.3;
      min_distance_21_50_atr_m15 = 0.5;
      lookback_candles = 3;
      max_distance_atr = 0.8;
      max_duration_candles = 3;
      lookback_periods = 10;
      min_volatility_ratio = 0.7;
      max_volatility_ratio = 1.5;
      bearish_structure_atr_threshold = 0.5;
      adx_min_value = 25;
      adx_max_value = 60;

      // Initialize validation flags to true by default
      enable_ema_alignment_m15 = true;
      enable_ema_alignment_m3 = true;
      enable_strong_trend_m15 = true;
      enable_strong_trend_m3 = true;
      enable_bearish_momentum = true;
      enable_good_volatility = true;
      enable_bearish_structure_m15 = true;
      enable_bearish_structure_m3 = true;
      enable_adx_filter = true;
      enable_pullback_ema9 = true;
      enable_pullback_ema21 = true;

      // Initialize authorized timeframes (default to M15 and M3 for this strategy)
      ArrayResize(authorized_timeframes, 2);
      authorized_timeframes[0] = PERIOD_M15;
      authorized_timeframes[1] = PERIOD_M3;
   }
};

//--- Strategy Configuration
struct SStrategyConfig
{
   bool enabled;
   CStrategyConfig *strategies[];
};

#endif