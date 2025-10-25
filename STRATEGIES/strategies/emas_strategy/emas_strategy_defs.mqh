// Common Data
struct SStratedyBassicData{
   string fail_message;
};

//+------------------------------------------------------------------+
//| Estrutura para análise de Tendência Forte - EMAS                 |
//+------------------------------------------------------------------+
struct SStrongTrendEMAS:SStratedyBassicData
{
   // Distâncias absolutas entre EMAs
   double distance_ema_9_21;
   double distance_ema_21_50;
   double distance_ema_9_50;

   // Distâncias normalizadas por ATR
   double distance_ema_9_21_by_atr;
   double distance_ema_21_50_by_atr;
   double distance_ema_9_50_by_atr;

   // Valores das EMAs
   double ema9_value;
   double ema21_value;
   double ema50_value;
   double atr_value;

   // Resultado final
   bool is_strong_trend;

   // NOVOS CAMPOS PARA DIAGNÓSTICO
   ENUM_TIMEFRAMES timeframe;           // Timeframe analisado
   double min_distance_9_21_threshold;  // Threshold configurado para 9-21
   double min_distance_21_50_threshold; // Threshold configurado para 21-50
   bool distance_9_21_ok;               // Se distância 9-21 passou
   bool distance_21_50_ok;              // Se distância 21-50 passou

   // Método para resetar a estrutura
   void Reset()
   {
      fail_message = "";
      distance_ema_9_21 = 0.0;
      distance_ema_21_50 = 0.0;
      distance_ema_9_50 = 0.0;
      distance_ema_9_21_by_atr = 0.0;
      distance_ema_21_50_by_atr = 0.0;
      distance_ema_9_50_by_atr = 0.0;
      ema9_value = 0.0;
      ema21_value = 0.0;
      ema50_value = 0.0;
      atr_value = 0.0;
      is_strong_trend = false;
      timeframe = PERIOD_CURRENT;
      min_distance_9_21_threshold = 0.0;
      min_distance_21_50_threshold = 0.0;
      distance_9_21_ok = false;
      distance_21_50_ok = false;
   }
};

//+------------------------------------------------------------------+
//| Estrutura para análise de ADX - Força de Tendência               |
//+------------------------------------------------------------------+
struct SStrongTrendADX:SStratedyBassicData
{
   double adx_value_tf;
   double config_min_value;
   double config_max_value;
   bool isStrongTrendADX;
   
   void Reset()
   {
      fail_message = "";
      adx_value_tf = 0.0;
      config_min_value = 0.0;
      config_max_value = 0.0;
      isStrongTrendADX = false;
   }
};

//+------------------------------------------------------------------+
//| Estrutura para análise de Bollinger Bands                        |
//+------------------------------------------------------------------+
struct SBollingerStructure:SStratedyBassicData
{
   // Dados de entrada
   ENUM_TIMEFRAMES timeframe;
   double upper_band_value;
   double lower_band_value;
   double boll_width;
   double atr_value;
   
   // Configuração de largura
   double valid_min_width;
   double valid_max_width;
   bool width_in_range;
   
   bool contracting_upper;
   bool contracting_lower;
   bool is_contracting;
   
   // Micro inclinação banda superior
   double upper_lr_min;
   double upper_dd_min;
   double upper_sd_min;
   bool upper_is_sidewalk;
   bool upper_lr_ok;
   bool upper_dd_ok;
   bool upper_sd_ok;
   bool upper_micro_ok;
   
   // Validação banda inferior
   double lower_lr_abs_max;
   double lower_dd_abs_max;
   double lower_sd_abs_max;
   bool lower_is_sidewalk;
   bool lower_lr_invalid;
   bool lower_dd_invalid;
   bool lower_sd_invalid;
   bool lower_sidewalk_invalid;
   
   // Resultado final
   bool is_valid_structure;
   
   void Reset()
   {
      fail_message = "";
      timeframe = PERIOD_CURRENT;
      upper_band_value = 0.0;
      lower_band_value = 0.0;
      boll_width = 0.0;
      atr_value = 0.0;
      valid_min_width = 0.0;
      valid_max_width = 0.0;
      width_in_range = false;
      contracting_upper = false;
      contracting_lower = false;
      is_contracting = false;
      upper_lr_min = 0.0;
      upper_dd_min = 0.0;
      upper_sd_min = 0.0;
      upper_is_sidewalk = false;
      upper_lr_ok = false;
      upper_dd_ok = false;
      upper_sd_ok = false;
      upper_micro_ok = false;
      lower_lr_abs_max = 0.0;
      lower_dd_abs_max = 0.0;
      lower_sd_abs_max = 0.0;
      lower_is_sidewalk = false;
      lower_lr_invalid = false;
      lower_dd_invalid = false;
      lower_sd_invalid = false;
      lower_sidewalk_invalid = false;
      is_valid_structure = false;
   }
};


struct SIsValidPullback:SStratedyBassicData
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
   int found_at_bar;
   double prev_distance_atr;
   double improvement_factor;
   double improvement_ratio;
   
   void Reset()
   {
      fail_message = "";
      digits = 0;
      point = 0.0;
      pip_value = 0.0;
      distance_price = 0.0;
      last_close = 0.0;
      last_low = 0.0;
      current_ma_value = 0.0;
      tf_name = "";
      tf_enum = PERIOD_CURRENT;
      max_depth = 0.0;
      was_further = false;
      lookback_start = 0;
      lookback_end = 0;
      is_valid = false;
      invalid_position_for_pullback = false;
      valid_support_positions = false;
      max_penetration_below_ema = 0.0;
      penetration = 0.0;
      found_at_bar = 0;
      prev_distance_atr = 0.0;
      improvement_factor = 0.0;
      improvement_ratio = 0.0;
   }
};
//+------------------------------------------------------------------+
//| Estrutura para análise de momentum bullish                       |
//+------------------------------------------------------------------+
struct SBullishMomentum:SStratedyBassicData

{
   // Dados de entrada
   ENUM_TIMEFRAMES timeframe_m15;
   ENUM_TIMEFRAMES timeframe_m3;
   double ema21_m15_value;
   int lookback_candles;
   
   // Critério 1: Preço acima da EMA21
   int candles_above_ema21;
   int min_candles_required;
   bool price_above_ema21;
   
   // Critério 2: Ausência de pânico de venda
   bool no_panic_selling;
   int panic_candle_index;
   double panic_lower_shadow_ratio;
   
   // Critério 3: Última vela bullish
   double last_open;
   double last_close;
   bool last_candle_bullish;
   
   // Resultado final
   bool has_momentum;
   
   void Reset()
   {
      fail_message = "";
      timeframe_m15 = PERIOD_CURRENT;
      timeframe_m3 = PERIOD_CURRENT;
      ema21_m15_value = 0.0;
      lookback_candles = 0;
      candles_above_ema21 = 0;
      min_candles_required = 0;
      price_above_ema21 = false;
      no_panic_selling = true;
      panic_candle_index = -1;
      panic_lower_shadow_ratio = 0.0;
      last_open = 0.0;
      last_close = 0.0;
      last_candle_bullish = false;
      has_momentum = false;
   }
};

//+------------------------------------------------------------------+
//| Estrutura para análise de ambiente de volatilidade               |
//+------------------------------------------------------------------+
struct SVolatilityEnvironment:SStratedyBassicData
{
   // Dados de entrada
   ENUM_TIMEFRAMES timeframe;
   double current_atr;
   int lookback_periods;
   
   // Cálculos
   double sum_atr;
   int valid_periods;
   double avg_atr;
   double volatility_ratio;
   
   // Configuração
   double min_volatility_ratio;
   double max_volatility_ratio;
   
   // Validações
   bool has_valid_data;
   bool ratio_in_range;
   bool is_good_environment;
   
   void Reset()
   {
      fail_message = "";
      timeframe = PERIOD_CURRENT;
      current_atr = 0.0;
      lookback_periods = 0;
      sum_atr = 0.0;
      valid_periods = 0;
      avg_atr = 0.0;
      volatility_ratio = 0.0;
      min_volatility_ratio = 0.0;
      max_volatility_ratio = 0.0;
      has_valid_data = false;
      ratio_in_range = false;
      is_good_environment = false;
   }
};

//+------------------------------------------------------------------+
//| Estrutura para análise de estrutura bullish                      |
//+------------------------------------------------------------------+
struct SBullishStructure:SStratedyBassicData
{
   // Dados de entrada
   ENUM_TIMEFRAMES timeframe;
   double current_close;
   double ema50_value;
   double atr_value;
   
   // Critério 1: Preço acima da EMA50
   bool price_above_ema50;
   
   // Critério 2: Distância mínima da EMA50
   double distance_to_ema50;
   double distance_to_ema50_atr;
   double min_distance_threshold;
   bool distance_ok;
   
   // Critério 3: EMA50 inclinada para cima
   bool ema50_trending_up;
   
   // Resultado final
   bool is_bullish_structure;
   
   void Reset()
   {
      fail_message = "";
      timeframe = PERIOD_CURRENT;
      current_close = 0.0;
      ema50_value = 0.0;
      atr_value = 0.0;
      price_above_ema50 = false;
      distance_to_ema50 = 0.0;
      distance_to_ema50_atr = 0.0;
      min_distance_threshold = 0.0;
      distance_ok = false; 
      ema50_trending_up = false;
      is_bullish_structure = false;
   }
};

//+------------------------------------------------------------------+
//| DEPRECATED -- Still Needed in emas_bear_sell ---------------------
//+------------------------------------------------------------------+
struct SVolatilityEnv
{
   double avg_atr;
   double volatility_ratio;
   
   void Reset()
   {
      avg_atr = 0.0;
      volatility_ratio = 0.0;
   }
};
