#ifndef __STRATEGIES_TYPES_MQH__
#define __STRATEGIES_TYPES_MQH__

//--- Base configuraton
class CStrategyConfig
{
public:
   string name;
   string type;
   bool enabled;
   virtual ~CStrategyConfig() {}
};

class CEmasBullBuyConfig : public CStrategyConfig
{
   public:
   CEmasBullBuyConfig() {}
};


//--- Strategy Configuration
struct SStrategyConfig
{
   bool enabled;
   CStrategyConfig *strategies[];
};

#endif