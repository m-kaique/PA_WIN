#ifndef __INDICATOR_FACTORY_MQH__
#define __INDICATOR_FACTORY_MQH__

#include "../indicators/ma/moving_averages.mqh"
#include "../indicators/stochastic/stochastic.mqh"
#include "../indicators/volume/volume.mqh"
#include "../indicators/vwap/vwap.mqh"
#include "../indicators/bollinger/bollinger.mqh"
#include "../indicators/fibonacci/fibonacci.mqh"
#include "../indicators/trendline/trendline.mqh"
#include "../indicators/sup_res/sup_res.mqh"
#include "../config_types.mqh"

// Creator function signature
typedef CIndicatorBase *(*IndicatorCreatorFunc)(string symbol, ENUM_TIMEFRAMES timeframe, CIndicatorConfig *config);

class CIndicatorFactory
{
private:
   struct SCreator
   {
      string type;
      IndicatorCreatorFunc func;
   };
   SCreator m_creators[];
   static CIndicatorFactory *s_instance;

   CIndicatorFactory()
   {
      ArrayResize(m_creators, 0);
      RegisterDefaults();
   }

   void RegisterDefaults();

   static CIndicatorBase *CreateMA(string symbol, ENUM_TIMEFRAMES tf, CIndicatorConfig *cfg);
   static CIndicatorBase *CreateSTO(string symbol, ENUM_TIMEFRAMES tf, CIndicatorConfig *cfg);
   static CIndicatorBase *CreateVOL(string symbol, ENUM_TIMEFRAMES tf, CIndicatorConfig *cfg);
   static CIndicatorBase *CreateVWAP(string symbol, ENUM_TIMEFRAMES tf, CIndicatorConfig *cfg);
   static CIndicatorBase *CreateBOLL(string symbol, ENUM_TIMEFRAMES tf, CIndicatorConfig *cfg);
   static CIndicatorBase *CreateFIBO(string symbol, ENUM_TIMEFRAMES tf, CIndicatorConfig *cfg);
   static CIndicatorBase *CreateTrendline(string Symbol, ENUM_TIMEFRAMES tf, CIndicatorConfig *cfg);
   static CIndicatorBase *CreateSupRes(string Symbol, ENUM_TIMEFRAMES tf, CIndicatorConfig *cfg);

public:
   static CIndicatorFactory *Instance()
   {
      if (s_instance == NULL)
         s_instance = new CIndicatorFactory();
      return s_instance;
   }

   bool Register(string type, IndicatorCreatorFunc func)
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

   CIndicatorBase *Create(string type, string symbol, ENUM_TIMEFRAMES tf, CIndicatorConfig *cfg)
   {
      for (int i = 0; i < ArraySize(m_creators); i++)
         if (m_creators[i].type == type)
            return m_creators[i].func(symbol, tf, cfg);
      return NULL;
   }
};

//--- Static member initialization
CIndicatorFactory *CIndicatorFactory::s_instance = NULL;

//--- Register default creators
void CIndicatorFactory::RegisterDefaults()
{
   Register("MA", CreateMA);
   Register("STO", CreateSTO);
   Register("VOL", CreateVOL);
   Register("VWAP", CreateVWAP);
   Register("BOLL", CreateBOLL);
   Register("FIBO", CreateFIBO);
   Register("TRENDLINE", CreateTrendline);
   Register("SUPRES", CreateSupRes);
}

CIndicatorBase *CIndicatorFactory::CreateMA(string symbol, ENUM_TIMEFRAMES tf, CIndicatorConfig *cfg)
{
   CMAConfig *c = (CMAConfig *)cfg;
   if (c == NULL)
      return NULL;
   CMovingAverages *ind = new CMovingAverages();
   if (ind != NULL && ind.Init(symbol, tf, *c))
      return ind;
   delete ind;
   return NULL;
}

CIndicatorBase *CIndicatorFactory::CreateSTO(string symbol, ENUM_TIMEFRAMES tf, CIndicatorConfig *cfg)
{
   CStochasticConfig *c = (CStochasticConfig *)cfg;
   if (c == NULL)
      return NULL;
   CStochastic *ind = new CStochastic();
   if (ind != NULL && ind.Init(symbol, tf, *c))
      return ind;
   delete ind;
   return NULL;
}

CIndicatorBase *CIndicatorFactory::CreateVOL(string symbol, ENUM_TIMEFRAMES tf, CIndicatorConfig *cfg)
{
   CVolumeConfig *c = (CVolumeConfig *)cfg;
   if (c == NULL)
      return NULL;
   CVolume *ind = new CVolume();
   if (ind != NULL && ind.Init(symbol, tf, c.shift, MODE_SMA))
      return ind;
   delete ind;
   return NULL;
}

CIndicatorBase *CIndicatorFactory::CreateVWAP(string symbol, ENUM_TIMEFRAMES tf, CIndicatorConfig *cfg)
{
   CVWAPConfig *c = (CVWAPConfig *)cfg;
   if (c == NULL)
      return NULL;
   CVWAP *ind = new CVWAP();
   if (ind != NULL && ind.Init(
                          symbol, tf, *c))
      return ind;
   delete ind;
   return NULL;
}

CIndicatorBase *CIndicatorFactory::CreateBOLL(string symbol, ENUM_TIMEFRAMES tf, CIndicatorConfig *cfg)
{
   CBollingerConfig *c = (CBollingerConfig *)cfg;
   if (c == NULL)
      return NULL;
   CBollinger *ind = new CBollinger();
   if (ind != NULL && ind.Init(symbol, tf, *c))
      return ind;
   delete ind;
   return NULL;
}

CIndicatorBase *CIndicatorFactory::CreateFIBO(string symbol, ENUM_TIMEFRAMES tf, CIndicatorConfig *cfg)
{
   CFiboConfig *c = (CFiboConfig *)cfg;
   if (c == NULL)
      return NULL;
   CFibonacci *ind = new CFibonacci();
   if (ind != NULL && ind.Init(symbol, tf, *c))
      return ind;
   delete ind;
   return NULL;
}

CIndicatorBase *CIndicatorFactory::CreateTrendline(string symbol, ENUM_TIMEFRAMES tf, CIndicatorConfig *cfg)
{
   CTrendLineConfig *c = (CTrendLineConfig *)cfg;
   if (c == NULL)
      return NULL;
   CTrendLine *ind = new CTrendLine();
   if (ind != NULL && ind.Init(symbol, tf, *c))
      return ind;
   delete ind;
   return NULL;
}

CIndicatorBase* CIndicatorFactory::CreateSupRes(string symbol, ENUM_TIMEFRAMES tf, CIndicatorConfig *cfg)
  {
   CSupResConfig *c = (CSupResConfig*)cfg;
   if(c==NULL)
      return NULL;
   CSupRes *ind = new CSupRes();
   if(ind!=NULL && ind.Init(symbol, tf, *c))
      return ind;
   delete ind;
   return NULL;
  }
#endif // __INDICATOR_FACTORY_MQH__
