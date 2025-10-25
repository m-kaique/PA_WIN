// Common Data
struct SStratedyBassicData{
   string fail_message;
   string success_message;

   // Propriedades comuns
   ENUM_TIMEFRAMES timeframe;     // Timeframe analisado
   string tf_name;                // Nome do timeframe (ex: "M15", "H1")
   double atr_value;              // Valor do ATR
   bool validation_result;        // Resultado final da validação

   // Método base para reset
   void ResetBase()
   {
      fail_message = "";
      success_message = "";
      timeframe = PERIOD_CURRENT;
      tf_name = "";
      atr_value = 0.0;
      validation_result = false;
   }
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

   // NOVOS CAMPOS PARA DIAGNÓSTICO
   double min_distance_9_21_threshold;  // Threshold configurado para 9-21
   double min_distance_21_50_threshold; // Threshold configurado para 21-50
   bool distance_9_21_ok;               // Se distância 9-21 passou
   bool distance_21_50_ok;              // Se distância 21-50 passou

   // Método para resetar a estrutura
   void Reset()
   {
      ResetBase();  // Reseta propriedades da base
      distance_ema_9_21 = 0.0;
      distance_ema_21_50 = 0.0;
      distance_ema_9_50 = 0.0;
      distance_ema_9_21_by_atr = 0.0;
      distance_ema_21_50_by_atr = 0.0;
      distance_ema_9_50_by_atr = 0.0;
      ema9_value = 0.0;
      ema21_value = 0.0;
      ema50_value = 0.0;
      min_distance_9_21_threshold = 0.0;
      min_distance_21_50_threshold = 0.0;
      distance_9_21_ok = false;
      distance_21_50_ok = false;
      validation_result = distance_9_21_ok && distance_21_50_ok;
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

     void Reset()
     {
        ResetBase();  // Reseta propriedades da base
        adx_value_tf = 0.0;
        config_min_value = 0.0;
        config_max_value = 0.0;
        validation_result = false;
     }
};

//+------------------------------------------------------------------+
//| Estrutura para análise de Bollinger Bands                        |
//+------------------------------------------------------------------+
struct SBollingerStructure:SStratedyBassicData
{
    // Dados de entrada
    double upper_band_value;
    double lower_band_value;
    double boll_width;

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

    void Reset()
    {
       ResetBase();  // Reseta propriedades da base
       upper_band_value = 0.0;
       lower_band_value = 0.0;
       boll_width = 0.0;
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
       validation_result = width_in_range && !is_contracting && upper_micro_ok && !lower_sidewalk_invalid;
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
     double max_depth;
     bool was_further;
     int lookback_start;
     int lookback_end;
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
        ResetBase();  // Reseta propriedades da base
        digits = 0;
        point = 0.0;
        pip_value = 0.0;
        distance_price = 0.0;
        last_close = 0.0;
        last_low = 0.0;
        current_ma_value = 0.0;
        max_depth = 0.0;
        was_further = false;
        lookback_start = 0;
        lookback_end = 0;
        invalid_position_for_pullback = false;
        valid_support_positions = false;
        max_penetration_below_ema = 0.0;
        penetration = 0.0;
        found_at_bar = 0;
        prev_distance_atr = 0.0;
        improvement_factor = 0.0;
        improvement_ratio = 0.0;
        validation_result = true;
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

    void Reset()
    {
       ResetBase();  // Reseta propriedades da base
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
       validation_result = price_above_ema21 && no_panic_selling && last_candle_bullish;
    }
};

//+------------------------------------------------------------------+
//| Estrutura para análise de ambiente de volatilidade               |
//+------------------------------------------------------------------+
struct SVolatilityEnvironment:SStratedyBassicData
{
    // Dados de entrada
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

    void Reset()
    {
       ResetBase();  // Reseta propriedades da base
       lookback_periods = 0;
       sum_atr = 0.0;
       valid_periods = 0;
       avg_atr = 0.0;
       volatility_ratio = 0.0;
       min_volatility_ratio = 0.0;
       max_volatility_ratio = 0.0;
       has_valid_data = false;
       ratio_in_range = false;
       validation_result = has_valid_data && ratio_in_range;
    }
};

//+------------------------------------------------------------------+
//| Estrutura para análise de estrutura bullish                      |
//+------------------------------------------------------------------+
struct SBullishStructure:SStratedyBassicData
{
    // Dados de entrada
    double current_close;
    double ema50_value;

    // Critério 1: Preço acima da EMA50
    bool price_above_ema50;

    // Critério 2: Distância mínima da EMA50
    double distance_to_ema50;
    double distance_to_ema50_atr;
    double min_distance_threshold;
    bool distance_ok;

    // Critério 3: EMA50 inclinada para cima
    bool ema50_trending_up;

    void Reset()
    {
       ResetBase();  // Reseta propriedades da base
       current_close = 0.0;
       ema50_value = 0.0;
       price_above_ema50 = false;
       distance_to_ema50 = 0.0;
       distance_to_ema50_atr = 0.0;
       min_distance_threshold = 0.0;
       distance_ok = false;
       ema50_trending_up = false;
       validation_result = price_above_ema50 && distance_ok && ema50_trending_up;
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
