#ifndef __ORDER_TYPES_MQH__
#define __ORDER_TYPES_MQH__

//+------------------------------------------------------------------+
//| Enums for order management                                       |
//+------------------------------------------------------------------+
enum ENUM_POSITION_STATE
{
    POSITION_NONE,
    POSITION_OPEN,
    POSITION_PENDING,
    POSITION_CLOSED
};

enum ENUM_ORDER_DIRECTION
{
    ORDER_BUY,
    ORDER_SELL
};

enum ENUM_TRAILING_MODE
{
    TRAILING_NONE,
    TRAILING_FIXED,
    TRAILING_PERCENTAGE
};

enum ENUM_VOLUME_MODE
{
    VOLUME_FIXED = 0,   // usa fixed_volume_lots
    VOLUME_RISK  = 1    // (opcional) calcular por risco no futuro
};

//+------------------------------------------------------------------+
//| Structure for order position information                         |
//+------------------------------------------------------------------+
struct SOrderPositionInfo
{
    string strategy_name;
    string symbol;
    ENUM_TIMEFRAMES timeframe;
    ENUM_ORDER_DIRECTION order_type;
    ENUM_POSITION_STATE state;
    ulong ticket;
    double entry_price;
    double current_price;
    double stop_loss;
    double take_profit;
    double lot_size;
    double breakeven_level;
    double trailing_stop_level;
    datetime open_time;
    datetime last_update;
    bool breakeven_enabled;
    bool trailing_enabled;
    ENUM_TRAILING_MODE trailing_mode;
    double trailing_distance;

    // Parciais
    bool partials_closed[3];
    bool enable_partials_local;
    double initial_volume;

    // Trailing state machine
    bool trailed_once;
    datetime last_trail_time;
    datetime last_trail_attempt; // para cooldown independente

    void Reset()
    {
        strategy_name = "";
        symbol = "";
        timeframe = PERIOD_CURRENT;
        order_type = ORDER_BUY;
        state = POSITION_NONE;
        ticket = 0;
        entry_price = 0.0;
        current_price = 0.0;
        stop_loss = 0.0;
        take_profit = 0.0;
        lot_size = 0.0;
        breakeven_level = 0.0;
        trailing_stop_level = 0.0;
        open_time = 0;
        last_update = 0;
        breakeven_enabled = false;
        trailing_enabled = false;
        trailing_mode = TRAILING_NONE;
        trailing_distance = 0.0;

        // Parciais
        ArrayFill(partials_closed, 0, 3, false);
        enable_partials_local = false;
        initial_volume = 0.0;

        // Trailing state
        trailed_once = false;
        last_trail_time = 0;
        last_trail_attempt = 0;
    }
};

//+------------------------------------------------------------------+
//| Structure for partial order configuration                        |
//+------------------------------------------------------------------+
struct SOrderPartial
{
    double percent;       // % do volume total (0–100)
    int target_points;    // alvo em pontos a partir da entrada
};

//+------------------------------------------------------------------+
//| Structure for order configuration - VERSÃO ATUALIZADA           |
//+------------------------------------------------------------------+
struct SOrderConfig
{
    double risk_percent;
    // Campos obrigatórios em pontos:
    double stop_loss_points;          // SL sempre em pontos
    double take_profit_points;        // TP em pontos (0 = sem TP)

    ENUM_VOLUME_MODE volume_mode;     // NOVO
    double fixed_volume_lots;         // NOVO

    bool   enable_breakeven;
    bool   enable_trailing_stop;
    ENUM_TRAILING_MODE trailing_mode;
    double breakeven_trigger_points;  // quando lucro >= X, aplicar BE
    double breakeven_level_points;    // quanto travar a favor após BE
    double trailing_distance_points;  // distância fixa do preço
    double minimum_improvement_points;      // histerese do trailing
    double trailing_start_buffer_points;    // buffer pós-BE p/ iniciar trailing

    // Parciais
    bool enable_partials;
    int  min_lots_for_partials;           // >=2
    bool scale_up_to_enable_partials;     // se true, força N lotes
    SOrderPartial partials[3];  // até 3 parciais
    int partial_count;

    // Trailing avançado
    int m_be_trigger_pts;                 // lucro mínimo p/ ativar BE
    int m_be_offset_pts;                  // BE deixa margem p/ spread e custos
    int m_trail_cooldown_sec;             // cooldown geral do trailing
    int m_cooldown_after_partial_sec;     // cooldown específico após parcial
    int m_cooldown_after_be_sec;          // cooldown específico após breakeven
    int m_trail_offset_pts;               // só trail se gap ≥ X pts
    int m_trail_step_pts;                 // só move SL se avanço ≥ X pts

    // Chandelier + Swing
    int m_atr_period;                     // período ATR
    double m_atr_mult;                   // multiplicador ATR
    int m_swing_lookback;                // lookback para swings

    void Reset()
    {
        // Risco ainda disponível se quiser usar depois
        risk_percent                   = 1.0;

        // 100% em PONTOS (sem pips)
        stop_loss_points               = 250.0;
        take_profit_points             = 0.0;    // SEM TP

        // Volume manual por padrão
        volume_mode                    = VOLUME_FIXED;
        fixed_volume_lots              = 10.0;    // defina aqui o volume desejado

        enable_breakeven               = true;
        enable_trailing_stop           = true;
        trailing_mode                  = TRAILING_FIXED;

        // Defaults acordados
        breakeven_trigger_points       = 100.0;  // aciona BE ao ganhar 100
        breakeven_level_points         = 150.0;   // trava +80 após BE
        trailing_distance_points       = 250.0;  // distância do SL ao preço

        // Histerese e buffer em pontos
        minimum_improvement_points     = 0.5 * trailing_distance_points; // 50
        trailing_start_buffer_points   = 0.5 * trailing_distance_points; // 50

        // Parciais
        enable_partials                = true;
        min_lots_for_partials          = 2;
        scale_up_to_enable_partials    = false;  // mantém risco se false
        partial_count                  = 2;
        partials[0].percent            = 0.5;   // 50% em +150 pts
        partials[0].target_points      = 150;
        partials[1].percent            = 0.5;   // 50% em +300 pts
        partials[1].target_points      = 300;

        // Trailing avançado
        m_be_trigger_pts               = 250;   // lucro mínimo p/ ativar BE
        m_be_offset_pts                = 30;    // BE deixa margem p/ spread e custos
        m_trail_cooldown_sec           = 25;    // cooldown geral do trailing
        m_cooldown_after_partial_sec   = 25;    // cooldown após parcial
        m_cooldown_after_be_sec        = 0;     // cooldown após breakeven (0 = imediato)
        m_trail_offset_pts             = 260;   // só trail se gap ≥ 260 pts
        m_trail_step_pts               = 40;    // só move SL se avanço ≥ 40 pts

        // Chandelier + Swing
        m_atr_period                   = 14;
        m_atr_mult                     = 1.2;
        m_swing_lookback               = 14;
    }
};

// -------- Trailing Config --------
struct TrailingConfig {
  int fixed_points;
  int fixed_points_last;
  int atr_period;
  double atr_mult;
  int swing_lookback;
  int cooldown_sec;
  int min_imp_points;
  bool start_buffer_enabled;
  int  start_buffer_points;

  void Reset() {
    fixed_points = 200;
    fixed_points_last = 180;
    atr_period = 14;
    atr_mult = 3.0;
    swing_lookback = 1;
    cooldown_sec = 25;
    min_imp_points = 10;
    start_buffer_enabled = false;
    start_buffer_points = 0;
  }
};

#endif // __ORDER_TYPES_MQH__