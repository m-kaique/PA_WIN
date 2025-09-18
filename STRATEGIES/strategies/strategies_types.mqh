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
    double min_distance_9_21_atr;
    double min_distance_21_50_atr;
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
    bool enable_strong_trend;
    bool enable_bullish_momentum;
    bool enable_good_volatility;
    bool enable_bullish_structure_m15;
    bool enable_bullish_structure_m3;
    bool enable_adx_filter;
    bool enable_pullback_ema9;
    bool enable_pullback_ema21;

    CEmasBullBuyConfig()
    {
       type = "emas_buy_bull";
       risk_percent = 1.0;
       stop_loss_pips = 50.0;
       take_profit_ratio = 2.0;

       // Initialize new parameters with default values
       min_distance_9_21_atr = 0.3;
       min_distance_21_50_atr = 0.5;
       lookback_candles = 3;
       max_distance_atr = 0.8;
       max_duration_candles = 3;
       lookback_periods = 10;
       min_volatility_ratio = 0.7;
       max_volatility_ratio = 1.5;
       bullish_structure_atr_threshold = 0.5;
       adx_min_value = 25;
       adx_max_value = 60;

       // Initialize validation flags to true by default
       enable_ema_alignment_m15 = true;
       enable_ema_alignment_m3 = true;
       enable_strong_trend = true;
       enable_bullish_momentum = true;
       enable_good_volatility = true;
       enable_bullish_structure_m15 = true;
       enable_bullish_structure_m3 = true;
       enable_adx_filter = true;
       enable_pullback_ema9 = true;
       enable_pullback_ema21 = true;
    }
};

//--- Strategy Configuration
struct SStrategyConfig
{
   bool enabled;
   CStrategyConfig *strategies[];
};

#endif