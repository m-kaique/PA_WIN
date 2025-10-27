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
    // Campos obrigatórios em pontos:
    double stop_loss_points;          // SL sempre em pontos
    double take_profit_points;        // TP em pontos (0 = sem TP)
    bool   enable_breakeven;
    bool   enable_trailing_stop;
    ENUM_TRAILING_MODE trailing_mode;
    double breakeven_trigger_points;  // quando lucro >= X, aplicar BE
    double breakeven_level_points;    // quanto travar a favor após BE
    double trailing_distance_points;  // distância fixa do preço
    double minimum_improvement_points;      // histerese do trailing
    double trailing_start_buffer_points;    // buffer pós-BE p/ iniciar trailing

    void Reset()
    {
        risk_percent                   = 1.0;

        // 100% em PONTOS
        stop_loss_points               = 250.0;
        take_profit_points             = 0.0;    // SEM TP

        enable_breakeven               = true;
        enable_trailing_stop           = true;
        trailing_mode                  = TRAILING_FIXED;

        // Defaults acordados
        breakeven_trigger_points       = 100.0;  // aciona BE ao ganhar 100
        breakeven_level_points         = 80.0;   // trava +80 após BE
        trailing_distance_points       = 100.0;  // distância do SL ao preço

        // Histerese e buffer em pontos
        minimum_improvement_points     = 0.5 * trailing_distance_points; // 50
        trailing_start_buffer_points   = 0.5 * trailing_distance_points; // 50
    }
};

#endif // __ORDER_TYPES_MQH__