struct SDistance_MA
{
   double ema_9_21;
   double ema_21_50;
   double ema_9_50;

   double ema_9_21_by_atr;
   double ema_21_50_by_atr;
   double ema_9_50_by_atr;
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