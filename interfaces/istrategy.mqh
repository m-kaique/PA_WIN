#ifndef __ISTRATEGY_MQH__
#define __ISTRATEGY_MQH__

// Include necessary types
#include "../STRATEGIES/strategies/strategy_base/strategy_base.mqh"

// Forward declarations
class CStrategyConfig;
struct SStrategySignal;

//+------------------------------------------------------------------+
//| Interface for trading strategies                                |
//+------------------------------------------------------------------+
interface IStrategy
{
public:
    // Initialize strategy with configuration
    virtual bool Init(string name, CStrategyConfig *config) = 0;

    // Update strategy state
    virtual bool Update() = 0;

    // Check for trading signals
    virtual SStrategySignal CheckForSignal() = 0;

    // Get strategy properties
    virtual bool IsEnabled() const = 0;
    virtual string GetName() const = 0;
    virtual ENUM_STRATEGY_STATE GetState() const = 0;
};

#endif // __ISTRATEGY_MQH__