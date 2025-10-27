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
    }
};

//+------------------------------------------------------------------+
//| Structure for order configuration - VERSÃO ATUALIZADA           |
//+------------------------------------------------------------------+
struct SOrderConfig
{
    double risk_percent;
    double stop_loss_pips;
    double take_profit_points;        // TP em pontos absolutos
    bool enable_breakeven;
    bool enable_trailing_stop;
    ENUM_TRAILING_MODE trailing_mode;
    double trailing_distance_points;  // Trailing em pontos
    double breakeven_trigger_points;  // Trigger do BE em pontos
    double breakeven_level_points;    // Nível do BE em pontos

    void Reset()
    {
        risk_percent = 1.0;
        stop_loss_pips = 25.0;           // SL em 25 pips (250 pontos)
        take_profit_points = 0.0;        // SEM TP - deixa rolar com trailing
        enable_breakeven = true;
        enable_trailing_stop = true;
        trailing_mode = TRAILING_FIXED;
        trailing_distance_points = 250.0; // Trailing a cada 20 pontos
        breakeven_trigger_points = 100.0; // Trigger aos 100 pontos de lucro
        breakeven_level_points = 5.0;    // Move SL para +5 pontos
    }
};

#endif // __ORDER_TYPES_MQH__