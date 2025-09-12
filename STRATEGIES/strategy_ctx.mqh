#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "2.00"

#include "factories/strategy_factory.mqh"
#include "strategies/strategies_types.mqh" 

class STRATEGY_CTX
{
private:
   CStrategyConfig *m_cfg[];
   CStrategyBase *m_strategies[];

public:
   STRATEGY_CTX();
   ~STRATEGY_CTX();

};

STRATEGY_CTX::STRATEGY_CTX(){}

STRATEGY_CTX::~STRATEGY_CTX(){}