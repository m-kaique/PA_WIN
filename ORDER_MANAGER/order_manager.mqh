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
    Print("  Trailing: ", (position_info.trailing_enabled ? "ATIVO (20 pts)" : "INATIVO"));
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

    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    
    // Distância do SL em pontos
    double stop_loss_distance = m_default_config.stop_loss_pips * point * 10;
    
    // Calcular Stop Loss
    if (signal.type == SIGNAL_BUY)
    {
        stop_loss = signal.entry_price - stop_loss_distance;
    }
    else
    {
        stop_loss = signal.entry_price + stop_loss_distance;
    }
    
    // Normalizar SL ao tick size
    stop_loss = NormalizeDouble(MathRound(stop_loss / tick_size) * tick_size, digits);
    
    // Take Profit: se for 0, não define TP (deixa rolar com trailing)
    if (m_default_config.take_profit_points > 0)
    {
        double take_profit_distance = m_default_config.take_profit_points * point;
        
        if (signal.type == SIGNAL_BUY)
            take_profit = signal.entry_price + take_profit_distance;
        else
            take_profit = signal.entry_price - take_profit_distance;
            
        take_profit = NormalizeDouble(MathRound(take_profit / tick_size) * tick_size, digits);
        
        Print("Order params: Vol=", lot_size, " Entry=", signal.entry_price, 
              " SL=", stop_loss, " (", (int)(stop_loss_distance/point), " pts)",
              " TP=", take_profit, " (", (int)(MathAbs(take_profit - signal.entry_price)/point), " pts)");
    }
    else
    {
        take_profit = 0.0; // SEM TP - deixa rolar com trailing
        
        Print("Order params: Vol=", lot_size, " Entry=", signal.entry_price, 
              " SL=", stop_loss, " (", (int)(stop_loss_distance/point), " pts)",
              " TP=SEM (Trailing apenas)");
    }

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

    double current_price = position.current_price;
    double entry_price = position.entry_price;
    double current_stop = position.stop_loss;
    
    double point = SymbolInfoDouble(position.symbol, SYMBOL_POINT);
    
    double breakeven_trigger = m_default_config.breakeven_trigger_points * point;
    double breakeven_level = m_default_config.breakeven_level_points * point;

    double new_stop_loss = 0.0;
    double profit_points = 0.0;

    if (position.order_type == ORDER_BUY)
    {
        profit_points = (current_price - entry_price) / point;
        
        if (profit_points >= m_default_config.breakeven_trigger_points && 
            current_stop < entry_price + breakeven_level)
        {
            new_stop_loss = entry_price + breakeven_level;
            Print("BUY - Lucro: ", (int)profit_points, " pts. Movendo para breakeven.");
        }
    }
    else
    {
        profit_points = (entry_price - current_price) / point;
        
        if (profit_points >= m_default_config.breakeven_trigger_points && 
            current_stop > entry_price - breakeven_level)
        {
            new_stop_loss = entry_price - breakeven_level;
            Print("SELL - Lucro: ", (int)profit_points, " pts. Movendo para breakeven.");
        }
    }

    if (new_stop_loss != 0.0 && new_stop_loss != current_stop)
    {
        if (ModifyPositionStopLoss(position.ticket, new_stop_loss))
        {
            position.stop_loss = new_stop_loss;
            position.breakeven_level = new_stop_loss;
            Print("✓ Breakeven aplicado: Ticket=", position.ticket, 
                  " NovoSL=", new_stop_loss, " (+", (int)profit_points, " pts)");
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

    double current_price = position.current_price;
    double current_stop = position.stop_loss;
    double point = SymbolInfoDouble(position.symbol, SYMBOL_POINT);
    
    // Distância fixa de 20 pontos
    double trail_distance = m_default_config.trailing_distance_points * point;

    double new_stop_loss = 0.0;
    double profit_points = 0.0;

    if (position.order_type == ORDER_BUY)
    {
        profit_points = (current_price - position.entry_price) / point;
        double trail_level = current_price - trail_distance;
        
        // CORREÇÃO: só move se o novo stop for pelo menos X pontos melhor que o atual
        // Isso evita saltos grandes logo após o breakeven
        double minimum_improvement = 10.0 * point; // Melhoria mínima de 10 pontos
        
        if (trail_level > (current_stop + minimum_improvement))
        {
            new_stop_loss = trail_level;
        }
    }
    else
    {
        profit_points = (position.entry_price - current_price) / point;
        double trail_level = current_price + trail_distance;
        
        double minimum_improvement = 10.0 * point;
        
        if (trail_level < (current_stop - minimum_improvement))
        {
            new_stop_loss = trail_level;
        }
    }

    if (new_stop_loss != 0.0 && new_stop_loss != current_stop)
    {
        double tick_size = SymbolInfoDouble(position.symbol, SYMBOL_TRADE_TICK_SIZE);
        int digits = (int)SymbolInfoInteger(position.symbol, SYMBOL_DIGITS);
        new_stop_loss = NormalizeDouble(MathRound(new_stop_loss / tick_size) * tick_size, digits);
        
        if (ModifyPositionStopLoss(position.ticket, new_stop_loss))
        {
            double stop_distance = 0.0;
            if (position.order_type == ORDER_BUY)
                stop_distance = (current_price - new_stop_loss) / point;
            else
                stop_distance = (new_stop_loss - current_price) / point;
                
            position.stop_loss = new_stop_loss;
            position.trailing_stop_level = new_stop_loss;
            Print("✓ Trailing: Ticket=", position.ticket, 
                  " NovoSL=", new_stop_loss, 
                  " Dist=", (int)stop_distance, " pts",
                  " Lucro=", (int)profit_points, " pts");
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