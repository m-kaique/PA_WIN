#ifndef __PA_STRATEGY_FACTORY_MQH__
#define __PA_STRATEGY_FACTORY_MQH__

#include "../../interfaces/icontext_provider.mqh"
#include "../strategies/emas_bull_buy/emas_bull_buy.mqh"
#include "../strategies/strategies_types.mqh"
#include "../strategies/strategy_base/strategy_base.mqh"

// Creator function signature
typedef CStrategyBase *(*StrategyCreatorFunc)(string name, CStrategyConfig *config, IContextProvider *context_provider);

class CStrategyFactory
{
private:
   struct SStrategyCreator
   {
      string type;
      StrategyCreatorFunc func;
   };
   SStrategyCreator m_creators[];
   static CStrategyFactory *s_instance;

   CStrategyFactory()
   {
      ArrayResize(m_creators, 0);
      RegisterDefaults();
   }

   void RegisterDefaults();

   static CStrategyBase *CreateEmasBuyBull(string name, CStrategyConfig *cfg, IContextProvider *context_provider);
   // Adicionar outros creators conforme necessário
   // static CStrategyBase *CreateEmasSellBear(string name, CStrategyConfig *cfg);

public:
   static CStrategyFactory *Instance()
   {
      if (s_instance == NULL)
         s_instance = new CStrategyFactory();
      return s_instance;
   }

   bool Register(string type, StrategyCreatorFunc func)
   {
      for (int i = 0; i < ArraySize(m_creators); i++)
         if (m_creators[i].type == type)
            return false;
      int pos = ArraySize(m_creators);
      ArrayResize(m_creators, pos + 1);
      m_creators[pos].type = type;
      m_creators[pos].func = func;
      return true;
   }

   bool IsRegistered(string type)
   {
      for (int i = 0; i < ArraySize(m_creators); i++)
         if (m_creators[i].type == type)
            return true;
      return false;
   }

   CStrategyBase *Create(string type, string name, CStrategyConfig *cfg, IContextProvider *context_provider)
   {
      for (int i = 0; i < ArraySize(m_creators); i++)
         if (m_creators[i].type == type)
            return m_creators[i].func(name, cfg, context_provider);
      return NULL;
   }

   static void Cleanup()
   {
      if (s_instance != NULL)
      {
         delete s_instance;
         s_instance = NULL;
      }
   }
};

//--- Static member initialization
CStrategyFactory *CStrategyFactory::s_instance = NULL;

//--- Register default creators
void CStrategyFactory::RegisterDefaults()
{
   Register("emas_buy_bull", CreateEmasBuyBull);
   // Register("emas_sell_bear", CreateEmasSellBear);
}

CStrategyBase *CStrategyFactory::CreateEmasBuyBull(string name, CStrategyConfig *cfg, IContextProvider *context_provider)
{
    CEmasBullBuyConfig *c = (CEmasBullBuyConfig *)cfg;
    if (c == NULL)
       return NULL;
    CEmasBuyBull *strategy = new CEmasBuyBull(context_provider);
    if (strategy != NULL && strategy.Init(name, *c))
       return strategy;
    delete strategy;
    return NULL;
}

#endif // __PA_STRATEGY_FACTORY_MQH__