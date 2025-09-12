#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "2.00"

#include "factories/strategy_factory.mqh"
#include "strategies/strategies_types.mqh"
#include "strategies/strategy_base/strategy_base.mqh"

class STRATEGY_CTX
{
private:
   // Configurações e instâncias das estratégias
   CStrategyConfig *m_cfg[];
   CStrategyBase *m_strategies[];
   string m_names[];

   bool CreateStrategies();
   void AddStrategy(CStrategyBase *strategy, string name);

public:
   STRATEGY_CTX();
   ~STRATEGY_CTX();

};

STRATEGY_CTX::STRATEGY_CTX(){}

STRATEGY_CTX::~STRATEGY_CTX(){}

bool STRATEGY_CTX::CreateStrategies(){
   return true;
}

void STRATEGY_CTX::AddStrategy(CStrategyBase *strategy, string name){
   int pos = ArraySize(m_strategies);
   ArrayResize(m_strategies,pos+1);
   ArrayResize(m_names, pos +1);
   m_strategies[pos] = strategy;
   m_names[pos] = name;
}