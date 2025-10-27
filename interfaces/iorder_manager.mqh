#ifndef __IORDER_MANAGER_MQH__
#define __IORDER_MANAGER_MQH__

#include "../STRATEGIES/strategies/strategy_base/strategy_base.mqh"
#include "../ORDER_MANAGER/order_types.mqh"

//+------------------------------------------------------------------+
//| Interface for Order Manager                                      |
//+------------------------------------------------------------------+
interface IOrderManager
{
public:
    // Initialize order manager
    virtual bool Init() = 0;

    // Process strategy signal and open position if valid
    virtual bool ProcessSignal(const SStrategySignal &signal, string strategy_name, string symbol, ENUM_TIMEFRAMES timeframe) = 0;

    // Update existing positions (breakeven, trailing stop)
    virtual bool UpdatePositions() = 0;

    // Close position for a specific strategy
    virtual bool ClosePosition(string strategy_name) = 0;

    // Get position information
    virtual bool GetPositionInfo(string strategy_name, SOrderPositionInfo &info) = 0;

    // Check if strategy has active position
    virtual bool HasActivePosition(string strategy_name) = 0;

    // Get all active positions
    virtual int GetActivePositions(string &strategy_names[]) = 0;

    // Cleanup resources
    virtual void Cleanup() = 0;
};

#endif // __IORDER_MANAGER_MQH__