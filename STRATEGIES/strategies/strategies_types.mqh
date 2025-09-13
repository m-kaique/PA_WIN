#ifndef __STRATEGIES_TYPES_MQH__
#define __STRATEGIES_TYPES_MQH__

//+------------------------------------------------------------------+
//| Classe base para configuração de estratégias                    |
//+------------------------------------------------------------------+
class CStrategyConfig
{
public:
   string name;
   string type;
   bool enabled;
   CStrategyConfig()
   {
      name = "";
      type = "";
      enabled = false;
   }
   virtual ~CStrategyConfig() {}
};

//+------------------------------------------------------------------+
//| Configuração para estratégia EMA Buy Bull                       |
//+------------------------------------------------------------------+
class CEmasBullBuyConfig : public CStrategyConfig
{
public:
   int ema_fast_period;
   int ema_slow_period;
   double risk_percent;
   double stop_loss_pips;
   double take_profit_ratio;
   
   CEmasBullBuyConfig()
   {
      type = "emas_buy_bull";
      ema_fast_period = 21;
      ema_slow_period = 50;
      risk_percent = 1.0;
      stop_loss_pips = 50.0;
      take_profit_ratio = 2.0;
   }
};

//--- Strategy Configuration
struct SStrategyConfig
{
   bool enabled;
   CStrategyConfig *strategies[];
};

#endif