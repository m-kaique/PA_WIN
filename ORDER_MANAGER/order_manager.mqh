#ifndef __ORDER_MANAGER_MQH__
#define __ORDER_MANAGER_MQH__

#include "../interfaces/iorder_manager.mqh"
#include "order_types.mqh"

//+------------------------------------------------------------------+
//| Order Manager Implementation                                     |
//+------------------------------------------------------------------+
class COrderManager : public IOrderManager
{
private:
    // Position tracking
    SOrderPositionInfo m_positions[];
    string m_strategy_names[];
    int m_max_positions;

    // Configuration
    SOrderConfig m_default_config;

    // Risk management sequencing
    int m_min_position_age_seconds;

    // Helper methods
    int FindPositionIndex(string strategy_name);
    bool AddPosition(const SOrderPositionInfo &position);
    bool UpdatePosition(int index, const SOrderPositionInfo &position);
    bool RemovePosition(int index);
    bool OpenMarketOrder(const SStrategySignal &signal, string strategy_name, string symbol, ENUM_TIMEFRAMES timeframe, SOrderPositionInfo &position_info);
    bool CalculateOrderParameters(const SStrategySignal &signal, string symbol, double &lot_size, double &stop_loss, double &take_profit);
    void ApplyBreakeven(SOrderPositionInfo &position);
    void ApplyTrailingStop(SOrderPositionInfo &position);
    double GetCurrentPrice(string symbol, ENUM_ORDER_DIRECTION direction);
    bool ModifyPositionStopLoss(ulong ticket, double new_stop_loss);

public:
    COrderManager(int max_positions = 10);
    ~COrderManager();

    virtual bool Init();
    virtual bool ProcessSignal(const SStrategySignal &signal, string strategy_name, string symbol, ENUM_TIMEFRAMES timeframe);
    virtual bool UpdatePositions();
    virtual bool ClosePosition(string strategy_name);
    virtual bool GetPositionInfo(string strategy_name, SOrderPositionInfo &info);
    virtual bool HasActivePosition(string strategy_name);
    virtual int GetActivePositions(string &strategy_names[]);
    virtual void Cleanup();
};

//+------------------------------------------------------------------+
COrderManager::COrderManager(int max_positions)
{
    m_max_positions = max_positions;
    m_min_position_age_seconds = 5;
    ArrayResize(m_positions, 0);
    ArrayResize(m_strategy_names, 0);
    m_default_config.Reset();
}

//+------------------------------------------------------------------+
COrderManager::~COrderManager()
{
    Cleanup();
}

//+------------------------------------------------------------------+
bool COrderManager::Init()
{
    Print("OrderManager initialized with max positions: ", m_max_positions);
    Print("Configuration: TP=", m_default_config.take_profit_points, " pts, Trailing=", 
          m_default_config.trailing_distance_points, " pts");
    return true;
}

//+------------------------------------------------------------------+
bool COrderManager::ProcessSignal(const SStrategySignal &signal, string strategy_name, string symbol, ENUM_TIMEFRAMES timeframe)
{
    if (HasActivePosition(strategy_name))
    {
        Print("Strategy ", strategy_name, " already has an active position. Skipping signal.");
        return false;
    }

    if (!signal.is_valid)
    {
        Print("Invalid signal received from strategy: ", strategy_name);
        return false;
    }

    SOrderPositionInfo position_info;
    if (!OpenMarketOrder(signal, strategy_name, symbol, timeframe, position_info))
    {
        Print("Failed to open position for strategy: ", strategy_name);
        return false;
    }

    if (!AddPosition(position_info))
    {
        Print("Failed to track position for strategy: ", strategy_name);
        if (position_info.ticket > 0)
        {
            MqlTradeRequest close_request = {};
            MqlTradeResult close_result = {};
            close_request.action = TRADE_ACTION_DEAL;
            close_request.position = position_info.ticket;
            close_request.volume = position_info.lot_size;
            close_request.type = (position_info.order_type == ORDER_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            OrderSend(close_request, close_result);
        }
        return false;
    }

    Print("Position opened successfully for strategy: ", strategy_name, " - Ticket: ", position_info.ticket);
    return true;
}

//+------------------------------------------------------------------+
bool COrderManager::UpdatePositions()
{
    bool all_updated = true;

    for (int i = ArraySize(m_positions) - 1; i >= 0; i--)
    {
        if (m_positions[i].state != POSITION_OPEN)
            continue;
            
        if (!PositionSelectByTicket(m_positions[i].ticket))
        {
            Print("Position ", m_positions[i].ticket, " for strategy ", 
                  m_positions[i].strategy_name, " no longer exists. Removing from tracking.");
            RemovePosition(i);
            continue;
        }

        // Update from actual position
        m_positions[i].current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
        m_positions[i].stop_loss = PositionGetDouble(POSITION_SL);
        m_positions[i].take_profit = PositionGetDouble(POSITION_TP);
        m_positions[i].last_update = TimeCurrent();

        int position_age = (int)(TimeCurrent() - m_positions[i].open_time);
        if (position_age < m_min_position_age_seconds)
            continue;

        if (!PositionSelectByTicket(m_positions[i].ticket))
        {
            Print("Position ", m_positions[i].ticket, " closed during update. Removing from tracking.");
            RemovePosition(i);
            continue;
        }

        if (m_positions[i].breakeven_enabled && m_positions[i].breakeven_level == 0.0)
        {
            ApplyBreakeven(m_positions[i]);
            
            if (!PositionSelectByTicket(m_positions[i].ticket))
            {
                Print("Position ", m_positions[i].ticket, " closed after breakeven. Removing from tracking.");
                RemovePosition(i);
                continue;
            }
        }
        else if (m_positions[i].breakeven_level != 0.0 && m_positions[i].trailing_enabled)
        {
            ApplyTrailingStop(m_positions[i]);
            
            if (!PositionSelectByTicket(m_positions[i].ticket))
            {
                Print("Position ", m_positions[i].ticket, " closed after trailing stop. Removing from tracking.");
                RemovePosition(i);
                continue;
            }
        }
    }

    return all_updated;
}

//+------------------------------------------------------------------+
bool COrderManager::ClosePosition(string strategy_name)
{
    int index = FindPositionIndex(strategy_name);
    if (index < 0)
    {
        Print("No active position found for strategy: ", strategy_name);
        return false;
    }

    if (m_positions[index].ticket <= 0)
    {
        Print("Invalid ticket for strategy: ", strategy_name);
        RemovePosition(index);
        return false;
    }

    MqlTradeRequest close_request = {};
    MqlTradeResult close_result = {};

    close_request.action = TRADE_ACTION_DEAL;
    close_request.position = m_positions[index].ticket;
    close_request.volume = m_positions[index].lot_size;
    close_request.type = (m_positions[index].order_type == ORDER_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    close_request.price = GetCurrentPrice(m_positions[index].symbol, m_positions[index].order_type);

    bool closed = OrderSend(close_request, close_result);
    if (closed && close_result.retcode == TRADE_RETCODE_DONE)
    {
        Print("Position closed for strategy: ", strategy_name);
        m_positions[index].state = POSITION_CLOSED;
        RemovePosition(index);
    }
    else
    {
        Print("Failed to close position for strategy: ", strategy_name, " Retcode: ", close_result.retcode);
    }

    return closed;
}

//+------------------------------------------------------------------+
bool COrderManager::GetPositionInfo(string strategy_name, SOrderPositionInfo &info)
{
    int index = FindPositionIndex(strategy_name);
    if (index < 0)
        return false;

    info = m_positions[index];
    return true;
}

//+------------------------------------------------------------------+
bool COrderManager::HasActivePosition(string strategy_name)
{
    int index = FindPositionIndex(strategy_name);
    return (index >= 0 && m_positions[index].state == POSITION_OPEN);
}

//+------------------------------------------------------------------+
int COrderManager::GetActivePositions(string &strategy_names[])
{
    ArrayResize(strategy_names, 0);
    int count = 0;

    for (int i = 0; i < ArraySize(m_positions); i++)
    {
        if (m_positions[i].state == POSITION_OPEN)
        {
            ArrayResize(strategy_names, count + 1);
            strategy_names[count] = m_positions[i].strategy_name;
            count++;
        }
    }

    return count;
}

//+------------------------------------------------------------------+
void COrderManager::Cleanup()
{
    ArrayResize(m_positions, 0);
    ArrayResize(m_strategy_names, 0);
}

//+------------------------------------------------------------------+
int COrderManager::FindPositionIndex(string strategy_name)
{
    for (int i = 0; i < ArraySize(m_strategy_names); i++)
    {
        if (m_strategy_names[i] == strategy_name)
            return i;
    }
    return -1;
}

//+------------------------------------------------------------------+
bool COrderManager::AddPosition(const SOrderPositionInfo &position)
{
    if (ArraySize(m_positions) >= m_max_positions)
    {
        Print("Maximum positions reached. Cannot add new position.");
        return false;
    }

    int index = ArraySize(m_positions);
    ArrayResize(m_positions, index + 1);
    ArrayResize(m_strategy_names, index + 1);

    m_positions[index] = position;
    m_strategy_names[index] = position.strategy_name;

    return true;
}

//+------------------------------------------------------------------+
bool COrderManager::UpdatePosition(int index, const SOrderPositionInfo &position)
{
    if (index < 0 || index >= ArraySize(m_positions))
        return false;

    m_positions[index] = position;
    return true;
}

//+------------------------------------------------------------------+
bool COrderManager::RemovePosition(int index)
{
    if (index < 0 || index >= ArraySize(m_positions))
        return false;

    for (int i = index; i < ArraySize(m_positions) - 1; i++)
    {
        m_positions[i] = m_positions[i + 1];
        m_strategy_names[i] = m_strategy_names[i + 1];
    }

    ArrayResize(m_positions, ArraySize(m_positions) - 1);
    ArrayResize(m_strategy_names, ArraySize(m_strategy_names) - 1);

    return true;
}

//+------------------------------------------------------------------+
//| Open market order - VERSÃO ATUALIZADA                           |
//+------------------------------------------------------------------+
bool COrderManager::OpenMarketOrder(const SStrategySignal &signal, string strategy_name, string symbol, ENUM_TIMEFRAMES timeframe, SOrderPositionInfo &position_info)
{
    double lot_size, stop_loss, take_profit;

    if (!CalculateOrderParameters(signal, symbol, lot_size, stop_loss, take_profit))
    {
        Print("Failed to calculate order parameters");
        return false;
    }

    ENUM_ORDER_TYPE order_type = (signal.type == SIGNAL_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

    MqlTradeRequest request = {};
    MqlTradeResult result = {};

    request.action = TRADE_ACTION_DEAL;
    request.symbol = symbol;
    request.volume = lot_size;
    request.type = order_type;
    request.price = signal.entry_price;
    request.sl = stop_loss;
    request.tp = (take_profit > 0) ? take_profit : 0; // Só define TP se > 0
    request.deviation = 10;
    request.comment = strategy_name;

    if (!OrderSend(request, result))
    {
        Print("OrderSend failed: ", GetLastError());
        return false;
    }

    if (result.retcode != TRADE_RETCODE_DONE)
    {
        Print("OrderSend failed with retcode: ", result.retcode);
        return false;
    }

    Sleep(100);
    
    ulong position_ticket = 0;
    
    if (PositionSelect(symbol))
    {
        position_ticket = PositionGetInteger(POSITION_TICKET);
    }
    else
    {
        Print("ERROR: Could not find position after order execution.");
        return false;
    }

    if (!PositionSelectByTicket(position_ticket))
    {
        Print("ERROR: Cannot select position by ticket ", position_ticket);
        return false;
    }

    double actual_entry = PositionGetDouble(POSITION_PRICE_OPEN);
    double actual_sl = PositionGetDouble(POSITION_SL);
    double actual_tp = PositionGetDouble(POSITION_TP);
    double actual_volume = PositionGetDouble(POSITION_VOLUME);

    position_info.Reset();
    position_info.strategy_name = strategy_name;
    position_info.symbol = symbol;
    position_info.timeframe = timeframe;
    position_info.order_type = (signal.type == SIGNAL_BUY) ? ORDER_BUY : ORDER_SELL;
    position_info.state = POSITION_OPEN;
    position_info.ticket = position_ticket;
    position_info.entry_price = actual_entry;
    position_info.current_price = actual_entry;
    position_info.stop_loss = actual_sl;
    position_info.take_profit = actual_tp;
    position_info.lot_size = actual_volume;
    position_info.open_time = TimeCurrent();
    position_info.last_update = TimeCurrent();
    position_info.breakeven_enabled = m_default_config.enable_breakeven;
    position_info.trailing_enabled = m_default_config.enable_trailing_stop;
    position_info.trailing_mode = m_default_config.trailing_mode;
    position_info.trailing_distance = m_default_config.trailing_distance_points;

    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int sl_points = (int)(MathAbs(actual_entry - actual_sl) / point);
    int tp_points = (actual_tp > 0) ? (int)(MathAbs(actual_tp - actual_entry) / point) : 0;

    Print("══════════════════════════════════════");
    Print("✓ POSIÇÃO ABERTA");
    Print("  Estratégia: ", strategy_name);
    Print("  Ticket: ", position_ticket);
    Print("  Tipo: ", (position_info.order_type == ORDER_BUY ? "COMPRA" : "VENDA"));
    Print("  Volume: ", actual_volume);
    Print("  Entrada: ", actual_entry);
    Print("  Stop Loss: ", actual_sl, " (", sl_points, " pts)");
    if (actual_tp > 0)
        Print("  Take Profit: ", actual_tp, " (", tp_points, " pts)");
    else
        Print("  Take Profit: SEM TP - Trailing apenas");
    Print("  Breakeven: ", (position_info.breakeven_enabled ? "ATIVO (100 pts)" : "INATIVO"));
    Print("  Trailing: ", (position_info.trailing_enabled ? "ATIVO (" + IntegerToString((int)m_default_config.trailing_distance_points) + " pts)" : "INATIVO"));
    Print("══════════════════════════════════════");

    return true;
}

//+------------------------------------------------------------------+
//| Calculate order parameters - SEM TP (trailing apenas)           |
//+------------------------------------------------------------------+
bool COrderManager::CalculateOrderParameters(const SStrategySignal &signal, string symbol, double &lot_size, double &stop_loss, double &take_profit)
{
    double min_volume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double max_volume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double volume_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

    // Volume fixo - 1 contrato
    lot_size = min_volume;
    lot_size = MathFloor(lot_size / volume_step) * volume_step;
    lot_size = MathMax(min_volume, MathMin(lot_size, max_volume));

    const double point     = SymbolInfoDouble(symbol, SYMBOL_POINT);
    const int    digits    = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    const double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    const long   stops_lvl = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
    const long   freeze_lv = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);

    // SL sempre em pontos
    double sl_price = (signal.type == SIGNAL_BUY)
        ? signal.entry_price - m_default_config.stop_loss_points * point
        : signal.entry_price + m_default_config.stop_loss_points * point;

    // snap para o múltiplo de tick
    if(tick_size > 0.0) sl_price = MathRound(sl_price / tick_size) * tick_size;
    sl_price = NormalizeDouble(sl_price, digits);

    // Se houver TP > 0, calcula e valida
    double tp_price = 0.0;
    if(m_default_config.take_profit_points > 0.0)
    {
        tp_price = (signal.type == SIGNAL_BUY)
                 ? signal.entry_price + m_default_config.take_profit_points * point
                 : signal.entry_price - m_default_config.take_profit_points * point;
        // snap para o múltiplo de tick
        if(tick_size > 0.0) tp_price = MathRound(tp_price / tick_size) * tick_size;
        tp_price = NormalizeDouble(tp_price, digits);
    }

    // valida distância mínima exigida
    double min_dist = (double)stops_lvl * point;
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);

    // BUY: SL < bid - min_dist ; TP > ask + min_dist
    if(signal.type == SIGNAL_BUY)
    {
        if(sl_price >= bid - min_dist)
        {
            sl_price = bid - min_dist;
            if(tick_size > 0.0) sl_price = MathRound(sl_price / tick_size) * tick_size;
            sl_price = NormalizeDouble(sl_price, digits);
        }
        if(tp_price > 0.0 && tp_price <= ask + min_dist)
        {
            // afasta o TP…
            tp_price = ask + min_dist;
            if(tick_size > 0.0) tp_price = MathRound(tp_price / tick_size) * tick_size;
            tp_price = NormalizeDouble(tp_price, digits);
        }
    }
    // SELL: SL > ask + min_dist ; TP < bid - min_dist
    else
    {
        if(sl_price <= ask + min_dist)
        {
            sl_price = ask + min_dist;
            if(tick_size > 0.0) sl_price = MathRound(sl_price / tick_size) * tick_size;
            sl_price = NormalizeDouble(sl_price, digits);
        }
        if(tp_price > 0.0 && tp_price >= bid - min_dist)
        {
            // afasta…
            tp_price = bid - min_dist;
            if(tick_size > 0.0) tp_price = MathRound(tp_price / tick_size) * tick_size;
            tp_price = NormalizeDouble(tp_price, digits);
        }
    }

    stop_loss = sl_price;
    take_profit = tp_price;

    // Log para diagnóstico
    PrintFormat("Order params: entry=%.0f sl=%.0f tp=%s stops_level=%ld freeze_level=%ld tick_size=%.0f",
                signal.entry_price, sl_price, (tp_price>0?DoubleToString(tp_price,0):"0"),
                stops_lvl, freeze_lv, tick_size);

    return true;
}

//+------------------------------------------------------------------+
//| Apply breakeven - VERSÃO EM PONTOS                              |
//+------------------------------------------------------------------+
void COrderManager::ApplyBreakeven(SOrderPositionInfo &position)
{
    if (!position.breakeven_enabled || position.state != POSITION_OPEN)
        return;

    if (position.breakeven_level != 0.0)
        return;

    if (!PositionSelectByTicket(position.ticket))
        return;

    double point = SymbolInfoDouble(position.symbol, SYMBOL_POINT);

    // Lucro atual em pontos
    double profit_pts = (position.order_type == ORDER_BUY)
        ? (position.current_price - position.entry_price) / point
        : (position.entry_price - position.current_price) / point;

    // Aciona BE ao atingir gatilho
    if (m_default_config.enable_breakeven &&
        profit_pts >= m_default_config.breakeven_trigger_points)
    {
        double new_sl = (position.order_type == ORDER_BUY)
            ? position.entry_price + m_default_config.breakeven_level_points * point
            : position.entry_price - m_default_config.breakeven_level_points * point;

        // Só eleva (BUY) / só abaixa (SELL)
        if ((position.order_type == ORDER_BUY && (position.stop_loss == 0 || new_sl > position.stop_loss)) ||
            (position.order_type == ORDER_SELL && (position.stop_loss == 0 || new_sl < position.stop_loss)))
        {
            if (ModifyPositionStopLoss(position.ticket, new_sl))
            {
                position.stop_loss = new_sl;
                position.breakeven_level = new_sl;
                Print("✓ Breakeven aplicado: Ticket=", position.ticket,
                      " NovoSL=", new_sl, " (+", (int)profit_pts, " pts)");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Apply trailing stop - VERSÃO CORRIGIDA                          |
//+------------------------------------------------------------------+
void COrderManager::ApplyTrailingStop(SOrderPositionInfo &position)
{
    if (!position.trailing_enabled || position.state != POSITION_OPEN)
        return;

    if (!PositionSelectByTicket(position.ticket))
        return;

    double point = SymbolInfoDouble(position.symbol, SYMBOL_POINT);

    if (m_default_config.enable_trailing_stop && m_default_config.trailing_mode == TRAILING_FIXED)
    {
        // Exige BE acionado + buffer pós-BE
        double profit_pts = (position.order_type == ORDER_BUY)
            ? (position.current_price - position.entry_price) / point
            : (position.entry_price - position.current_price) / point;

        double start_pts = m_default_config.breakeven_trigger_points
                         + m_default_config.trailing_start_buffer_points; // ex.: 150

        if (profit_pts < start_pts)
            return; // ainda não traila

        // Nível alvo do SL pelo trailing
        double trail_sl = (position.order_type == ORDER_BUY)
            ? (position.current_price - m_default_config.trailing_distance_points * point)
            : (position.current_price + m_default_config.trailing_distance_points * point);

        // Histerese (step mínimo) em pontos
        double min_imp = m_default_config.minimum_improvement_points * point;

        // Piso do BE: nunca permitir que o trailing reduza abaixo do BE travado
        double be_floor = (position.order_type == ORDER_BUY)
            ? (position.entry_price + m_default_config.breakeven_level_points * point)
            : (position.entry_price - m_default_config.breakeven_level_points * point);

        if (position.order_type == ORDER_BUY)
        {
            trail_sl = MathMax(trail_sl, be_floor);
            if (position.stop_loss == 0 || trail_sl > position.stop_loss + min_imp)
            {
                double tick_size = SymbolInfoDouble(position.symbol, SYMBOL_TRADE_TICK_SIZE);
                int digits = (int)SymbolInfoInteger(position.symbol, SYMBOL_DIGITS);
                trail_sl = NormalizeDouble(MathRound(trail_sl / tick_size) * tick_size, digits);

                if (ModifyPositionStopLoss(position.ticket, trail_sl))
                {
                    position.stop_loss = trail_sl;
                    position.trailing_stop_level = trail_sl;
                    Print("✓ Trailing: Ticket=", position.ticket,
                          " NovoSL=", trail_sl,
                          " Dist=", (int)((position.current_price - trail_sl) / point), " pts",
                          " Lucro=", (int)profit_pts, " pts");
                }
            }
        }
        else // SELL
        {
            trail_sl = MathMin(trail_sl, be_floor);
            if (position.stop_loss == 0 || trail_sl < position.stop_loss - min_imp)
            {
                double tick_size = SymbolInfoDouble(position.symbol, SYMBOL_TRADE_TICK_SIZE);
                int digits = (int)SymbolInfoInteger(position.symbol, SYMBOL_DIGITS);
                trail_sl = NormalizeDouble(MathRound(trail_sl / tick_size) * tick_size, digits);

                if (ModifyPositionStopLoss(position.ticket, trail_sl))
                {
                    position.stop_loss = trail_sl;
                    position.trailing_stop_level = trail_sl;
                    Print("✓ Trailing: Ticket=", position.ticket,
                          " NovoSL=", trail_sl,
                          " Dist=", (int)((trail_sl - position.current_price) / point), " pts",
                          " Lucro=", (int)profit_pts, " pts");
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
double COrderManager::GetCurrentPrice(string symbol, ENUM_ORDER_DIRECTION direction)
{
    if (direction == ORDER_BUY)
        return SymbolInfoDouble(symbol, SYMBOL_BID);
    else
        return SymbolInfoDouble(symbol, SYMBOL_ASK);
}

//+------------------------------------------------------------------+
bool COrderManager::ModifyPositionStopLoss(ulong ticket, double new_stop_loss)
{
    if (!PositionSelectByTicket(ticket))
    {
        Print("ModifyPositionStopLoss: Position ", ticket, " does not exist");
        return false;
    }

    string symbol = PositionGetString(POSITION_SYMBOL);
    double current_sl = PositionGetDouble(POSITION_SL);
    double current_tp = PositionGetDouble(POSITION_TP);

    if (MathAbs(current_sl - new_stop_loss) < SymbolInfoDouble(symbol, SYMBOL_POINT))
    {
        return true;
    }

    MqlTradeRequest request = {};
    MqlTradeResult result = {};

    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = symbol;
    request.sl = new_stop_loss;
    request.tp = current_tp;

    if (!OrderSend(request, result))
    {
        Print("ModifyPositionStopLoss: OrderSend failed for ticket ", ticket, " Error: ", GetLastError());
        return false;
    }

    if (result.retcode != TRADE_RETCODE_DONE)
    {
        Print("ModifyPositionStopLoss: Failed with retcode ", result.retcode, " for ticket ", ticket);
        return false;
    }

    return true;
}

#endif // __ORDER_MANAGER_MQH__