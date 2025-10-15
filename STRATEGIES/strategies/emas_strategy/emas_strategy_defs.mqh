#ifndef __EMAS_STRATEGY_DEFS_MQH__
#define __EMAS_STRATEGY_DEFS_MQH__

#include "../../../TF_CTX/indicators/indicator_base/submodules/indicator_slope/slope_defs.mqh"
#include "../../../TF_CTX/indicators/indicator_base/submodules/indicator_candle_distance/candle_distance_defs.mqh"

struct SDistance_MA
{
   ENUM_TIMEFRAMES timeframe;

   double ema_9_21;
   double ema_21_50;
   double ema_9_50;

   double ema_9_21_by_atr;
   double ema_21_50_by_atr;
   double ema_9_50_by_atr;

   double ema9_value;
   double ema21_value;
   double ema50_value;
   double atr_value;

   double min_distance_9_21_config;
   double min_distance_21_50_config;

   bool is_strong_trend;
   bool is_enabled;
   bool is_evaluated;

   void Reset()
   {
      timeframe = PERIOD_CURRENT;
      ema_9_21 = 0.0;
      ema_21_50 = 0.0;
      ema_9_50 = 0.0;
      ema_9_21_by_atr = 0.0;
      ema_21_50_by_atr = 0.0;
      ema_9_50_by_atr = 0.0;
      ema9_value = 0.0;
      ema21_value = 0.0;
      ema50_value = 0.0;
      atr_value = 0.0;
      min_distance_9_21_config = 0.0;
      min_distance_21_50_config = 0.0;
      is_strong_trend = false;
      is_enabled = false;
      is_evaluated = false;
   }
};

struct SVolatilityEnv
{
   double current_atr;
   double avg_atr;
   double volatility_ratio;
   int valid_periods;

   bool is_good_volatility;
   bool is_enabled;
   bool is_evaluated;

   void Reset()
   {
      current_atr = 0.0;
      avg_atr = 0.0;
      volatility_ratio = 0.0;
      valid_periods = 0;
      is_good_volatility = false;
      is_enabled = false;
      is_evaluated = false;
   }
};

struct SStrongTrendADX
{
   double adx_value_tf;
   double config_min_value;
   double config_max_value;
   bool isStrongTrendADX;
   bool is_enabled;
   bool is_evaluated;

   void Reset()
   {
      adx_value_tf = 0.0;
      config_min_value = 0.0;
      config_max_value = 0.0;
      isStrongTrendADX = false;
      is_enabled = false;
      is_evaluated = false;
   }
};

struct SBollingerValidStructure
{
   bool is_valid;
   bool is_enabled;
   bool is_evaluated;

   double valid_min_width;
   double valid_max_width;

   double upper_band_value;
   double middle_band_value;
   double lower_band_value;
   double boll_width;
   double atr_value;

   bool contracting_condition;
   bool slope_upper_sidewalk;
   bool slope_lower_sidewalk;
   bool slope_upper_micro_ok;
   bool slope_lower_micro_ok;

   SSlopeValidation slope_upper;
   SSlopeValidation slope_middle;
   SSlopeValidation slope_lower;

   void Reset()
   {
      is_valid = false;
      is_enabled = false;
      is_evaluated = false;
      valid_min_width = 0.0;
      valid_max_width = 0.0;
      upper_band_value = 0.0;
      middle_band_value = 0.0;
      lower_band_value = 0.0;
      boll_width = 0.0;
      atr_value = 0.0;
      contracting_condition = false;
      slope_upper_sidewalk = false;
      slope_lower_sidewalk = false;
      slope_upper_micro_ok = false;
      slope_lower_micro_ok = false;
      ZeroMemory(slope_upper);
      ZeroMemory(slope_middle);
      ZeroMemory(slope_lower);
   }
};

struct SBullishMomentum
{
   int candles_above_ema21;
   bool price_above_ema21;
   bool no_panic_selling;
   bool last_candle_bullish;

   bool is_valid;
   bool is_enabled;
   bool is_evaluated;

   void Reset()
   {
      candles_above_ema21 = 0;
      price_above_ema21 = false;
      no_panic_selling = false;
      last_candle_bullish = false;
      is_valid = false;
      is_enabled = false;
      is_evaluated = false;
   }
};

struct SBullishStructure
{
   ENUM_TIMEFRAMES timeframe;
   double current_close;
   double ema50_value;
   double atr_value;
   double distance_to_ema50;
   double threshold_config;

   bool price_above_ema50;
   bool distance_ok;
   bool ema50_trending_up;
   bool is_valid;
   bool is_enabled;
   bool is_evaluated;

   SSlopeValidation ema50_slope;

   void Reset()
   {
      timeframe = PERIOD_CURRENT;
      current_close = 0.0;
      ema50_value = 0.0;
      atr_value = 0.0;
      distance_to_ema50 = 0.0;
      threshold_config = 0.0;
      price_above_ema50 = false;
      distance_ok = false;
      ema50_trending_up = false;
      is_valid = false;
      is_enabled = false;
      is_evaluated = false;
      ZeroMemory(ema50_slope);
   }
};

struct SEMAAlignmentState
{
   ENUM_TIMEFRAMES timeframe;
   double ema9_value;
   double ema21_value;
   double ema50_value;
   bool ema9_vs_ema21;
   bool ema21_vs_ema50;
   bool is_valid;
   bool is_enabled;

   void Reset()
   {
      timeframe = PERIOD_CURRENT;
      ema9_value = 0.0;
      ema21_value = 0.0;
      ema50_value = 0.0;
      ema9_vs_ema21 = false;
      ema21_vs_ema50 = false;
      is_valid = false;
      is_enabled = false;
   }
};

struct SPullbackValidation
{
   string label;
   ENUM_TIMEFRAMES timeframe;
   SPositionInfo position_info;

   double atr_value;
   double pip_value;
   double distance_price;
   double max_depth;
   double current_ma;
   double last_close;
   double last_low;
   int lookback_start;
   int lookback_end;

   bool depth_ok;
   bool was_further_above;
   int found_at_bar;
   double best_previous_distance_atr;
   double current_distance_atr;
   bool invalid_position_for_pullback;
   double penetration;
   double max_penetration_allowed;
   bool penetration_ok;

   bool price_condition;
   bool is_valid;
   bool is_enabled;
   bool is_evaluated;
   bool inputs_valid;

   void Reset()
   {
      label = "";
      timeframe = PERIOD_CURRENT;
      ZeroMemory(position_info);
      atr_value = 0.0;
      pip_value = 0.0;
      distance_price = 0.0;
      max_depth = 0.0;
      current_ma = 0.0;
      last_close = 0.0;
      last_low = 0.0;
      lookback_start = 0;
      lookback_end = 0;
      depth_ok = false;
      was_further_above = false;
      found_at_bar = -1;
      best_previous_distance_atr = 0.0;
      current_distance_atr = 0.0;
      invalid_position_for_pullback = false;
      penetration = 0.0;
      max_penetration_allowed = 0.0;
      penetration_ok = false;
      price_condition = false;
      is_valid = false;
      is_enabled = false;
      is_evaluated = false;
      inputs_valid = false;
   }
};

struct SLastSignalEvaluation
{
   bool filtros_ok;
   bool setup_ok;
   bool entrada_valida;
   double atr_value_m3;

   void Reset()
   {
      filtros_ok = false;
      setup_ok = false;
      entrada_valida = false;
      atr_value_m3 = 0.0;
   }
};

#endif // __EMAS_STRATEGY_DEFS_MQH__
