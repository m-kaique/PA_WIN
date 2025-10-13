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