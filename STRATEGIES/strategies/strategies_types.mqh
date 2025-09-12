#ifndef __STRATEGIES_TYPES_MQH__
#define __STRATEGIES_TYPES_MQH__

#include "emas_bull_buy/emas_bull_buy_defs.mqh"

//--- Base configuraton
class CStrategyConfig
{
public:
   string name;
   string type;
   bool enabled;
   virtual ~CStrategyConfig() {}
};

class CEmasBullBuy : public CStrategyConfig
{
   CEmasBullBuy() {}
};

#endif