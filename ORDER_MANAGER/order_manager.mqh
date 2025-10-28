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

    // Temporary storage for partials config
    bool m_enable_partials_local;

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
    void CheckPartials(SOrderPositionInfo &position);
    double GetCurrentPrice(string symbol, ENUM_ORDER_DIRECTION direction);
    bool ModifyPositionStopLoss(ulong ticket, double new_stop_loss);
    bool PositionClosePartial(ulong ticket, double volume);

    // Utility functions for SL validation
    double MinDistPts(string symbol);
    double ToTick(string symbol, double price);
    bool BuildValidSL(string symbol, bool is_buy, double &sl_target);

    // Advanced trailing functions
    double CalculateATR(string symbol, int period, int shift = 0);
    double CalculateSwingHigh(string symbol, int lookback, int shift = 0);
    double CalculateSwingLow(string symbol, int lookback, int shift = 0);
    double CalculateChandelierSL(string symbol, bool is_buy, int atr_period, double atr_mult, int swing_lookback);

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

        // Sempre aplicar breakeven se habilitado e ainda não acionado
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

        // Sempre aplicar trailing se habilitado (independente do breakeven)
        if (m_positions[i].trailing_enabled)
        {
            ApplyTrailingStop(m_positions[i]);

            if (!PositionSelectByTicket(m_positions[i].ticket))
            {
                Print("Position ", m_positions[i].ticket, " closed after trailing stop. Removing from tracking.");
                RemovePosition(i);
                continue;
            }
        }

        // Verificar parciais
        CheckPartials(m_positions[i]);

        if (!PositionSelectByTicket(m_positions[i].ticket))
        {
            Print("Position ", m_positions[i].ticket, " closed after partial close. Removing from tracking.");
            RemovePosition(i);
            continue;
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

    // Parciais
    position_info.enable_partials_local = m_enable_partials_local;
    position_info.initial_volume = lot_size;

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
    const double min_volume  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    const double max_volume  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    const double vol_step    = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    const double point       = SymbolInfoDouble(symbol, SYMBOL_POINT);
    const int    digits      = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

    // --------- VOLUME (manual pelo SOrderConfig) ----------
    double vol = min_volume; // fallback
    if (m_default_config.volume_mode == VOLUME_FIXED && m_default_config.fixed_volume_lots > 0.0)
        vol = m_default_config.fixed_volume_lots;

    // normalizar para step/min/max
    vol = MathFloor(vol / vol_step) * vol_step;
    vol = MathMax(min_volume, MathMin(vol, max_volume));
    lot_size = vol;

    // Gate de parciais
    bool enable_partials_local = m_default_config.enable_partials;
    int lots = (int)lot_size;
    if (enable_partials_local && lots < m_default_config.min_lots_for_partials){
        if (m_default_config.scale_up_to_enable_partials)
            lots = m_default_config.min_lots_for_partials;  // aumenta lotes (aceita maior risco)
        else
            enable_partials_local = false;                  // desabilita parciais neste trade
    }

    // Store for later use in OpenMarketOrder
    m_enable_partials_local = enable_partials_local;

    const double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    const long   stops_lvl = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
    const long   freeze_lv = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);

    // --------- STOP/TP em PONTOS ----------
    const double sl_dist = m_default_config.stop_loss_points * point;

    if (signal.type == SIGNAL_BUY)
        stop_loss = signal.entry_price - sl_dist;
    else
        stop_loss = signal.entry_price + sl_dist;

    // TP opcional (0 = sem TP → trailing apenas)
    if (m_default_config.take_profit_points > 0.0)
    {
        const double tp_dist = m_default_config.take_profit_points * point;
        take_profit = (signal.type == SIGNAL_BUY)
                      ? signal.entry_price + tp_dist
                      : signal.entry_price - tp_dist;
    }
    else
    {
        take_profit = 0.0;
    }

    // Logs úteis
    const int sl_pts = (int)(m_default_config.stop_loss_points);
    if (take_profit > 0.0)
    {
        const int tp_pts = (int)(m_default_config.take_profit_points);
        Print("Order params: Vol=", lot_size, " Entry=", signal.entry_price,
              " SL=", stop_loss, " (", sl_pts, " pts)",
              " TP=", take_profit, " (", tp_pts, " pts)");
    }
    else
    {
        Print("Order params: Vol=", lot_size, " Entry=", signal.entry_price,
              " SL=", stop_loss, " (", sl_pts, " pts)",
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

    double point = SymbolInfoDouble(position.symbol, SYMBOL_POINT);

    // Lucro atual em pontos
    double profit_pts = (position.order_type == ORDER_BUY)
        ? (position.current_price - position.entry_price) / point
        : (position.entry_price - position.current_price) / point;

    // Aciona BE ao atingir gatilho
    if (m_default_config.enable_breakeven &&
        profit_pts >= m_default_config.m_be_trigger_pts)
    {
        double new_sl = (position.order_type == ORDER_BUY)
            ? position.entry_price + m_default_config.m_be_offset_pts * point
            : position.entry_price - m_default_config.m_be_offset_pts * point;

        // Só eleva (BUY) / só abaixa (SELL)
        if ((position.order_type == ORDER_BUY && (position.stop_loss == 0 || new_sl > position.stop_loss)) ||
            (position.order_type == ORDER_SELL && (position.stop_loss == 0 || new_sl < position.stop_loss)))
        {
            bool is_buy = (position.order_type == ORDER_BUY);
            if (BuildValidSL(position.symbol, is_buy, new_sl))
            {
                if (ModifyPositionStopLoss(position.ticket, new_sl))
                {
                    position.stop_loss = new_sl;
                    position.breakeven_level = new_sl;
                    position.trailed_once = false; // reset trailing state
                    position.last_trail_time = TimeCurrent();
                    Print("✓ Breakeven aplicado: Ticket=", position.ticket,
                          " NovoSL=", new_sl, " (+", (int)profit_pts, " pts)");
                }
            }
            else
            {
                Print("⚠ Breakeven cancelado - SL inválido: Ticket=", position.ticket,
                      " SL=", new_sl, " Profit=", (int)profit_pts, " pts");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check partial closes                                              |
//+------------------------------------------------------------------+
void COrderManager::CheckPartials(SOrderPositionInfo &position)
{
    if(!position.enable_partials_local) return;
    int remaining = (int)position.lot_size; // WIN: inteiro

    if (!PositionSelectByTicket(position.ticket))
        return;

    double point = SymbolInfoDouble(position.symbol, SYMBOL_POINT);
    int profit_pts = (position.order_type == ORDER_BUY)
        ? (int)((position.current_price - position.entry_price)/point)
        : (int)((position.entry_price - position.current_price)/point);

    for(int i=0; i<m_default_config.partial_count; i++){
        if(position.partials_closed[i]) continue;
        SOrderPartial p = m_default_config.partials[i];
        if(p.percent<=0 || p.target_points<=0) continue;

        if(profit_pts >= p.target_points){
            int close_lots = (int)MathRound((double)position.initial_volume * (p.percent>1? p.percent/100.0 : p.percent));
            close_lots = MathMax(1, MathMin(close_lots, remaining-1)); // nunca zera tudo aqui
            if(close_lots <= 0) continue;

            if(PositionClosePartial(position.ticket, close_lots)){
                position.lot_size -= close_lots;
                remaining -= close_lots;
                position.partials_closed[i] = true;
                position.last_update = TimeCurrent(); // update timestamp for cooldown
                PrintFormat("✓ Parcial %d: fechou %d lotes @ +%d pts (restam %d)",
                            i+1, close_lots, p.target_points, remaining);
                if(remaining<=1) break; // sem mais parciais úteis
            }
        }
    }

    // FIX: NUNCA desligar trailing no último lote
    if (PositionSelectByTicket(position.ticket))
    {
        const double vol = PositionGetDouble(POSITION_VOLUME);
        const double vol_min = SymbolInfoDouble(position.symbol, SYMBOL_VOLUME_MIN);

        // Se restou 1 volume (ou volume mínimo), trailing continua habilitado
        if (vol <= vol_min + 1e-8)
            position.trailing_enabled = true; // garantir
    }
}

//+------------------------------------------------------------------+
//| Position close partial                                            |
//+------------------------------------------------------------------+
bool COrderManager::PositionClosePartial(ulong ticket, double volume)
{
    if (!PositionSelectByTicket(ticket))
        return false;

    string symbol = PositionGetString(POSITION_SYMBOL);
    long type = PositionGetInteger(POSITION_TYPE);
    double price = (type == POSITION_TYPE_BUY)
        ? SymbolInfoDouble(symbol, SYMBOL_BID)
        : SymbolInfoDouble(symbol, SYMBOL_ASK);

    MqlTradeRequest req = {};
    MqlTradeResult res = {};

    req.action = TRADE_ACTION_DEAL;
    req.symbol = symbol;
    req.volume = volume; // WIN: volume em lotes inteiros
    req.type = (type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    req.price = price;
    req.deviation = 10;
    req.comment = "Partial Close";

    if (!OrderSend(req, res))
    {
        PrintFormat("Partial close failed: %d", _LastError);
        return false;
    }

    return (res.retcode == TRADE_RETCODE_DONE);
}

//+------------------------------------------------------------------+
//| Utility functions for SL validation                              |
//+------------------------------------------------------------------+
double COrderManager::MinDistPts(string symbol)
{
    int stops_lvl = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
    int freeze_lvl = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
    return (double)MathMax(stops_lvl, freeze_lvl);
}

double COrderManager::ToTick(string symbol, double price)
{
    double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    return MathRound(price / tick_size) * tick_size;
}

bool COrderManager::BuildValidSL(string symbol, bool is_buy, double &sl_target)
{
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double min_dist = MinDistPts(symbol) * point;

    if(is_buy)
    {
        double max_sl = bid - min_dist;
        if(sl_target >= max_sl)
            sl_target = max_sl - tick_size;
    }
    else
    {
        double min_sl = ask + min_dist;
        if(sl_target <= min_sl)
            sl_target = min_sl + tick_size;
    }

    sl_target = ToTick(symbol, NormalizeDouble(sl_target, digits));

    if(is_buy)  return (sl_target < bid - min_dist);
    else        return (sl_target > ask + min_dist);
}

//+------------------------------------------------------------------+
//| Advanced trailing calculations                                   |
//+------------------------------------------------------------------+
double COrderManager::CalculateATR(string symbol, int period, int shift = 0)
{
    double atr_values[];
    ArraySetAsSeries(atr_values, true);

    if(CopyBuffer(iATR(symbol, PERIOD_CURRENT, period), 0, shift, 1, atr_values) <= 0)
        return 0.0;

    return atr_values[0];
}

double COrderManager::CalculateSwingHigh(string symbol, int lookback, int shift = 0)
{
    double highs[];
    ArraySetAsSeries(highs, true);

    if(CopyHigh(symbol, PERIOD_CURRENT, shift, lookback, highs) <= 0)
        return 0.0;

    double swing_high = highs[0];
    for(int i = 1; i < lookback; i++)
        swing_high = MathMax(swing_high, highs[i]);

    return swing_high;
}

double COrderManager::CalculateSwingLow(string symbol, int lookback, int shift = 0)
{
    double lows[];
    ArraySetAsSeries(lows, true);

    if(CopyLow(symbol, PERIOD_CURRENT, shift, lookback, lows) <= 0)
        return 0.0;

    double swing_low = lows[0];
    for(int i = 1; i < lookback; i++)
        swing_low = MathMin(swing_low, lows[i]);

    return swing_low;
}

double COrderManager::CalculateChandelierSL(string symbol, bool is_buy, int atr_period, double atr_mult, int swing_lookback)
{
    double atr = CalculateATR(symbol, atr_period);
    if(atr <= 0) return 0.0;

    double chandelier_sl;
    if(is_buy)
    {
        double swing_high = CalculateSwingHigh(symbol, swing_lookback);
        chandelier_sl = swing_high - (atr * atr_mult);
    }
    else
    {
        double swing_low = CalculateSwingLow(symbol, swing_lookback);
        chandelier_sl = swing_low + (atr * atr_mult);
    }

    return chandelier_sl;
}

//+------------------------------------------------------------------+
//| Apply trailing stop - VERSÃO CORRIGIDA COM FIX PARA ÚLTIMA PARCIAL |
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
        // FIX: gating simples independente de parciais
        const string symbol = position.symbol;
        const bool is_buy = (position.order_type == ORDER_BUY);
        const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

        // Verificar se é a última parcial (volume mínimo)
        const double vol = PositionGetDouble(POSITION_VOLUME);
        const double vol_min = SymbolInfoDouble(position.symbol, SYMBOL_VOLUME_MIN);
        const bool is_last_partial = (vol <= vol_min + 1e-8);

        // DEBUG: Log do estado atual (só uma vez por minuto para não poluir)
        static datetime last_debug_time = 0;
        if (TimeCurrent() - last_debug_time >= 60)
        {
            PrintFormat("TRAILING DEBUG: Ticket=%llu, Vol=%.2f, VolMin=%.2f, IsLastPartial=%s, BE_Level=%.5f",
                        position.ticket, vol, vol_min, is_last_partial ? "TRUE" : "FALSE", position.breakeven_level);
            last_debug_time = TimeCurrent();
        }

        // Opcional: buffer de início pós-BE (só para parciais intermediárias)
        if (!is_last_partial && m_default_config.enable_breakeven && position.breakeven_level > 0)
        {
            const double price = is_buy ? SymbolInfoDouble(symbol, SYMBOL_BID)
                                        : SymbolInfoDouble(symbol, SYMBOL_ASK);
            const double profit_pts = (is_buy ? price - position.breakeven_level
                                              : position.breakeven_level - price) / point;
            if (profit_pts < m_default_config.trailing_start_buffer_points)
            {
                PrintFormat("TRAILING DEBUG: Buffer BE não atingido (%.0f < %.0f pts)", profit_pts, m_default_config.trailing_start_buffer_points);
                return;
            }
        }

        // Cooldown configurável baseado no último evento
        int cooldown_seconds = 0;

        // Determinar qual cooldown usar baseado no último evento
        if (position.last_update > position.last_trail_time)
        {
            // Último evento foi uma atualização geral (possivelmente parcial)
            cooldown_seconds = m_default_config.m_cooldown_after_partial_sec;
        }
        else if (position.breakeven_level > 0 && position.last_trail_time == 0)
        {
            // Breakeven foi acionado mas trailing ainda não
            cooldown_seconds = m_default_config.m_cooldown_after_be_sec;
        }
        else
        {
            // Cooldown geral do trailing
            cooldown_seconds = m_default_config.m_trail_cooldown_sec;
        }

        if (cooldown_seconds > 0 &&
            (TimeCurrent() - position.last_trail_attempt) < cooldown_seconds)
        {
            PrintFormat("TRAILING DEBUG: Cooldown ativo (%d seg restantes, tipo: %s)",
                        cooldown_seconds - (TimeCurrent() - position.last_trail_attempt),
                        cooldown_seconds == m_default_config.m_cooldown_after_partial_sec ? "após parcial" :
                        cooldown_seconds == m_default_config.m_cooldown_after_be_sec ? "após BE" : "geral");
            position.last_trail_attempt = TimeCurrent(); // atualizar tentativa mesmo no cooldown
            return;
        }

        // FIX: cálculo do SL sem depender de parciais
        double new_sl;

        if (is_last_partial)
        {
            // ÚLTIMA PARCIAL: manter trailing DINÂMICO (Chandelier)
            double chandelier_sl = CalculateChandelierSL(symbol, is_buy,
                                                        m_default_config.m_atr_period,
                                                        m_default_config.m_atr_mult,
                                                        m_default_config.m_swing_lookback);

            PrintFormat("TRAILING DEBUG: Chandelier SL calculado = %.5f", chandelier_sl);
            if(chandelier_sl <= 0)
            {
                Print("TRAILING DEBUG: Chandelier SL inválido, abortando");
                return; // erro no cálculo
            }
            new_sl = chandelier_sl;
        }
        else
        {
            // PARCIAIS INTERMEDIÁRIAS: trailing FIXO (distância fixa)
            const double price = is_buy ? SymbolInfoDouble(symbol, SYMBOL_BID)
                                        : SymbolInfoDouble(symbol, SYMBOL_ASK);
            const double dist = m_default_config.trailing_distance_points * point;
            new_sl = is_buy ? (price - dist) : (price + dist);
            PrintFormat("TRAILING DEBUG: Trailing fixo calculado = %.5f (preço=%.5f, dist=%.0f pts)", new_sl, price, m_default_config.trailing_distance_points);
        }

        // Piso no BE se houver
        if (position.breakeven_level > 0)
            new_sl = is_buy ? MathMax(new_sl, position.breakeven_level)
                            : MathMin(new_sl, position.breakeven_level);

        // Histerese: só move se melhorar ao menos X pontos
        double current_sl = PositionGetDouble(POSITION_SL);
        PrintFormat("TRAILING DEBUG: Current SL = %.5f, New SL = %.5f", current_sl, new_sl);

        if (current_sl > 0)
        {
            const double min_imp = m_default_config.minimum_improvement_points * point;
            bool should_move = true;

            if (is_buy && new_sl <= current_sl + min_imp)
            {
                PrintFormat("TRAILING DEBUG: Histerese BUY não atingida (%.5f <= %.5f + %.5f)", new_sl, current_sl, min_imp);
                should_move = false;
            }
            if (!is_buy && new_sl >= current_sl - min_imp)
            {
                PrintFormat("TRAILING DEBUG: Histerese SELL não atingida (%.5f >= %.5f - %.5f)", new_sl, current_sl, min_imp);
                should_move = false;
            }

            if (!should_move) return;
        }

        // Normaliza SL e aplica
        PrintFormat("TRAILING DEBUG: Tentando aplicar SL = %.5f", new_sl);
        if (!BuildValidSL(symbol, is_buy, new_sl))
        {
            Print("TRAILING DEBUG: BuildValidSL falhou");
            return;
        }

        if (ModifyPositionStopLoss(position.ticket, new_sl))
        {
            position.stop_loss = new_sl;
            position.trailing_stop_level = new_sl;
            position.trailed_once = true;
            position.last_trail_time = TimeCurrent();
            position.last_update = TimeCurrent();
            position.last_trail_attempt = TimeCurrent(); // sucesso = reset cooldown

            double profit_pts = (position.order_type == ORDER_BUY)
                ? (position.current_price - position.entry_price) / point
                : (position.entry_price - position.current_price) / point;

            string trail_type = is_last_partial ? "Dinâmico (Última Parcial)" : "Fixo (Intermediária)";
            Print("✓ Trailing ", trail_type, ": Ticket=", position.ticket,
                  " NovoSL=", new_sl,
                  " Lucro=", (int)profit_pts, " pts");
        }
        else
        {
            Print("TRAILING DEBUG: ModifyPositionStopLoss falhou");
            position.last_trail_attempt = TimeCurrent(); // falha = ainda conta para cooldown
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
        // Detailed logging for debugging
        double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
        double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
        int stops_lvl = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
        int freeze_lvl = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
        double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);

        Print("ModifyPositionStopLoss: Failed with retcode ", result.retcode, " for ticket ", ticket);
        Print("  Debug Info: Bid=", bid, " Ask=", ask, " StopsLevel=", stops_lvl,
              " FreezeLevel=", freeze_lvl, " TickSize=", tick_size, " SL_Target=", new_stop_loss);
        return false;
    }

    return true;
}

#endif // __ORDER_MANAGER_MQH__