struct SStrongTrendEMAS
{
   double distance_ema_9_21;
   double distance_ema_21_50;
   double distance_ema_9_50;

   double distance_ema_9_21_by_atr;
   double distance_ema_21_50_by_atr;
   double distance_ema_9_50_by_atr;

   double ema9_value;
   double ema21_value;
   double ema50_value;
   double atr_value;

   bool is_strong_trend;
};

struct SVolatilityEnv
{
   double avg_atr;
   double volatility_ratio;
};

struct SStrongTrendADX
{
   double adx_value_tf;
   double config_min_value;
   double config_max_value;
   bool isStrongTrendADX;
};

struct SBollingerValidStructure
{
   bool is_valid;
   double valid_min_width;
   double valid_max_width;
   double upper_band_value;
   double lower_band_value;
   double boll_width;
   double atr_value;
};

struct SIsValidPullback
{
   int digits;
   double point;
   double pip_value;
   double distance_price;
   double last_close;
   double last_low;
   double current_ma_value;
   string tf_name;
   ENUM_TIMEFRAMES tf_enum;
   double max_depth;
   bool was_further;
   int lookback_start;
   int lookback_end;
   bool is_valid;
   bool invalid_position_for_pullback;
   bool valid_support_positions;
   double max_penetration_below_ema;
   double penetration;
};