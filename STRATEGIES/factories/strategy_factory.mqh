#ifndef __PA_STRATEGY_FACTORY_MQH__
#define __PA_STRATEGY_FACTORY_MQH__

#include "../strategies/emas_bull_buy/emas_bull_buy.mqh"

typedef CStrategyBase *(*CStrategyCreatorFunc)(CStrategyBase *config);

class CStrategyFactory
{
   private:
   public:
}
#endif