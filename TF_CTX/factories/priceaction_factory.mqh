#ifndef __PRICEACTION_FACTORY_MQH__
#define __PRICEACTION_FACTORY_MQH__

#include "../priceaction/trendline/trendline.mqh"
#include "../priceaction/sup_res/sup_res.mqh"
#include "../priceaction/d1_analysis/d1_analysis.mqh"
#include "../config_types.mqh"

// Creator function signature
typedef CPriceActionBase* (*PriceActionCreatorFunc)(string symbol, ENUM_TIMEFRAMES timeframe, CPriceActionConfig *config);

class CPriceActionFactory
  {
private:
   struct SCreator
     {
      string type;
      PriceActionCreatorFunc func;
     };
   SCreator            m_creators[];
   static CPriceActionFactory *s_instance;

   CPriceActionFactory()
     {
      ArrayResize(m_creators,0);
      RegisterDefaults();
     }

  void RegisterDefaults();
  static CPriceActionBase* CreateTrendLine(string symbol, ENUM_TIMEFRAMES tf, CPriceActionConfig *cfg);
  static CPriceActionBase* CreateSupRes(string symbol, ENUM_TIMEFRAMES tf, CPriceActionConfig *cfg);
  static CPriceActionBase* CreateD1Analysis(string symbol, ENUM_TIMEFRAMES tf, CPriceActionConfig *cfg);

public:
   static CPriceActionFactory* Instance()
     {
      if(s_instance==NULL)
         s_instance=new CPriceActionFactory();
      return s_instance;
     }

   bool Register(string type, PriceActionCreatorFunc func)
     {
      for(int i=0;i<ArraySize(m_creators);i++)
         if(m_creators[i].type==type)
            return false;
      int pos=ArraySize(m_creators);
      ArrayResize(m_creators,pos+1);
      m_creators[pos].type=type;
      m_creators[pos].func=func;
      return true;
     }

   bool IsRegistered(string type)
     {
      for(int i=0;i<ArraySize(m_creators);i++)
         if(m_creators[i].type==type)
            return true;
      return false;
     }

   CPriceActionBase* Create(string type, string symbol, ENUM_TIMEFRAMES tf, CPriceActionConfig *cfg)
     {
      for(int i=0;i<ArraySize(m_creators);i++)
         if(m_creators[i].type==type)
            return m_creators[i].func(symbol,tf,cfg);
      return NULL;
     }
  };

//--- Static initialization
CPriceActionFactory* CPriceActionFactory::s_instance = NULL;

void CPriceActionFactory::RegisterDefaults()
  {
   Register("TRENDLINE", CreateTrendLine);
   Register("SUPRES",   CreateSupRes);
   Register("D1ANALYSIS", CreateD1Analysis);
  }

CPriceActionBase* CPriceActionFactory::CreateTrendLine(string symbol, ENUM_TIMEFRAMES tf, CPriceActionConfig *cfg)
  {
   CTrendLineConfig *c = (CTrendLineConfig*)cfg;
   if(c==NULL)
      return NULL;
   CTrendLine *pa = new CTrendLine();
   if(pa!=NULL && pa.Init(symbol, tf, *c))
      return pa;
  delete pa;
  return NULL;
  }

CPriceActionBase* CPriceActionFactory::CreateSupRes(string symbol, ENUM_TIMEFRAMES tf, CPriceActionConfig *cfg)
  {
   CSupResConfig *c = (CSupResConfig*)cfg;
   if(c==NULL)
      return NULL;
   CSupRes *pa = new CSupRes();
   if(pa!=NULL && pa.Init(symbol, tf, *c))
      return pa;
   delete pa;
   return NULL;
  }

CPriceActionBase* CPriceActionFactory::CreateD1Analysis(string symbol, ENUM_TIMEFRAMES tf, CPriceActionConfig *cfg)
  {
   CD1AnalysisConfig *c = (CD1AnalysisConfig*)cfg;
   if(c==NULL)
      return NULL;
   CD1Analysis *pa = new CD1Analysis();
   if(pa!=NULL && pa.Init(symbol, tf, *c))
      return pa;
   delete pa;
   return NULL;
  }

#endif // __PRICEACTION_FACTORY_MQH__
