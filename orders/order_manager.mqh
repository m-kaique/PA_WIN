#ifndef __ORDER_MANAGER_MQH__
#define __ORDER_MANAGER_MQH__

//+------------------------------------------------------------------+
//|                                                        order_manager.mqh |
//|  Centralized order management with risk controls and automation |
//+------------------------------------------------------------------+

#include <Trade\Trade.mqh>

#include "../utils/common_types.mqh"
#include "../interfaces/inetwork_client.mqh"
#include "../PROVIDER/provider.mqh"

//+------------------------------------------------------------------+
//| Estrutura com requisitos e configurações do sistema de ordens   |
//+------------------------------------------------------------------+
struct SOrderManagerSettings
{
   double risk_percent;                 // Risco padrão por ordem (em % do saldo)
   double max_total_risk_percent;       // Risco máximo agregado permitido
   double min_stop_loss_points;         // Distância mínima de SL em pontos
   double max_stop_loss_points;         // Distância máxima de SL em pontos
   double atr_period;                   // Período do ATR para trailing stop
   double atr_multiplier;               // Multiplicador aplicado ao ATR
   double break_even_trigger_points;    // Lucro em pontos para ativar break-even
   double break_even_offset_points;     // Offset aplicado ao mover para break-even
   bool   enable_break_even;            // Ativa gerenciamento de break-even
   bool   enable_trailing_stop;         // Ativa trailing stop baseado em ATR
   bool   enable_partial_closes;        // Ativa realização parcial
   double partial_close_levels_points[];// Níveis (pontos) para partial closes
   double partial_close_percents[];     // Percentual a ser fechado em cada nível
   double minimum_partial_volume;       // Volume mínimo permitido para partial close
   double maximum_volume;               // Volume máximo permitido para operações
   double minimum_volume;               // Volume mínimo permitido para operações
   double volume_step;                  // Incremento de volume permitido
   double slippage;                     // Desvio máximo em pontos para ordens
   int    magic_number;                 // Magic number para identificação
   ENUM_TIMEFRAMES atr_timeframe;       // Timeframe utilizado para ATR

   void Reset()
   {
      risk_percent = 1.0;
      max_total_risk_percent = 3.0;
      min_stop_loss_points = 200; // ~20 pips em símbolos com 5 dígitos
      max_stop_loss_points = 5000;
      atr_period = 14;
      atr_multiplier = 2.0;
      break_even_trigger_points = 400; // 40 pips
      break_even_offset_points = 50;
      enable_break_even = true;
      enable_trailing_stop = true;
      enable_partial_closes = false;
      ArrayResize(partial_close_levels_points, 0);
      ArrayResize(partial_close_percents, 0);
      minimum_partial_volume = 0.01;
      maximum_volume = 10.0;
      minimum_volume = 0.01;
      volume_step = 0.01;
      slippage = 5;
      magic_number = 0;
      atr_timeframe = PERIOD_CURRENT;
   }

   SOrderManagerSettings()
   {
      Reset();
   }
};

//+------------------------------------------------------------------+
//| Estado interno de posições gerenciadas                          |
//+------------------------------------------------------------------+
struct SManagedPositionState
{
   ulong ticket;
   int next_partial_index;
   bool break_even_applied;

   void Reset()
   {
      ticket = 0;
      next_partial_index = 0;
      break_even_applied = false;
   }

   SManagedPositionState()
   {
      Reset();
   }
};

//+------------------------------------------------------------------+
//| Resultado das execuções de ordens                               |
//+------------------------------------------------------------------+
struct SOrderExecutionResult
{
   bool success;
   ulong ticket;
   double volume;
   double price;
   string message;

   void Reset()
   {
      success = false;
      ticket = 0;
      volume = 0.0;
      price = 0.0;
      message = "";
   }

   SOrderExecutionResult()
   {
      Reset();
   }
};

//+------------------------------------------------------------------+
//| Order Manager central                                            |
//+------------------------------------------------------------------+
class COrderManager
{
private:
   CTrade            m_trade;
   SOrderManagerSettings m_settings;
   INetworkClient   *m_network_client;
   string            m_symbol;
   string            m_strategy_name;
   SManagedPositionState m_states[];

   int  FindStateIndex(ulong ticket);
   int  EnsureState(ulong ticket);
   void RemoveState(ulong ticket);
   void NotifyOrderEvent(string event_type, ulong ticket, double volume, double price, double sl, double tp, string details = "");
   double NormalizeVolume(double volume);
   double CalculateRiskPerLot(double stop_loss_price, double entry_price);
   double CalculateATR(string symbol, ENUM_TIMEFRAMES timeframe);
   bool  ApplyBreakEven(ulong ticket, ENUM_POSITION_TYPE type, double open_price, double current_price, double &sl, SManagedPositionState &state);
   bool  ApplyTrailingStop(ulong ticket, ENUM_POSITION_TYPE type, double atr_value, double current_price, double &sl);
   bool  ApplyPartialCloses(ulong ticket, ENUM_POSITION_TYPE type, double open_price, double current_price, double &volume);
   double CurrentPriceForType(ENUM_POSITION_TYPE type);
   double GetStopLossDistancePoints(double entry_price, double stop_loss);
   double CalculateExistingRiskPercent();

public:
   COrderManager();

   void SetNetworkClient(INetworkClient *client) { m_network_client = client; }
   void SetSymbol(string symbol) { m_symbol = symbol; }
   void SetStrategyName(string name) { m_strategy_name = name; }
   void Configure(const SOrderManagerSettings &settings);
   const SOrderManagerSettings &GetSettings() const { return m_settings; }

   // Execução de ordens
   SOrderExecutionResult OpenMarketOrder(ENUM_ORDER_TYPE order_type, double stop_loss_price, double take_profit_price, string comment = "", double requested_volume = 0.0);
   void UpdateOpenPositions(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT);
   bool HasOpenPositions() const;
};

//+------------------------------------------------------------------+
//| Implementação                                                    |
//+------------------------------------------------------------------+
COrderManager::COrderManager()
{
   m_network_client = NULL;
   m_symbol = Symbol();
   m_strategy_name = "";
   m_settings.Reset();
   ArrayResize(m_states, 0);
}

void COrderManager::Configure(const SOrderManagerSettings &settings)
{
   m_settings = settings;
   // Atualizar informações de volume com base no símbolo atual
   if (SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN) > 0)
      m_settings.minimum_volume = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
   if (SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX) > 0)
      m_settings.maximum_volume = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
   if (SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP) > 0)
      m_settings.volume_step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
}

int COrderManager::FindStateIndex(ulong ticket)
{
   for (int i = 0; i < ArraySize(m_states); i++)
   {
      if (m_states[i].ticket == ticket)
         return i;
   }
   return -1;
}

int COrderManager::EnsureState(ulong ticket)
{
   int index = FindStateIndex(ticket);
   if (index >= 0)
      return index;

   SManagedPositionState state;
   state.ticket = ticket;
   index = ArraySize(m_states);
   ArrayResize(m_states, index + 1);
   m_states[index] = state;
   return index;
}

void COrderManager::RemoveState(ulong ticket)
{
   int index = FindStateIndex(ticket);
   if (index < 0)
      return;

   for (int i = index; i < ArraySize(m_states) - 1; i++)
      m_states[i] = m_states[i + 1];
   ArrayResize(m_states, MathMax(0, ArraySize(m_states) - 1));
}

double COrderManager::NormalizeVolume(double volume)
{
   double normalized = volume;
   double step = m_settings.volume_step;
   if (step <= 0)
      step = 0.01;

   normalized = MathMax(normalized, m_settings.minimum_volume);
   normalized = MathMin(normalized, m_settings.maximum_volume);
   normalized = MathFloor(normalized / step + 0.0001) * step;
   normalized = NormalizeDouble(normalized, 2);
   return normalized;
}

double COrderManager::CalculateRiskPerLot(double stop_loss_price, double entry_price)
{
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   double tick_value = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);

   double distance = MathAbs(stop_loss_price - entry_price);
   if (distance <= 0.0 || tick_value <= 0.0 || tick_size <= 0.0)
      return 0.0;

   double ticks = distance / tick_size;
   double risk = ticks * tick_value;
   return risk;
}

double COrderManager::GetStopLossDistancePoints(double entry_price, double stop_loss)
{
   if (stop_loss <= 0 || entry_price <= 0)
      return 0.0;

   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   return MathAbs(entry_price - stop_loss) / point;
}

double COrderManager::CalculateExistingRiskPercent()
{
   double total_risk = 0.0;
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if (balance <= 0)
      return 0.0;

   int positions = PositionsTotal();
   for (int i = positions - 1; i >= 0; i--)
   {
      if (!PositionSelectByIndex(i))
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      if (symbol != m_symbol)
         continue;

      long magic = PositionGetInteger(POSITION_MAGIC);
      if (magic != m_settings.magic_number)
         continue;

      double volume = PositionGetDouble(POSITION_VOLUME);
      double sl = PositionGetDouble(POSITION_SL);
      double price_open = PositionGetDouble(POSITION_PRICE_OPEN);

      double risk_per_lot = CalculateRiskPerLot(sl, price_open);
      if (risk_per_lot <= 0)
         continue;

      double position_risk = risk_per_lot * volume;
      total_risk += (position_risk / balance) * 100.0;
   }

   return total_risk;
}

SOrderExecutionResult COrderManager::OpenMarketOrder(ENUM_ORDER_TYPE order_type, double stop_loss_price, double take_profit_price, string comment, double requested_volume)
{
   SOrderExecutionResult result;

   double price = (order_type == ORDER_TYPE_BUY || order_type == ORDER_TYPE_BUY_LIMIT || order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_BUY_STOP_LIMIT)
                  ? SymbolInfoDouble(m_symbol, SYMBOL_ASK)
                  : SymbolInfoDouble(m_symbol, SYMBOL_BID);

   if (price <= 0)
   {
      result.message = "Preço inválido para abertura";
      return result;
   }

   double stop_distance_points = GetStopLossDistancePoints(price, stop_loss_price);
   if (stop_distance_points <= 0)
   {
      result.message = "Stop loss inválido";
      return result;
   }

   if (stop_distance_points < m_settings.min_stop_loss_points || stop_distance_points > m_settings.max_stop_loss_points)
   {
      result.message = "Distância de stop fora dos limites";
      return result;
   }

   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_money = account_balance * (m_settings.risk_percent / 100.0);
   double risk_per_lot = CalculateRiskPerLot(stop_loss_price, price);
   if (risk_per_lot <= 0)
   {
      result.message = "Não foi possível calcular risco por lote";
      return result;
   }

   double volume = requested_volume;
   if (volume <= 0)
      volume = risk_money / risk_per_lot;

   volume = NormalizeVolume(volume);
   if (volume < m_settings.minimum_volume - (m_settings.volume_step / 2.0))
   {
      result.message = "Volume calculado menor que o mínimo";
      return result;
   }

   double projected_risk_percent = (risk_per_lot * volume) / account_balance * 100.0;
   double existing_risk = CalculateExistingRiskPercent();
   if (existing_risk + projected_risk_percent > m_settings.max_total_risk_percent + 0.0001)
   {
      result.message = "Limite de risco agregado excedido";
      return result;
   }

   m_trade.SetExpertMagicNumber(m_settings.magic_number);
   m_trade.SetDeviationInPoints((int)m_settings.slippage);

   bool order_sent = m_trade.PositionOpen(m_symbol, order_type, volume, price, stop_loss_price, take_profit_price, comment);
   if (!order_sent)
   {
      result.message = StringFormat("Falha ao abrir ordem: %d", GetLastError());
      return result;
   }

   ulong ticket = m_trade.ResultDeal();
   if (ticket == 0)
      ticket = m_trade.ResultOrder();

   result.success = true;
   result.ticket = ticket;
   result.volume = volume;
   result.price = price;
   result.message = "Ordem aberta com sucesso";

   if (ticket != 0)
      EnsureState(ticket);

   NotifyOrderEvent("open", ticket, volume, price, stop_loss_price, take_profit_price, comment);
   return result;
}

bool COrderManager::HasOpenPositions() const
{
   int positions = PositionsTotal();
   for (int i = positions - 1; i >= 0; i--)
   {
      if (!PositionSelectByIndex(i))
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      if (symbol != m_symbol)
         continue;

      long magic = PositionGetInteger(POSITION_MAGIC);
      if (magic != m_settings.magic_number)
         continue;

      return true;
   }
   return false;
}

double COrderManager::CurrentPriceForType(ENUM_POSITION_TYPE type)
{
   if (type == POSITION_TYPE_BUY)
      return SymbolInfoDouble(m_symbol, SYMBOL_BID);
   else
      return SymbolInfoDouble(m_symbol, SYMBOL_ASK);
}

double COrderManager::CalculateATR(string symbol, ENUM_TIMEFRAMES timeframe)
{
   if (timeframe == PERIOD_CURRENT)
      timeframe = (ENUM_TIMEFRAMES)Period();

   int handle = iATR(symbol, timeframe, (int)MathMax(1.0, m_settings.atr_period));
   if (handle == INVALID_HANDLE)
      return 0.0;

   double values[];
   if (CopyBuffer(handle, 0, 0, 2, values) <= 0)
   {
      IndicatorRelease(handle);
      return 0.0;
   }

   IndicatorRelease(handle);
   return values[0];
}

bool COrderManager::ApplyBreakEven(ulong ticket, ENUM_POSITION_TYPE type, double open_price, double current_price, double &sl, SManagedPositionState &state)
{
   if (!m_settings.enable_break_even)
      return false;

   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   double profit_points = (type == POSITION_TYPE_BUY)
                          ? (current_price - open_price) / point
                          : (open_price - current_price) / point;

   if (profit_points < m_settings.break_even_trigger_points || state.break_even_applied)
      return false;

   double break_even_price = open_price;
   if (m_settings.break_even_offset_points > 0)
   {
      double offset = m_settings.break_even_offset_points * point;
      break_even_price = (type == POSITION_TYPE_BUY) ? open_price + offset : open_price - offset;
   }

   if ((type == POSITION_TYPE_BUY && sl < break_even_price) || (type == POSITION_TYPE_SELL && sl > break_even_price) || sl == 0.0)
   {
      sl = break_even_price;
      state.break_even_applied = true;
      return true;
   }

   return false;
}

bool COrderManager::ApplyTrailingStop(ulong ticket, ENUM_POSITION_TYPE type, double atr_value, double current_price, double &sl)
{
   if (!m_settings.enable_trailing_stop)
      return false;

   if (atr_value <= 0)
      return false;

   double trailing_distance = atr_value * m_settings.atr_multiplier;
   double new_sl = (type == POSITION_TYPE_BUY)
                   ? current_price - trailing_distance
                   : current_price + trailing_distance;

    if ((type == POSITION_TYPE_BUY && (sl == 0.0 || new_sl > sl)) ||
        (type == POSITION_TYPE_SELL && (sl == 0.0 || new_sl < sl)))
    {
       sl = new_sl;
       return true;
    }
   return false;
}

bool COrderManager::ApplyPartialCloses(ulong ticket, ENUM_POSITION_TYPE type, double open_price, double current_price, double &volume)
{
   if (!m_settings.enable_partial_closes)
      return false;

   int index = EnsureState(ticket);
   if (index < 0)
      return false;

   if (m_states[index].next_partial_index >= ArraySize(m_settings.partial_close_levels_points) ||
       m_states[index].next_partial_index >= ArraySize(m_settings.partial_close_percents))
      return false;

   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   double profit_points = (type == POSITION_TYPE_BUY)
                          ? (current_price - open_price) / point
                          : (open_price - current_price) / point;

   double target_points = m_settings.partial_close_levels_points[m_states[index].next_partial_index];
   if (profit_points < target_points)
      return false;

   double percent = m_settings.partial_close_percents[m_states[index].next_partial_index];
   double volume_to_close = NormalizeVolume(volume * percent);
   if (volume_to_close < m_settings.minimum_partial_volume)
      return false;

   if (!m_trade.PositionClosePartial(m_symbol, volume_to_close))
   {
      Print("Falha ao realizar partial close para ticket ", ticket, ": ", GetLastError());
      return false;
   }

   volume -= volume_to_close;
   m_states[index].next_partial_index++;
   NotifyOrderEvent("partial_close", ticket, volume_to_close, current_price, PositionGetDouble(POSITION_SL), PositionGetDouble(POSITION_TP), "Partial close executado");
   return true;
}

void COrderManager::UpdateOpenPositions(ENUM_TIMEFRAMES timeframe)
{
   int positions = PositionsTotal();
   double atr_value = 0.0;

   if (positions <= 0)
   {
      ArrayResize(m_states, 0);
      return;
   }

   for (int i = positions - 1; i >= 0; i--)
   {
      if (!PositionSelectByIndex(i))
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      if (symbol != m_symbol)
         continue;

      long magic = PositionGetInteger(POSITION_MAGIC);
      if (magic != m_settings.magic_number)
         continue;

      ulong ticket = PositionGetInteger(POSITION_TICKET);
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double volume = PositionGetDouble(POSITION_VOLUME);
      int state_index = EnsureState(ticket);

      double current_price = CurrentPriceForType(type);
      if (current_price <= 0)
         continue;

      bool modified = false;
      bool break_even_applied = false;
      bool trailing_applied = false;
      bool requires_modify = false;

      if (m_settings.enable_break_even)
      {
         if (state_index >= 0 && ApplyBreakEven(ticket, type, open_price, current_price, sl, m_states[state_index]))
         {
            modified = true;
            requires_modify = true;
            break_even_applied = true;
         }
      }

      if (m_settings.enable_trailing_stop)
      {
         if (atr_value == 0.0)
            atr_value = CalculateATR(m_symbol, (m_settings.atr_timeframe == PERIOD_CURRENT) ? timeframe : m_settings.atr_timeframe);

         if (atr_value > 0 && ApplyTrailingStop(ticket, type, atr_value, current_price, sl))
         {
            modified = true;
            requires_modify = true;
            trailing_applied = true;
         }
      }

      if (m_settings.enable_partial_closes)
      {
         if (ApplyPartialCloses(ticket, type, open_price, current_price, volume))
            modified = true;
      }

      if (modified && requires_modify)
      {
         if (!m_trade.PositionModify(m_symbol, sl, tp))
         {
            Print("Falha ao modificar posição ", ticket, ": ", GetLastError());
         }
         else
         {
            if (break_even_applied)
               NotifyOrderEvent("break_even", ticket, volume, current_price, sl, tp, "Break-even aplicado");
            if (trailing_applied)
               NotifyOrderEvent("trailing", ticket, volume, current_price, sl, tp, "Trailing stop ajustado");
         }
      }
   }

   // Remover estados de posições que já foram encerradas
   for (int idx = ArraySize(m_states) - 1; idx >= 0; idx--)
   {
      ulong ticket = m_states[idx].ticket;
      if (!PositionSelectByTicket(ticket))
         RemoveState(ticket);
   }
}

void COrderManager::NotifyOrderEvent(string event_type, ulong ticket, double volume, double price, double sl, double tp, string details)
{
   CJAVal payload;
   payload["type"] = "order";
   payload["event"] = event_type;
   payload["strategy"] = m_strategy_name;
   payload["symbol"] = m_symbol;
   payload["ticket"] = (long)ticket;
   payload["volume"] = volume;
   payload["price"] = price;
   payload["sl"] = sl;
   payload["tp"] = tp;
   payload["details"] = details;
   payload["timestamp"] = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);

   string json = payload.Serialize();

   if (m_network_client != NULL)
   {
      if (!m_network_client.SendJson(json))
         Print("Falha ao enviar evento de ordem pela interface de rede");
   }
   else
   {
      FrancisSocketSend(json);
   }
}

#endif // __ORDER_MANAGER_MQH__
